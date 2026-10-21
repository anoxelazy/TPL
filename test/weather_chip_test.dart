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

  testWidgets('ไม่มีพิกัด ป้ายยังขึ้นให้แตะ ไม่หายไปเฉย ๆ', (tester) async {
    final asks = <WeatherAsk>[];
    Future<WeatherNow?> fetch({WeatherAsk ask = WeatherAsk.prompt}) async {
      asks.add(ask);
      return null;
    }

    await tester.pumpWidget(
      _NoMotionApp(
        home: Scaffold(body: WeatherChip(fetch: fetch)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('อากาศ'), findsOneWidget);
    expect(find.byIcon(Icons.wb_cloudy_outlined), findsOneWidget);

    // เปิดหน้าขอสิทธิ์ทันที (prompt) ยังไม่ได้ก็เป็นป้ายให้แตะ แตะแล้วขอแบบพาไป
    // หน้าตั้งค่าได้ (insist) ยังไม่ได้อีกก็กลับมาเป็นป้ายเดิม ไม่ค้างหมุน
    await tester.tap(find.text('อากาศ'));
    await tester.pumpAndSettle();

    expect(asks, [WeatherAsk.prompt, WeatherAsk.insist]);
    expect(find.text('อากาศ'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('ได้อากาศแล้วโชว์อุณหภูมิ ฝนเยอะโชว์ร่ม', (tester) async {
    Future<WeatherNow?> sunny({WeatherAsk ask = WeatherAsk.prompt}) async =>
        const WeatherNow(temperature: 31.4, code: 0, rainChance: 10);
    Future<WeatherNow?> rainy({WeatherAsk ask = WeatherAsk.prompt}) async =>
        const WeatherNow(temperature: 27, code: 61, rainChance: 70);

    await tester.pumpWidget(
      _NoMotionApp(
        home: Scaffold(body: WeatherChip(fetch: sunny, showPopup: false)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('31°'), findsOneWidget);
    expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);

    await tester.pumpWidget(
      _NoMotionApp(
        home: Scaffold(
          body: WeatherChip(key: UniqueKey(), fetch: rainy, showPopup: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ฝน 70%'), findsOneWidget);
    expect(find.byIcon(Icons.umbrella_outlined), findsOneWidget);
  });
}

/// แอปที่ปิดแอนิเมชันวนซ้ำ (เหมือนเครื่องที่เปิด "ลดการเคลื่อนไหว")
///
/// ไอคอนบนป้ายขยับวนไม่หยุด pumpAndSettle จะรอไม่จบ
class _NoMotionApp extends StatelessWidget {
  final Widget home;

  const _NoMotionApp({required this.home});

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: home,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
  );
}
