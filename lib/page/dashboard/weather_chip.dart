/// อุณหภูมิกับโอกาสฝนตรงที่ผู้ใช้อยู่ โชว์มุมบนขวาของหน้าหลัก
///
/// ใช้ Open-Meteo ฟรีและไม่ต้องมี key ดึงครั้งเดียวแล้วเก็บไว้ 30 นาที
/// ดึงหน้าหลักลงรีเฟรชกี่ครั้งก็ไม่ยิงซ้ำ
///
/// ป้ายขึ้นให้ทุกคนเห็นเสมอ ไม่หายไปเงียบ ๆ:
/// - เปิดหน้าหลัก → ถ้ายังไม่เคยให้สิทธิ์ตำแหน่ง ขอทันทีด้วยหน้าต่างของระบบ
///   ([WeatherAsk.prompt]) ให้สิทธิ์แล้วโชว์อุณหภูมิเลย ไม่ต้องรอไปแตะ
/// - ปฏิเสธ / GPS ปิด / ดึงไม่ได้ → ป้าย "อากาศ" ให้แตะ แตะแล้วขอใหม่ และพาไป
///   หน้าตั้งค่าถ้าระบบไม่ยอมให้ถามซ้ำแล้ว ([WeatherAsk.insist])
///
/// ตอนเปิดหน้าไม่พาออกไปหน้าตั้งค่าเอง เปิดแอปแล้วโดนดีดออกไปหน้าอื่นทันที
/// แย่กว่าไม่เห็นอากาศ ทำแบบนั้นเฉพาะตอนผู้ใช้แตะเองเท่านั้น
///
/// ไม่เดาว่าอยู่กรุงเทพ เพราะคนขับต่างจังหวัดจะเห็นอากาศที่ไม่ใช่ของตัวเอง
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:claim/page/dashboard/weather_animated_icon.dart';
import 'package:claim/page/dashboard/weather_popup.dart';
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

/// คำบรรยายอากาศภาษาไทยตามรหัส WMO จัดกลุ่มเดียวกับ [weatherIcon]
String weatherLabel(int code) {
  if (code == 0) return 'ท้องฟ้าแจ่มใส';
  if (code <= 2) return 'มีเมฆบางส่วน';
  if (code == 3) return 'เมฆมาก';
  if (code == 45 || code == 48) return 'มีหมอก';
  if (code >= 95) return 'พายุฝนฟ้าคะนอง';
  if (code >= 80) return 'ฝนซู่';
  if (code >= 61) return 'ฝนตก';
  if (code >= 51) return 'ฝนปรอย ๆ';
  return 'มีเมฆ';
}

WeatherNow? _cached;
DateTime? _cachedAt;

/// ขอสิทธิ์ตำแหน่งได้แค่ไหน
enum WeatherAsk {
  /// ตอนเปิดหน้าหลัก: ยังไม่เคยให้สิทธิ์ก็ขอด้วยหน้าต่างของระบบ
  /// แต่ไม่พาออกไปหน้าตั้งค่าเอง
  prompt,

  /// ผู้ใช้แตะป้ายเอง: ขอสิทธิ์ และพาไปหน้าตั้งค่าถ้าระบบไม่ให้ถามซ้ำแล้ว
  /// หรือ GPS ปิดอยู่
  insist,
}

/// อากาศตรงที่ผู้ใช้อยู่ null เมื่อไม่มีสิทธิ์ ไม่มีพิกัด หรือดึงไม่ได้
Future<WeatherNow?> fetchWeatherHere({
  WeatherAsk ask = WeatherAsk.prompt,
}) async {
  final cachedAt = _cachedAt;
  if (_cached != null &&
      cachedAt != null &&
      DateTime.now().difference(cachedAt) < _cacheFor) {
    return _cached;
  }

  final insist = ask == WeatherAsk.insist;

  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (insist) await Geolocator.openLocationSettings();
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      // ระบบไม่ให้ถามซ้ำแล้ว ทางเดียวคือให้ผู้ใช้ไปเปิดเองในตั้งค่า
      if (insist) await Geolocator.openAppSettings();
      return null;
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return null;
    }

    // พิกัดล่าสุดที่เครื่องจำไว้ได้ทันที ไม่ต้องรอจับ GPS ใหม่
    // อากาศคลาดไปไม่กี่กิโลไม่ต่างกัน ไม่มีค่อยจับใหม่แบบหยาบ ๆ
    final position =
        await Geolocator.getLastKnownPosition() ??
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 15),
          ),
        );

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
/// ยังดึงไม่ได้ก็ขึ้นป้าย "อากาศ" ให้แตะ ไม่หายไปเฉย ๆ จนไม่มีใครรู้ว่ามี
class WeatherChip extends StatefulWidget {
  /// ตัวดึงอากาศ เปลี่ยนได้เฉพาะในเทสต์ ของจริงใช้ [fetchWeatherHere]
  final Future<WeatherNow?> Function({WeatherAsk ask}) fetch;

  /// ได้อากาศครั้งแรกตอนเปิดแอปแล้วเด้งการ์ดอากาศลงมาจากด้านบนด้วยไหม
  /// ปิดได้ในเทสต์ที่ไม่ได้ทดสอบตัวการ์ด
  final bool showPopup;

  const WeatherChip({
    super.key,
    this.fetch = fetchWeatherHere,
    this.showPopup = true,
  });

  @override
  State<WeatherChip> createState() => _WeatherChipState();
}

class _WeatherChipState extends State<WeatherChip> {
  WeatherNow? _weather;

  /// หมุนเฉพาะตอนผู้ใช้แตะแล้วรออยู่ ตอนเปิดหน้าโชว์ป้าย "อากาศ" ไปก่อน
  /// (ระหว่างนั้นหน้าต่างขอสิทธิ์ของระบบอาจเด้งอยู่) ได้ค่าค่อยเปลี่ยนเป็นอุณหภูมิ
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // ขอสิทธิ์ตั้งแต่เข้าหน้าหลักเลย ไม่ต้องรอให้คนเห็นป้ายแล้วนึกจะแตะเอง
    _load(WeatherAsk.prompt);
  }

  Future<void> _load(WeatherAsk ask) async {
    if (ask == WeatherAsk.insist) setState(() => _loading = true);

    final weather = await widget.fetch(ask: ask);
    if (!mounted) return;

    setState(() {
      _weather = weather;
      _loading = false;
    });

    // เด้งเฉพาะรอบเปิดหน้า ถ้าผู้ใช้แตะป้ายเองป้ายก็เปลี่ยนให้เห็นอยู่แล้ว
    if (weather != null && widget.showPopup && ask == WeatherAsk.prompt) {
      showWeatherPopupOnce(context, weather);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final weather = _weather;

    if (weather == null) {
      return Tooltip(
        message: 'แตะเพื่อดูอากาศตรงที่คุณอยู่ (ต้องเปิดตำแหน่ง)',
        child: _chip(
          background: scheme.surfaceContainerHighest,
          onTap: _loading ? null : () => _load(WeatherAsk.insist),
          icon: _loading
              ? SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              : Icon(
                  Icons.wb_cloudy_outlined,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
          label: Text(
            'อากาศ',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final rain = weather.rainLikely;
    final color = rain ? scheme.onTertiaryContainer : scheme.onSurfaceVariant;

    return Tooltip(
      message: 'แตะเพื่อดูอากาศ',
      child: _chip(
        // แตะดูรายละเอียดได้ทุกเมื่อ ไม่ต้องรอป๊อปอัปเด้งตอนเปิดแอป
        onTap: () => showWeatherPopup(context, weather),
        background: rain
            ? scheme.tertiaryContainer
            : scheme.surfaceContainerHighest,
        // ขยับท่าเดียวกับในกล่องอากาศ ป้ายบนหน้าหลักจะได้ไม่ดูนิ่งตาย
        icon: AnimatedWeatherIcon(weather: weather, size: 16, color: color),
        label: Text(
          rain
              ? 'ฝน ${weather.rainChance}%'
              : '${weather.temperature.round()}°',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: rain ? color : scheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _chip({
    required Color background,
    required Widget icon,
    required Widget label,
    VoidCallback? onTap,
  }) {
    final radius = BorderRadius.circular(12);

    return Material(
      color: background,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [icon, const SizedBox(width: 4), label],
          ),
        ),
      ),
    );
  }
}
