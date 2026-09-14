import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/utils/dio_service.dart';

const String kRankJsonUrl =
    'https://raw.githubusercontent.com/anoxelazy/API_json/main/rank.json';

const String _cacheKey = 'user_rank_json';

/// ชั้นของป้ายบนรูปโปรไฟล์
enum RankTier {
  /// ผู้สร้างแอป ป้ายถาวร ไม่เกี่ยวกับรอบสำรวจ
  diamond,
  gold,
  silver,
  bronze;

  static RankTier? fromRank(int rank) => switch (rank) {
    1 => RankTier.gold,
    2 => RankTier.silver,
    3 => RankTier.bronze,
    _ => null,
  };
}

/// อันดับของผู้ใช้ที่ล็อกอินอยู่ null = ไม่ติดอันดับ
class UserRank {
  /// null เมื่อเป็นเพชร เพราะเพชรไม่ใช่ลำดับที่ แต่เป็นชั้นพิเศษ
  final int? rank;
  final RankTier tier;
  final int reports;
  final int images;

  /// รอบที่สำรวจ เช่น "กันยายน 2569" ว่างได้
  final String period;

  const UserRank({
    required this.rank,
    required this.tier,
    required this.reports,
    required this.images,
    required this.period,
  });

  bool get isDiamond => tier == RankTier.diamond;

  String get title =>
      isDiamond ? 'ผู้สร้างแอป' : 'ผู้ส่งบันทึกสินค้าเสียหายสูญหายอันดับ $rank';
}

class RankService {
  RankService._();

  static final RankService I = RankService._();
  final ValueNotifier<UserRank?> rank = ValueNotifier(null);
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final empId = prefs.getString('driverID')?.trim() ?? '';

    if (empId.isEmpty) {
      rank.value = null;
      return;
    }

    if (prefs.containsKey(_cacheKey)) {
      rank.value = _parse(prefs.getString(_cacheKey), empId);
    }

    try {
      final response = await dio.get(
        kRankJsonUrl,
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

      rank.value = _parse(body, empId);
      await prefs.setString(_cacheKey, body);
    } catch (e) {
      debugPrint('rank.json error: $e');
    }
  }

  void forgetCurrentUser() => rank.value = null;

  UserRank? _parse(String? body, String empId) {
    if (body == null || body.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;

      final period = decoded['period']?.toString().trim() ?? '';

      if (_isCreator(decoded['creator'], empId)) {
        final stats = _statsOf(decoded['ranks'], empId);
        return UserRank(
          rank: null,
          tier: RankTier.diamond,
          reports: stats?.$1 ?? 0,
          images: stats?.$2 ?? 0,
          period: period,
        );
      }

      final ranks = decoded['ranks'];
      if (ranks is! Map) return null;

      final entry = ranks[empId];
      if (entry is! Map) return null;

      final number = _int(entry['rank']);
      final tier = number == null ? null : RankTier.fromRank(number);
      if (tier == null) return null;

      return UserRank(
        rank: number,
        tier: tier,
        reports: _int(entry['reports']) ?? 0,
        images: _int(entry['images']) ?? 0,
        period: period,
      );
    } catch (e) {
      debugPrint('rank.json parse error: $e');
      return null;
    }
  }

  /// รองรับทั้งผู้สร้างคนเดียวและหลายคน
  bool _isCreator(dynamic value, String empId) {
    if (value == null) return false;
    if (value is List) {
      return value.any((e) => e?.toString().trim() == empId);
    }
    return value.toString().trim() == empId;
  }

  /// ผู้สร้างอาจติดอันดับด้วย ถ้ามีตัวเลขก็เอามาโชว์บนการ์ดเพชร
  (int, int)? _statsOf(dynamic ranks, String empId) {
    if (ranks is! Map) return null;
    final entry = ranks[empId];
    if (entry is! Map) return null;
    return (_int(entry['reports']) ?? 0, _int(entry['images']) ?? 0);
  }

  int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString().trim() ?? '');
  }
}
