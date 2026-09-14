import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// พิกัดที่แนบไปกับรูปถ่าย
class GeoPoint {
  final double lat;
  final double lon;

  const GeoPoint(this.lat, this.lon);

  /// รูปแบบที่ API ฝั่ง gps ต้องการ
  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon};

  /// (0, 0) คือค่าที่เซิร์ฟเวอร์ใช้แทน "ไม่มีพิกัด" ไม่ใช่พิกัดจริง
  bool get isValid => lat != 0 || lon != 0;

  @override
  String toString() => '$lat,$lon';
}

/// สาเหตุที่ขอพิกัดไม่ได้ ใช้เลือกข้อความบอกผู้ใช้
enum LocationFailure {
  /// ผู้ใช้ปิด GPS ที่ตัวเครื่อง
  serviceDisabled,

  /// ปฏิเสธสิทธิ์ (ยังขอใหม่ได้)
  denied,

  /// ปฏิเสธถาวร ต้องไปเปิดในตั้งค่าเครื่อง
  deniedForever,

  /// ขอแล้วแต่หาไม่เจอ / หมดเวลา
  unavailable,
}

/// ผลของการขอพิกัด สำเร็จจะมี [point] ล้มเหลวจะมี [failure]
class LocationResult {
  final GeoPoint? point;
  final LocationFailure? failure;

  const LocationResult.success(GeoPoint this.point) : failure = null;
  const LocationResult.failed(LocationFailure this.failure) : point = null;

  bool get isSuccess => point != null;
}

/// ดึงพิกัดปัจจุบันความละเอียดสูง
///
/// ไม่ throw ในทุกกรณี ผู้เรียกดูจาก [LocationResult.isSuccess] แล้วตัดสินใจเอง
/// (ฟีเจอร์บันทึกไมล์ใช้ผลนี้เป็นเงื่อนไขว่าจะอัปโหลดรูปต่อหรือไม่)
class LocationService {
  LocationService._();

  static final LocationService I = LocationService._();

  /// เผื่อเวลาให้เครื่องจับดาวเทียม แต่ไม่ปล่อยให้ผู้ใช้รอไม่จบ
  static const Duration _timeLimit = Duration(seconds: 20);

  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.failed(LocationFailure.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.failed(LocationFailure.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult.failed(LocationFailure.denied);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _timeLimit,
        ),
      );

      return LocationResult.success(
        GeoPoint(position.latitude, position.longitude),
      );
    } catch (e) {
      debugPrint('LocationService failed: $e');
      return const LocationResult.failed(LocationFailure.unavailable);
    }
  }

  /// เปิดหน้าตั้งค่าตำแหน่งของเครื่อง ใช้ตอนผู้ใช้ปฏิเสธถาวร
  Future<void> openSettings(LocationFailure failure) async {
    if (failure == LocationFailure.serviceDisabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}
