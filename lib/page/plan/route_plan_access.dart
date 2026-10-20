import 'package:shared_preferences/shared_preferences.dart';

/// รหัสพนักงานที่เห็นแผนเดินรถได้ตอนนี้
///
/// ช่วงทดสอบเปิดให้คนเดียวก่อน ยังไม่ผูกกับระบบสิทธิ์ (`Permissions.Modules`)
/// เพราะฝั่ง API ยังไม่มี module ให้ผูก และของยังอ่านจากไฟล์ JSON ทดสอบอยู่
/// ไม่ใช่ข้อมูลจริงจาก `GetBillList`
///
/// เพิ่มคนทดสอบ = เติมรหัสในลิสต์นี้แล้วอัปแอปใหม่ ถ้าถึงจุดที่ต้องเปิดเป็นกลุ่ม
/// ให้ย้ายไปอ่านจากไฟล์ JSON บน repo แบบ [PmAccessService] จะได้เปิดให้คนอื่น
/// โดยไม่ต้องอัปแอปทุกครั้ง
const List<String> kRoutePlanTesters = ['68148'];

/// รหัสนี้เห็นแผนเดินรถได้ไหม
///
/// แยกจาก [canSeeRoutePlan] ให้เทสต์เรียกได้โดยไม่ต้องมี SharedPreferences
bool isRoutePlanTester(String? empId) {
  final id = empId?.trim() ?? '';
  if (id.isEmpty) return false;
  return kRoutePlanTesters.contains(id);
}

/// คนที่ล็อกอินอยู่ตอนนี้เห็นแผนเดินรถได้ไหม
///
/// อ่าน `driverID` จาก prefs ตรง ๆ แบบเดียวกับ [PmAccessService] ไม่ผ่าน
/// [RoleService] เพราะตัวนั้นถือสิทธิ์ของระบบแจ้งซ่อม คนละเรื่องกัน
Future<bool> canSeeRoutePlan() async {
  final prefs = await SharedPreferences.getInstance();
  return isRoutePlanTester(prefs.getString('driverID'));
}
