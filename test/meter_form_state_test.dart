import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/meter/meter_api.dart';
import 'package:claim/page/meter/meter_controller.dart';

MeterSide _side({int meter = 0, String? url}) =>
    MeterSide(meter: meter, imageUrl: url);

MeterDay _day({required MeterSide start, required MeterSide end}) =>
    MeterDay(tranDate: DateTime(2026, 9, 8), start: start, end: end);

/// ฟอร์มที่กรอกครบพร้อมบันทึกช่วงเช้า
MeterController _readyMorning() {
  final c = MeterController()
    ..driverId = 'D001'
    ..truckId = 'T001'
    ..startMeter = 125000;
  c.startImage.url = 'http://x/start.jpg';
  return c;
}

void main() {
  group('ช่วงของวันตัดสินจากผล getmeter', () {
    test('ยังไม่มีข้อมูล = ช่วงเช้า', () {
      expect(MeterController.phaseFor(null), MeterPhase.morning);
    });

    test('มีไมล์ต้นครบ แต่ไม่มีไมล์ปลาย = ช่วงเย็น', () {
      final day = _day(
        start: _side(meter: 125000, url: 'http://x/s.jpg'),
        end: _side(),
      );
      expect(MeterController.phaseFor(day), MeterPhase.evening);
    });

    test('ครบทั้งสองช่วง = complete', () {
      final day = _day(
        start: _side(meter: 125000, url: 'http://x/s.jpg'),
        end: _side(meter: 125420, url: 'http://x/e.jpg'),
      );
      expect(MeterController.phaseFor(day), MeterPhase.complete);
    });

    test('มีเลขไมล์ต้นแต่ไม่มีรูป ยังเป็นช่วงเช้าเพื่อให้เติมรูปได้', () {
      final day = _day(start: _side(meter: 125000), end: _side());
      expect(MeterController.phaseFor(day), MeterPhase.morning);
    });

    test('มีรูปไมล์ต้นแต่เลขไมล์เป็น 0 ก็ยังเป็นช่วงเช้า', () {
      final day = _day(
        start: _side(url: 'http://x/s.jpg'),
        end: _side(),
      );
      expect(MeterController.phaseFor(day), MeterPhase.morning);
    });

    test('มีไมล์ปลายแต่ไมล์ต้นยังไม่ครบ ต้องกลับไปทำไมล์ต้นก่อน', () {
      final day = _day(
        start: _side(meter: 125000),
        end: _side(meter: 125420, url: 'http://x/e.jpg'),
      );
      expect(MeterController.phaseFor(day), MeterPhase.morning);
    });
  });

  group('ลำดับการเตือนก่อนบันทึก', () {
    test('รูปที่ยังอัปโหลดไม่เสร็จมาก่อนทุกข้อ', () {
      final c = _readyMorning();
      c.startImage.uploading = true;

      final problem = c.validate()!;
      expect(problem.message, 'กรุณารอให้อัปโหลดรูปเสร็จก่อน');
      // ข้อนี้เตือนเฉย ๆ ไม่ต้องขึ้น dialog
      expect(problem.asDialog, isFalse);
    });

    test('เลือกรูปแล้วแต่ยังไม่ได้ URL ก็ถือว่ายังไม่เสร็จ', () {
      final c = _readyMorning();
      c.endImage
        ..localFile = File('a.jpg')
        ..url = null;

      expect(c.validate()!.message, 'กรุณารอให้อัปโหลดรูปเสร็จก่อน');
    });

    test('ไมล์ต้นเป็น 0 เตือนก่อนเรื่องรูป', () {
      final c = MeterController()..startMeter = 0;
      final problem = c.validate()!;

      expect(problem.message, 'กรุณากรอกเลขไมล์ต้นก่อนบันทึก');
      expect(problem.asDialog, isTrue);
    });

    test('มีไมล์ต้นแต่ไม่มี URL รูปไมล์ต้น', () {
      final c = MeterController()..startMeter = 125000;

      expect(
        c.validate()!.message,
        'กรุณาถ่ายรูปไมล์ต้นและรออัปโหลดให้เสร็จก่อนบันทึก',
      );
    });

    test('ข้อมูลครบแล้วให้ไปดูหน้าผล ไม่ใช่บันทึกซ้ำ', () {
      final c = _readyMorning()..phase = MeterPhase.complete;
      final problem = c.validate()!;

      expect(
        problem.message,
        'ข้อมูลครบแล้ว ใช้ปุ่มดูรายละเอียดการชดเชยน้ำมันได้เลย',
      );
      expect(problem.asDialog, isFalse);
    });

    test('ช่วงเย็นที่ยังไม่กรอกไมล์ปลาย', () {
      final c = _readyMorning()..phase = MeterPhase.evening;

      expect(c.validate()!.message, 'กรุณากรอกเลขไมล์ปลายก่อนบันทึกช่วงเย็น');
    });

    test('ช่วงเย็นที่มีไมล์ปลายแต่ไม่มีรูป', () {
      final c = _readyMorning()
        ..phase = MeterPhase.evening
        ..endMeter = 125420;

      expect(
        c.validate()!.message,
        'กรุณาถ่ายรูปไมล์ปลายและรออัปโหลดให้เสร็จก่อนบันทึก',
      );
    });

    test('ช่วงเช้าที่กรอกครบผ่าน validate โดยไม่ต้องมีไมล์ปลาย', () {
      expect(_readyMorning().validate(), isNull);
    });

    test('ช่วงเย็นที่กรอกครบผ่าน validate', () {
      final c = _readyMorning()
        ..phase = MeterPhase.evening
        ..endMeter = 125420;
      c.endImage.url = 'http://x/end.jpg';

      expect(c.validate(), isNull);
    });
  });

  group('ระยะทางที่แสดงในฟอร์ม', () {
    test('คิดจากไมล์ปลายลบไมล์ต้น', () {
      final c = MeterController()
        ..startMeter = 125000
        ..endMeter = 125420;
      expect(c.previewDistance, 420);
    });

    test('ยังไม่มีไมล์ปลายให้เป็น 0 ไม่ใช่ค่าติดลบ', () {
      final c = MeterController()..startMeter = 125000;
      expect(c.previewDistance, 0);
    });

    test('ไมล์ปลายน้อยกว่าไมล์ต้น (กรอกผิด) ให้เป็น 0', () {
      final c = MeterController()
        ..startMeter = 125000
        ..endMeter = 100;
      expect(c.previewDistance, 0);
    });
  });

  group('เปลี่ยนคนขับ/หมายเลขรถ', () {
    test('ข้อมูลที่ผู้ใช้กรอกเองไม่ถูกล้างตอนแก้หมายเลขรถ', () {
      final c = MeterController()
        ..onIdentityChanged(driver: 'D001', truck: 'T001')
        ..startMeter = 125000;
      c.startImage.url = 'http://x/start.jpg';

      // แก้หมายเลขรถทีหลัง ยังไม่เคยโหลดข้อมูลเดิมมา
      c.onIdentityChanged(truck: 'T00');

      expect(c.startMeter, 125000);
      expect(c.startImage.url, 'http://x/start.jpg');
      c.dispose();
    });

    test('ข้อมูลที่โหลดมาของคู่ก่อนหน้าต้องถูกล้าง ไม่ให้บันทึกข้ามคู่', () {
      final c = MeterController()
        ..driverId = 'D001'
        ..truckId = 'T001'
        ..startMeter = 125000
        ..phase = MeterPhase.evening
        ..existing = _day(
          start: _side(meter: 125000, url: 'http://x/s.jpg'),
          end: _side(),
        );
      c.startImage.url = 'http://x/s.jpg';

      c.onIdentityChanged(driver: 'D002');

      expect(c.existing, isNull);
      expect(c.startMeter, 0);
      expect(c.startImage.url, isNull);
      expect(c.phase, MeterPhase.morning);
      c.dispose();
    });
  });
}
