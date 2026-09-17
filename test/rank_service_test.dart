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

/// ตารางอันดับที่ได้จาก json ก้อนเดียวกัน
Future<RankBoard?> boardOf(String empId, Map<String, dynamic> json) async {
  SharedPreferences.setMockInitialValues({
    'driverID': empId,
    'user_rank_json': jsonEncode(json),
  });
  await RankService.I.init();
  return RankService.I.board.value;
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

    Future<UserRank?> rankAt(int number) => rankOf('55555', {
      ...base,
      'ranks': {
        ...base['ranks']! as Map<String, dynamic>,
        '55555': {'rank': number, 'reports': 10, 'images': 20},
      },
    });

    test('อันดับ 4 ถึง 10 ได้ป้ายชั้นสิบอันดับ มีเลขของตัวเอง', () async {
      for (var number = 4; number <= 10; number++) {
        final rank = await rankAt(number);

        expect(rank, isNotNull, reason: 'อันดับ $number ต้องมีป้าย');
        expect(rank!.tier, RankTier.top10);
        expect(rank.rank, number, reason: 'ป้ายต้องโชว์เลขอันดับจริง');
      }
    });

    test('เกิน 10 ไม่มีป้าย เพราะตารางเก็บแค่สิบ', () async {
      expect(await rankAt(11), isNull);
      expect(await rankAt(25), isNull);
    });

    test('สามอันดับแรกยังเป็นเหรียญ ไม่ถูกกลืนเป็นชั้นสิบอันดับ', () async {
      expect((await rankAt(1))?.tier, RankTier.gold);
      expect((await rankAt(2))?.tier, RankTier.silver);
      expect((await rankAt(3))?.tier, RankTier.bronze);
    });
  });
  group('ตารางอันดับ', () {
    final ten = {
      'period': 'กันยายน 2569',
      'ranks': {
        for (var i = 1; i <= 12; i++)
          'emp$i': {'rank': i, 'reports': 100 - i, 'images': 200 - i},
      },
    };

    test('เรียงจากอันดับ 1 ลงมา ถึงจะสลับกันมาใน json', () async {
      final board = await boardOf('emp1', {
        'period': 'กันยายน 2569',
        'ranks': {
          'c': {'rank': 3, 'reports': 1, 'images': 1},
          'a': {'rank': 1, 'reports': 1, 'images': 1},
          'b': {'rank': 2, 'reports': 1, 'images': 1},
        },
      });

      expect(board!.entries.map((e) => e.rank), [1, 2, 3]);
      expect(board.entries.map((e) => e.empId), ['a', 'b', 'c']);
      expect(board.period, 'กันยายน 2569');
    });

    test('มาเกินสิบก็ตัดเหลือสิบ', () async {
      final board = await boardOf('emp1', ten);

      expect(board!.entries.length, kRankBoardSize);
      expect(board.entries.last.rank, 10);
    });

    test('ไม่มีชื่อใน json ใช้รหัสพนักงานแทน', () async {
      final board = await boardOf('80770', base);
      expect(board!.entries.first.label, 'รหัส 80770');
    });

    test('มีชื่อใน json ก็ใช้ชื่อ', () async {
      final board = await boardOf('80770', {
        ...base,
        'ranks': {
          '80770': {
            'rank': 1,
            'name': 'สมชาย ใจดี',
            'reports': 592,
            'images': 2015,
          },
        },
      });

      expect(board!.entries.first.label, 'สมชาย ใจดี');
      expect(board.entries.first.name, 'สมชาย ใจดี');
    });

    test('แถวที่ไม่มีเลขอันดับถูกข้าม', () async {
      final board = await boardOf('80770', {
        ...base,
        'ranks': {
          '80770': {'rank': 1, 'reports': 592, 'images': 2015},
          '99999': {'reports': 5, 'images': 5},
        },
      });

      expect(board!.entries.length, 1);
    });

    test('ทุกแถวในตารางมีเลขและมีสีของตัวเอง', () async {
      final board = await boardOf('emp5', ten);

      for (final entry in board!.entries) {
        expect(entry.rank, inInclusiveRange(1, kRankBoardSize));
        expect(
          entry.tier,
          isNotNull,
          reason: 'อันดับ ${entry.rank} ต้องมีชั้นของตัวเอง ไม่ใช่วงเปล่า',
        );
      }

      expect(board.entries[4].tier, RankTier.top10, reason: 'อันดับ 5');
      expect(RankService.I.currentEmpId, 'emp5', reason: 'ไว้ไฮไลต์แถวตัวเอง');
    });

    test('logout แล้วตารางหายไปด้วย', () async {
      await boardOf('80770', base);
      RankService.I.forgetCurrentUser();

      expect(RankService.I.board.value, isNull);
      expect(RankService.I.currentEmpId, isEmpty);
    });
  });

  /// รอบใหม่ ranks เป็น array พก emp_id มาในแถว และมี full_name กับ location
  /// แต่ไม่นับรูปมาให้แล้ว
  group('ranks แบบ array', () {
    final array = {
      'creator': ['68148', '68224'],
      'period': 'กันยายน 2569',
      'updated_at': '2026-09-15T20:18:02+07:00',
      'ranks': [
        {
          'rank': 1,
          'emp_id': '80770',
          'full_name': 'เกษมพงศ์ เกลี้ยงบุญอาน',
          'location': 'สุราษฎร์ธานี',
          'reports': 596,
        },
        {
          'rank': 2,
          'emp_id': '66293',
          'full_name': 'วิลาวัลย์ ศรีสุขเจริญ',
          'location': 'สิงห์บุรี',
          'reports': 494,
        },
        {
          'rank': 3,
          'emp_id': '10164046',
          'full_name': 'สุรินทร์',
          'location': 'สุรินทร์',
          'reports': 429,
        },
      ],
    };

    test('อ่านครบทุกแถว เรียงตามอันดับ', () async {
      final board = await boardOf('80770', array);

      expect(board!.entries.map((e) => e.rank), [1, 2, 3]);
      expect(board.entries.map((e) => e.empId), ['80770', '66293', '10164046']);
      expect(board.period, 'กันยายน 2569');
    });

    test('full_name กับ location เข้าแถวถูกช่อง', () async {
      final board = await boardOf('80770', array);
      final first = board!.entries.first;

      expect(first.label, 'เกษมพงศ์ เกลี้ยงบุญอาน');
      expect(first.location, 'สุราษฎร์ธานี');
      expect(first.reports, 596);
    });

    test('ไม่มีช่อง images ก็ไม่พัง นับเป็นศูนย์', () async {
      final board = await boardOf('80770', array);
      expect(board!.entries.every((e) => e.images == 0), isTrue);
    });

    test('ป้ายของผู้ใช้อ่านจาก array ได้เหมือนกัน', () async {
      final rank = await rankOf('66293', array);

      expect(rank!.tier, RankTier.silver);
      expect(rank.rank, 2);
      expect(rank.reports, 494);
    });

    test('ผู้สร้างยังได้เพชร ถึงจะไม่อยู่ใน array', () async {
      final rank = await rankOf('68148', array);
      expect(rank!.tier, RankTier.diamond);
    });

    test('แถวที่ไม่มี emp_id ถูกข้าม', () async {
      final board = await boardOf('80770', {
        ...array,
        'ranks': [
          {'rank': 1, 'emp_id': '80770', 'reports': 596},
          {'rank': 2, 'full_name': 'ไม่มีรหัส', 'reports': 494},
        ],
      });

      expect(board!.entries.length, 1);
      expect(board.entries.first.empId, '80770');
    });

    test('คนเดิมซ้ำหลายแถว เหลือแถวเดียวที่อันดับดีสุด', () async {
      final board = await boardOf('80770', {
        ...array,
        'ranks': [
          {'rank': 1, 'emp_id': '80770', 'reports': 596},
          {'rank': 2, 'emp_id': '66293', 'reports': 494},
          {'rank': 3, 'emp_id': '80770', 'reports': 429},
        ],
      });

      expect(board!.entries.map((e) => e.empId), ['80770', '66293']);
      expect(board.entries.first.rank, 1);
    });

    test(
      'ranks เป็น map แบบเดิมก็ยังอ่านได้ json ที่ cache ไว้จะได้ไม่หาย',
      () async {
        final board = await boardOf('80770', base);
        expect(board!.entries.map((e) => e.rank), [1, 2, 3]);
      },
    );
  });

  /// App Script เคยส่งคอลัมน์รูปมาลงช่อง full_name ทั้งก้อน
  /// ถ้าปล่อยผ่าน ตารางจะมีลิงก์ยาวเป็นบรรทัดแทนชื่อคน
  group('full_name ที่ไม่ใช่ชื่อคน', () {
    Future<RankEntry> entryWithName(String name) async {
      final board = await boardOf('81719', {
        'period': 'กันยายน 2569',
        'ranks': {
          '81719': {'rank': 1, 'full_name': name, 'reports': 1, 'images': 1},
        },
      });
      return board!.entries.first;
    }

    test('ก้อน json ของ url รูป ตกไปใช้รหัสพนักงาน', () async {
      final entry = await entryWithName(
        '["https://internal.thaiparcels.com:4433/Tps/Claim/0060533975E/a.png",'
        '"https://internal.thaiparcels.com:4433/Tps/Claim/0060533975E/b.png"]',
      );

      expect(entry.name, isEmpty);
      expect(entry.label, 'รหัส 81719');
    });

    test('url เดี่ยว ๆ ก็ไม่ใช่ชื่อ', () async {
      final entry = await entryWithName(
        'https://internal.thaiparcels.com/a.png',
      );
      expect(entry.label, 'รหัส 81719');
    });

    test('ชื่อคนปกติไม่โดนตัดทิ้ง', () async {
      final entry = await entryWithName('สมชาย ใจดี');
      expect(entry.label, 'สมชาย ใจดี');
    });
  });
}
