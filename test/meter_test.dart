import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/meter/meter_api.dart';
import 'package:claim/page/meter/meter_widgets.dart';
import 'package:claim/utils/url_utils.dart';

/// รูปแบบที่ /getmeter ตอบมาจริงตอนบันทึกไมล์ต้นไปแล้ว
const String _getMeterResponse =
    '[{"TranDate":"2026-09-08T00:00:00","InputData":{'
    '"StartMeter":{"Meter":125000,"MeterURL":"http://x/img//start.jpg",'
    '"gps":{"lat":13.75,"lon":100.5}},'
    '"EndMeter":{"Meter":0,"MeterURL":"","gps":{"lat":0,"lon":0}}}}]';

/// ผลจาก /InputMeter คีย์เล็กใหญ่ปนกันและ endtMeter สะกดผิดตามของจริง
const String _inputMeterResponse =
    '{"TranDate":"2026-09-08T00:00:00","DriverID":"D001","TruckID":"T001",'
    '"TruckLicesen":"1กก-1234","SLat":13.7563,"SLon":100.5018,'
    '"ELat":13.8,"ELon":100.6,'
    '"startMeter":125000,"StartMeterURL":"http://x/start.jpg",'
    '"endtMeter":125420,"EndMeterURL":"http://x/end.jpg",'
    '"standardFuelPrice":"30.5","currentFuelPrice":32.75,'
    '"fuelConsumptionRate":8.5,"distanceDifference":420,'
    '"fuelPriceDifference":2.25,"fuelCompensation":49.41,'
    '"compensationRate":111.18,'
    '"RecBranchEmp":"BKK10","RecEmp":"EMP001","RecDate":"2026-09-08T18:30:00"}';

MeterDay _day(String json) => MeterDay.fromJson(
  Map<String, dynamic>.from((jsonDecode(json) as List).first),
);

void main() {
  group('normalizeUrl', () {
    test('เติม http:// ให้ URL ที่ไม่มี scheme', () {
      expect(
        normalizeUrl('147.50.36.66/img/a.jpg'),
        'http://147.50.36.66/img/a.jpg',
      );
    });

    test('บีบ slash ซ้อนใน path แต่ไม่พัง scheme', () {
      expect(normalizeUrl('http://x//img///a.jpg'), 'http://x/img/a.jpg');
      expect(normalizeUrl('https://x//a.jpg'), 'https://x/a.jpg');
    });

    test('ค่าที่แปลว่าไม่มีรูปต้องได้ null', () {
      expect(resolveImageUrl(''), isNull);
      expect(resolveImageUrl(0), isNull);
      expect(resolveImageUrl('0'), isNull);
      expect(resolveImageUrl(null), isNull);
      expect(resolveImageUrl('http://x/a.jpg'), 'http://x/a.jpg');
    });
  });

  group('getmeter', () {
    test('อ่านไมล์ต้น รูป และพิกัดจาก element ตัวแรก', () {
      final day = _day(_getMeterResponse);

      expect(day.tranDate, DateTime(2026, 9, 8));
      expect(day.start.meter, 125000);
      // normalize ตอนอ่านด้วย ไม่ใช่แค่ตอนอัปโหลด
      expect(day.start.imageUrl, 'http://x/img/start.jpg');
      expect(day.start.gps?.lat, 13.75);
      expect(day.start.isComplete, isTrue);
    });

    test('ไมล์ปลายที่ยังไม่มีข้อมูลต้องไม่ถือว่าครบ', () {
      final day = _day(_getMeterResponse);

      expect(day.end.meter, 0);
      expect(day.end.imageUrl, isNull);
      // gps 0,0 คือค่าที่เซิร์ฟเวอร์ใช้แทน "ไม่มีพิกัด"
      expect(day.end.gps, isNull);
      expect(day.end.isComplete, isFalse);
    });

    test('InputData เป็น null = ยังไม่มีข้อมูลของวันนี้', () {
      final day = MeterDay.fromJson({
        'TranDate': '2026-09-08T00:00:00',
        'InputData': null,
      });

      expect(day.isEmpty, isTrue);
    });

    test('เลขไมล์มาเป็น string ก็ต้องอ่านได้', () {
      final side = MeterSide.fromJson({'Meter': '125000', 'MeterURL': ''});
      expect(side.meter, 125000);
      expect(side.hasMeter, isTrue);
      // มีเลขไมล์แต่ไม่มีรูป ยังไม่นับว่าครบ ต้องเติมรูปได้
      expect(side.isComplete, isFalse);
    });
  });

  group('InputMeter response', () {
    test('map ตามคีย์ที่เซิร์ฟเวอร์ส่งจริงครบทุกตัวเลข', () {
      final result = MeterResult.fromJson(
        jsonDecode(_inputMeterResponse) as Map<String, dynamic>,
      );

      expect(result.driverId, 'D001');
      expect(result.truckId, 'T001');
      expect(result.truckLicense, '1กก-1234');
      // startMeter ตัวเล็ก / endtMeter สะกดผิด / StartMeterURL ตัวใหญ่
      expect(result.startMeter, 125000);
      expect(result.endMeter, 125420);
      expect(result.startMeterUrl, 'http://x/start.jpg');
      expect(result.endMeterUrl, 'http://x/end.jpg');
      // ส่งมาเป็น string ต้องได้ค่าเท่ากับที่ส่งมาเป็น number
      expect(result.standardFuelPrice, 30.5);
      expect(result.currentFuelPrice, 32.75);
      expect(result.fuelConsumptionRate, 8.5);
      expect(result.distanceDifference, 420);
      expect(result.fuelPriceDifference, 2.25);
      expect(result.fuelCompensation, 49.41);
      expect(result.compensationRate, 111.18);
      expect(result.recEmp, 'EMP001');
      expect(result.recBranchEmp, 'BKK10');
      expect(result.recDate, DateTime(2026, 9, 8, 18, 30));
    });

    test('URL ที่เป็น 0 หรือว่างต้องกลายเป็น null', () {
      final result = MeterResult.fromJson({
        'startMeter': 1,
        'StartMeterURL': 0,
        'endtMeter': 2,
        'EndMeterURL': '',
      });

      expect(result.startMeterUrl, isNull);
      expect(result.endMeterUrl, isNull);
    });
  });

  group('ช่องกรอกเลขไมล์', () {
    const formatter = ThousandsInputFormatter();

    TextEditingValue format(String text) => formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: text),
    );

    test('ใส่คอมมาคั่นหลักพันระหว่างพิมพ์', () {
      expect(format('125000').text, '125,000');
      expect(format('1').text, '1');
      expect(format('12').text, '12');
      expect(format('1234').text, '1,234');
    });

    test('พิมพ์ตัวอักษรอื่นไม่ติด', () {
      expect(format('12a3').text, '123');
    });

    test('ค่าที่ส่ง API ต้องเป็นตัวเลขล้วนไม่มีคอมมา', () {
      expect(parseMeterInput('125,000'), 125000);
      expect(parseMeterInput(''), 0);
      expect(parseMeterInput('  '), 0);
    });

    test('cursor อยู่ท้ายข้อความหลัง format', () {
      final value = format('125000');
      expect(value.selection.baseOffset, value.text.length);
    });
  });
}
