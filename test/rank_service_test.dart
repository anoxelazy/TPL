import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/utils/rank_service.dart';

/// ยัด json ลง cache แล้วให้ service อ่าน
///
/// ในเทสต์ยิงเน็ตไม่ได้ ตัวโหลดจะ throw แล้วตกไปใช้ค่าที่ cache ไว้
/// ซึ่งเป็นเส้นทางเดียวกับตอนผู้ใช้เปิดแอปแบบไม่มีเน็ต
Future<UserRank?> rankOf(String empId, Map<String, dynamic> json) async {
  SharedPreferences.setMockInitialValues({
    'driverID': empId,
    'user_rank_json': jsonEncode(json),
  });
  await RankService.I.init();
  return RankService.I.rank.value;
}

void main() {
  final base = {
    'period': 'กันยายน 2569',
    'ranks': {
      '80770': {'rank': 1, 'reports': 592, 'images': 2015},
      '66293': {'rank': 2, 'reports': 494, 'images': 1923},
      '10164046': {'rank': 3, 'reports': 406, 'images': 2010},
    },
  };

  group('ผู้สร้างคนเดียว', () {
    test('รหัสตรงได้เพชร', () async {
      final rank = await rankOf('68148', {...base, 'creator': '68148'});

      expect(rank, isNotNull);
      expect(rank!.tier, RankTier.diamond);
      expect(rank.rank, isNull, reason: 'เพชรไม่ใช่ลำดับที่ ไม่ต้องมีเลข');
    });

    test('รหัสไม่ตรงไม่ได้เพชร', () async {
      final rank = await rankOf('99999', {...base, 'creator': '68148'});
      expect(rank, isNull);
    });
  });

  group('ผู้สร้างหลายคน', () {
    final many = {
      ...base,
      'creator': ['68148', '68224', '70001'],
    };

    test('ทุกคนในลิสต์ได้เพชร', () async {
      for (final id in ['68148', '68224', '70001']) {
        final rank = await rankOf(id, many);
        expect(rank?.tier, RankTier.diamond, reason: 'รหัส $id ต้องได้เพชร');
      }
    });

    test('คนนอกลิสต์ไม่ได้เพชร', () async {
      final rank = await rankOf('12345', many);
      expect(rank, isNull);
    });

    test('คนในลิสต์ที่ติดอันดับด้วย ยังได้เพชร แต่ดึงตัวเลขมาโชว์', () async {
      final rank = await rankOf('80770', {
        ...base,
        'creator': ['68148', '80770'],
      });

      expect(rank!.tier, RankTier.diamond, reason: 'เพชรสูงกว่าอันดับ 1');
      expect(rank.reports, 592);
      expect(rank.images, 2015);
    });
  });

  group('อันดับปกติ', () {
    test('1/2/3 ได้ทอง เงิน ทองแดง', () async {
      final expected = {
        '80770': RankTier.gold,
        '66293': RankTier.silver,
        '10164046': RankTier.bronze,
      };

      for (final entry in expected.entries) {
        final rank = await rankOf(entry.key, base);
        expect(rank?.tier, entry.value);
        expect(rank?.period, 'กันยายน 2569');
      }
    });

    test('อันดับเกิน 3 ไม่มีป้าย', () async {
      final rank = await rankOf('55555', {
        ...base,
        'ranks': {
          ...base['ranks']! as Map<String, dynamic>,
          '55555': {'rank': 4, 'reports': 10, 'images': 20},
        },
      });

      expect(rank, isNull, reason: 'มีแค่ 3 ชั้น อันดับ 4 ไม่ต้องมีป้าย');
    });
  });
}
