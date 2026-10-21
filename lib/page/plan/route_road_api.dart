/// ขอเส้นทางตามถนนจริงมาวาดบนแมป
///
/// ไล่ลองทีละที่ ได้ที่ไหนก่อนใช้ที่นั่น:
/// 1. OpenRouteService — ฟรีแต่ต้องมี key ([MapKeys.ors]) มีโควตาต่อวันชัดเจน
///    และทำมาให้แอปใช้งานจริง ต่างจาก OSRM สาธารณะที่เป็นแค่เซิร์ฟเวอร์ทดลอง
/// 2. OSRM ตัวสาธารณะ — ไม่ต้องมี key แต่ไม่มีใครรับประกันว่าจะขึ้นตลอด
/// 3. ผู้เรียกลากเส้นตรงระหว่างจุดเอง (ฟังก์ชันนี้คืนลิสต์ว่าง)
///
/// ไม่มี key ก็ข้ามข้อ 1 ไปเลย แอปทำงานแบบเดิมทุกอย่าง
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'package:claim/utils/dio_service.dart';
import 'package:claim/utils/map_keys.dart';

const String kOsrmBaseUrl = 'https://router.project-osrm.org';

// key ของ OpenRouteService มาจากไฟล์คีย์กลาง ดู [MapKeys]
// สมัครฟรีที่ openrouteservice.org ไม่ฝังไว้ในโค้ดเพราะ repo นี้ไม่ได้ลับ

const String kOrsDirectionsUrl =
    'https://api.openrouteservice.org/v2/directions/driving-car/geojson';

/// จำนวนจุดสูงสุดที่ส่งให้ OpenRouteService ต่อครั้ง (แพ็กเกจฟรีรับได้ 50)
const int kOrsMaxPoints = 50;

/// จำนวนจุดสูงสุดที่ส่งไปขอเส้นทางต่อครั้ง
///
/// OSRM ตัวสาธารณะจำกัดความยาว URL อยู่ แผนหนึ่งรอบของจริงไม่เกิน 30 จุดอยู่แล้ว
const int kOsrmMaxPoints = 25;

/// URL ขอเส้นทางขับรถผ่านทุกจุดตามลำดับ
///
/// OSRM เรียงพิกัดเป็น `lon,lat` กลับกับที่คนทั่วไปเขียน สลับผิดแล้วจะได้
/// เส้นทางกลางทะเลจีนใต้
Uri buildOsrmRouteUrl(List<LatLng> points) {
  final coords = points
      .take(kOsrmMaxPoints)
      .map((p) => '${p.longitude},${p.latitude}')
      .join(';');

  return Uri.parse(
    '$kOsrmBaseUrl/route/v1/driving/$coords'
    '?overview=full&geometries=geojson',
  );
}

/// แกะเส้นทางออกจาก response ของ OSRM คืนลิสต์ว่างเมื่ออ่านไม่ได้
///
/// geometry เป็น GeoJSON LineString: `coordinates` เป็นคู่ `[lon, lat]`
List<LatLng> parseOsrmGeometry(dynamic data) {
  try {
    if (data is! Map) return const [];

    final routes = data['routes'];
    if (routes is! List || routes.isEmpty) return const [];

    final coordinates = (routes.first as Map)['geometry']?['coordinates'];
    if (coordinates is! List) return const [];

    return [
      for (final pair in coordinates)
        if (pair is List && pair.length >= 2)
          LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble()),
    ];
  } catch (e) {
    debugPrint('osrm parse: $e');
    return const [];
  }
}

/// body ที่ส่งให้ OpenRouteService พิกัดเป็น `[lon, lat]` แบบเดียวกับ OSRM
Map<String, dynamic> buildOrsRouteBody(List<LatLng> points) => {
  'coordinates': [
    for (final p in points.take(kOrsMaxPoints)) [p.longitude, p.latitude],
  ],
};

/// แกะเส้นทางออกจาก GeoJSON ของ OpenRouteService คืนลิสต์ว่างเมื่ออ่านไม่ได้
///
/// ต่างจาก OSRM ตรงที่ห่อมาเป็น FeatureCollection: เส้นทางอยู่ที่
/// `features[0].geometry.coordinates`
List<LatLng> parseOrsGeometry(dynamic data) {
  try {
    if (data is! Map) return const [];

    final features = data['features'];
    if (features is! List || features.isEmpty) return const [];

    final coordinates = (features.first as Map)['geometry']?['coordinates'];
    if (coordinates is! List) return const [];

    return [
      for (final pair in coordinates)
        if (pair is List && pair.length >= 2)
          LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble()),
    ];
  } catch (e) {
    debugPrint('ors parse: $e');
    return const [];
  }
}

/// เส้นทางตามถนนที่ลากผ่านทุกจุดตามลำดับ คืนลิสต์ว่างเมื่อขอไม่ได้ทุกที่
///
/// ไม่ throw เพราะผู้เรียกมีทางถอยอยู่แล้ว (ลากเส้นตรง) การโยน exception
/// ขึ้นไปมีแต่ทำให้หน้าแมปพังทั้งหน้าทั้งที่ยังแสดงอะไรได้อยู่
Future<List<LatLng>> fetchRoadRoute(List<LatLng> points) async {
  if (points.length < 2) return const [];

  if (MapKeys.ors.isNotEmpty) {
    final road = await _fetchOrsRoute(points);
    if (road.isNotEmpty) return road;
  }

  return _fetchOsrmRoute(points);
}

Future<List<LatLng>> _fetchOrsRoute(List<LatLng> points) async {
  try {
    final response = await dio.post(
      kOrsDirectionsUrl,
      data: buildOrsRouteBody(points),
      options: Options(
        headers: {'Authorization': MapKeys.ors},
        receiveTimeout: const Duration(seconds: 20),
        validateStatus: (_) => true,
      ),
    );

    // 401/403 = key ผิด, 429 = โควตาวันนี้หมด ถอยไป OSRM ทั้งคู่
    if (response.statusCode != 200) {
      debugPrint('ors: HTTP ${response.statusCode}');
      return const [];
    }

    return parseOrsGeometry(response.data);
  } catch (e) {
    debugPrint('ors: $e');
    return const [];
  }
}

Future<List<LatLng>> _fetchOsrmRoute(List<LatLng> points) async {
  try {
    final response = await dio.getUri(
      buildOsrmRouteUrl(points),
      options: Options(
        receiveTimeout: const Duration(seconds: 20),
        validateStatus: (_) => true,
      ),
    );

    if (response.statusCode != 200) {
      debugPrint('osrm: HTTP ${response.statusCode}');
      return const [];
    }

    return parseOsrmGeometry(response.data);
  } catch (e) {
    debugPrint('osrm: $e');
    return const [];
  }
}
