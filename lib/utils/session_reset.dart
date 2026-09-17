import 'package:claim/page/repair/repair_watch_service.dart';
import 'package:claim/page/tracking/tracking_cache.dart';
import 'package:claim/utils/announcement_service.dart';
import 'package:claim/utils/claim_reminder_service.dart';
import 'package:claim/utils/claim_store.dart';
import 'package:claim/utils/mobile_api.dart';
import 'package:claim/utils/permission_service.dart';
import 'package:claim/utils/pm_access_service.dart';
import 'package:claim/utils/profile_avatar_service.dart';
import 'package:claim/utils/rank_service.dart';
import 'package:claim/utils/role_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// คีย์ใน SharedPreferences ที่ผูกกับคนที่ล็อกอินอยู่ ต้องหายไปตอน logout
const List<String> kSignedInPrefsKeys = [
  'token',
  'fullname',
  'driverID',
  'username',
];

/// ล้างทุกอย่างที่ผูกกับผู้ใช้คนที่เพิ่งออกจากระบบ
///
/// logout ไม่ได้ปิดแอป ตัว singleton ทุกตัวยังมีชีวิตอยู่ต่อพร้อมข้อมูลเดิม
/// ของที่ลืมล้างตรงนี้จะค้างให้คนถัดไปที่ล็อกอินบนเครื่องเดียวกันเห็น
/// เคยพลาดมาแล้วสองที่ (ผลค้นหาพัสดุกับ token ของระบบ PM) จึงรวมไว้ที่เดียว
/// เพิ่ม service ใหม่ที่เก็บข้อมูลรายคนเมื่อไหร่ ให้มาต่อท้ายที่นี่
///
/// รูปโปรไฟล์เป็นข้อยกเว้น เก็บแยกตามรหัสพนักงานอยู่แล้ว แค่เอาออกจากหน้าจอ
/// คนเดิมกลับมา login จะได้รูปเดิมคืน ไม่ต้องเลือกใหม่ทุกครั้ง
Future<void> forgetSignedInUser() async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in kSignedInPrefsKeys) {
    await prefs.remove(key);
  }

  await PermissionService.I.clear();
  // token ของระบบ PM เป็นคนละใบกับ token หลัก และถูกเก็บลงดิสก์ด้วย
  // ไม่ล้างแล้วคนถัดไปจะยิง API ของ PM ด้วยสิทธิ์ของคนก่อนหน้า
  await MobileSession.I.clear();

  ProfileAvatarService.I.forgetCurrentUser();
  RoleService.I.forgetCurrentUser();
  RankService.I.forgetCurrentUser();
  AnnouncementService.I.forgetCurrentUser();
  PmAccessService.I.forgetCurrentUser();
  RepairWatchService.I.forgetCurrentUser();
  // ผลค้นหาพัสดุมีชื่อ ที่อยู่ และเบอร์ผู้รับติดมาด้วย ห้ามค้างข้ามคน
  TrackingCache.I.clear();

  await ClaimStore.I.clear();
  await ClaimReminderService.I.cancel();
}
