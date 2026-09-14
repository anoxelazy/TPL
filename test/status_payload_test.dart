import 'dart:convert';

import 'package:claim/page/stock/status_post_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('body ที่ส่งตอนพักสถานะ', () {
    final payload = buildStatusPayload(
      a1: 'HVR012609071881',
      statusCode: kParkStatusCode,
      user: '10164008',
      timestamp: DateTime(2026, 9, 8, 10, 30),
      reasonCode: '62',
    );

    // ignore: avoid_print
    print(const JsonEncoder.withIndent('  ').convert(payload));
    expect(payload.keys, [
      'A1',
      'StatusCode',
      'Lat',
      'Long',
      'Timestemp',
      'records',
      'Signature',
      'User',
      'ReasonCode',
      'Relationship',
      'Remark',
      'image1',
      'image2',
      'image3',
      'image4',
      'image5',
      'TypeAddr',
      'pod_img',
    ]);

    expect(payload['A1'], 'HVR012609071881');
    expect(payload['StatusCode'], '2');
    expect(payload['ReasonCode'], '62');
    expect(payload['User'], '10164008');
    expect(payload['Timestemp'], '2026-09-08T10:30:00.000');
    expect(payload['Lat'], 0);
    expect(payload['Long'], 0);
    expect(payload['records'], isEmpty);
    // หน้าจอไม่มีช่องหมายเหตุแล้ว จึงส่ง null
    expect(payload['Remark'], isNull);
  });

  test('records แปลงเป็น json ตามรูปในตัวอย่าง cURL', () {
    final payload = buildStatusPayload(
      a1: 'TP123456789',
      statusCode: kParkStatusCode,
      user: 'EMP001',
      timestamp: DateTime(2026, 9, 8, 10, 30),
      reasonCode: '90',
      records: [
        CallRecord(
          dateTime: DateTime(2026, 9, 8, 10, 25),
          answered: true,
          durationSeconds: 45,
          number: '0812345678',
        ),
      ],
    );

    expect(payload['records'], [
      {
        'datetime': '2026-09-08T10:25:00.000',
        'answered': true,
        'durationSeconds': 45,
        'number': '0812345678',
      },
    ]);
  });
}
