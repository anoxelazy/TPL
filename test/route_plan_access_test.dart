import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/plan/route_plan_access.dart';

Map<String, dynamic> _fixture() =>
    jsonDecode(File('test/fixtures/route_plan.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('สิทธิ์เห็นแผนเดินรถ', () {
    test('ตอนนี้เปิดให้ 68148 คนเดียว', () {
      expect(kRoutePlanTesters, ['68148']);

      expect(isRoutePlanTester('68148'), isTrue);
      expect(isRoutePlanTester('68051'), isFalse);
      expect(isRoutePlanTester('68052'), isFalse);
    });

    test('ยังไม่ได้ล็อกอินหรือรหัสว่าง ต้องไม่เห็น', () {
      expect(isRoutePlanTester(null), isFalse);
      expect(isRoutePlanTester(''), isFalse);
      expect(isRoutePlanTester('   '), isFalse);
    });

    test('ช่องว่างหัวท้ายไม่ทำให้สิทธิ์หลุด', () {
      // prefs เคยเก็บค่าที่มีช่องว่างติดมาจากฟอร์มล็อกอิน
      expect(isRoutePlanTester(' 68148 '), isTrue);
    });
  });

  group('ไฟล์ทดสอบแผนเดินรถ', () {
    test('มีแผนของ 68148 ให้ทดสอบ และมีของคนอื่นไว้เช็คว่ากรองจริง', () {
      final plans = (_fixture()['plans'] as List).cast<Map<String, dynamic>>();

      final mine = plans.where((p) => p['driverid'] == '68148').toList();
      final others = plans.where((p) => p['driverid'] != '68148').toList();

      expect(mine, hasLength(2));
      expect(
        others,
        isNotEmpty,
        reason: 'ต้องมีแผนของคนอื่นปนอยู่ ไม่งั้นเทสต์ตัวกรองไม่ได้ว่ากรองจริง',
      );
    });

    test('ทุกจุดส่งมีช่องพิกัดครบ แม้ค่าจะว่าง', () {
      final plans = (_fixture()['plans'] as List).cast<Map<String, dynamic>>();

      for (final plan in plans) {
        for (final stop in (plan['stops'] as List).cast<Map>()) {
          expect(
            stop.containsKey('poslat') && stop.containsKey('poslon'),
            isTrue,
            reason: 'ใบ ${stop['docid']} ไม่มีช่องพิกัด ตัวอ่านจะพังตั้งแต่ต้น',
          );
        }
      }
    });

    test('แผนของ 68148 มีทั้งพิกัดปกติและเคสพิกัดใช้ไม่ได้', () {
      final plans = (_fixture()['plans'] as List).cast<Map<String, dynamic>>();
      final stops = [
        for (final plan in plans.where((p) => p['driverid'] == '68148'))
          ...(plan['stops'] as List).cast<Map>(),
      ];

      bool usable(Map stop) {
        final lat = stop['poslat'];
        final lon = stop['poslon'];
        // 0 ถือว่าไม่มีพิกัด ไม่ใช่จุดกลางมหาสมุทรแอตแลนติก
        return lat is num && lon is num && lat != 0 && lon != 0;
      }

      expect(stops.where(usable), isNotEmpty);
      expect(
        stops.where((s) => !usable(s)),
        isNotEmpty,
        reason: 'ต้องมีเคสพิกัดว่าง/เป็นศูนย์ไว้ให้ตัวจัดเส้นทางเจอ',
      );
      expect(
        stops.where((s) => s['status_online'] == '1'),
        isNotEmpty,
        reason: 'ต้องมีใบที่ส่งไปแล้ว ไว้เช็คว่าไม่ถูกเอาเข้าเส้นทาง',
      );
    });
  });
}
