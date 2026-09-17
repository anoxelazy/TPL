import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/utils/dio_service.dart';

const String kRankJsonUrl =
    'https://raw.githubusercontent.com/anoxelazy/API_json/main/rank.json';

const String _cacheKey = 'user_rank_json';

/// จำนวนแถวสูงสุดของตารางอันดับ json ส่งมาเกินนี้ก็ตัดทิ้ง
const int kRankBoardSize = 10;

/// ชั้นของป้ายบนรูปโปรไฟล์
enum RankTier {
  /// ผู้สร้างแอป ป้ายถาวร ไม่เกี่ยวกับรอบสำรวจ
  diamond,
  gold,
  silver,
  bronze,

  /// อันดับ 4 ถึง [kRankBoardSize] ติดสิบอันดับแต่ไม่ได้เหรียญ
  top10;

  /// เกินสิบอันดับคืน null เพราะตารางเก็บแค่สิบ ป้ายจึงไม่มีอะไรจะบอก
  static RankTier? fromRank(int rank) => switch (rank) {
    1 => RankTier.gold,
    2 => RankTier.silver,
    3 => RankTier.bronze,
    _ => rank >= 4 && rank <= kRankBoardSize ? RankTier.top10 : null,
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

/// หนึ่งแถวของตารางอันดับ ไม่ผูกกับผู้ใช้ที่ล็อกอินอยู่
class RankEntry {
  final String empId;

  /// ชื่อจาก json ช่อง full_name หรือ name ว่างได้ ไม่มีก็โชว์รหัสพนักงานแทน
  final String name;

  /// สาขาหรือจังหวัด ว่างได้ json รอบเก่าไม่มีช่องนี้
  final String location;
  final int rank;
  final int reports;
  final int images;

  const RankEntry({
    required this.empId,
    required this.name,
    required this.rank,
    required this.reports,
    required this.images,
    this.location = '',
  });

  /// มีสีประจำชั้นเฉพาะสามอันดับแรก ที่เหลือ null ใช้สีกลางของธีม
  RankTier? get tier => RankTier.fromRank(rank);

  String get label => name.isEmpty ? 'รหัส $empId' : name;
}

/// ตารางอันดับทั้งรอบ เรียงจากอันดับ 1 ลงมา
class RankBoard {
  /// รอบที่สำรวจ เช่น "กันยายน 2569" ว่างได้
  final String period;
  final List<RankEntry> entries;

  const RankBoard({required this.period, required this.entries});
}

class RankService {
  RankService._();

  static final RankService I = RankService._();
  final ValueNotifier<UserRank?> rank = ValueNotifier(null);

  /// ตารางสิบอันดับ มาจาก json ไฟล์เดียวกับ [rank] ใช้ที่หน้าตารางอันดับ
  final ValueNotifier<RankBoard?> board = ValueNotifier(null);

  String _empId = '';

  /// รหัสพนักงานที่ล็อกอินอยู่ หน้าตารางเอาไปไฮไลต์แถวของตัวเอง
  String get currentEmpId => _empId;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final empId = prefs.getString('driverID')?.trim() ?? '';
    _empId = empId;

    if (empId.isEmpty) {
      rank.value = null;
      board.value = null;
      return;
    }

    if (prefs.containsKey(_cacheKey)) {
      _apply(prefs.getString(_cacheKey), empId);
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

      _apply(body, empId);
      await prefs.setString(_cacheKey, body);
    } catch (e) {
      debugPrint('rank.json error: $e');
    }
  }

  void forgetCurrentUser() {
    _empId = '';
    rank.value = null;
    board.value = null;
  }

  /// json ก้อนเดียวป้อนได้ทั้งป้ายของผู้ใช้และตารางอันดับ แกะทีเดียวพอ
  void _apply(String? body, String empId) {
    final decoded = _decode(body);
    final entries = _entriesOf(decoded);
    rank.value = _parse(decoded, entries, empId);
    board.value = _board(decoded, entries);
  }

  Map? _decode(String? body) {
    if (body == null || body.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(body);
      return decoded is Map ? decoded : null;
    } catch (e) {
      debugPrint('rank.json parse error: $e');
      return null;
    }
  }

  /// ป้ายของผู้ใช้อ่านจากแถวชุดเดียวกับตาราง อันดับจะได้ไม่เพี้ยนกันเอง
  UserRank? _parse(Map? decoded, List<RankEntry> entries, String empId) {
    if (decoded == null) return null;

    final period = decoded['period']?.toString().trim() ?? '';
    final mine = _entryOf(entries, empId);

    /// ผู้สร้างอาจติดอันดับด้วย ถ้ามีตัวเลขก็เอามาโชว์บนการ์ดเพชร
    if (_isCreator(decoded['creator'], empId)) {
      return UserRank(
        rank: null,
        tier: RankTier.diamond,
        reports: mine?.reports ?? 0,
        images: mine?.images ?? 0,
        period: period,
      );
    }

    if (mine == null) return null;

    final tier = RankTier.fromRank(mine.rank);
    if (tier == null) return null;

    return UserRank(
      rank: mine.rank,
      tier: tier,
      reports: mine.reports,
      images: mine.images,
      period: period,
    );
  }

  RankEntry? _entryOf(List<RankEntry> entries, String empId) {
    for (final entry in entries) {
      if (entry.empId == empId) return entry;
    }
    return null;
  }

  /// แถวทั้งหมดของรอบ เรียงจากอันดับ 1 ลงมา ยังไม่ตัดที่สิบ
  ///
  /// รอบใหม่ส่ง ranks มาเป็น array ที่พก emp_id มาในแถว รอบเก่าส่งเป็น map
  /// ที่ใช้รหัสพนักงานเป็น key รับทั้งคู่ json เก่าที่ cache ไว้จะได้ยังอ่านออก
  List<RankEntry> _entriesOf(Map? decoded) {
    if (decoded == null) return const [];

    try {
      final ranks = decoded['ranks'];
      final rows = <RankEntry>[];

      if (ranks is List) {
        for (final row in ranks) {
          if (row is! Map) continue;
          final entry = _entry(row['emp_id'] ?? row['empId'], row);
          if (entry != null) rows.add(entry);
        }
      } else if (ranks is Map) {
        ranks.forEach((key, value) {
          if (value is! Map) return;
          final entry = _entry(key, value);
          if (entry != null) rows.add(entry);
        });
      }

      return _dedupe(rows);
    } catch (e) {
      debugPrint('rank.json board parse error: $e');
      return const [];
    }
  }

  RankEntry? _entry(dynamic empId, Map row) {
    final id = empId?.toString().trim() ?? '';
    if (id.isEmpty) return null;

    final number = _int(row['rank']);
    if (number == null) return null;

    return RankEntry(
      empId: id,
      name: _name(row['full_name'] ?? row['name']),
      location: _name(row['location']),
      rank: number,
      reports: _int(row['reports']) ?? 0,
      images: _int(row['images']) ?? 0,
    );
  }

  /// คนเดียวโผล่หลายแถวได้ ถ้า json นับรายเอกสารแทนรายคน เก็บอันดับดีสุดพอ
  /// ปล่อยไว้ตารางสิบอันดับจะมีคนเดิมซ้ำสองสามบรรทัด แล้วเบียดคนอื่นตกไป
  List<RankEntry> _dedupe(List<RankEntry> rows) {
    final best = <String, RankEntry>{};

    for (final row in rows) {
      final current = best[row.empId];
      if (current == null || row.rank < current.rank) best[row.empId] = row;
    }

    final entries = best.values.toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));

    return List.unmodifiable(entries);
  }

  /// ตารางอันดับใช้ร่วมกันทุกคน ไม่ต้องรู้ว่าใครล็อกอินอยู่
  RankBoard? _board(Map? decoded, List<RankEntry> entries) {
    if (decoded == null || entries.isEmpty) return null;

    return RankBoard(
      period: decoded['period']?.toString().trim() ?? '',
      entries: List.unmodifiable(entries.take(kRankBoardSize)),
    );
  }

  /// รองรับทั้งผู้สร้างคนเดียวและหลายคน
  bool _isCreator(dynamic value, String empId) {
    if (value == null) return false;
    if (value is List) {
      return value.any((e) => e?.toString().trim() == empId);
    }
    return value.toString().trim() == empId;
  }

  /// บางรอบ json หยิบคอลัมน์ผิด full_name กลายเป็นก้อน url รูปของเอกสารทั้งใบ
  /// ปล่อยผ่านตารางจะโชว์ลิงก์ยาวเหยียดแทนชื่อคน ทิ้งแล้วตกไปใช้รหัสพนักงานดีกว่า
  String _name(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return '';
    if (text.startsWith('[') || text.startsWith('{')) return '';
    if (text.contains('://')) return '';
    return text;
  }

  int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString().trim() ?? '');
  }
}
