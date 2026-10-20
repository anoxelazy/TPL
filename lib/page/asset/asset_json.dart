/// ตัวช่วยอ่าน JSON ที่ระบบทรัพย์สินใช้ร่วมกันทุกไฟล์
///
/// แยกออกมาเพราะกลุ่ม AssetTransfer มีหลายเส้นและชื่อช่องไม่ได้สม่ำเสมอกันทั้งหมด
/// (บางเส้นเป็น `emp_id` บางเส้น `approver_id` ของเดียวกัน) ทุกที่จึงอ่านแบบ
/// เทียบชื่อช่องโดยตัดอักขระพิเศษและไม่สนตัวพิมพ์ แล้วไล่หาตามลำดับที่น่าจะเป็น
library;

import 'dart:convert';

/// ชื่อช่องแบบตัดอักขระพิเศษและเป็นตัวพิมพ์เล็ก — `current_site_id` → `currentsiteid`
String normalizedJsonKey(String key) =>
    key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

/// ข้อความของช่องแรกที่เจอตาม [keys] คืนค่าว่างเมื่อไม่เจอหรือค่าเป็นว่าง
String jsonPick(Map<String, dynamic> json, List<String> keys) {
  final byKey = <String, String>{};
  for (final entry in json.entries) {
    final text = entry.value?.toString().trim() ?? '';
    if (text.isEmpty) continue;
    byKey.putIfAbsent(normalizedJsonKey(entry.key), () => text);
  }

  for (final key in keys) {
    final value = byKey[key];
    if (value != null) return value;
  }
  return '';
}

/// ค่าดิบของช่องแรกที่เจอ ใช้กับช่องที่ไม่ใช่ข้อความ (ลิสต์, boolean)
/// ซึ่ง [jsonPick] แปลงเป็นสตริงไปแล้วใช้ไม่ได้
dynamic jsonRaw(Map<String, dynamic> json, List<String> keys) {
  final byKey = <String, dynamic>{};
  for (final entry in json.entries) {
    byKey.putIfAbsent(normalizedJsonKey(entry.key), () => entry.value);
  }

  for (final key in keys) {
    if (byKey.containsKey(key)) return byKey[key];
  }
  return null;
}

int jsonInt(String value) => int.tryParse(value.trim()) ?? 0;

/// จำนวนเต็มที่ "ไม่มีค่า" ต่างจาก 0 เช่น `days_overdue` ที่ null แปลว่ายังไม่เกินกำหนด
/// ส่วน 0 แปลว่าครบกำหนดพอดีวันนี้
int? jsonIntOrNull(String value) => int.tryParse(value.trim());

/// ค่า bool ที่อาจมาเป็น true/false, "true"/"false", 1/0 หรือไม่มาเลย
bool jsonBool(dynamic value, {required bool fallback}) {
  if (value is bool) return value;
  if (value is num) return value != 0;

  final text = value?.toString().trim().toLowerCase() ?? '';
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return fallback;
}

/// แกะช่องที่ควรเป็นลิสต์ รับทั้ง List ตรง ๆ และสตริง JSON
List<dynamic> jsonListOf(dynamic value) {
  dynamic decoded = value;

  if (decoded is String) {
    final text = decoded.trim();
    if (text.isEmpty) return const [];
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return const [];
    }
  }

  return decoded is List ? decoded : const [];
}

/// แกะลิสต์ของ object แล้วแปลงเป็นโมเดลทีละตัว
List<T> jsonRows<T>(
  dynamic value,
  T Function(Map<String, dynamic>) parse, {
  required bool Function(T) keep,
}) => [
  for (final item in jsonListOf(value))
    if (item is Map) parse(Map<String, dynamic>.from(item)),
].where(keep).toList();
