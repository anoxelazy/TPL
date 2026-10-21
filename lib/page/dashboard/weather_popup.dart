/// กล่องอากาศเล็ก ๆ ที่เด้งออกมาจากป้ายอากาศมุมบนขวาของหน้าหลัก
///
/// เด้งเองตอนเปิดแอปหนึ่งครั้ง และแตะป้ายอากาศเพื่อเปิดดูอีกได้ทุกเมื่อ
/// บอกอุณหภูมิ สภาพอากาศ และโอกาสฝน แตะตรงไหนก็ได้เพื่อปิด
///
/// ประวัติ: เคยเป็นการ์ดเลื่อนลงที่เก็บเองใน 4 วิ (มาช้า คนยังไม่ทันมองก็หาย)
/// แล้วเป็นป๊อปอัปใหญ่กลางจอ (ใหญ่เกินไปสำหรับข้อมูลแค่นี้) ตอนนี้เป็นกล่องเล็ก
/// ติดกับป้าย ค้างไว้จนกว่าจะแตะปิด ไม่บังทั้งจอ
library;

import 'package:flutter/material.dart';

import 'package:claim/page/dashboard/weather_animated_icon.dart';
import 'package:claim/page/dashboard/weather_chip.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/theme.dart';

bool _shownThisSession = false;

/// เริ่มนับใหม่เหมือนเพิ่งเปิดแอป กล่องจะเด้งอีกครั้งตอนเข้าหน้าหลักรอบถัดไป
///
/// เรียกตอนออกจากระบบ ล็อกอินใหม่โดยไม่ปิดแอปนับเหมือนเปิดแอปใหม่
/// (ส่วนสลับแท็บไปโปรไฟล์แล้วกลับมา หรือกดกลับจากหน้าย่อย ไม่เด้ง)
void resetWeatherPopupSession() => _shownThisSession = false;

/// รอบนี้เด้งไปแล้วหรือยัง
@visibleForTesting
bool get weatherPopupShownThisSession => _shownThisSession;

/// ทำเหมือนเพิ่งเด้งไปแล้ว ให้เทสต์ที่ไม่มีหน้าจอเตรียมสถานะได้
@visibleForTesting
void markWeatherPopupShown() => _shownThisSession = true;

/// ข้อความบรรทัดรองของกล่อง
String weatherPopupDetail(WeatherNow weather) => weather.rainLikely
    ? 'โอกาสฝน ${weather.rainChance}% ใน 3 ชั่วโมงนี้ เตรียมคลุมของด้วย'
    : 'โอกาสฝน ${weather.rainChance}% ใน 3 ชั่วโมงนี้';

/// เด้งกล่องอากาศเองตอนเปิดแอป ถ้ารอบนี้เคยเด้งไปแล้วไม่ทำอะไร
///
/// [context] ต้องเป็นของป้ายอากาศ กล่องจะเด้งออกมาใต้ตัวป้ายพอดี
void showWeatherPopupOnce(BuildContext context, WeatherNow weather) {
  if (_shownThisSession) return;
  showWeatherPopup(context, weather);
}

/// เปิดกล่องอากาศใต้ป้าย ใช้ทั้งตอนเด้งเองและตอนผู้ใช้แตะป้าย
Future<void> showWeatherPopup(BuildContext context, WeatherNow weather) {
  // แตะดูเองแล้วถือว่าเห็นแล้ว ไม่ต้องเด้งให้อีกในรอบนี้
  _shownThisSession = true;

  final anchor = _rectOf(context);

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'ปิด',
    // ไม่ทำให้จอมืด กล่องเล็กแค่นี้ไม่ควรดึงความสนใจไปจากทั้งหน้า
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (_, _, _) => WeatherPopup(weather: weather, anchor: anchor),
    // ขยายออกจากมุมบนขวา (ฝั่งที่ป้ายอยู่) ให้ดูเหมือนงอกออกมาจากป้าย
    transitionBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          alignment: Alignment.topRight,
          scale: Tween(begin: 0.5, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// ตำแหน่งของป้ายบนจอ หาไม่ได้ก็ null แล้วกล่องจะไปชิดมุมบนขวาแทน
Rect? _rectOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

class WeatherPopup extends StatelessWidget {
  final WeatherNow weather;

  /// ตำแหน่งของป้ายอากาศ กล่องจะวางใต้ป้าย ชิดขอบขวาเดียวกัน
  final Rect? anchor;

  const WeatherPopup({super.key, required this.weather, this.anchor});

  static const double _width = 248;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final rain = weather.rainLikely;
    final animate = !MediaQuery.disableAnimationsOf(context);

    final anchor = this.anchor;
    final top = anchor != null ? anchor.bottom + 8 : media.padding.top + 56;
    final right = anchor != null
        ? (media.size.width - anchor.right).clamp(12.0, double.infinity)
        : 16.0;

    return Stack(
      children: [
        Positioned(
          top: top,
          right: right,
          width: _width,
          child: Material(
            color: AppTheme.cardColor(scheme),
            elevation: 8,
            shadowColor: scheme.shadow.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: rain
                            ? scheme.tertiaryContainer
                            : AppColors.brandBg,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: AnimatedWeatherIcon(
                        weather: weather,
                        size: 24,
                        color: rain
                            ? scheme.onTertiaryContainer
                            : AppColors.brandText,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ตัวเลขนับขึ้นจาก 0 ให้กล่องดูมีชีวิตตอนเด้ง
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: weather.temperature),
                            duration: animate
                                ? const Duration(milliseconds: 700)
                                : Duration.zero,
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => Text(
                              '${value.round()}° · '
                              '${weatherLabel(weather.code)}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          // ข้อความรองตามมาทีหลังนิดนึง เลื่อนขึ้นพร้อมจางเข้า
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: animate
                                ? const Duration(milliseconds: 650)
                                : Duration.zero,
                            curve: const Interval(
                              0.35,
                              1,
                              curve: Curves.easeOut,
                            ),
                            builder: (context, value, child) => Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, (1 - value) * 6),
                                child: child,
                              ),
                            ),
                            child: Text(
                              weatherPopupDetail(weather),
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: rain
                                    ? scheme.onTertiaryContainer
                                    : scheme.onSurfaceVariant,
                                fontWeight: rain
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
