/// ไอคอนอากาศที่ขยับตามสภาพอากาศ ใช้ในกล่องอากาศ
///
/// - แดดออก: พระอาทิตย์หมุนช้า ๆ มีแสงเรืองเป็นจังหวะ
/// - มีเมฆ: เมฆลอยไปมา
/// - ฝน: ร่มโยก มีเม็ดฝนตก
/// - พายุ: เมฆกับฟ้าแลบเป็นจังหวะ
/// - หมอก: ลอยไปมาจาง ๆ
///
/// เครื่องที่เปิด "ลดการเคลื่อนไหว" ไว้ (หรือในเทสต์) วาดนิ่ง ๆ ไม่ขยับ
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:claim/page/dashboard/weather_chip.dart';

/// กลุ่มท่าขยับ จัดจากรหัส WMO ให้ตรงกับ [weatherIcon]
enum WeatherMotion { sun, cloud, fog, rain, storm }

WeatherMotion weatherMotionFor(WeatherNow weather) {
  final code = weather.code;
  if (code >= 95) return WeatherMotion.storm;
  // โอกาสฝนสูงถึงตอนนี้ฟ้ายังโปร่ง ก็โชว์ร่มให้เตรียมตัว ตรงกับป้ายบนหัว
  if (weather.rainLikely || code >= 51) return WeatherMotion.rain;
  if (code == 45 || code == 48) return WeatherMotion.fog;
  if (code == 0) return WeatherMotion.sun;
  return WeatherMotion.cloud;
}

class AnimatedWeatherIcon extends StatefulWidget {
  final WeatherNow weather;
  final double size;
  final Color color;

  const AnimatedWeatherIcon({
    super.key,
    required this.weather,
    required this.color,
    this.size = 24,
  });

  @override
  State<AnimatedWeatherIcon> createState() => _AnimatedWeatherIconState();
}

class _AnimatedWeatherIconState extends State<AnimatedWeatherIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = weatherMotionFor(widget.weather);

    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => _frame(motion, _controller.value),
      ),
    );
  }

  Widget _frame(WeatherMotion motion, double t) {
    final size = widget.size;
    final color = widget.color;
    final wave = math.sin(t * 2 * math.pi);

    switch (motion) {
      case WeatherMotion.sun:
        return Stack(
          alignment: Alignment.center,
          children: [
            // แสงเรืองหายใจเข้าออก
            Container(
              width: size * (0.7 + 0.12 * (wave + 1) / 2),
              height: size * (0.7 + 0.12 * (wave + 1) / 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
              ),
            ),
            // หมุนรอบละ 2 รอบของ controller ให้ช้าพอไม่เวียนหัว
            Transform.rotate(
              angle: t * math.pi,
              child: Icon(Icons.wb_sunny_outlined, size: size, color: color),
            ),
          ],
        );

      case WeatherMotion.cloud:
        return Transform.translate(
          offset: Offset(wave * size * 0.08, 0),
          child: Icon(Icons.wb_cloudy_outlined, size: size, color: color),
        );

      case WeatherMotion.fog:
        return Opacity(
          opacity: 0.65 + 0.35 * (wave + 1) / 2,
          child: Transform.translate(
            offset: Offset(wave * size * 0.1, 0),
            child: Icon(Icons.foggy, size: size, color: color),
          ),
        );

      case WeatherMotion.rain:
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // เม็ดฝน 3 เม็ด ตกไม่พร้อมกัน
            for (final (index, x) in const [-0.28, 0.0, 0.28].indexed)
              _drop(t, phase: index / 3, x: x),
            Transform.rotate(
              angle: wave * 0.14,
              alignment: Alignment.bottomCenter,
              child: Icon(
                Icons.umbrella_outlined,
                size: size * 0.82,
                color: color,
              ),
            ),
          ],
        );

      case WeatherMotion.storm:
        // แลบสองครั้งติดกันต้นรอบ แล้วเงียบ เหมือนฟ้าแลบจริง
        final flash = (t < 0.06) || (t > 0.12 && t < 0.17);
        return Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.thunderstorm_outlined, size: size, color: color),
            if (flash)
              Icon(
                Icons.flash_on,
                size: size * 0.7,
                color: Colors.amber.shade600,
              ),
          ],
        );
    }
  }

  /// เม็ดฝนเม็ดหนึ่ง ตกจากใต้ร่มลงล่างแล้วจางหาย
  Widget _drop(double t, {required double phase, required double x}) {
    final size = widget.size;
    final p = (t + phase) % 1;

    return Positioned(
      left: size / 2 + x * size - size * 0.06,
      top: size * (0.55 + 0.45 * p),
      child: Opacity(
        opacity: (1 - p).clamp(0, 1),
        child: Container(
          width: size * 0.12,
          height: size * 0.22,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(size),
          ),
        ),
      ),
    );
  }
}
