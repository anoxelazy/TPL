import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// รายการสินค้าเสียหายที่ยังอยู่ในเครื่อง เก็บใน SQLite (`claims.db`)
///
/// หน้าจออ่านจากรายการใน memory ([claims]) ซึ่งตอบทันที ส่วนการเขียนลง
/// ฐานข้อมูลเข้าคิวทำเบื้องหลังทีละแถว ([flush] ใช้รอให้คิวว่าง)
///
/// เดิมเก็บเป็นไฟล์ JSON ไฟล์เดียวแล้วเขียนทับทั้งไฟล์ทุกครั้งที่แก้อะไร
/// เปลี่ยนเป็น SQLite ให้แก้ทีละแถวได้ และไม่ต้องเขียนไฟล์ทั้งก้อนใหม่ทุกครั้ง
/// ไฟล์ JSON เก่าที่ค้างในเครื่องถูกย้ายเข้าฐานข้อมูลให้เองตอนเปิดครั้งแรก
///
/// รูปถ่ายยังเป็นไฟล์ในโฟลเดอร์ `claim_images/<id>/` ฐานข้อมูลเก็บแค่ที่อยู่
/// ไฟล์ (แบบ relative) ไม่เก็บตัวรูป รูปหลายเมกะไบต์ในฐานข้อมูลจะทำให้อ่านช้า
class ClaimStore {
  ClaimStore._();
  static final ClaimStore I = ClaimStore._();

  static const String _dbName = 'claims.db';
  static const String _table = 'claims';
  static const int _dbVersion = 1;

  /// ไฟล์ JSON ของเวอร์ชันก่อน อ่านครั้งเดียวตอนย้ายเข้า SQLite
  static const String _legacyFileName = 'claims.json';

  static const String _imageDirName = 'claim_images';
  static const String thumbSuffix = '.thumb.jpg';

  /// ใช้ในเทสต์เท่านั้น: โรงงานฐานข้อมูลแบบ FFI ที่รันบนเครื่องพัฒนาได้
  /// ในแอปจริงใช้ของ sqflite ตามปกติ
  @visibleForTesting
  static DatabaseFactory? debugDatabaseFactory;

  final List<Map<String, dynamic>> _claims = [];

  Directory? _rootDir;
  Future<Database>? _dbFuture;
  Future<void>? _initFuture;
  Future<void> _writeQueue = Future.value();
  Timer? _midnightTimer;

  /// ลำดับถัดไปของรายการใหม่ ใช้เรียงให้ตรงกับลำดับที่บันทึก
  int _nextSeq = 1;

  /// เพิ่มค่าเมื่อรายการถูกเปลี่ยนจากภายนอกหน้าจอ (เช่นถูกลบเพราะหมดอายุ)
  /// ให้หน้าจอ listen ไว้เพื่อ refresh ตัวเอง
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// จำนวนรายการที่ถูกลบเพราะหมดอายุในรอบล่าสุด
  int lastPurgedCount = 0;

  List<Map<String, dynamic>> get claims => List.unmodifiable(_claims);

  int get count => _claims.length;

  int get unsentCount => _claims.where((c) => c['isSent'] != true).length;

  /// ตัวเลขของแถบสรุปบนหน้ารายการ ส่งสำเร็จ / รอส่ง / ส่งไม่สำเร็จ
  ///
  /// นับจากรายการที่อยู่ในเครื่องตอนนี้ ซึ่งเป็นของวันนี้เท่านั้น
  /// (ของวันก่อนถูกลบตอนเที่ยงคืนด้วย [purgeExpired]) ตัวเลขจึงเริ่มใหม่ทุกวันเอง
  /// ไม่ต้องเก็บตัวนับแยก
  int get sentCount => _claims.where((c) => c['isSent'] == true).length;

  int get failedCount => _claims
      .where((c) => c['isSent'] != true && c['sendFailed'] == true)
      .length;

  int get pendingCount => _claims
      .where((c) => c['isSent'] != true && c['sendFailed'] != true)
      .length;

  /// โหลดรายการที่ค้างไว้จากฐานข้อมูล เรียกซ้ำได้ (ทำงานจริงครั้งเดียว)
  Future<void> init() => _initFuture ??= _load();

  /// รอให้การเขียนลงฐานข้อมูลที่ค้างอยู่เสร็จ
  Future<void> flush() => _writeQueue;

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
    claim['seq'] = _nextSeq++;
    _claims.add(claim);
    _enqueueUpsert(claim);
  }

  void updateClaim(int index, Map<String, dynamic> claim) {
    if (index < 0 || index >= _claims.length) return;
    final old = _claims[index];
    // คงตำแหน่งเดิมในรายการไว้ แก้ไขแล้วไม่กระโดดไปอยู่ท้ายสุด
    claim['seq'] = old['seq'] ?? _nextSeq++;
    _claims[index] = claim;

    final oldId = old['id']?.toString();
    if (oldId != null && oldId != claim['id']?.toString()) {
      _enqueueDelete([oldId]);
    }
    _enqueueUpsert(claim);
  }

  void removeClaim(int index) {
    if (index >= 0 && index < _claims.length) {
      final removed = _claims.removeAt(index);
      final id = removed['id']?.toString();
      if (id != null) _enqueueDelete([id]);
      _deleteImageDir(id);
    }
  }

  void markAsSent(int index) {
    if (index >= 0 && index < _claims.length) {
      _claims[index]['isSent'] = true;
      // ส่งใหม่สำเร็จแล้ว ความล้มเหลวรอบก่อนไม่มีความหมายอีก
      _claims[index].remove('sendFailed');
      _enqueueUpsert(_claims[index]);
    }
  }

  /// จำว่ารายการนี้ส่งไม่สำเร็จ ให้แถบสรุปกับการ์ดบอกผู้ใช้ว่าต้องส่งใหม่
  ///
  /// รายการที่เคยส่งสำเร็จแล้วแต่กดส่งซ้ำไม่ผ่าน ไม่นับเป็นไม่สำเร็จ
  /// ข้อมูลขึ้น Sheet ไปแล้วตั้งแต่รอบแรก
  void markSendFailed(int index) {
    if (index < 0 || index >= _claims.length) return;
    if (_claims[index]['isSent'] == true) return;
    _claims[index]['sendFailed'] = true;
    _enqueueUpsert(_claims[index]);
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
    _enqueueDelete([
      for (final c in expired)
        if (c['id'] != null) c['id'].toString(),
    ]);

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
    _enqueue((db) => db.delete(_table));
    await flush();
    await _deleteAllImages();
  }

  // ------------------------------------------------------------ ฐานข้อมูล

  Future<Database> _open() async {
    final root = await _root();
    final factory = debugDatabaseFactory ?? databaseFactory;
    return factory.openDatabase(
      p.join(root.path, _dbName),
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onCreate: (db, version) => db.execute('''
          CREATE TABLE $_table (
            id TEXT PRIMARY KEY,
            seq INTEGER NOT NULL,
            doc_number TEXT NOT NULL DEFAULT '',
            type TEXT NOT NULL DEFAULT '',
            car_code TEXT NOT NULL DEFAULT '',
            timestamp TEXT NOT NULL,
            created_at TEXT NOT NULL,
            images TEXT NOT NULL DEFAULT '[]',
            emp_id TEXT NOT NULL DEFAULT '',
            remark_type TEXT,
            is_sent INTEGER NOT NULL DEFAULT 0,
            send_failed INTEGER NOT NULL DEFAULT 0,
            from_front_store INTEGER NOT NULL DEFAULT 0,
            uploaded_links TEXT NOT NULL DEFAULT '[]'
          )
        '''),
      ),
    );
  }

  Future<void> _load() async {
    bool loaded = false;
    try {
      final root = await _root();
      final db = await _database();

      await _migrateLegacyJson(db, root);

      final rows = await db.query(_table, orderBy: 'seq ASC');
      _claims.clear();
      for (final row in rows) {
        final claim = await _fromRow(row, root);
        if (claim != null) _claims.add(claim);
      }
      _nextSeq =
          _claims.fold<int>(
            0,
            (max, c) => (c['seq'] as int) > max ? c['seq'] as int : max,
          ) +
          1;
      loaded = true;
      debugPrint('ClaimStore: loaded ${_claims.length} claims');
    } catch (e) {
      // เปิดฐานข้อมูลไม่ได้ ยังใช้งานต่อได้ในรอบนี้ แค่ไม่ได้บันทึกลงเครื่อง
      debugPrint('ClaimStore: load failed: $e');
    }

    if (loaded) {
      // ฟอร์มของวันก่อนหน้าหมดอายุแล้ว (กรณีปิดแอปข้ามคืนไว้)
      await purgeExpired();
      // ลบโฟลเดอร์รูปที่ไม่มีรายการอ้างถึงแล้ว (เช่นแอปถูก kill กลางการบันทึก)
      // ทำเฉพาะตอนโหลดสำเร็จ ไม่งั้นอาจลบรูปของรายการที่ยังอยู่
      await _pruneOrphanDirs();
    }
  }

  /// ย้ายรายการจากไฟล์ JSON ของเวอร์ชันก่อนเข้าฐานข้อมูล แล้วเปลี่ยนชื่อไฟล์
  /// เก่าเป็น `.migrated` (ไม่ลบทิ้ง เผื่อต้องกู้คืน)
  ///
  /// ย้ายเฉพาะตอนตารางยังว่าง ถ้าเคยย้ายแล้วหรือมีรายการใหม่อยู่แล้ว
  /// จะไม่เอาของเก่ามาซ้อน
  Future<void> _migrateLegacyJson(Database db, Directory root) async {
    final file = File(p.join(root.path, _legacyFileName));
    if (!await file.exists()) return;

    final existing = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_table'),
    );
    if ((existing ?? 0) == 0) {
      final raw = await file.readAsString();
      final decoded = raw.trim().isEmpty ? null : jsonDecode(raw);
      final list = (decoded is Map) ? decoded['claims'] : null;
      if (list is List) {
        final batch = db.batch();
        var seq = 1;
        for (final item in list) {
          if (item is! Map) continue;
          final json = Map<String, dynamic>.from(item);
          final id = json['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          batch.insert(
            _table,
            _legacyToRow(json, seq++),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
        debugPrint('ClaimStore: migrated ${seq - 1} claims from JSON');
      }
    }
    await file.rename(p.join(root.path, '$_legacyFileName.migrated'));
  }

  /// แถวฐานข้อมูลจากข้อมูลรูปแบบ JSON เดิม (ฟิลด์ชื่อเดียวกับ map ในแอป)
  Map<String, Object?> _legacyToRow(Map<String, dynamic> json, int seq) {
    final timestamp = json['timestamp']?.toString() ?? '';
    return {
      'id': json['id'].toString(),
      'seq': seq,
      'doc_number': json['docNumber']?.toString() ?? '',
      'type': json['type']?.toString() ?? 'เสียหาย',
      'car_code': json['carCode']?.toString() ?? '',
      'timestamp': timestamp.isEmpty
          ? DateTime.now().toIso8601String()
          : timestamp,
      // ข้อมูลเก่าที่ยังไม่มี createdAt ใช้วันที่ของรายการคิดอายุแทน
      'created_at':
          json['createdAt']?.toString() ??
          (timestamp.isEmpty ? DateTime.now().toIso8601String() : timestamp),
      'images': jsonEncode(
        (json['images'] is List)
            ? (json['images'] as List).map((e) => e.toString()).toList()
            : const <String>[],
      ),
      'emp_id': json['empID']?.toString() ?? '',
      'remark_type': json['remarkType']?.toString(),
      'is_sent': json['isSent'] == true ? 1 : 0,
      'send_failed': json['sendFailed'] == true ? 1 : 0,
      'from_front_store': json['fromFrontStore'] == true ? 1 : 0,
      'uploaded_links': jsonEncode(
        (json['uploadedLinks'] is List)
            ? (json['uploadedLinks'] as List).map((e) => e.toString()).toList()
            : const <String>[],
      ),
    };
  }

  Future<Map<String, dynamic>?> _fromRow(
    Map<String, Object?> row,
    Directory root,
  ) async {
    final String id = row['id']?.toString() ?? '';
    if (id.isEmpty) return null;

    final List<File> images = [];
    for (final rel in _decodeList(row['images'])) {
      final file = File(p.normalize(p.join(root.path, rel)));
      if (await file.exists()) {
        images.add(file);
      } else {
        debugPrint('ClaimStore: image missing, skipped: $rel');
      }
    }

    final timestamp =
        DateTime.tryParse(row['timestamp']?.toString() ?? '') ?? DateTime.now();
    return <String, dynamic>{
      'id': id,
      'seq': (row['seq'] as num?)?.toInt() ?? 0,
      'docNumber': row['doc_number']?.toString() ?? '',
      'type': row['type']?.toString() ?? 'เสียหาย',
      'carCode': row['car_code']?.toString() ?? '',
      'timestamp': timestamp,
      'createdAt':
          DateTime.tryParse(row['created_at']?.toString() ?? '') ?? timestamp,
      'images': images,
      'empID': row['emp_id']?.toString() ?? '',
      'remarkType': row['remark_type']?.toString(),
      'isSent': row['is_sent'] == 1,
      if (row['send_failed'] == 1) 'sendFailed': true,
      'fromFrontStore': row['from_front_store'] == 1,
      'uploadedLinks': _decodeList(row['uploaded_links']),
    };
  }

  Map<String, Object?> _toRow(Map<String, dynamic> claim, Directory root) {
    final images = List<File>.from(claim['images'] ?? const <File>[]);
    final timestamp = claim['timestamp'];
    final links = claim['uploadedLinks'];
    return {
      'id': claim['id']?.toString() ?? _newId(),
      'seq': (claim['seq'] as int?) ?? 0,
      'doc_number': claim['docNumber']?.toString() ?? '',
      'type': claim['type']?.toString() ?? '',
      'car_code': claim['carCode']?.toString() ?? '',
      'timestamp': (timestamp is DateTime ? timestamp : DateTime.now())
          .toIso8601String(),
      'created_at': _createdAt(claim).toIso8601String(),
      'images': jsonEncode(
        images.map((f) => p.relative(f.path, from: root.path)).toList(),
      ),
      'emp_id': claim['empID']?.toString() ?? '',
      'remark_type': claim['remarkType']?.toString(),
      'is_sent': claim['isSent'] == true ? 1 : 0,
      'send_failed': claim['sendFailed'] == true ? 1 : 0,
      'from_front_store': claim['fromFrontStore'] == true ? 1 : 0,
      'uploaded_links': jsonEncode(
        (links is List) ? links.map((e) => e.toString()).toList() : const [],
      ),
    };
  }

  List<String> _decodeList(Object? raw) {
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {}
    return const [];
  }

  /// ฐานข้อมูลที่เปิดแล้ว เปิดครั้งเดียวแล้วใช้ร่วมกันทั้งตอนโหลดและตอนเขียน
  ///
  /// ไม่ต้องรอ [init] ก่อนเขียน รายการที่บันทึกก่อนโหลดเสร็จก็ลงฐานข้อมูลได้
  ///
  /// เปิดไม่สำเร็จก็ไม่จำความล้มเหลวไว้ ครั้งหน้าลองเปิดใหม่ (พลาดชั่วคราว
  /// ครั้งเดียวไม่ควรทำให้บันทึกไม่ได้ไปจนปิดแอป)
  Future<Database> _database() {
    return _dbFuture ??= _open().catchError((Object e) {
      _dbFuture = null;
      throw e;
    });
  }

  /// เขียนลงฐานข้อมูลตามลำดับที่สั่ง ไม่ให้สองคำสั่งแซงกัน
  ///
  /// เปิดฐานข้อมูลไม่ได้ก็แค่ log ไว้ รายการใน memory ยังใช้งานได้ตามปกติ
  void _enqueue(Future<Object?> Function(Database db) op) {
    _writeQueue = _writeQueue
        .then((_) async => op(await _database()))
        .catchError((Object e) {
          debugPrint('ClaimStore: write failed: $e');
          return null;
        });
  }

  void _enqueueUpsert(Map<String, dynamic> claim) {
    // แปลงเป็นแถวตอนนี้เลยถ้าทำได้ ไม่ใช่ตอนคิวถึง ไม่งั้นค่าที่แก้ทีหลัง
    // จะหลุดเข้าไปก่อนลำดับของมัน
    final root = _rootDir;
    final row = root == null ? null : _toRow(claim, root);
    _enqueue(
      (db) async => db.insert(
        _table,
        row ?? _toRow(claim, await _root()),
        conflictAlgorithm: ConflictAlgorithm.replace,
      ),
    );
  }

  void _enqueueDelete(List<String> ids) {
    if (ids.isEmpty) return;
    final marks = List.filled(ids.length, '?').join(',');
    _enqueue(
      (db) => db.delete(_table, where: 'id IN ($marks)', whereArgs: ids),
    );
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
  ///
  /// ปิดฐานข้อมูลเดิมก่อน เทสต์จะได้เปิดใหม่จากไฟล์ในเครื่องเหมือนเปิดแอปใหม่
  @visibleForTesting
  Future<void> debugUseDirectory(Directory dir) async {
    stopAutoPurge();
    await flush();
    final db = _dbFuture;
    _dbFuture = null;
    try {
      await (await db)?.close();
    } catch (_) {
      // เปิดไม่สำเร็จตั้งแต่แรก ไม่มีอะไรให้ปิด
    }
    _rootDir = dir;
    _initFuture = null;
    _writeQueue = Future.value();
    _nextSeq = 1;
    lastPurgedCount = 0;
    _claims.clear();
  }

  Future<Directory> _imageDir(String claimId) async {
    final dir = Directory(p.join((await _root()).path, _imageDirName, claimId));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
