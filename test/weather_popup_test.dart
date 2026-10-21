import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/dashboard/weather_chip.dart';
import 'package:claim/page/dashboard/weather_popup.dart';

const _sunny = WeatherNow(temperature: 31.4, code: 0, rainChance: 10);
const _rainy = WeatherNow(temperature: 27, code: 63, rainChance: 70);

Future<WeatherNow?> _fetchSunny({WeatherAsk ask = WeatherAsk.prompt}) async =>
    _sunny;

Future<void> _pumpChip(WidgetTester tester) async {
  await tester.pumpWidget(
    const _NoMotionApp(
      home: Scaffold(body: WeatherChip(fetch: _fetchSunny)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(resetWeatherPopupSession);

  test('คำบรรยายอากาศเป็นภาษาไทยตามกลุ่มรหัส', () {
    expect(weatherLabel(0), 'ท้องฟ้าแจ่มใส');
    expect(weatherLabel(2), 'มีเมฆบางส่วน');
    expect(weatherLabel(3), 'เมฆมาก');
    expect(weatherLabel(45), 'มีหมอก');
    expect(weatherLabel(53), 'ฝนปรอย ๆ');
    expect(weatherLabel(63), 'ฝนตก');
    expect(weatherLabel(81), 'ฝนซู่');
    expect(weatherLabel(95), 'พายุฝนฟ้าคะนอง');
  });

  test('ฝนเยอะเตือนให้คลุมของ ฝนน้อยบอกแค่ตัวเลข', () {
    expect(weatherPopupDetail(_rainy), contains('เตรียมคลุมของ'));
    expect(weatherPopupDetail(_sunny), isNot(contains('เตรียมคลุมของ')));
    expect(weatherPopupDetail(_sunny), contains('10%'));
  });

  testWidgets('เปิดหน้ามาได้อากาศแล้วเด้งกล่องเล็ก ค้างจนกว่าจะปิด', (
    tester,
  ) async {
    await _pumpChip(tester);

    expect(find.byType(WeatherPopup), findsOneWidget);
    expect(find.text('31° · ท้องฟ้าแจ่มใส'), findsOneWidget);

    // ไม่หายไปเอง ต่างจากแบบเดิมที่เก็บเองใน 4 วิ
    await tester.pump(const Duration(seconds: 30));
    expect(find.byType(WeatherPopup), findsOneWidget);
  });

  testWidgets('กล่องเด้งใต้ป้ายอากาศ ชิดขอบขวาเดียวกับป้าย', (tester) async {
    await tester.pumpWidget(
      const _NoMotionApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: EdgeInsets.only(top: 40, right: 16),
              child: WeatherChip(fetch: _fetchSunny),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chip = tester.getRect(find.byType(WeatherChip));
    final box = tester.getRect(
      find.descendant(
        of: find.byType(WeatherPopup),
        matching: find.byType(Material),
      ),
    );

    expect(box.top, greaterThan(chip.bottom));
    expect(box.right, closeTo(chip.right, 0.5));
    // กล่องเล็ก ไม่ใช่ป๊อปอัปเต็มจอ
    expect(box.width, lessThan(300));
  });

  testWidgets('แตะที่กล่องเองก็ปิด', (tester) async {
    await _pumpChip(tester);

    await tester.tap(find.byType(WeatherPopup));
    await tester.pumpAndSettle();

    expect(find.byType(WeatherPopup), findsNothing);
  });

  testWidgets('แตะที่ว่างรอบ ๆ ก็ปิดได้', (tester) async {
    await _pumpChip(tester);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.byType(WeatherPopup), findsNothing);
  });

  testWidgets('เปิดแอปรอบเดียวเด้งครั้งเดียว หน้าหลักสร้างใหม่ก็ไม่เด้งซ้ำ', (
    tester,
  ) async {
    await _pumpChip(tester);
    await tester.tapAt(const Offset(5, 590));
    await tester.pumpAndSettle();

    // เหมือนสลับแท็บแล้วกลับมา หน้าหลักสร้างป้ายอากาศใหม่
    await tester.pumpWidget(const _NoMotionApp(home: SizedBox()));
    await _pumpChip(tester);

    expect(find.byType(WeatherPopup), findsNothing);
  });

  testWidgets('ปิดไปแล้ว แตะป้ายอากาศเปิดดูอีกได้ทุกเมื่อ', (tester) async {
    await _pumpChip(tester);
    await tester.tapAt(const Offset(5, 590));
    await tester.pumpAndSettle();

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byType(WeatherChip));
      await tester.pumpAndSettle();
      expect(find.byType(WeatherPopup), findsOneWidget);

      await tester.tapAt(const Offset(5, 590));
      await tester.pumpAndSettle();
      expect(find.byType(WeatherPopup), findsNothing);
    }
  });

  testWidgets('แตะดูเองก่อนแล้ว ไม่เด้งซ้ำให้อีก', (tester) async {
    final popup = Builder(
      builder: (context) => TextButton(
        onPressed: () => showWeatherPopup(context, _sunny),
        child: const Text('ดู'),
      ),
    );
    await tester.pumpWidget(_NoMotionApp(home: Scaffold(body: popup)));
    await tester.tap(find.text('ดู'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 590));
    await tester.pumpAndSettle();

    await _pumpChip(tester);

    expect(find.byType(WeatherPopup), findsNothing);
  });

  testWidgets('ดึงอากาศไม่ได้ ไม่เด้งป๊อปอัปว่าง ๆ', (tester) async {
    Future<WeatherNow?> none({WeatherAsk ask = WeatherAsk.prompt}) async =>
        null;

    await tester.pumpWidget(
      _NoMotionApp(
        home: Scaffold(body: WeatherChip(fetch: none)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WeatherPopup), findsNothing);
  });
}

/// แอปที่ปิดแอนิเมชันวนซ้ำ (เหมือนเครื่องที่เปิด "ลดการเคลื่อนไหว")
///
/// ไอคอนอากาศขยับวนไม่หยุด pumpAndSettle จะรอไม่จบ
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
