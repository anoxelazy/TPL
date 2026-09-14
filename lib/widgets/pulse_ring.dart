import 'package:flutter/material.dart';

/// วงแหวนกระเพื่อมออกจาก [child] บอกว่ามีของค้างอยู่ตรงนี้
///
/// วาดอยู่หลัง child และล้นออกนอกกรอบได้ ผู้เรียกต้องไม่ clip
class PulseRing extends StatelessWidget {
  final Animation<double> animation;
  final Color color;
  final Widget child;

  /// ระยะที่วงแหวนขยายออกจากขอบ child
  final double grow;

  const PulseRing({
    super.key,
    required this.animation,
    required this.color,
    required this.child,
    this.grow = 15,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _PulsePainter(animation: animation, color: color, grow: grow),
    child: child,
  );
}

class _PulsePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  final double grow;

  _PulsePainter({
    required this.animation,
    required this.color,
    required this.grow,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final alpha = 0.4 * (1 - t);
    if (alpha <= 0) return;

    canvas.drawCircle(
      size.center(Offset.zero),
      (size.shortestSide + grow * t) / 2,
      Paint()..color = color.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(_PulsePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.grow != grow ||
      oldDelegate.animation != animation;
}
