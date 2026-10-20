import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/dashboard/weather_chip.dart';

void main() {
  group('อ่านอากาศจาก Open-Meteo', () {
    test('อ่านอุณหภูมิ รหัสอากาศ และโอกาสฝนสูงสุดใน 3 ชั่วโมง', () {
      final data = jsonDecode('''
        {"current":{"temperature_2m":31.2,"weather_code":1},
         "hourly":{"precipitation_probability":[30,47,63]}}
      ''');

      final weather = parseWeather(data)!;

      expect(weather.temperature, 31.2);
      expect(weather.code, 1);
      expect(weather.rainChance, 63);
      expect(weather.rainLikely, isTrue);
    });

    test('ไม่มีข้อมูลโอกาสฝนถือว่า 0', () {
      final weather = parseWeather({
        'current': {'temperature_2m': 28, 'weather_code': 0},
      })!;

      expect(weather.rainChance, 0);
      expect(weather.rainLikely, isFalse);
    });

    test('ของที่อ่านไม่ได้คืน null ไม่ throw', () {
      expect(parseWeather(null), isNull);
      expect(parseWeather('พัง'), isNull);
      expect(parseWeather({'current': {}}), isNull);
      expect(parseWeather({'error': true, 'reason': 'bad'}), isNull);
    });
  });

  test('ลิงก์ส่งพิกัดและขอเวลาไทย', () {
    final url = buildWeatherUrl(lat: 13.72, lon: 100.53);

    expect(url.host, 'api.open-meteo.com');
    expect(url.queryParameters['latitude'], '13.72');
    expect(url.queryParameters['longitude'], '100.53');
    expect(url.queryParameters['timezone'], 'Asia/Bangkok');
  });

  test('ไอคอนตามกลุ่มรหัสอากาศ', () {
    expect(weatherIcon(0), Icons.wb_sunny_outlined);
    expect(weatherIcon(2), Icons.wb_cloudy_outlined);
    expect(weatherIcon(45), Icons.foggy);
    expect(weatherIcon(63), Icons.water_drop_outlined);
    expect(weatherIcon(95), Icons.thunderstorm_outlined);
  });

  testWidgets('ไม่มีพิกัด ป้ายไม่กินที่เลย', (tester) async {
    // เทสต์ไม่มี plugin ตำแหน่ง ขอพิกัดไม่ได้ ต้องไม่ throw และไม่โชว์อะไร
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WeatherChip())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Icon), findsNothing);
    expect(tester.getSize(find.byType(WeatherChip)), Size.zero);
  });
}
