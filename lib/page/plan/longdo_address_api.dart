/// แปลงพิกัดเป็นที่อยู่ภาษาไทยด้วย Longdo Map (และ URL ภาพแผนที่ของ Longdo)
///
/// ใช้กับจุดส่งที่ระบบส่งพิกัดมาแต่ช่องที่อยู่ว่าง คนขับจะได้รู้ว่าจุดนั้นอยู่
/// ตำบลไหน ถนนอะไร ไม่ต้องเดาจากหมุดบนแมปอย่างเดียว
///
/// เลือก Longdo แทน Nominatim ของ OSM เพราะชื่อตำบล/อำเภอ/รหัสไปรษณีย์ไทย
/// ครบและตรงกว่า และ Nominatim จำกัด 1 ครั้งต่อวินาที ห้ามยิงจากแอปพร้อมกันเยอะ ๆ
///
/// ไม่ได้ใส่ key ตอน build ก็ไม่ยิงเลย คืนค่าว่างให้หน้าจอแสดงแบบเดิม
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:claim/utils/dio_service.dart';
import 'package:claim/utils/map_keys.dart';

/// key ของ Longdo Map มาจากไฟล์คีย์กลาง ดู [MapKeys]
///
/// สมัครฟรีที่ map.longdo.com ไม่ฝังไว้ในโค้ดเพราะ repo นี้ไม่ได้ลับ

/// ภาพแผนที่ของ Longdo สำหรับ `TileLayer` ของ flutter_map ใช้ key ตัวเดียวกัน
///
/// เป็น tile มาตรฐาน x/y/z แบบเดียวกับ OSM แค่ส่งเป็น query แทน path
/// `{key}` เติมจาก `additionalOptions` ของ TileLayer
const String kLongdoTileUrl =
    'https://ms.longdo.com/mmmap/tile.php'
    '?key={key}&proj=epsg3857&zoom={z}&x={x}&y={y}&mode=normal';

/// URL ขอที่อยู่ของพิกัดหนึ่งจุด
///
/// `noelevation=1` ตัดความสูงจากระดับน้ำทะเลออก ไม่ได้ใช้และทำให้ตอบช้าลง
Uri buildLongdoAddressUrl({
  required double lat,
  required double lon,
  String? key,
}) => Uri.https('api.longdo.com', '/map/services/address', {
  'lat': '$lat',
  'lon': '$lon',
  'noelevation': '1',
  'key': key ?? MapKeys.longdo,
});

/// ประกอบที่อยู่เป็นบรรทัดเดียว เช่น `ถนนสาทรเหนือ แขวงสีลม เขตบางรัก
/// กรุงเทพมหานคร 10500` คืนค่าว่างเมื่ออ่านไม่ได้
///
/// ช่องไหนไม่มีก็ข้าม จุดกลางทุ่งจะไม่มี `road` มาด้วย
String parseLongdoAddress(dynamic data) {
  if (data is! Map) return '';

  return [
    for (final field in ['road', 'subdistrict', 'district', 'province'])
      if (data[field] is String) (data[field] as String).trim(),
    if (data['postcode'] != null) '${data['postcode']}'.trim(),
  ].where((part) => part.isNotEmpty).join(' ');
}

/// ที่อยู่ของพิกัดนี้ คืนค่าว่างเมื่อไม่มี key หรือขอไม่สำเร็จ
///
/// ไม่ throw เพราะที่อยู่เป็นของเสริม ขอไม่ได้หน้าจอยังใช้งานได้ปกติ
Future<String> fetchAddress({required double lat, required double lon}) async {
  if (MapKeys.longdo.isEmpty) return '';

  try {
    final response = await dio.getUri(
      buildLongdoAddressUrl(lat: lat, lon: lon),
      options: Options(
        receiveTimeout: const Duration(seconds: 10),
        validateStatus: (_) => true,
      ),
    );

    if (response.statusCode != 200) {
      debugPrint('longdo: HTTP ${response.statusCode}');
      return '';
    }

    return parseLongdoAddress(response.data);
  } catch (e) {
    debugPrint('longdo: $e');
    return '';
  }
}
