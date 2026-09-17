import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/utils/supabase_config.dart';

/// สิทธิ์ในระบบแจ้งซ่อม อ่านจากตาราง users_role ของ Supabase
enum UserRole {
  /// ทีม IT รับงานซ่อม ปิดงาน และแก้ทะเบียนเครื่องได้
  it('IT'),

  /// พนักงานทั่วไป ดูข้อมูลกับแจ้งซ่อมได้อย่างเดียว
  user('USER');

  final String code;

  const UserRole(this.code);

  /// ไม่รู้จักค่าที่ได้มาให้ถือเป็น USER ตามที่ระบบกำหนด
  static UserRole fromCode(String? code) {
    final normalized = code?.trim().toUpperCase();
    for (final role in UserRole.values) {
      if (role.code == normalized) return role;
    }
    return UserRole.user;
  }
}

/// สิทธิ์ของผู้ใช้ที่ล็อกอินอยู่ในระบบแจ้งซ่อม
///
/// ล็อกอินยังทำที่ API หลักเหมือนเดิม ที่นี่แค่เอา driverID ไปถาม Supabase
/// ต่ออีกทีว่าเป็น IT หรือไม่ เก็บ cache แยกตามรหัสพนักงานเพราะมือถือเครื่องเดียว
/// มีหลายคนผลัดกันใช้
///
/// ระวัง: ค่านี้ใช้ตัดสินแค่ว่าจะโชว์ปุ่มไหน **ไม่ใช่การกันสิทธิ์จริง**
/// ฝั่ง Supabase เชื่อ requester_role ที่ client ส่งไปตรง ๆ ใครแก้แอปก็ปลอมได้
class RoleService {
  RoleService._();

  static final RoleService I = RoleService._();

  static const String _roleKey = 'user_role';

  /// สิทธิ์ที่ใช้อยู่ตอนนี้ หน้าจอ listen ตัวนี้เพื่ออัปเดตเมนูเมื่อถามเสร็จ
  final ValueNotifier<UserRole> role = ValueNotifier(UserRole.user);

  String? _empId;

  bool get isIt => role.value == UserRole.it;

  /// อ่านสิทธิ์ที่ cache ไว้ของคนที่ล็อกอินอยู่ แล้วถามของใหม่เบื้องหลัง
  ///
  /// เรียกตอนเปิดแอปและเรียกซ้ำหลังล็อกอินสำเร็จ ตอนเปิดแอปยังไม่รู้ว่าใครจะเข้ามา
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final empId = prefs.getString('driverID');

    _empId = (empId == null || empId.isEmpty) ? null : empId;

    if (_empId == null) {
      role.value = UserRole.user;
      return;
    }

    role.value = UserRole.fromCode(prefs.getString(_roleKeyFor(_empId!)));

    // ถามของใหม่โดยไม่ให้ผู้ใช้รอ ค่าที่ cache ไว้ใช้ไปพลางก่อนได้
    unawaited(refresh());
  }

  /// ถามสิทธิ์ล่าสุดจาก Supabase
  ///
  /// ถามไม่ได้ก็ใช้ค่าเดิมต่อ ไม่รีเซ็ตเป็น USER เพราะคนขับเน็ตหลุดบ่อย
  /// ถ้าเมนูหายกลางทางจะทำงานต่อไม่ได้
  Future<void> refresh() async {
    final empId = _empId;
    if (empId == null || !await SupabaseConfig.ensureKey()) return;

    // employee_number ในตารางเป็น int ส่งค่าที่ไม่ใช่ตัวเลขไป PostgREST ตอบ 400
    if (int.tryParse(empId) == null) {
      debugPrint('role: driverID "$empId" ไม่ใช่ตัวเลข ข้ามการถาม role');
      return;
    }

    try {
      final response = await supabaseDio.get(
        '/rest/v1/users_role',
        queryParameters: {
          'employee_number': 'eq.$empId',
          'select': 'role',
          'limit': 1,
        },
      );

      final rows = response.data;
      if (rows is! List) return;

      // ไม่มีแถว = ไม่ได้อยู่ในทีม IT ถือเป็น USER ตามที่ระบบกำหนด
      final next = rows.isEmpty
          ? UserRole.user
          : UserRole.fromCode((rows.first as Map?)?['role']?.toString());

      await _save(empId, next);
    } on DioException catch (e) {
      debugPrint('role lookup failed: ${e.type} ${e.message}');
    } catch (e) {
      debugPrint('role lookup failed: $e');
    }
  }

  /// ล้างสิทธิ์ออกจากหน้าจอตอน logout แต่ไม่ลบ cache ของคนนั้นทิ้ง
  void forgetCurrentUser() {
    _empId = null;
    role.value = UserRole.user;
  }

  Future<void> _save(String empId, UserRole next) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKeyFor(empId), next.code);
    // ระหว่างรอคำตอบผู้ใช้อาจ logout ไปแล้ว อย่าเอาสิทธิ์ของคนเก่ามาใส่
    if (_empId == empId) role.value = next;
  }

  static String _roleKeyFor(String empId) => '${_roleKey}_$empId';
}
