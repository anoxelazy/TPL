import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/utils/dio_service.dart';
import 'package:claim/utils/permission_service.dart';
import 'package:claim/utils/role_service.dart';
import 'package:claim/utils/update_service.dart';

const String kAnnouncementJsonUrl =
    'https://raw.githubusercontent.com/anoxelazy/API_json/main/announcement.json';

const String _cacheKey = 'announcement_json';
const String _dismissedKey = 'announcement_dismissed';

/// ประกาศ 1 ก้อนจาก announcement.json
class Announcement {
  /// ใช้จำว่าผู้ใช้กด "ไม่แสดงอีก" ของอันไหนไปแล้ว ห้ามซ้ำกับก้อนอื่น
  final String id;
  final String title;
  final String message;
  final String link;
  final String linkLabel;

  /// ใส่มาแล้วจะแสดงเป็นรูปเต็มจอแทนกล่องข้อความ
  final String image;

  /// เงื่อนไขการแสดง ค่าว่าง = ไม่กรอง ทุกคนเห็น
  final String branch;
  final String role;
  final String minVersion;
  final String showUntil;

  final bool active;

  const Announcement({
    required this.id,
    required this.title,
    required this.message,
    required this.link,
    required this.linkLabel,
    required this.image,
    required this.branch,
    required this.role,
    required this.minVersion,
    required this.showUntil,
    required this.active,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
    id: _str(json['id']),
    title: _str(json['title']),
    message: _str(json['message']),
    link: _str(json['link']),
    linkLabel: _str(json['link_label']),
    image: _str(json['image']),
    branch: _str(json['branch']),
    role: _str(json['role']),
    minVersion: _str(json['min_version']),
    showUntil: _str(json['show_until']),
    // ไม่ใส่ active มาถือว่าเปิด จะได้ไม่ต้องใส่ทุกก้อน
    active: json['active'] == null || json['active'] == true,
  );

  bool get hasLink => link.startsWith('http');

  bool get hasImage => image.startsWith('http');
}

/// ประกาศจากส่วนกลาง เด้งตอนเปิดแอป กด "ไม่แสดงอีก" แล้วจำเป็นราย id
///
/// เก็บว่าปิดอันไหนไปแล้วในเครื่อง แยกตามรหัสพนักงาน ตัว json ไม่ต้องรู้เรื่องนี้
/// จึงเป็นไฟล์นิ่งบน GitHub ได้ ไม่ต้องมี backend
class AnnouncementService {
  AnnouncementService._();

  static final AnnouncementService I = AnnouncementService._();

  /// กันเด้งซ้ำระหว่างอยู่ในแอปรอบเดียวกัน "ปิด" = ไปเจอใหม่รอบเปิดแอปหน้า
  /// ไม่ใช่ทุกครั้งที่สลับกลับเข้าแอป
  final Set<String> _shownThisSession = {};

  bool _showing = false;

  /// หาประกาศที่เข้าเงื่อนไขแล้วแสดง ไม่มีก็เงียบ
  ///
  /// ไม่ throw เพราะเป็นงานเสริม โหลดไม่ได้ต้องไม่กระทบการเปิดแอป
  Future<void> showIfAny(BuildContext context) async {
    if (_showing) return;
    _showing = true;

    try {
      final list = await _load();
      if (list.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final empId = prefs.getString('driverID') ?? '';
      final dismissed = prefs.getStringList(_dismissedFor(empId)) ?? const [];
      final version = await _currentVersion();

      final pick = _pick(list, dismissed: dismissed, version: version);
      if (pick == null) return;

      _shownThisSession.add(pick.id);
      if (!context.mounted) return;

      await _show(context, pick, empId);
    } catch (e) {
      debugPrint('announcement failed: $e');
    } finally {
      _showing = false;
    }
  }

  /// เลือกอันล่างสุดของ array ที่ผ่านทุกเงื่อนไข = ประกาศใหม่สุด
  Announcement? _pick(
    List<Announcement> list, {
    required List<String> dismissed,
    required String version,
  }) {
    final branch = PermissionService.I.getBranchId() ?? '';
    final role = RoleService.I.role.value.code;
    final today = DateTime.now();

    for (final item in list.reversed) {
      if (!item.active || item.id.isEmpty) continue;
      if (dismissed.contains(item.id)) continue;
      if (_shownThisSession.contains(item.id)) continue;

      if (item.branch.isNotEmpty && item.branch != branch) continue;
      if (item.role.isNotEmpty && item.role != role) continue;
      if (!_versionAtLeast(version, item.minVersion)) continue;

      if (item.showUntil.isNotEmpty) {
        final until = DateTime.tryParse(item.showUntil);
        // หมดอายุนับถึงสิ้นวันของวันที่ระบุ
        if (until != null &&
            today.isAfter(until.add(const Duration(days: 1)))) {
          continue;
        }
      }

      return item;
    }

    return null;
  }

  Future<void> _show(
    BuildContext context,
    Announcement item,
    String empId,
  ) async {
    // เลือก future ก่อนแล้วค่อย await ทีเดียว จะได้ไม่ใช้ context หลัง await
    final dismiss = await (item.hasImage
        ? _showImage(context, item)
        : _showText(context, item));

    if (dismiss == true) await _remember(item.id, empId);
  }

  /// ประกาศแบบข้อความ ใช้เมื่อ json ไม่ได้ใส่ image มา
  Future<bool?> _showText(BuildContext context, Announcement item) {
    final scheme = Theme.of(context).colorScheme;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.title.isEmpty ? 'ประกาศ' : item.title),
        // ประกาศมักยาวกว่าที่คิด ไม่ครอบไว้จะล้นกรอบบนจอเตี้ย
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.message, style: const TextStyle(fontSize: 14)),
              if (item.hasLink) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => UpdateService.launchExternalUrl(item.link),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(
                      item.linkLabel.isEmpty ? 'เปิดลิงก์' : item.linkLabel,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
            ),
            child: const Text('ไม่แสดงอีก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  /// ประกาศแบบรูปเต็มจอ ปุ่มกากบาทลอยอยู่นอกกรอบรูปมุมบนขวา
  ///
  /// พื้นหลังโปร่งใสให้รูปเป็นพระเอก แตะนอกรูปหรือกดกากบาท = ปิดเฉย ๆ
  /// ยังเจอใหม่รอบหน้า ต้องกด ไม่แสดงอีก ถึงจะจำ
  Future<bool?> _showImage(BuildContext context, Announcement item) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // ให้ลูกกว้างเต็มกรอบทุกตัว รูปจะได้อยู่กลางและขอบซ้ายขวาเท่ากัน
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // วางไว้เหนือรูปแทนการลอยทับ จะได้ไม่บังเนื้อรูปและไม่โดน clip
            // ชิดขวาให้ตรงกับขอบขวาของรูปพอดี
            Align(
              alignment: Alignment.centerRight,
              child: _CloseButton(
                onTap: () => Navigator.of(dialogContext).pop(false),
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: GestureDetector(
                  onTap: item.hasLink
                      ? () {
                          UpdateService.launchExternalUrl(item.link);
                          Navigator.of(dialogContext).pop(false);
                        }
                      : null,
                  child: Image.network(
                    item.image,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                        ? child
                        : const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                    // โหลดรูปไม่ได้ยังต้องเห็นเนื้อประกาศ ไม่ใช่กล่องเปล่า
                    errorBuilder: (context, error, stack) => Container(
                      padding: const EdgeInsets.all(20),
                      color: Theme.of(dialogContext).colorScheme.surface,
                      child: Text(
                        item.message.isEmpty ? item.title : item.message,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // ชิดขวาให้ตรงกับขอบขวาของรูป เป็นคู่กับกากบาทที่มุมขวาบน
            // สายตาจะได้อยู่แนวเดียวกันทั้งบนและล่าง
            Align(
              alignment: Alignment.centerRight,
              child: _DismissButton(
                onTap: () => Navigator.of(dialogContext).pop(true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _remember(String id, String empId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _dismissedFor(empId);
    final saved = prefs.getStringList(key) ?? <String>[];
    if (saved.contains(id)) return;

    saved.add(id);
    await prefs.setStringList(key, saved);
  }

  /// โหลดจากเน็ตก่อน ล้มเหลวค่อยใช้ก้อนที่เคยโหลดได้
  Future<List<Announcement>> _load() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final response = await dio.get(
        kAnnouncementJsonUrl,
        options: Options(
          headers: {'Accept': 'application/json'},
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final body = response.data is String
          ? response.data as String
          : jsonEncode(response.data);

      final parsed = _parse(body);
      await prefs.setString(_cacheKey, body);
      return parsed;
    } catch (e) {
      debugPrint('announcement.json error: $e');
      return _parse(prefs.getString(_cacheKey));
    }
  }

  List<Announcement> _parse(String? body) {
    if (body == null || body.trim().isEmpty) return const [];

    try {
      dynamic decoded = jsonDecode(body);
      if (decoded is Map) decoded = decoded['announcements'];
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map>()
          .map((e) => Announcement.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('announcement.json parse error: $e');
      return const [];
    }
  }

  Future<String> _currentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (e) {
      return '';
    }
  }

  /// เวอร์ชันที่ติดตั้งอยู่ใหม่กว่าหรือเท่ากับที่ประกาศต้องการหรือไม่
  ///
  /// อ่านเวอร์ชันไม่ได้ให้ถือว่าผ่าน ดีกว่าปิดประกาศทิ้งเพราะเรื่องเล็กน้อย
  bool _versionAtLeast(String current, String required) {
    if (required.isEmpty || current.isEmpty) return true;

    final a = _parts(current);
    final b = _parts(required);

    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] > b[i]) return true;
      if (a[i] < b[i]) return false;
    }
    return a.length >= b.length;
  }

  List<int> _parts(String version) =>
      version.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();

  String _dismissedFor(String empId) =>
      empId.isEmpty ? _dismissedKey : '${_dismissedKey}_$empId';
}

String _str(dynamic value) {
  if (value == null) return '';
  final text = value.toString().trim();
  return text == 'null' ? '' : text;
}

/// กากบาทวงกลมสีขาวโปร่ง อ่านออกทั้งบนรูปสว่างและรูปมืด
class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(7),
          child: Icon(Icons.close, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

/// "ไม่แสดงอีก" มุมขวาล่างของรูปประกาศ
///
/// เป็นตัวหนังสือขีดเส้นใต้ ไม่ใช่ปุ่มทึบ เพราะเป็นทางเลือกรอง ไม่ใช่สิ่งที่
/// อยากให้กดเป็นอันดับแรก ปุ่มทึบเด่นเกินจนแย่งความสนใจไปจากตัวประกาศเอง
///
/// ใส่เงาดำจาง ๆ ไว้ใต้ตัวอักษร เพราะฉากหลังเป็นแค่ม่านทับจอ ความสว่างจึง
/// เปลี่ยนไปตามหน้าที่อยู่ข้างหลัง ขาวล้วนไม่มีเงาจะจางหายบนพื้นสว่าง
class _DismissButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DismissButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: const Padding(
        // กว้างพอให้นิ้วกดติด ตัวหนังสืออย่างเดียวพื้นที่แตะจะเล็กเกินไป
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          'ไม่แสดงอีก',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            decoration: TextDecoration.underline,
            decorationColor: Colors.white,
            shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}
