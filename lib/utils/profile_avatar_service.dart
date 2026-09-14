import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/page/profile/profile_avatar_api.dart';

/// รูปโปรไฟล์ที่ผู้ใช้เลือก เก็บติดเครื่องแต่**แยกตามรหัสพนักงาน**
///
/// แยกตามคนเพราะมือถือเครื่องเดียวมีหลายคนผลัดกันใช้ ถ้าเก็บรวมกัน
/// คนที่ login ต่อจะเห็นรูปของคนก่อนหน้า และการ logout ก็ไม่ต้องลบรูปทิ้ง
/// (กลับมา login เดิมจะได้รูปเดิมคืน)
///
/// เก็บ url ไว้คู่กับ id ด้วย หน้าจอที่โชว์รูปจะได้ไม่ต้องรอโหลด profile.json
class ProfileAvatarService {
  ProfileAvatarService._();

  static final ProfileAvatarService I = ProfileAvatarService._();

  static const String _idKey = 'profile_avatar_id';
  static const String _urlKey = 'profile_avatar_url';

  /// null = ยังไม่ได้เลือก ให้ใช้รูปที่ติดมากับแอป
  final ValueNotifier<String?> imageUrl = ValueNotifier(null);

  String? _selectedId;

  /// รหัสพนักงานเจ้าของรูปที่โหลดอยู่ null = ยังไม่ได้ login
  String? _empId;

  String? get selectedId => _selectedId;

  /// โหลดรูปของผู้ใช้ที่ login อยู่
  ///
  /// เรียกตอนเปิดแอป และเรียกซ้ำหลัง login สำเร็จ เพราะตอนเปิดแอป
  /// อาจยังไม่รู้ว่าใครจะ login เข้ามา
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final empId = prefs.getString('driverID');

    _empId = (empId == null || empId.isEmpty) ? null : empId;

    if (_empId == null) {
      _selectedId = null;
      imageUrl.value = null;
      return;
    }

    await _migrateLegacyKeys(prefs);

    _selectedId = prefs.getString(_idKeyFor(_empId!));
    imageUrl.value = prefs.getString(_urlKeyFor(_empId!));
  }

  Future<void> select(ProfileAvatar avatar) async {
    final empId = _empId;
    if (empId == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_idKeyFor(empId), avatar.id);
    await prefs.setString(_urlKeyFor(empId), avatar.url);
    _selectedId = avatar.id;
    imageUrl.value = avatar.url;
  }

  /// ลบรูปที่เลือกไว้ของผู้ใช้คนนี้ถาวร ใช้ตอนผู้ใช้กด "ใช้รูปเริ่มต้น"
  Future<void> clear() async {
    final empId = _empId;
    _selectedId = null;
    imageUrl.value = null;
    if (empId == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_idKeyFor(empId));
    await prefs.remove(_urlKeyFor(empId));
  }

  /// ล้างรูปออกจากหน้าจอตอน logout แต่**ไม่ลบของที่เก็บไว้**
  ///
  /// ต้องล้างค่าในหน่วยความจำ ไม่งั้นคนถัดไปที่มาถึงหน้า login
  /// จะยังเห็นรูปของคนก่อนค้างอยู่จนกว่าจะปิดเปิดแอป
  void forgetCurrentUser() {
    _empId = null;
    _selectedId = null;
    imageUrl.value = null;
  }

  /// ตาม url ใหม่ให้ตรงกับ profile.json เผื่อลิงก์ของ id เดิมถูกเปลี่ยน
  /// ถ้า id ที่เลือกไว้หายไปจากไฟล์แล้วจะถอยกลับไปใช้รูปที่ติดมากับแอป
  Future<void> syncWith(List<ProfileAvatar> avatars) async {
    final id = _selectedId;
    if (id == null) return;

    for (final avatar in avatars) {
      if (avatar.id != id) continue;
      if (avatar.url != imageUrl.value) await select(avatar);
      return;
    }

    await clear();
  }

  static String _idKeyFor(String empId) => '${_idKey}_$empId';

  static String _urlKeyFor(String empId) => '${_urlKey}_$empId';

  /// ย้ายรูปที่เก็บด้วย key แบบเก่า (ไม่แยกคน) มาเป็นของผู้ใช้คนนี้
  ///
  /// ทำครั้งเดียว คนที่เคยเลือกรูปไว้ก่อนอัปเดตจะไม่เสียรูปที่เลือก
  Future<void> _migrateLegacyKeys(SharedPreferences prefs) async {
    final legacyId = prefs.getString(_idKey);
    if (legacyId == null) return;

    final empId = _empId!;
    // ถ้าคนนี้มีรูปของตัวเองอยู่แล้ว ไม่ต้องเอาของเก่ามาทับ
    if (prefs.getString(_idKeyFor(empId)) == null) {
      await prefs.setString(_idKeyFor(empId), legacyId);
      final legacyUrl = prefs.getString(_urlKey);
      if (legacyUrl != null) {
        await prefs.setString(_urlKeyFor(empId), legacyUrl);
      }
    }

    await prefs.remove(_idKey);
    await prefs.remove(_urlKey);
  }
}
