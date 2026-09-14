import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/utils/dio_service.dart';

/// ตารางแปลงรหัสสถานที่เป็นชื่อ อ่านจากลิงก์ แก้ได้โดยไม่ต้องอัปแอป
///
/// ระบบ PM เก็บ `location` เป็นเลข ("2") ตามค่าของ `ddlLocation` บนเว็บ
/// เอามาโชว์ดิบ ๆ คนอ่านไม่รู้เรื่องว่าเลข 2 คืออะไร
///
/// วางไว้ใน repo เดียวกับ issue.json ที่แอปใช้อยู่แล้ว
const String kLocationJsonUrl =
    'https://raw.githubusercontent.com/anoxelazy/API_json/main/pmlocations.json';

const String _cacheKey = 'pm_location_json';

/// สถานที่ 1 รายการ
class PmLocation {
  /// ค่าที่เก็บจริงในฐานข้อมูล เป็นสตริงเสมอแม้หน้าตาเป็นตัวเลข
  final String code;
  final String name;

  const PmLocation({required this.code, required this.name});
}

/// ค่าที่ติดมากับแอป ใช้ตอนยังโหลดไฟล์จากลิงก์ไม่ได้
///
/// ต้องมีติดไว้ ไม่ปล่อยว่าง เพราะช่างออกไปทำ PM ตามสาขาที่เน็ตไม่ดี
/// ถ้าโหลดไม่ได้แล้วไม่มีค่าสำรอง ช่องเลือกสถานที่จะว่างจนกรอกงานไม่ได้
///
/// ชุดนี้คัดจาก `ddlLocation` บนเว็บ ณ ก.ย. 2569
const List<PmLocation> kFallbackLocations = [
  PmLocation(code: '0', name: 'ไม่ระบุตำแหน่ง'),
  PmLocation(code: '1', name: 'เลขา'),
  PmLocation(code: '2', name: 'IT'),
  PmLocation(code: '3', name: 'Sale'),
  PmLocation(code: '4', name: 'CC'),
  PmLocation(code: '5', name: 'SC'),
  PmLocation(code: '6', name: 'Operation'),
  PmLocation(code: '7', name: 'การตลาด'),
  PmLocation(code: '8', name: 'การเงิน'),
  PmLocation(code: '9', name: 'กฎหมาย'),
  PmLocation(code: '10', name: 'CS'),
  PmLocation(code: '11', name: 'เคลม'),
  PmLocation(code: '12', name: 'บัญชี'),
  PmLocation(code: '13', name: 'จัดซื้อ'),
  PmLocation(code: '14', name: 'HR'),
  PmLocation(code: '15', name: 'WH1'),
  PmLocation(code: '16', name: 'WH2'),
  PmLocation(code: '17', name: 'ออกเอกสาร'),
  PmLocation(code: '18', name: 'IT Data'),
  PmLocation(code: '19', name: 'WH3 Ecom'),
  PmLocation(code: '20', name: 'RT'),
  PmLocation(code: '21', name: 'ซ่อมบำรุงพาหนะ'),
  PmLocation(code: '22', name: 'ออฟฟิศ ECOM'),
  PmLocation(code: '23', name: 'WH4'),
  PmLocation(code: '24', name: 'เดินธุรการพาหนะ'),
  PmLocation(code: '25', name: 'WH5'),
];

/// แปลงเนื้อไฟล์ JSON เป็นรายการสถานที่ คืน null เมื่ออ่านไม่ได้
///
/// แยกออกมาให้เทสต์ได้โดยไม่ต้องต่อเน็ต
/// รายการที่ code หรือ name ว่างจะถูกข้าม ไม่ทิ้งทั้งไฟล์
/// แก้ผิดบรรทัดเดียวจะได้ไม่ทำให้ทั้งตารางใช้ไม่ได้
List<PmLocation>? parseLocations(String? body) {
  if (body == null || body.trim().isEmpty) return null;

  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;

    final raw = decoded['locations'];
    if (raw is! List) return null;

    final list = <PmLocation>[];
    for (final item in raw) {
      if (item is! Map) continue;

      final code = item['code']?.toString().trim() ?? '';
      final name = item['name']?.toString().trim() ?? '';
      if (code.isEmpty || name.isEmpty) continue;

      list.add(PmLocation(code: code, name: name));
    }

    return list.isEmpty ? null : list;
  } catch (e) {
    debugPrint('pmlocations.json parse error: $e');
    return null;
  }
}

/// รายการสถานที่ที่ใช้อยู่ตอนนี้
class PmLocations {
  PmLocations._();

  static final PmLocations I = PmLocations._();

  final ValueNotifier<List<PmLocation>> items = ValueNotifier(
    kFallbackLocations,
  );

  /// ค้นชื่อจากรหัสได้เร็วโดยไม่ต้องวนลิสต์ทุกครั้งที่วาดแถว
  Map<String, String> _byCode = {
    for (final l in kFallbackLocations) l.code: l.name,
  };

  /// ชื่อของรหัสนี้ คืน null เมื่อไม่รู้จัก
  ///
  /// ไม่คืนรหัสดิบแทน เพื่อให้ฝั่ง UI ตัดสินใจเองได้ว่าจะโชว์อะไรเมื่อไม่รู้จัก
  String? nameOf(String? code) {
    final key = code?.trim();
    if (key == null || key.isEmpty) return null;
    return _byCode[key];
  }

  /// ชื่อสำหรับแสดงผล ไม่รู้จักก็บอกเลขไปตรง ๆ
  ///
  /// ดีกว่าโชว์ว่าง เพราะถ้าเว็บเพิ่มรหัสใหม่แล้วยังไม่ได้อัปไฟล์ อย่างน้อย
  /// ช่างยังเห็นเลขแล้วไปถามต่อได้ว่าเลขนี้คือที่ไหน
  String labelOf(String? code) {
    final key = code?.trim();
    if (key == null || key.isEmpty) return '-';
    return _byCode[key] ?? 'รหัส $key';
  }

  /// อ่านของที่ cache ไว้ให้ใช้ทันที แล้วค่อยดึงของใหม่เบื้องหลัง
  ///
  /// ไม่ throw เพราะเป็นแค่ตารางแปลงชื่อ โหลดไม่ได้ก็ยังมีค่าที่ติดมากับแอป
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final cached = parseLocations(prefs.getString(_cacheKey));
    if (cached != null) _apply(cached);

    try {
      final response = await dio.get(
        kLocationJsonUrl,
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

      final parsed = parseLocations(body);
      if (parsed == null) throw Exception('รูปแบบไฟล์ไม่ถูกต้อง');

      _apply(parsed);
      await prefs.setString(_cacheKey, body);
    } catch (e) {
      debugPrint('pmlocations.json error: $e');
    }
  }

  void _apply(List<PmLocation> list) {
    items.value = list;
    _byCode = {for (final l in list) l.code: l.name};
  }
}
