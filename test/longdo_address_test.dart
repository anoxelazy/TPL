import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/plan/longdo_address_api.dart';

void main() {
  group('ลิงก์ขอที่อยู่จาก Longdo', () {
    test('ส่ง lat/lon แยกช่อง พร้อม key', () {
      final url = buildLongdoAddressUrl(
        lat: 13.72427,
        lon: 100.53726,
        key: 'k',
      );

      expect(url.host, 'api.longdo.com');
      expect(url.path, '/map/services/address');
      expect(url.queryParameters['lat'], '13.72427');
      expect(url.queryParameters['lon'], '100.53726');
      expect(url.queryParameters['noelevation'], '1');
      expect(url.queryParameters['key'], 'k');
    });
  });

  group('ประกอบที่อยู่', () {
    test('เรียงถนน ตำบล อำเภอ จังหวัด รหัสไปรษณีย์', () {
      final address = parseLongdoAddress({
        'geocode': '100402',
        'province': 'กรุงเทพมหานคร',
        'district': 'เขตบางรัก',
        'subdistrict': 'แขวงสีลม',
        'postcode': '10500',
        'road': 'ถนนสาทรเหนือ',
      });

      expect(address, 'ถนนสาทรเหนือ แขวงสีลม เขตบางรัก กรุงเทพมหานคร 10500');
    });

    test('จุดที่ไม่อยู่ติดถนน ข้ามช่องถนนไป', () {
      final address = parseLongdoAddress({
        'province': 'ชลบุรี',
        'district': 'อำเภอบางละมุง',
        'subdistrict': 'ตำบลหนองปรือ',
        'postcode': 20150,
      });

      expect(address, 'ตำบลหนองปรือ อำเภอบางละมุง ชลบุรี 20150');
    });

    test('ของที่อ่านไม่ได้คืนค่าว่าง', () {
      expect(parseLongdoAddress(null), '');
      expect(parseLongdoAddress('ไม่ใช่ json'), '');
      expect(parseLongdoAddress({}), '');
    });
  });
}
