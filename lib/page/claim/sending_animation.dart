import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/theme.dart';

enum SendingStatus { sending, success, error }

/// กล่องสถานะตอนส่งรายการสินค้าเสียหายไป Google Sheet
///
/// - กำลังส่ง: วงแหวนไล่สีหมุนรอบเครื่องบินกระดาษที่ลอยขึ้นลง มีคลื่นกระจาย
///   ออกเป็นจังหวะ และจุดไข่ปลาวิ่งท้ายข้อความ
/// - สำเร็จ: วงเขียวเด้งขึ้นมา เครื่องหมายถูกถูกวาดเป็นเส้น จุดเล็ก ๆ
///   กระจายออกรอบวง
/// - ผิดพลาด: วงแดง กากบาทถูกวาดเป็นเส้น แล้วสั่นซ้ายขวาสองสามที
///
/// ข้อความเปลี่ยนแบบจางสลับ ไม่กระโดด ผู้เรียกแค่เปลี่ยนค่าใน
/// [statusNotifier] กล่องจัดการแอนิเมชันเอง
class SendingAnimation extends StatefulWidget {
  final ValueNotifier<SendingStatus> statusNotifier;
  final String message;
  final String successMessage;
  final String errorMessage;

  const SendingAnimation({
    super.key,
    required this.statusNotifier,
    this.message = 'กำลังส่งข้อมูล...',
    this.successMessage = 'ส่งข้อมูลสำเร็จ',
    this.errorMessage = 'เกิดข้อผิดพลาด',
  });

  @override
  State<SendingAnimation> createState() => _SendingAnimationState();
}

class _SendingAnimationState extends State<SendingAnimation>
    with TickerProviderStateMixin {
  static const double _badge = 96;

  /// หมุนวงแหวน คลื่น และจุดไข่ปลา วนตลอดตอนกำลังส่ง
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  /// ผลลัพธ์ (สำเร็จ/ผิดพลาด) เล่นครั้งเดียวตอนสถานะเปลี่ยน
  late final AnimationController _result = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    widget.statusNotifier.addListener(_onStatusChanged);
    _onStatusChanged();
  }

  void _onStatusChanged() {
    if (widget.statusNotifier.value == SendingStatus.sending) return;
    _loop.stop();
    _result.forward(from: 0);
  }

  @override
  void dispose() {
    widget.statusNotifier.removeListener(_onStatusChanged);
    _loop.dispose();
    _result.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<SendingStatus>(
      valueListenable: widget.statusNotifier,
      builder: (context, status, _) {
        final text = switch (status) {
          SendingStatus.sending => widget.message,
          SendingStatus.success => widget.successMessage,
          SendingStatus.error => widget.errorMessage,
        };

        return Center(
          child: Container(
            width: 260,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: AppTheme.cardColor(scheme),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: _badge + 40,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_loop, _result]),
                    builder: (context, _) => switch (status) {
                      SendingStatus.sending => _sending(scheme),
                      SendingStatus.success => _success(),
                      SendingStatus.error => _error(),
                    },
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.25),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _label(
                    key: ValueKey(status),
                    text: text,
                    status: status,
                    scheme: scheme,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _label({
    required Key key,
    required String text,
    required SendingStatus status,
    required ColorScheme scheme,
  }) {
    final style = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: switch (status) {
        SendingStatus.error => AppColors.danger,
        SendingStatus.success => AppColors.brandText,
        SendingStatus.sending => scheme.onSurface,
      },
    );

    if (status != SendingStatus.sending) {
      return Text(text, key: key, style: style, textAlign: TextAlign.center);
    }

    // ตัดจุดท้ายข้อความเดิมออก แล้ววาดจุดไข่ปลาที่วิ่งเองแทน
    final base = text.replaceAll(RegExp(r'[.…]+$'), '');
    return AnimatedBuilder(
      key: key,
      animation: _loop,
      builder: (context, _) {
        final dots = (_loop.value * 3).floor() % 3 + 1;
        return Text.rich(
          TextSpan(
            text: base,
            children: [
              TextSpan(text: '.' * dots),
              // จองที่ให้จุดที่ยังไม่ขึ้น ข้อความจะได้ไม่ขยับไปมา
              TextSpan(
                text: '.' * (3 - dots),
                style: const TextStyle(color: Colors.transparent),
              ),
            ],
          ),
          style: style,
          textAlign: TextAlign.center,
        );
      },
    );
  }

  Widget _sending(ColorScheme scheme) {
    final t = _loop.value;
    final color = scheme.primary;
    // ลอยขึ้นลงช้ากว่าวงหมุนครึ่งหนึ่ง ไม่ให้ดูกระตุกตามกัน
    final bob = math.sin(t * 2 * math.pi);

    return Stack(
      alignment: Alignment.center,
      children: [
        // คลื่นสองวงกระจายออก ห่างกันครึ่งรอบ
        for (final phase in const [0.0, 0.5]) _ripple((t + phase) % 1, color),
        Container(
          width: _badge,
          height: _badge,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.brandBg,
          ),
        ),
        Transform.rotate(
          angle: t * 2 * math.pi,
          child: CustomPaint(
            size: const Size.square(_badge),
            painter: _RingPainter(color: color),
          ),
        ),
        Transform.translate(
          offset: Offset(bob * 3, -bob * 4),
          child: Transform.rotate(
            angle: -0.35,
            child: Icon(Icons.send_rounded, size: 38, color: color),
          ),
        ),
      ],
    );
  }

  Widget _ripple(double p, Color color) {
    final size = _badge * (1 + 0.38 * p);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: 0.35 * (1 - p)),
          width: 2,
        ),
      ),
    );
  }

  Widget _success() {
    final t = _result.value;
    final pop = Curves.elasticOut.transform(
      const Interval(0, 0.55).transform(t),
    );
    final draw = Curves.easeOutCubic.transform(
      const Interval(0.3, 0.75).transform(t),
    );
    final burst = Curves.easeOut.transform(const Interval(0.2, 1).transform(t));

    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: const Size.square(_badge + 40),
          painter: _BurstPainter(progress: burst),
        ),
        Transform.scale(
          scale: 0.6 + 0.4 * pop,
          child: Container(
            width: _badge,
            height: _badge,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: CustomPaint(painter: _CheckPainter(progress: draw)),
          ),
        ),
      ],
    );
  }

  Widget _error() {
    final t = _result.value;
    final pop = Curves.easeOutBack.transform(
      const Interval(0, 0.4).transform(t),
    );
    final draw = Curves.easeOutCubic.transform(
      const Interval(0.2, 0.55).transform(t),
    );
    // สั่นซ้ายขวาแรงแล้วค่อย ๆ หยุด
    final shakeT = const Interval(0.45, 1).transform(t);
    final shake = math.sin(shakeT * math.pi * 6) * 8 * (1 - shakeT);

    // Center ปล่อยให้วงเป็นขนาด [_badge] ของมันเอง ไม่ถูกยืดเต็มกรอบนอก
    return Center(
      child: Transform.translate(
        offset: Offset(shake, 0),
        child: Transform.scale(
          scale: 0.7 + 0.3 * pop,
          child: Container(
            width: _badge,
            height: _badge,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.danger,
            ),
            child: CustomPaint(painter: _CrossPainter(progress: draw)),
          ),
        ),
      ),
    );
  }
}

/// วงแหวนไล่สีจากจางไปเข้ม หางเรียวเหมือนดาวหาง
class _RingPainter extends CustomPainter {
  final Color color;

  const _RingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 4.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);

    canvas.drawCircle(
      rect.center,
      arcRect.width / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color.withValues(alpha: 0.12),
    );

    canvas.drawArc(
      arcRect,
      0,
      math.pi * 1.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          endAngle: math.pi * 1.5,
          colors: [color.withValues(alpha: 0), color],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color;
}

/// วาดเส้นตามสัดส่วน [progress] ของความยาวรวม ให้ดูเหมือนค่อย ๆ ลากเส้น
void _drawPartial(Canvas canvas, Path path, double progress, Paint paint) {
  if (progress <= 0) return;
  for (final metric in path.computeMetrics()) {
    canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
  }
}

Paint _markPaint(Size size) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = size.width * 0.085
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..color = Colors.white;

class _CheckPainter extends CustomPainter {
  final double progress;

  const _CheckPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.29, w * 0.52)
      ..lineTo(w * 0.44, w * 0.66)
      ..lineTo(w * 0.72, w * 0.37);
    _drawPartial(canvas, path, progress, _markPaint(size));
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}

class _CrossPainter extends CustomPainter {
  final double progress;

  const _CrossPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final paint = _markPaint(size);
    // สองเส้นวาดต่อกัน เส้นแรกครึ่งแรก เส้นที่สองครึ่งหลัง
    _drawPartial(
      canvas,
      Path()
        ..moveTo(w * 0.34, w * 0.34)
        ..lineTo(w * 0.66, w * 0.66),
      (progress * 2).clamp(0, 1),
      paint,
    );
    _drawPartial(
      canvas,
      Path()
        ..moveTo(w * 0.66, w * 0.34)
        ..lineTo(w * 0.34, w * 0.66),
      (progress * 2 - 1).clamp(0, 1),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CrossPainter old) => old.progress != progress;
}

/// จุดเล็ก ๆ หลายสีพุ่งออกจากวงตอนส่งสำเร็จ
class _BurstPainter extends CustomPainter {
  final double progress;

  const _BurstPainter({required this.progress});

  static const _colors = [
    AppColors.success,
    AppColors.brand,
    AppColors.pending,
    AppColors.rankDiamond,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final center = size.center(Offset.zero);
    const count = 12;
    final inner = size.width * 0.34;
    final travel = size.width * 0.18;

    for (var i = 0; i < count; i++) {
      final angle = i / count * 2 * math.pi + 0.2;
      // จุดสลับระยะใกล้ไกล ไม่เป็นวงกลมเป๊ะจนดูแข็ง
      final reach = inner + travel * progress * (i.isEven ? 1 : 0.7);
      final offset = center + Offset(math.cos(angle), math.sin(angle)) * reach;
      canvas.drawCircle(
        offset,
        (i.isEven ? 3.5 : 2.5) * (1 - progress * 0.5),
        Paint()
          ..color = _colors[i % _colors.length].withValues(alpha: 1 - progress),
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}
