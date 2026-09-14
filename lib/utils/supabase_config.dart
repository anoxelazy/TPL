import 'package:dio/dio.dart';

/// ค่าตั้งค่าและ client ของ Supabase (ระบบแจ้งซ่อม/ทะเบียนเครื่อง)
///
/// เป็นคนละระบบกับ API หลักของแอป ใช้แค่เป็นแหล่งข้อมูลเสริม
/// การล็อกอินยังทำที่ API หลักเหมือนเดิม ดู `ApiHost`
class SupabaseConfig {
  const SupabaseConfig._();

  static const String baseUrl = 'https://qzqumefhywgsfplfuqag.supabase.co';

  /// publishable key ของโปรเจกต์ (คีย์รูปแบบใหม่ที่มาแทน anon key)
  ///
  /// คีย์นี้ฝังอยู่ใน bundle ของเว็บอยู่แล้วจึงไม่ใช่ความลับ
  /// แต่ sb_secret_ (ตัวที่มาแทน service_role) ห้ามเอามาใส่ที่นี่เด็ดขาด
  ///
  /// **ต้องใส่ตอน build เสมอ** ด้วย --dart-define=SUPABASE_ANON_KEY=...
  ///
  /// ไม่เก็บค่าจริงไว้ในโค้ดเพราะ repo นี้เป็น public และ RLS ของโปรเจกต์
  /// ยังปิดอยู่ ใครถือคีย์ก็อ่านและเขียนทุกตารางได้
  /// ไม่ใส่ = ระบบแจ้งซ่อมกับป้ายอันดับจะเงียบไป แต่แอปส่วนอื่นใช้งานได้ปกติ
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// ยังไม่ได้ใส่คีย์ = ข้ามการคุยกับ Supabase ไปเลย ไม่ให้แอปพัง
  static bool get isConfigured => anonKey.isNotEmpty;
}

/// dio แยกตัวสำหรับ Supabase โดยเฉพาะ
///
/// ห้ามใช้ dio ตัวหลักร่วมกัน เพราะตัวหลักมี interceptor สลับ host สำรอง
/// กับตัวรายงานสถานะเน็ตติดอยู่ ถ้า Supabase ล่มจะไปทำให้แถบ "ไม่มีอินเทอร์เน็ต"
/// ขึ้นทั้งที่ระบบหลักยังใช้งานได้ปกติ
final Dio supabaseDio = Dio(
  BaseOptions(
    baseUrl: SupabaseConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'apikey': SupabaseConfig.anonKey,
      'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
      'Accept': 'application/json',
    },
  ),
);
