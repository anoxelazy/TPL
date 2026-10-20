import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/plan/route_map_page.dart';
import 'package:claim/page/plan/route_plan_models.dart';

RouteStopGroup _group(double lat, double lon) => RouteStopGroup(
  lat: lat,
  lon: lon,
  stops: [RouteStop(seq: 1, docId: 'D', lat: lat, lon: lon)],
);

void main() {
  group('ลิงก์เส้นทางทั้งรอบ', () {
    test('เริ่มจากตำแหน่งปัจจุบัน ไม่ล็อกจุดเริ่มเป็นคลัง', () {
      final url = buildMapsRouteUrl(
        order: [_group(13.7376, 100.7605), _group(13.7106, 100.746)],
      );

      // ไม่ส่ง origin ไป กูเกิลแมปจะใช้ตำแหน่งรถตอนนั้นให้เอง
      expect(url.queryParameters.containsKey('origin'), isFalse);
      expect(url.queryParameters['travelmode'], 'driving');
    });

    test('ไม่สั่งเริ่มนำทางเอง ให้คนขับกดเริ่มเองตอนพร้อม', () {
      final url = buildMapsRouteUrl(order: [_group(13.72, 100.52)]);

      // มี dir_action=navigate เมื่อไหร่ แมปจะเข้าโหมดนำทางทันทีตั้งแต่ยังจอด
      // อยู่ท้ายคลัง เสียงบอกทางจะพูดทั้งที่คนขับยังจัดของอยู่
      expect(url.queryParameters.containsKey('dir_action'), isFalse);
    });

    test('จุดสุดท้ายเป็นปลายทาง ที่เหลือเป็นจุดแวะ', () {
      final url = buildMapsRouteUrl(
        order: [
          _group(13.7376, 100.7605),
          _group(13.7106, 100.746),
          _group(13.6929, 100.77),
        ],
      );

      expect(url.queryParameters['destination'], '13.6929,100.77');
      expect(
        url.queryParameters['waypoints'],
        '13.7376,100.7605|13.7106,100.746',
      );
    });

    test('จุดเดียวก็เป็นปลายทางเลย ไม่มีจุดแวะ', () {
      final url = buildMapsRouteUrl(order: [_group(13.7376, 100.7605)]);

      expect(url.queryParameters['destination'], '13.7376,100.7605');
      expect(url.queryParameters.containsKey('waypoints'), isFalse);
    });

    test('จุดเยอะเกินที่แมปรับได้ ตัดให้เหลือเท่าที่เปิดขึ้น', () {
      final order = [
        for (var i = 0; i < kMapMaxWaypoints + 5; i++)
          _group(13.7 + i * 0.01, 100.5),
      ];

      final params = buildMapsRouteUrl(order: order).queryParameters;

      // ส่งครบทุกจุดแล้วลิงก์จะยาวจนแมปไม่ยอมเปิด กลายเป็นจอขาว
      expect(params['waypoints']!.split('|'), hasLength(kMapMaxWaypoints));
      expect(params['destination'], isNotNull);
    });

    test('ไม่มีจุดเลยก็ยังสร้างลิงก์ได้ ไม่ throw', () {
      expect(buildMapsRouteUrl(order: const []).host, 'www.google.com');
    });
  });

  group('ลิงก์เส้นทางไปจุดเดียว', () {
    test('ตั้งปลายทางให้ แต่ไม่สั่งเริ่มนำทางและไม่ล็อกจุดเริ่ม', () {
      final url = buildMapsStopUrl(lat: 13.7376, lon: 100.7605);

      expect(url.queryParameters['destination'], '13.7376,100.7605');
      expect(url.queryParameters['travelmode'], 'driving');
      // คนขับกดเริ่มเองในแมป และแมปใช้ตำแหน่งรถตอนนั้นเป็นจุดเริ่ม
      expect(url.queryParameters.containsKey('dir_action'), isFalse);
      expect(url.queryParameters.containsKey('origin'), isFalse);
    });
  });
}
