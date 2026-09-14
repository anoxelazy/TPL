import 'dart:convert';

import 'package:flutter/painting.dart' show BoxFit;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:claim/utils/dio_service.dart';

/// ที่อยู่ไฟล์ JSON รายการแบนเนอร์
///
/// เป็น URL เต็ม dio จะข้าม baseUrl ให้เอง จึงยิงข้าม host ได้
const String kBannerJsonUrl =
    'https://raw.githubusercontent.com/anoxelazy/API_json/main/banner.json';

/// แบนเนอร์ 1 รูปบนหน้าหลัก
class BannerItem {
  final String id;
  final String imageUrl;

  /// ลิงก์ที่เปิดเมื่อกดแบนเนอร์ null = กดไม่ได้
  final String? link;

  /// วิธีจัดรูปให้พอดีกรอบ 2:1
  ///
  /// cover (ค่าเริ่มต้น) = เต็มกรอบแต่ครอบตัดส่วนเกิน เหมาะกับรูปที่เป็น 2:1 อยู่แล้ว
  /// contain = เห็นครบทั้งรูปแต่มีแถบว่างข้าง ๆ เหมาะกับรูปสัดส่วนอื่น
  /// ที่มีข้อความริมขอบซึ่งห้ามโดนตัด
  final BoxFit fit;

  const BannerItem({
    required this.id,
    required this.imageUrl,
    this.link,
    this.fit = BoxFit.cover,
  });

  factory BannerItem.fromJson(Map<String, dynamic> json) => BannerItem(
    id: _str(json['id']),
    imageUrl: _str(json['image_url']),
    link: _link(json['link']),
    fit: _fit(json['fit']),
  );

  /// ค่าที่ไม่รู้จักหรือไม่ใส่มาถือเป็น cover ตามพฤติกรรมเดิม
  static BoxFit _fit(dynamic value) =>
      _str(value).toLowerCase() == 'contain' ? BoxFit.contain : BoxFit.cover;

  /// ไฟล์ JSON ใส่ค่าว่างมาสองแบบ: สตริง "null" กับสตริงว่าง
  /// ทั้งคู่หมายถึงไม่มีลิงก์ ต้องกันไว้ ไม่งั้นจะพยายามเปิด URL ชื่อ "null"
  static String? _link(dynamic value) {
    final text = _str(value);
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }

  static String _str(dynamic value) {
    if (value == null) return '';
    final text = value.toString().trim();
    return text == 'null' ? '' : text;
  }
}

/// ดึงรายการแบนเนอร์ ไม่ต้องใช้ token เพราะเป็นไฟล์สาธารณะ
Future<List<BannerItem>> fetchBanners() async {
  try {
    final response = await dio.get(
      kBannerJsonUrl,
      options: Options(
        headers: {'Accept': 'application/json'},
        // ไฟล์อยู่คนละ host กับ API หลัก เผื่อเวลาให้มากกว่า default 7 วิ
        receiveTimeout: const Duration(seconds: 20),
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('โหลดแบนเนอร์ไม่สำเร็จ (HTTP ${response.statusCode})');
    }

    dynamic decoded = response.data;
    if (decoded is String) {
      final trimmed = decoded.trim();
      if (trimmed.isEmpty) return const [];
      decoded = jsonDecode(trimmed);
    }

    final list = decoded is Map ? decoded['banners'] : decoded;
    if (list is! List) return const [];

    return list
        .whereType<Map>()
        .map((e) => BannerItem.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.imageUrl.isNotEmpty)
        .toList();
  } on DioException catch (e) {
    debugPrint('banner.json error: ${e.type} ${e.message}');
    throw Exception('โหลดแบนเนอร์ไม่สำเร็จ');
  }
}
