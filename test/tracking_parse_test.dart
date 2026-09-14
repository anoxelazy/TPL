import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/tracking/api.dart';
import 'package:claim/page/tracking/models.dart';

/// JSON จริงที่ดึงมาจาก tracking.aspx เก็บไว้แบบดิบ ยังไม่ผ่านการซ่อม
///
/// เก็บดิบไว้ตั้งใจ เพราะกับดักสำคัญของ API ตัวนี้อยู่ในตัวไฟล์เอง
/// (backslash ที่ทำให้ jsonDecode พัง) ถ้าซ่อมก่อนเก็บ เทสต์จะไม่คลุมของจริง
String _fixture(String name) => File('test/fixtures/$name').readAsStringSync();

void main() {
  group('repairJsonEscapes', () {
    test('payload จริงของใบที่ส่งถึงแล้ว decode ไม่ได้ถ้าไม่ซ่อมก่อน', () {
      final raw = _fixture('tracking_delivered.json');

      // ยืนยันว่ากับดักมีจริง ไม่ได้กันไว้เผื่อ ๆ
      expect(raw, contains(r'11092026\Success'));
      expect(() => jsonDecode(raw), throwsFormatException);

      // แล้วพอซ่อมก่อนถึงอ่านผ่าน
      expect(() => decodeTrackingBody(raw), returnsNormally);
    });

    test('escape ที่ถูกต้องอยู่แล้วต้องไม่ถูกแตะ', () {
      expect(repairJsonEscapes(r'{"a":"x\ny"}'), r'{"a":"x\ny"}');
      expect(repairJsonEscapes(r'{"a":"x\\y"}'), r'{"a":"x\\y"}');
      expect(repairJsonEscapes(r'{"a":"x\"y"}'), r'{"a":"x\"y"}');
      expect(repairJsonEscapes(r'{"a":"\u0e01"}'), r'{"a":"\u0e01"}');
    });

    test('backslash ดิบถูก escape เพิ่มให้', () {
      expect(repairJsonEscapes(r'{"a":"c:\Success"}'), r'{"a":"c:\\Success"}');
    });
  });

  group('decodeTrackingBody', () {
    TrackingResult delivered() =>
        decodeTrackingBody(_fixture('tracking_delivered.json'));

    test('อ่านการ์ดสรุปได้', () {
      final r = delivered();

      expect(r.tpTracking, 'HVR012609093457');
      expect(r.cusTracking, 'C301213354');
      expect(r.currentStatusCode, '7');
      expect(r.currentStatus, 'Delivered');
      expect(r.currentStatusTime, DateTime(2026, 9, 11, 13, 6, 40));
      expect(r.currentStatusLocation, 'ชลบุรี');
    });

    test('อ่าน all_status ครบทุกแถว', () {
      expect(delivered().events, hasLength(9));
    });

    test('B00 ที่ต่อท้าย list ถูกจัดไปล่างสุดของไทม์ไลน์', () {
      final events = delivered().events;

      expect(events.first.statusId, '7');
      expect(events.last.statusId, 'B00');
      // เรียงจากใหม่ไปเก่าจริง ไม่ใช่แค่ลำดับที่ server ส่งมา
      final times = events.map((e) => e.statusDate!).toList();
      for (int i = 1; i < times.length; i++) {
        expect(times[i].isAfter(times[i - 1]), isFalse);
      }
    });

    test('URL รูปถูกแปลง backslash เป็น slash', () {
      final latest = delivered().events.first;

      expect(latest.pictures, hasLength(3));
      for (final url in latest.allImages) {
        expect(url, isNot(contains(r'\')));
        expect(url, startsWith('https://'));
      }
      expect(latest.signature, endsWith('/signature.png'));
      expect(latest.allImages, hasLength(4));
    });

    test('คนขับกับเบอร์อ่านได้จากสถานะ 6', () {
      final driving = delivered().events.firstWhere((e) => e.statusId == '6');

      expect(driving.driver, 'ปวิช ทองท่อ');
      expect(driving.tel, '095-1058256');
      // สถานะนี้ไม่มีรูป ต้องไม่หลุดมาเป็นรูปแตก
      expect(driving.allImages, isEmpty);
    });

    test('jobstatusid ยังเป็น String ไม่ถูก parse เป็น int', () {
      final ids = delivered().events.map((e) => e.statusId).toList();

      expect(ids, contains('B00'));
      expect(ids.every((id) => id.isNotEmpty), isTrue);
    });

    test('ค้นด้วยเลขร้านค้าได้ผลชุดเดียวกัน', () {
      final byTk = decodeTrackingBody(_fixture('tracking_by_tk.json'));

      expect(byTk.tpTracking, 'HVR012609093457');
      expect(byTk.events, hasLength(9));
    });

    test('พิกัดอ่านได้ และ 0,0 ถือว่าไม่มีพิกัด', () {
      expect(delivered().events.first.coordinates, '13.1678771, 101.0013249');

      const noFix = TrackingEvent(
        statusId: '7',
        statusName: 'x',
        lat: '0',
        lon: '0',
      );
      expect(noFix.coordinates, isNull);
    });
  });

  group('error แบบ plain text พร้อม HTTP 200', () {
    test('Unknow DocumentNumber = ไม่พบพัสดุ', () {
      expect(
        () => decodeTrackingBody('Unknow DocumentNumber'),
        throwsA(
          isA<TrackingException>().having((e) => e.notFound, 'notFound', true),
        ),
      );
    });

    test('unknow client = ปัญหาสิทธิ์ ไม่ใช่ไม่พบพัสดุ', () {
      expect(
        () => decodeTrackingBody('unknow client'),
        throwsA(
          isA<TrackingException>().having((e) => e.notFound, 'notFound', false),
        ),
      );
    });

    test('please check data = พารามิเตอร์ไม่ครบ', () {
      expect(
        () => decodeTrackingBody('please check data'),
        throwsA(isA<TrackingException>()),
      );
    });

    test('body ว่างหรือข้อความที่ไม่รู้จักก็ไม่พัง', () {
      expect(() => decodeTrackingBody(''), throwsA(isA<TrackingException>()));
      expect(
        () => decodeTrackingBody('อะไรก็ไม่รู้'),
        throwsA(isA<TrackingException>()),
      );
    });

    test('JSON ที่ซ่อมแล้วยังพังก็ไม่ throw ดิบออกไป', () {
      expect(
        () => decodeTrackingBody('{"a":'),
        throwsA(isA<TrackingException>()),
      );
    });
  });

  group('lastFourDigits', () {
    test('ตัดอักขระที่ไม่ใช่ตัวเลขแล้วเอา 4 ตัวท้าย', () {
      expect(lastFourDigits('095-1058256'), '8256');
      expect(lastFourDigits('095 105 8256'), '8256');
      expect(lastFourDigits('8256'), '8256');
    });

    test('สั้นกว่า 4 หลักหรือไม่มีค่า คืน null (จะไม่ส่ง tel ไป)', () {
      expect(lastFourDigits('123'), isNull);
      expect(lastFourDigits(''), isNull);
      expect(lastFourDigits(null), isNull);
      expect(lastFourDigits('-- --'), isNull);
    });
  });

  group('parseStatusDate', () {
    test('อ่านรูปแบบที่ API ส่งมาได้ และไม่แปลง timezone', () {
      final date = parseStatusDate('2026-09-11T13:06:40');

      expect(date, DateTime(2026, 9, 11, 13, 6, 40));
      expect(date!.isUtc, isFalse);
    });

    test('มี Z ต่อท้ายก็ยังอ่านเป็นเวลาไทยตามตัวเลขที่เห็น', () {
      expect(
        parseStatusDate('2026-09-11T13:06:40Z'),
        DateTime(2026, 9, 11, 13, 6, 40),
      );
    });

    test('ค่าที่อ่านไม่ออกคืน null ไม่ throw', () {
      expect(parseStatusDate(''), isNull);
      expect(parseStatusDate(null), isNull);
      expect(parseStatusDate('11/09/2026'), isNull);
    });
  });

  group('readText', () {
    test('สตริงว่างถือว่าไม่มีค่า', () {
      expect(readText(''), isNull);
      expect(readText('   '), isNull);
      expect(readText(null), isNull);
      expect(readText(13.75), '13.75');
    });
  });

  group('sortEventsNewestFirst', () {
    test('แถวที่อ่านวันที่ไม่ออกถูกดันไปท้าย ไม่ถูกทิ้ง', () {
      final sorted = sortEventsNewestFirst([
        const TrackingEvent(statusId: 'X', statusName: 'ไม่รู้จัก'),
        TrackingEvent(
          statusId: '7',
          statusName: 'ส่งถึง',
          statusDate: DateTime(2026, 9, 11),
        ),
        TrackingEvent(
          statusId: '1',
          statusName: 'คีย์เอกสาร',
          statusDate: DateTime(2026, 9, 9),
        ),
      ]);

      expect(sorted.map((e) => e.statusId).toList(), ['7', '1', 'X']);
    });
  });
}
