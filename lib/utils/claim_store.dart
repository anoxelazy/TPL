import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ClaimStore {
  ClaimStore._();
  static final ClaimStore I = ClaimStore._();

  static const String _fileName = 'claims.json';
  static const String _imageDirName = 'claim_images';
  static const String thumbSuffix = '.thumb.jpg';
  static const int _schemaVersion = 1;

  final List<Map<String, dynamic>> _claims = [];

  Directory? _rootDir;
  Future<void>? _initFuture;
  Future<void> _saveQueue = Future.value();
  Timer? _midnightTimer;

  /// เพิ่มค่าเมื่อรายการถูกเปลี่ยนจากภายนอกหน้าจอ (เช่นถูกลบเพราะหมดอายุ)
  /// ให้หน้าจอ listen ไว้เพื่อ refresh ตัวเอง
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// จำนวนรายการที่ถูกลบเพราะหมดอายุในรอบล่าสุด
  int lastPurgedCount = 0;

  List<Map<String, dynamic>> get claims => List.unmodifiable(_claims);

  int get count => _claims.length;

  int get unsentCount => _claims.where((c) => c['isSent'] != true).length;

  /// โหลดรายการที่ค้างไว้จากดิสก์ เรียกซ้ำได้ (ทำงานจริงครั้งเดียว)
  Future<void> init() => _initFuture ??= _load();

  /// รอให้การเขียนลงดิสก์ที่ค้างอยู่เสร็จ
  Future<void> flush() => _saveQueue;

  /// เตรียมรายการก่อนบันทึก: ใส่ id และคัดลอกรูปไปโฟลเดอร์ถาวร
  /// ส่ง [id] เดิมเข้ามาเมื่อเป็นการแก้ไขรายการที่มีอยู่แล้ว
  Future<Map<String, dynamic>> prepareClaim(
    Map<String, dynamic> claim, {
    String? id,
  }) async {
    final String claimId = (id == null || id.isEmpty) ? _newId() : id;
    final result = Map<String, dynamic>.from(claim);
    result['id'] = claimId;
    // วันที่สร้างใช้คิดอายุของฟอร์ม การแก้ไขไม่ต่ออายุให้ (คงค่าเดิมไว้)
    result['createdAt'] = _resolveCreatedAt(claim, claimId);
    result['images'] = await _persistImages(
      claimId,
      List<File>.from(claim['images'] ?? const <File>[]),
    );
    return result;
  }

  DateTime _resolveCreatedAt(Map<String, dynamic> claim, String claimId) {
    final provided = claim['createdAt'];
    if (provided is DateTime) return provided;
    final parsed = DateTime.tryParse(provided?.toString() ?? '');
    if (parsed != null) return parsed;
    for (final existing in _claims) {
      if (existing['id']?.toString() == claimId) return _createdAt(existing);
    }
    return DateTime.now();
  }

  void addClaim(Map<String, dynamic> claim) {
    _claims.add(claim);
    _scheduleSave();
  }

  void updateClaim(int index, Map<String, dynamic> claim) {
    if (index >= 0 && index < _claims.length) {
      _claims[index] = claim;
      _scheduleSave();
    }
  }

  void removeClaim(int index) {
    if (index >= 0 && index < _claims.length) {
      final removed = _claims.removeAt(index);
      _scheduleSave();
      _deleteImageDir(removed['id']?.toString());
    }
  }

  void markAsSent(int index) {
    if (index >= 0 && index < _claims.length) {
      _claims[index]['isSent'] = true;
      _scheduleSave();
    }
  }

  // ------------------------------------------------------------- อายุของฟอร์ม

  /// ลบรายการที่สร้างก่อนวันนี้ทั้งหมด (ฟอร์มมีอายุแค่ภายในวันที่สร้าง)
  /// คืนค่าจำนวนรายการที่ถูกลบ
  Future<int> purgeExpired({DateTime? now}) async {
    final DateTime today = _startOfDay(now ?? DateTime.now());
    final expired = _claims
        .where((c) => _createdAt(c).isBefore(today))
        .toList();
    if (expired.isEmpty) return 0;

    _claims.removeWhere((c) => expired.any((e) => identical(e, c)));
    lastPurgedCount = expired.length;
    _scheduleSave();

    for (final claim in expired) {
      debugPrint(
        'ClaimStore: expired claim removed '
        '${claim['docNumber']} (${_createdAt(claim)})',
      );
      await _deleteImageDir(claim['id']?.toString());
    }
    await flush();
    revision.value++;
    return expired.length;
  }

  /// ตั้งเวลาลบรายการที่หมดอายุตอนเที่ยงคืน แล้วตั้งรอบถัดไปต่อเนื่อง
  /// (ใช้ตอนแอปเปิดค้างข้ามวัน ส่วนตอนเปิดแอป/กลับมาจาก background
  /// ให้เรียก [purgeExpired] เพราะ timer อาจไม่ทำงานขณะระบบพักแอป)
  void startAutoPurge() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 1),
      () async {
        await purgeExpired();
        startAutoPurge();
      },
    );
  }

  void stopAutoPurge() {
    _midnightTimer?.cancel();
    _midnightTimer = null;
  }

  DateTime _createdAt(Map<String, dynamic> claim) {
    final value = claim['createdAt'];
    if (value is DateTime) return value;
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
    // ข้อมูลเก่าที่ยังไม่มี createdAt ใช้วันที่ของรายการแทน
    final timestamp = claim['timestamp'];
    return timestamp is DateTime ? timestamp : DateTime.now();
  }

  DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// ล้างรายการทั้งหมดพร้อมรูปภาพในเครื่อง (ใช้ตอน logout)
  Future<void> clear() async {
    // ตอนเปิดแอปไม่ได้รอโหลดให้เสร็จก่อนแล้ว ถ้าล้างระหว่างที่ยังโหลดอยู่
    // ของเก่าจะไหลกลับเข้ามาทีหลัง
    await init();
    _claims.clear();
    _scheduleSave();
    await flush();
    await _deleteAllImages();
  }

  // ---------------------------------------------------------------- โหลด/บันทึก

  Future<void> _load() async {
    bool parsed = false;
    try {
      final root = await _root();
      final file = File(p.join(root.path, _fileName));
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.trim().isNotEmpty) {
          final decoded = jsonDecode(raw);
          final list = (decoded is Map) ? decoded['claims'] : null;
          if (list is List) {
            _claims.clear();
            for (final item in list) {
              if (item is! Map) continue;
              final claim = await _fromJson(
                Map<String, dynamic>.from(item),
                root,
              );
              if (claim != null) _claims.add(claim);
            }
            parsed = true;
          }
        } else {
          parsed = true;
        }
      } else {
        parsed = true;
      }
      debugPrint('ClaimStore: loaded ${_claims.length} claims');
    } catch (e) {
      debugPrint('ClaimStore: load failed: $e');
    }

    if (parsed) {
      // ฟอร์มของวันก่อนหน้าหมดอายุแล้ว (กรณีปิดแอปข้ามคืนไว้)
      await purgeExpired();
      // ลบโฟลเดอร์รูปที่ไม่มีรายการอ้างถึงแล้ว (เช่นแอปถูก kill กลางการบันทึก)
      // ทำเฉพาะตอนอ่านไฟล์สำเร็จ ไม่งั้นอาจลบรูปของรายการที่ยังอยู่
      await _pruneOrphanDirs();
    }
  }

  Future<Map<String, dynamic>?> _fromJson(
    Map<String, dynamic> json,
    Directory root,
  ) async {
    final String id = json['id']?.toString() ?? '';
    if (id.isEmpty) return null;

    final List<File> images = [];
    final rawImages = json['images'];
    if (rawImages is List) {
      for (final rel in rawImages) {
        final file = File(p.normalize(p.join(root.path, rel.toString())));
        if (await file.exists()) {
          images.add(file);
        } else {
          debugPrint('ClaimStore: image missing, skipped: $rel');
        }
      }
    }

    final rawLinks = json['uploadedLinks'];
    return <String, dynamic>{
      'id': id,
      'docNumber': json['docNumber']?.toString() ?? '',
      'type': json['type']?.toString() ?? 'เสียหาย',
      'carCode': json['carCode']?.toString() ?? '',
      'timestamp':
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      'createdAt':
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      'images': images,
      'empID': json['empID']?.toString() ?? '',
      'remarkType': json['remarkType']?.toString(),
      'isSent': json['isSent'] == true,
      'fromFrontStore': json['fromFrontStore'] == true,
      if (rawLinks is List)
        'uploadedLinks': rawLinks.map((e) => e.toString()).toList(),
    };
  }

  Map<String, dynamic> _toJson(Map<String, dynamic> claim, Directory root) {
    final images = List<File>.from(claim['images'] ?? const <File>[]);
    final timestamp = claim['timestamp'];
    final links = claim['uploadedLinks'];
    return <String, dynamic>{
      'id': claim['id']?.toString() ?? _newId(),
      'docNumber': claim['docNumber']?.toString() ?? '',
      'type': claim['type']?.toString() ?? '',
      'carCode': claim['carCode']?.toString() ?? '',
      'timestamp': (timestamp is DateTime ? timestamp : DateTime.now())
          .toIso8601String(),
      'createdAt': _createdAt(claim).toIso8601String(),
      'images': images.map((f) => p.relative(f.path, from: root.path)).toList(),
      'empID': claim['empID']?.toString() ?? '',
      'remarkType': claim['remarkType']?.toString(),
      'isSent': claim['isSent'] == true,
      'fromFrontStore': claim['fromFrontStore'] == true,
      'uploadedLinks': (links is List)
          ? links.map((e) => e.toString()).toList()
          : const <String>[],
    };
  }

  void _scheduleSave() {
    _saveQueue = _saveQueue.then((_) => _save()).catchError((Object e) {
      debugPrint('ClaimStore: save failed: $e');
    });
  }

  Future<void> _save() async {
    final root = await _root();
    final payload = jsonEncode({
      'version': _schemaVersion,
      'claims': _claims.map((c) => _toJson(c, root)).toList(),
    });
    // เขียนไฟล์ชั่วคราวแล้ว rename เพื่อไม่ให้ไฟล์พังถ้าแอปตายกลางการเขียน
    final tmp = File(p.join(root.path, '$_fileName.tmp'));
    await tmp.writeAsString(payload, flush: true);
    await tmp.rename(p.join(root.path, _fileName));
  }

  // ------------------------------------------------------------------- รูปภาพ

  Future<List<File>> _persistImages(String claimId, List<File> images) async {
    try {
      final dir = await _imageDir(claimId);
      final List<File> saved = [];
      final Set<String> keep = {};

      for (int i = 0; i < images.length; i++) {
        final source = images[i];
        if (p.equals(p.dirname(source.path), dir.path)) {
          // อยู่ในโฟลเดอร์ถาวรแล้ว (แก้ไขรายการเดิม) ไม่ต้องคัดลอกทับตัวเอง
          saved.add(source);
          keep.add(p.normalize(source.path));
          continue;
        }
        if (!await source.exists()) {
          debugPrint('ClaimStore: source image gone: ${source.path}');
          continue;
        }
        final ext = p.extension(source.path);
        final name =
            'img_${DateTime.now().microsecondsSinceEpoch}_$i'
            '${ext.isEmpty ? '.jpg' : ext}';
        final copied = await source.copy(p.join(dir.path, name));
        saved.add(copied);
        keep.add(p.normalize(copied.path));
      }

      await _pruneImageDir(dir, keep);
      return saved;
    } catch (e) {
      debugPrint('ClaimStore: persist images failed: $e');
      // ยังส่งงานรอบนี้ได้ด้วยไฟล์เดิม แต่จะไม่รอดถ้าปิดแอป
      return images;
    }
  }

  /// ลบไฟล์ในโฟลเดอร์ที่ไม่ได้ใช้แล้ว (เช่นรูปที่ผู้ใช้ลบออกจากฟอร์ม)
  /// เก็บ thumbnail ของรูปที่ยังอยู่ไว้
  Future<void> _pruneImageDir(Directory dir, Set<String> keep) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final path = p.normalize(entity.path);
        if (keep.contains(path)) continue;
        if (path.endsWith(thumbSuffix) &&
            keep.contains(
              path.substring(0, path.length - thumbSuffix.length),
            )) {
          continue;
        }
        await entity.delete();
      }
    } catch (e) {
      debugPrint('ClaimStore: prune failed: $e');
    }
  }

  Future<void> _pruneOrphanDirs() async {
    try {
      final base = Directory(p.join((await _root()).path, _imageDirName));
      if (!await base.exists()) return;
      final ids = _claims.map((c) => c['id']?.toString()).toSet();
      await for (final entity in base.list()) {
        if (entity is! Directory) continue;
        if (ids.contains(p.basename(entity.path))) continue;
        debugPrint('ClaimStore: removing orphan images ${entity.path}');
        await entity.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('ClaimStore: prune orphan failed: $e');
    }
  }

  Future<void> _deleteImageDir(String? claimId) async {
    if (claimId == null || claimId.isEmpty) return;
    try {
      final dir = Directory(
        p.join((await _root()).path, _imageDirName, claimId),
      );
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('ClaimStore: delete images failed: $e');
    }
  }

  Future<void> _deleteAllImages() async {
    try {
      final base = Directory(p.join((await _root()).path, _imageDirName));
      if (await base.exists()) await base.delete(recursive: true);
    } catch (e) {
      debugPrint('ClaimStore: delete all images failed: $e');
    }
  }

  // ------------------------------------------------------------------- helpers

  String _newId() => 'claim_${DateTime.now().microsecondsSinceEpoch}';

  Future<Directory> _root() async {
    return _rootDir ??= await getApplicationDocumentsDirectory();
  }

  /// ใช้ในเทสต์เท่านั้น: กำหนดโฟลเดอร์เก็บข้อมูลและรีเซ็ตสถานะใน memory
  @visibleForTesting
  void debugUseDirectory(Directory dir) {
    stopAutoPurge();
    _rootDir = dir;
    _initFuture = null;
    lastPurgedCount = 0;
    _claims.clear();
  }

  Future<Directory> _imageDir(String claimId) async {
    final dir = Directory(p.join((await _root()).path, _imageDirName, claimId));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
