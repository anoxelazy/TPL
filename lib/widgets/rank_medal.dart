import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:claim/widgets/pulse_ring.dart';

/// วงเหรียญพร้อมเลขอันดับ เล่นอนิเมชันตอนโผล่ครั้งแรก
///
/// วงขยายขึ้นมาก่อน เลขค่อยกระแทกลงมาประทับทับทีหลังเหมือนตราประทับ
/// ปิดท้ายด้วยวงกระเพื่อมออกหนึ่งที ให้รู้สึกว่าอันดับนี้ไม่ได้ได้มาง่าย ๆ
///
/// อนิเมชันเล่นรอบเดียวแล้วจบ ไม่วนต่อ หน้าจอจะได้ไม่ดิ้นค้างไว้
class RankMedal extends StatefulWidget {
  final double size;
  final Color color;

  /// เลขอันดับหรือไอคอนเพชร ผู้เรียกจัดสีมาเองแล้ว
  final Widget child;

  /// หน่วงก่อนเริ่มเล่น ตารางส่งไล่ทีละแถว เลขจะได้ทยอยขึ้นจากอันดับ 1 ลงมา
  final Duration delay;

  /// วงกระเพื่อมรอบเหรียญ เปิดเฉพาะวงใหญ่ในการ์ด วงเล็กในตารางจะรกเกิน
  ///
  /// วงล้นออกนอกกรอบ ที่ที่ clip เนื้อหาอยู่ห้ามเปิด
  final bool halo;

  const RankMedal({
    super.key,
    required this.size,
    required this.color,
    required this.child,
    this.delay = Duration.zero,
    this.halo = false,
  });

  @override
  State<RankMedal> createState() => _RankMedalState();
}

class _RankMedalState extends State<RankMedal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  );

  /// วงโผล่ก่อน เผื่อ overshoot ให้เด้งนิดหนึ่งตอนหยุด
  late final Animation<double> _circle = CurvedAnimation(
    parent: _enter,
    curve: const Interval(0, 0.5, curve: Curves.easeOutBack),
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _enter,
    curve: const Interval(0, 0.2),
  );

  /// เลขตามลงมาทีหลัง จะได้เห็นว่าประทับลงบนวง ไม่ใช่โผล่มาพร้อมกัน
  late final Animation<double> _stamp = CurvedAnimation(
    parent: _enter,
    curve: const Interval(0.28, 0.78, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _halo = CurvedAnimation(
    parent: _enter,
    curve: const Interval(0.25, 1, curve: Curves.easeOutQuad),
  );

  @override
  void initState() {
    super.initState();

    if (widget.delay == Duration.zero) {
      _enter.forward();
      return;
    }

    Future.delayed(widget.delay, () {
      if (mounted) _enter.forward();
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _enter,
    // เลขไม่ได้เปลี่ยนตามเฟรม ส่งผ่าน child ไม่ต้องสร้างใหม่ทุกที
    child: widget.child,
    builder: (context, child) {
      // แสงเรืองวาบตอนกลางทาง แล้วดับไปตอนจบ ไม่ค้างเป็นเงาถาวร
      final glow = math.sin(math.pi * _enter.value).clamp(0.0, 1.0);

      final medal = Opacity(
        opacity: _fade.value,
        child: Transform.scale(
          scale: 0.5 + 0.5 * _circle.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: glow == 0
                  ? null
                  : [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.45 * glow),
                        blurRadius: widget.size * 0.3 * glow,
                        spreadRadius: widget.size * 0.04 * glow,
                      ),
                    ],
            ),
            child: Transform.scale(
              scale: 1.9 - 0.9 * _stamp.value,
              child: Opacity(opacity: _stamp.value, child: child),
            ),
          ),
        ),
      );

      if (!widget.halo) return medal;

      return PulseRing(
        animation: _halo,
        color: widget.color,
        grow: widget.size * 0.55,
        child: medal,
      );
    },
  );
}
