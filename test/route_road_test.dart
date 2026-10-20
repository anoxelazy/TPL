import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:claim/page/plan/route_road_api.dart';

void main() {
  group('ลิงก์ขอเส้นทางจาก OSRM', () {
    test('เรียงพิกัดเป็น lon,lat ตามที่ OSRM ต้องการ', () {
      final url = buildOsrmRouteUrl([
        LatLng(13.7279, 100.7856),
        LatLng(13.7376, 100.7605),
      ]);

      // สลับผิดเมื่อไหร่ได้เส้นทางกลางทะเลจีนใต้ทันที
      expect(url.path, contains('100.7856,13.7279;100.7605,13.7376'));
      expect(url.queryParameters['geometries'], 'geojson');
      expect(url.queryParameters['overview'], 'full');
    });

    test('จุดเยอะเกินที่เซิร์ฟเวอร์รับ ตัดให้เหลือเท่าที่ส่งได้', () {
      final points = [
        for (var i = 0; i < kOsrmMaxPoints + 10; i++)
          LatLng(13.7 + i * 0.01, 100.5),
      ];

      final coords = buildOsrmRouteUrl(points).pathSegments.last.split(';');

      expect(coords, hasLength(kOsrmMaxPoints));
    });
  });

  group('แกะเส้นทางที่ได้มา', () {
    test('อ่าน GeoJSON LineString เป็นลิสต์พิกัด', () {
      final data = jsonDecode('''
        {"routes":[{"geometry":{"coordinates":[[100.7856,13.7279],[100.7605,13.7376]]}}]}
      ''');

      final points = parseOsrmGeometry(data);

      expect(points, hasLength(2));
      // GeoJSON เก็บ [lon, lat] ต้องสลับกลับตอนอ่าน
      expect(points.first.latitude, closeTo(13.7279, 0.00001));
      expect(points.first.longitude, closeTo(100.7856, 0.00001));
    });

    test('ของที่อ่านไม่ได้คืนลิสต์ว่าง ไม่ throw', () {
      expect(parseOsrmGeometry(null), isEmpty);
      expect(parseOsrmGeometry('ไม่ใช่ json'), isEmpty);
      expect(parseOsrmGeometry({'routes': []}), isEmpty);
      expect(parseOsrmGeometry({'routes': 'พัง'}), isEmpty);
      expect(
        parseOsrmGeometry({
          'routes': [
            {'geometry': null},
          ],
        }),
        isEmpty,
      );
    });

    test('ข้ามพิกัดที่ไม่ครบคู่ ไม่ทิ้งทั้งเส้น', () {
      final points = parseOsrmGeometry({
        'routes': [
          {
            'geometry': {
              'coordinates': [
                [100.5, 13.7],
                [100.6],
                [100.7, 13.8],
              ],
            },
          },
        ],
      });

      expect(points, hasLength(2));
    });
  });
}
