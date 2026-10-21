import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/dashboard/weather_animated_icon.dart';
import 'package:claim/page/dashboard/weather_chip.dart';

WeatherNow _w(int code, {int rain = 0}) =>
    WeatherNow(temperature: 30, code: code, rainChance: rain);

void main() {
  test('เลือกท่าขยับตามสภาพอากาศ', () {
    expect(weatherMotionFor(_w(0)), WeatherMotion.sun);
    expect(weatherMotionFor(_w(2)), WeatherMotion.cloud);
    expect(weatherMotionFor(_w(45)), WeatherMotion.fog);
    expect(weatherMotionFor(_w(61)), WeatherMotion.rain);
    expect(weatherMotionFor(_w(95)), WeatherMotion.storm);
  });

  test('ฟ้ายังโปร่งแต่โอกาสฝนสูง โชว์ร่มให้เตรียมตัว', () {
    expect(weatherMotionFor(_w(0, rain: 80)), WeatherMotion.rain);
  });

  for (final code in [0, 2, 45, 61, 95]) {
    testWidgets('ไอคอนรหัส $code ขยับได้โดยไม่พัง', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: AnimatedWeatherIcon(weather: _w(code), color: Colors.green),
          ),
        ),
      );

      // เดินหน้าไปหลายช่วงของรอบ ให้ผ่านทุกท่า รวมจังหวะฟ้าแลบ
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(tester.takeException(), isNull);
      expect(tester.hasRunningAnimations, isTrue);
    });
  }

  testWidgets('ป้ายอากาศบนหน้าหลักก็ขยับ ไม่ใช่แค่ในกล่อง', (tester) async {
    Future<WeatherNow?> rainy({WeatherAsk ask = WeatherAsk.prompt}) async =>
        _w(61, rain: 80);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WeatherChip(fetch: rainy, showPopup: false)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.descendant(
        of: find.byType(WeatherChip),
        matching: find.byType(AnimatedWeatherIcon),
      ),
      findsOneWidget,
    );
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('เครื่องที่เปิดลดการเคลื่อนไหว ไอคอนนิ่ง', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Center(
          child: AnimatedWeatherIcon(weather: _w(0), color: Colors.green),
        ),
      ),
    );

    expect(tester.hasRunningAnimations, isFalse);
  });
}
