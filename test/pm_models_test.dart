import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/pm/pm_models.dart';

/// ข้อมูลจริง 3 เครื่องที่ตัดมาจาก /api/PMDetails/list
///
/// เลือกมาให้ครอบคลุมของจริง: เครื่องที่มีปี 2026 แล้ว เครื่องที่ยังไม่มีรูปหลัง
/// และเครื่องธรรมดา ถ้า backend เปลี่ยนรูปแบบ ต้องดึงของใหม่มาทับไฟล์นี้
List<PmHead> _heads() {
  final raw = File('test/fixtures/pm_list.json').readAsStringSync();
  return (jsonDecode(raw) as List)
      .cast<Map<String, dynamic>>()
      .map(PmHead.fromJson)
      .toList();
}

void main() {
  group('PmHead.fromJson', () {
    test('อ่านหัวใบได้ครบ', () {
      final head = _heads().firstWhere((h) => h.comName == 'TP-COM-300');

      expect(head.no, 1);
      expect(head.fixAsset, 'F800-6703-0001');
      expect(head.empNo, '68051');
      // remark เป็นช่องพิมพ์อิสระ ของจริงปนทั้งชื่อคนและหมายเหตุ
      // ใบนี้บังเอิญเป็นชื่อคน ต้องอ่านมาตามที่กรอกไว้ ไม่ตีความอะไรเพิ่ม
      expect(head.remark, 'ชัชวาลย์ จันทรเสนา');
      expect(head.details, hasLength(12));
    });

    test('แต่ละปีมี 6 หัวข้อ เรียงตาม subNo', () {
      final head = _heads().firstWhere((h) => h.comName == 'TP-COM-300');
      final year2024 = head.detailsOf(2024);

      expect(year2024, hasLength(pmTaskCount));
      expect(year2024.map((d) => d.subNo).toList(), [1, 2, 3, 4, 5, 6]);
    });

    test('ปีเรียงใหม่ไปเก่า', () {
      final head = _heads().firstWhere((h) => h.comName == 'TP-COM-300');

      expect(head.years, [2025, 2024]);
    });

    test('ปีที่ไม่มีข้อมูลคืนลิสต์ว่าง ไม่ throw', () {
      final head = _heads().first;

      expect(head.detailsOf(1999), isEmpty);
      expect(head.completedCount(1999), 0);
      expect(head.isDone(1999), isFalse);
    });
  });

  group('รูปที่เป็นขีด ต้องนับว่าไม่มีรูป', () {
    test('picAfter เป็น "-" แปลว่ายังไม่ได้ถ่ายรูปหลังทำ', () {
      // ของจริงมีแถวแบบนี้ 367 จาก 1,446 แถว ไม่ใช่ข้อมูลเสีย
      const detail = PmDetail(subNo: 1, yearCheck: 2025);
      expect(detail.hasAfter, isFalse);
      expect(detail.isComplete, isFalse);

      final parsed = PmDetail.fromJson(const {
        'no': 1,
        'yearCheck': 2025,
        'picBefore': 'https://x.test/a.png',
        'picAfter': '-',
      });
      expect(parsed.picAfter, isNull);
      expect(parsed.picBefore, 'https://x.test/a.png');
      expect(parsed.isComplete, isFalse);
    });

    test('มีครบทั้งก่อนและหลังถึงนับว่าเสร็จ', () {
      final parsed = PmDetail.fromJson(const {
        'no': 2,
        'yearCheck': 2025,
        'picBefore': 'https://x.test/a.png',
        'picAfter': 'https://x.test/b.png',
      });

      expect(parsed.isComplete, isTrue);
    });
  });

  group('ความคืบหน้าของปี', () {
    test('นับเฉพาะหัวข้อที่มีรูปครบ ไม่ได้นับว่ามีแถว', () {
      final head = _heads().firstWhere((h) => h.comName == 'TP-COM-300');
      final done = head.completedCount(2025);

      // มี 6 แถวเสมอ แต่จำนวนที่ถ่ายครบต้องไม่เกินนั้น
      expect(head.detailsOf(2025), hasLength(pmTaskCount));
      expect(done, lessThanOrEqualTo(pmTaskCount));
      expect(head.isDone(2025), done == pmTaskCount);
    });

    test('ทำบางส่วนถือว่ายังไม่เสร็จ', () {
      final head = _heads().first;
      for (final year in head.years) {
        final done = head.completedCount(year);
        if (done > 0 && done < pmTaskCount) {
          expect(head.isPartial(year), isTrue);
          expect(head.isDone(year), isFalse);
        }
      }
    });
  });

  group('ชื่อหัวข้อ', () {
    test('subNo 1-6 มีชื่อครบ', () {
      expect(pmTaskTitles, hasLength(pmTaskCount));
      for (var i = 1; i <= pmTaskCount; i++) {
        final d = PmDetail(subNo: i, yearCheck: 2026);
        expect(d.title, pmTaskTitles[i - 1]);
      }
    });

    test('subNo นอกช่วงไม่ทำให้พัง', () {
      expect(const PmDetail(subNo: 99, yearCheck: 2026).title, 'หัวข้อที่ 99');
      expect(const PmDetail(subNo: 0, yearCheck: 2026).title, 'หัวข้อที่ 0');
    });
  });

  group('pmDate', () {
    test('อ่านเวลาไทยตามตัวเลขที่ส่งมา ไม่แปลง timezone', () {
      final date = pmDate('2024-05-18T14:07:08.327');

      expect(date, DateTime(2024, 5, 18, 14, 7, 8));
      expect(date!.isUtc, isFalse);
    });

    test('ค่าที่อ่านไม่ออกคืน null', () {
      expect(pmDate('-'), isNull);
      expect(pmDate(''), isNull);
      expect(pmDate(null), isNull);
    });
  });

  group('ค้นหา', () {
    test('ค้นได้ทั้งชื่อเครื่อง รหัสทรัพย์สิน และชื่อผู้ใช้', () {
      final head = _heads().firstWhere((h) => h.comName == 'TP-COM-300');

      expect(head.searchIndex, contains('tp-com-300'));
      expect(head.searchIndex, contains('f800-6703-0001'));
      expect(head.searchIndex, contains('ชัชวาลย์'));
    });
  });
}
