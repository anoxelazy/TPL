/// อุณหภูมิกับโอกาสฝนตรงที่ผู้ใช้อยู่ โชว์มุมบนขวาของหน้าหลัก
///
/// ใช้ Open-Meteo ฟรีและไม่ต้องมี key ดึงครั้งเดียวแล้วเก็บไว้ 30 นาที
/// ดึงหน้าหลักลงรีเฟรชกี่ครั้งก็ไม่ยิงซ้ำ
///
/// **ไม่ขอสิทธิ์ตำแหน่งเอง** ใช้เฉพาะเมื่อเคยให้สิทธิ์ไว้แล้ว (ตอนถ่ายรูปไมล์
/// หรือแนบพิกัด) หน้าหลักเด้งถามสิทธิ์ตั้งแต่เปิดแอปเพื่อเอาไปโชว์อากาศ
/// เป็นเรื่องที่ไม่คุ้มให้คนกดปฏิเสธแล้วไปกระทบฟีเจอร์ที่ต้องใช้พิกัดจริง
///
/// ไม่ได้สิทธิ์ ไม่มีพิกัดล่าสุด หรือดึงไม่สำเร็จ ก็ไม่โชว์อะไรเลย ไม่เดาว่า
/// อยู่กรุงเทพ เพราะคนขับต่างจังหวัดจะเห็นอากาศที่ไม่ใช่ของตัวเอง
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:claim/utils/dio_service.dart';

/// โอกาสฝนตั้งแต่เท่านี้ขึ้นไปเปลี่ยนเป็นไอคอนร่ม เตือนให้เตรียมคลุมของ
const int kRainAlertPercent = 50;

const Duration _cacheFor = Duration(minutes: 30);

class WeatherNow {
  final double temperature;

  /// รหัสสภาพอากาศมาตรฐาน WMO (0 = ฟ้าโปร่ง, 61 = ฝน, 95 = พายุฝนฟ้าคะนอง)
  final int code;

  /// โอกาสฝนสูงสุดในอีก 3 ชั่วโมงข้างหน้า เป็นเปอร์เซ็นต์
  final int rainChance;

  const WeatherNow({
    required this.temperature,
    required this.code,
    required this.rainChance,
  });

  bool get rainLikely => rainChance >= kRainAlertPercent;
}

Uri buildWeatherUrl({required double lat, required double lon}) =>
    Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$lat',
      'longitude': '$lon',
      'current': 'temperature_2m,weather_code',
      'hourly': 'precipitation_probability',
      'forecast_hours': '3',
      'timezone': 'Asia/Bangkok',
    });

/// อ่านผลจาก Open-Meteo คืน null เมื่ออ่านไม่ได้
WeatherNow? parseWeather(dynamic data) {
  try {
    if (data is! Map) return null;

    final current = data['current'];
    if (current is! Map) return null;

    final temperature = current['temperature_2m'];
    final code = current['weather_code'];
    if (temperature is! num || code is! num) return null;

    final chances = data['hourly']?['precipitation_probability'];
    final rainChance = chances is List
        ? chances.whereType<num>().fold<num>(0, (a, b) => b > a ? b : a)
        : 0;

    return WeatherNow(
      temperature: temperature.toDouble(),
      code: code.toInt(),
      rainChance: rainChance.toInt(),
    );
  } catch (e) {
    debugPrint('weather parse: $e');
    return null;
  }
}

/// ไอคอนตามรหัส WMO จัดกลุ่มหยาบ ๆ พอให้ดูออกในพริบตา
IconData weatherIcon(int code) {
  if (code == 0) return Icons.wb_sunny_outlined;
  if (code <= 3) return Icons.wb_cloudy_outlined;
  if (code == 45 || code == 48) return Icons.foggy;
  if (code >= 95) return Icons.thunderstorm_outlined;
  if (code >= 51) return Icons.water_drop_outlined;
  return Icons.wb_cloudy_outlined;
}

WeatherNow? _cached;
DateTime? _cachedAt;

/// อากาศตรงที่ผู้ใช้อยู่ null เมื่อไม่มีสิทธิ์ ไม่มีพิกัด หรือดึงไม่ได้
Future<WeatherNow?> fetchWeatherHere() async {
  final cachedAt = _cachedAt;
  if (_cached != null &&
      cachedAt != null &&
      DateTime.now().difference(cachedAt) < _cacheFor) {
    return _cached;
  }

  try {
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return null;
    }

    // พิกัดล่าสุดที่เครื่องจำไว้ได้ทันที ไม่ต้องรอจับ GPS ใหม่
    // อากาศคลาดไปไม่กี่กิโลไม่ต่างกัน
    final position = await Geolocator.getLastKnownPosition();
    if (position == null) return null;

    final response = await dio.getUri(
      buildWeatherUrl(lat: position.latitude, lon: position.longitude),
      options: Options(
        receiveTimeout: const Duration(seconds: 10),
        validateStatus: (_) => true,
      ),
    );
    if (response.statusCode != 200) {
      debugPrint('weather: HTTP ${response.statusCode}');
      return null;
    }

    final weather = parseWeather(response.data);
    if (weather != null) {
      _cached = weather;
      _cachedAt = DateTime.now();
    }
    return weather;
  } catch (e) {
    // รวมถึงตอนรันเทสต์ที่ไม่มี plugin ตำแหน่งให้เรียก
    debugPrint('weather: $e');
    return null;
  }
}

/// ป้ายอากาศเล็ก ๆ เช่น `☀ 31°` หรือ `☂ ฝน 63%`
///
/// ยังไม่ได้ข้อมูลก็ไม่กินที่ แถบทักทายจะไม่กระตุกเพราะมีที่ว่างรอไว้
class WeatherChip extends StatefulWidget {
  const WeatherChip({super.key});

  @override
  State<WeatherChip> createState() => _WeatherChipState();
}

class _WeatherChipState extends State<WeatherChip> {
  WeatherNow? _weather;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final weather = await fetchWeatherHere();
    if (!mounted || weather == null) return;
    setState(() => _weather = weather);
  }

  @override
  Widget build(BuildContext context) {
    final weather = _weather;
    if (weather == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final rain = weather.rainLikely;
    final color = rain ? scheme.onTertiaryContainer : scheme.onSurfaceVariant;

    return Tooltip(
      message: rain
          ? 'โอกาสฝน ${weather.rainChance}% ใน 3 ชั่วโมงนี้ เตรียมคลุมของด้วย'
          : 'อุณหภูมิตอนนี้ตรงที่คุณอยู่',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: rain
              ? scheme.tertiaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              rain ? Icons.umbrella_outlined : weatherIcon(weather.code),
              size: 16,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              rain
                  ? 'ฝน ${weather.rainChance}%'
                  : '${weather.temperature.round()}°',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: rain ? color : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
