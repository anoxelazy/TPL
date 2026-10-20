import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:claim/page/plan/route_road_api.dart';

void main() {
  group('body ขอเส้นทางจาก OpenRouteService', () {
    test('เรียงพิกัดเป็น [lon, lat]', () {
      final body = buildOrsRouteBody([
        LatLng(13.7279, 100.7856),
        LatLng(13.7376, 100.7605),
      ]);

      expect(body['coordinates'], [
        [100.7856, 13.7279],
        [100.7605, 13.7376],
      ]);
    });

    test('จุดเยอะเกินที่รับได้ ตัดให้เหลือเท่าที่ส่งได้', () {
      final points = [
        for (var i = 0; i < kOrsMaxPoints + 10; i++)
          LatLng(13.7 + i * 0.01, 100.5),
      ];

      expect(
        buildOrsRouteBody(points)['coordinates'],
        hasLength(kOrsMaxPoints),
      );
    });
  });

  group('แกะเส้นทางของ OpenRouteService', () {
    test('อ่านจาก features[0].geometry ของ FeatureCollection', () {
      final data = jsonDecode('''
        {"type":"FeatureCollection","features":[{"type":"Feature",
          "geometry":{"type":"LineString",
            "coordinates":[[100.7856,13.7279],[100.7605,13.7376]]}}]}
      ''');

      final points = parseOrsGeometry(data);

      expect(points, hasLength(2));
      expect(points.first.latitude, closeTo(13.7279, 0.00001));
      expect(points.first.longitude, closeTo(100.7856, 0.00001));
    });

    test('ของที่อ่านไม่ได้คืนลิสต์ว่าง ไม่ throw', () {
      expect(parseOrsGeometry(null), isEmpty);
      expect(parseOrsGeometry('ไม่ใช่ json'), isEmpty);
      expect(parseOrsGeometry({'features': []}), isEmpty);
      // หน้าตา error ของ ORS ตอน key ผิดหรือโควตาหมด
      expect(
        parseOrsGeometry({'error': 'Access to this API has been disallowed'}),
        isEmpty,
      );
      expect(
        parseOrsGeometry({
          'features': [
            {'geometry': null},
          ],
        }),
        isEmpty,
      );
    });
  });
}
