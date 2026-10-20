/// ที่มาของข้อมูลแผนเดินรถ ช่วงทดสอบ
///
/// อ่านจากไฟล์ JSON ไม่ใช่ `GetBillList` เพราะ endpoint นั้นยังไม่ส่งพิกัด
/// ลูกค้ามาให้ (มีแต่ที่อยู่เป็นข้อความ) พอ backend เติม `poslat`/`poslon`
/// เข้าไปแล้ว ให้เปลี่ยนแค่ฟังก์ชันในไฟล์นี้ ส่วนโมเดลกับหน้าจอใช้ต่อได้เลย
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/page/plan/route_plan_models.dart';
import 'package:claim/utils/dio_service.dart';

/// ไฟล์สำรองที่ติดมากับแอป ใช้เมื่อโหลดจาก [kRoutePlanJsonUrl] ไม่ได้
///
/// เนื้อหาเป็นชุดเดียวกับตอนที่อัปขึ้น repo ครั้งแรก ของบน repo เปลี่ยนแล้ว
/// ตัวนี้จะเก่ากว่า แต่ดีกว่าจอว่างตอนคนขับอยู่จุดอับสัญญาณ
const String kRoutePlanAsset = 'assets/json/route_plan.json';

/// ไฟล์จริงที่ใช้อยู่ อยู่ repo เดียวกับ pm.json / pmlocations.json
///
/// นี่คือตัวหลัก แก้แผนทดสอบได้จากที่นี่โดยไม่ต้องอัปแอปใหม่ ส่วนไฟล์ในแอป
/// ([kRoutePlanAsset]) เป็นตัวสำรองไว้ใช้ตอนเน็ตไม่ดี คนขับอยู่นอกออฟฟิศ
const String kRoutePlanJsonUrl =
    'https://raw.githubusercontent.com/anoxelazy/API_json/main/plan.json';

/// แผนเดินรถทั้งหมดที่อ่านได้ ยังไม่กรองว่าเป็นของใคร
///
/// ลองดึงจาก repo ก่อน ไม่ได้ค่อยใช้ไฟล์ในแอป ทำแบบเดียวกับ [PmLocations]
/// ที่มีค่าสำรองติดมากับแอปเสมอ เพราะคนขับอยู่นอกออฟฟิศ เน็ตไม่แน่นอน
Future<List<RoutePlan>> fetchRoutePlans() async {
  final remote = await _loadRemote();
  final body = remote ?? await rootBundle.loadString(kRoutePlanAsset);

  return parseRoutePlans(body);
}

/// เฉพาะแผนของคนที่ล็อกอินอยู่
///
/// เทียบกับ `driverID` ใน prefs ตัวเดียวกับที่ระบบสิทธิ์ใช้ ไม่ใช่ชื่อผู้ใช้
/// เพราะชื่อพิมพ์ไม่เหมือนกันในแต่ละที่
Future<List<RoutePlan>> fetchMyRoutePlans() async {
  final prefs = await SharedPreferences.getInstance();
  final driverId = prefs.getString('driverID')?.trim() ?? '';

  final plans = await fetchRoutePlans();
  if (driverId.isEmpty) return const [];

  return plans.where((plan) => plan.driverId.trim() == driverId).toList();
}

/// แกะไฟล์เป็นรายการแผน อ่านไม่ออกคืนลิสต์ว่าง ไม่ throw
///
/// รับสองรูป: เป็น object ที่มี `plans` (รูปที่ใช้อยู่) หรือเป็น array ของแผน
/// ตรง ๆ เผื่อวันหลังใครตัด wrapper ออก
List<RoutePlan> parseRoutePlans(String? body) {
  if (body == null || body.trim().isEmpty) return const [];

  try {
    final decoded = jsonDecode(body);

    final raw = decoded is Map ? decoded['plans'] : decoded;
    if (raw is! List) return const [];

    return [
      for (final item in raw)
        if (item is Map) RoutePlan.fromJson(Map<String, dynamic>.from(item)),
    ].where((plan) => plan.truckSendId.isNotEmpty).toList();
  } catch (e) {
    debugPrint('route_plan.json parse error: $e');
    return const [];
  }
}

/// คืนเนื้อไฟล์จาก repo คืน null เมื่อโหลดไม่ได้หรือยังไม่มีไฟล์
Future<String?> _loadRemote() async {
  try {
    final response = await dio.get(
      kRoutePlanJsonUrl,
      options: Options(
        headers: {'Accept': 'application/json'},
        receiveTimeout: const Duration(seconds: 15),
        // 404 คือยังไม่ได้อัปไฟล์ขึ้น repo ไม่ใช่ความผิดพลาดที่ต้องโยน
        validateStatus: (_) => true,
      ),
    );

    if (response.statusCode != 200) return null;

    final data = response.data;
    return data is String ? data : jsonEncode(data);
  } catch (e) {
    debugPrint('route_plan.json remote: $e');
    return null;
  }
}
