import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/utils/app_config.dart';
import 'package:claim/utils/dio_service.dart';

const String kIssueJsonUrl =
    'https://raw.githubusercontent.com/anoxelazy/API_json/main/issue.json';

const String _cacheKey = 'support_links_json';

/// ช่องทางแจ้งปัญหา อ่านจาก issue.json เปลี่ยนได้โดยไม่ต้องอัปแอป
class SupportLinks {
  /// ลิงก์ทัก LINE ผู้ดูแล (key `issue`)
  final String line;

  /// เว็บแจ้งเคสของทีม IT (key `web`)
  final String web;

  const SupportLinks({required this.line, required this.web});

  /// ค่าที่ติดมากับแอป ใช้ตอนยังโหลด json ไม่ได้
  static const SupportLinks fallback = SupportLinks(
    line: AppConfig.supportLineUrl,
    web: AppConfig.supportWebUrl,
  );

  /// ลิงก์ที่ว่างหรือพังใน json จะถอยไปใช้ค่าที่ติดมากับแอปทีละตัว
  /// ไม่ทิ้งทั้งก้อน เผื่อแก้ผิดแค่บรรทัดเดียว
  factory SupportLinks.fromJson(Map<String, dynamic> json) => SupportLinks(
    line: _url(json['issue']) ?? fallback.line,
    web: _url(json['web']) ?? fallback.web,
  );

  static String? _url(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (!text.startsWith('http')) return null;
    return text;
  }
}

/// ช่องทางแจ้งปัญหาที่ใช้อยู่ตอนนี้ หน้าจอ listen ตัวนี้เพื่ออัปเดตเมื่อโหลดเสร็จ
class SupportLinksService {
  SupportLinksService._();

  static final SupportLinksService I = SupportLinksService._();

  final ValueNotifier<SupportLinks> links = ValueNotifier(
    SupportLinks.fallback,
  );

  /// อ่านของที่ cache ไว้ให้ใช้ทันที แล้วค่อยดึงของใหม่เบื้องหลัง
  ///
  /// ไม่ throw เพราะเป็นแค่ลิงก์ติดต่อ โหลดไม่ได้ก็ยังมีค่าที่ติดมากับแอป
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final cached = _parse(prefs.getString(_cacheKey));
    if (cached != null) links.value = cached;

    try {
      final response = await dio.get(
        kIssueJsonUrl,
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
      if (parsed == null) throw Exception('รูปแบบไฟล์ไม่ถูกต้อง');

      links.value = parsed;
      await prefs.setString(_cacheKey, body);
    } catch (e) {
      debugPrint('issue.json error: $e');
    }
  }

  SupportLinks? _parse(String? body) {
    if (body == null || body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      return SupportLinks.fromJson(Map<String, dynamic>.from(decoded));
    } catch (e) {
      debugPrint('issue.json parse error: $e');
      return null;
    }
  }
}
