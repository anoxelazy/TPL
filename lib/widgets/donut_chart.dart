import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 1 ส่วนของกราฟวงกลม
class DonutSlice {
  final String label;
  final int value;
  final Color color;

  const DonutSlice({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// กราฟวงกลมพร้อมคำอธิบายด้านข้าง ใช้ร่วมกันทุกฟีเจอร์
///
/// วงกลมค่อย ๆ กวาดขึ้นตอนเปิดหน้า และกวาดใหม่เมื่อตัวเลขเปลี่ยน
/// วาดผ่าน CustomPainter ที่ผูก `repaint: animation` ไม่ใช้ AnimatedBuilder
/// เพราะจะ rebuild ข้อความกลางวงทุกเฟรมจนเลื่อน list กระตุก
class DonutChart extends StatefulWidget {
  final List<DonutSlice> slices;

  /// ข้อความบรรทัดบนกลางวง (ตัวใหญ่)
  final String centerTop;

  /// ข้อความบรรทัดล่างกลางวง (ตัวเล็ก)
  final String centerBottom;

  /// เส้นผ่านศูนย์กลางของวงกลม
  final double diameter;

  /// ซ่อนส่วนที่ค่าเป็น 0 ออกจากคำอธิบาย ใช้ตอนมีหลายสถานะ
  final bool hideEmpty;

  /// label ของส่วนที่กำลังถูกเลือก จะหนาขึ้นและตัวหนังสือข้าง ๆ ใหญ่ขึ้น
  /// ส่วนที่เหลือจะจางลงให้ส่วนที่เลือกเด่นออกมา null = ไม่เน้นส่วนไหน
  final String? selectedLabel;

  const DonutChart({
    super.key,
    required this.slices,
    required this.centerTop,
    required this.centerBottom,
    this.diameter = 132,
    this.hideEmpty = false,
    this.selectedLabel,
  });

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _sweep;

  /// คุมจังหวะตอนสลับส่วนที่เลือก ค่า 1 คือขยายสุดแล้ว
  late final AnimationController _highlight;

  int _selectedIndex = -1;
  int _previousIndex = -1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _sweep = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();

    _highlight = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1,
    );
    _selectedIndex = _indexOf(widget.selectedLabel);
  }

  @override
  void didUpdateWidget(DonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameValues(oldWidget.slices, widget.slices)) {
      _controller.forward(from: 0);
    }
    if (oldWidget.selectedLabel != widget.selectedLabel) {
      _previousIndex = _selectedIndex;
      _selectedIndex = _indexOf(widget.selectedLabel);
      _highlight.forward(from: 0);
    }
  }

  int _indexOf(String? label) {
    if (label == null) return -1;
    for (int i = 0; i < widget.slices.length; i++) {
      if (widget.slices[i].label == label) return i;
    }
    return -1;
  }

  static bool _sameValues(List<DonutSlice> a, List<DonutSlice> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].value != b[i].value) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _controller.dispose();
    _highlight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = widget.slices.fold<int>(0, (sum, s) => sum + s.value);
    final legend = widget.hideEmpty
        ? widget.slices.where((s) => s.value > 0).toList()
        : widget.slices;

    return Row(
      children: [
        SizedBox(
          width: widget.diameter,
          height: widget.diameter,
          child: CustomPaint(
            painter: _DonutPainter(
              slices: widget.slices,
              animation: _sweep,
              highlight: _highlight,
              selectedIndex: _selectedIndex,
              previousIndex: _previousIndex,
              trackColor: scheme.surfaceContainerHighest,
              stroke: widget.diameter * 0.16,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.centerTop,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    widget.centerBottom,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final slice in legend)
                _LegendRow(
                  slice: slice,
                  total: total,
                  selected: slice.label == widget.selectedLabel,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  final DonutSlice slice;
  final int total;
  final bool selected;

  const _LegendRow({
    required this.slice,
    required this.total,
    required this.selected,
  });

  static const Duration _duration = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = total == 0 ? 0 : (slice.value * 100 / total).round();
    final double dot = selected ? 14 : 10;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          AnimatedContainer(
            duration: _duration,
            curve: Curves.easeOut,
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              color: slice.color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: selected ? 6 : 8),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: _duration,
              curve: Curves.easeOut,
              style: TextStyle(
                fontSize: selected ? 16 : 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
              child: Text(
                slice.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          AnimatedDefaultTextStyle(
            duration: _duration,
            curve: Curves.easeOut,
            style: TextStyle(
              fontSize: selected ? 19 : 15,
              fontWeight: FontWeight.w700,
              color: slice.color,
            ),
            child: Text('${slice.value}'),
          ),
          SizedBox(
            width: 46,
            child: AnimatedDefaultTextStyle(
              duration: _duration,
              curve: Curves.easeOut,
              style: TextStyle(
                fontSize: selected ? 15 : 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? slice.color : scheme.onSurfaceVariant,
              ),
              child: Text('$percent%', textAlign: TextAlign.right),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSlice> slices;
  final Animation<double> animation;

  /// จังหวะขยาย/ยุบของส่วนที่เพิ่งถูกเลือกกับส่วนที่เพิ่งถูกยกเลิก
  final Animation<double> highlight;
  final int selectedIndex;
  final int previousIndex;
  final Color trackColor;
  final double stroke;

  /// ช่องว่างระหว่างส่วน ใส่เฉพาะตอนมีมากกว่า 1 ส่วน
  static const double _gap = 0.10;

  /// ส่วนที่ถูกเลือกหนาขึ้นข้างละเท่านี้
  ///
  /// เผื่อที่ว่างขอบนอกไว้เท่ากันตลอด วงจะได้ไม่ขยับตอนสลับส่วนที่เลือก
  static const double _grow = 4;

  /// ความจางของส่วนที่ไม่ได้เลือก
  static const double _dim = 0.35;

  late final Paint _trackPaint;
  late final List<Paint> _slicePaints;

  _DonutPainter({
    required this.slices,
    required this.animation,
    required this.highlight,
    required this.selectedIndex,
    required this.previousIndex,
    required this.trackColor,
    required this.stroke,
  }) : super(repaint: Listenable.merge([animation, highlight])) {
    // สร้าง Paint ครั้งเดียว paint() ถูกเรียกทุกเฟรมจึงต้องไม่จองใหม่ในนั้น
    _trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    _slicePaints = [
      for (final slice in slices)
        Paint()
          ..color = slice.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
    ];
  }

  /// ส่วนนี้ขยายอยู่แค่ไหน 0 = ปกติ 1 = ขยายเต็มที่
  double _growthOf(int index) {
    if (index == selectedIndex) return highlight.value;
    if (index == previousIndex) return 1 - highlight.value;
    return 0;
  }

  /// ตอนนี้มีส่วนที่ถูกเน้นอยู่แค่ไหน ใช้ตัดสินว่าส่วนอื่นต้องจางลงเท่าไหร่
  double get _focus {
    if (selectedIndex >= 0) return previousIndex >= 0 ? 1 : highlight.value;
    if (previousIndex >= 0) return 1 - highlight.value;
    return 0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // ขอบนอกเว้นที่ให้ส่วนที่ขยายไว้ตลอด ไม่ต้องย่อวงตอนมีคนถูกเลือก
    final rect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height,
    ).deflate(stroke / 2 + _grow);

    canvas.drawArc(rect, 0, 2 * math.pi, false, _trackPaint);

    final progress = animation.value;
    final visible = <int>[
      for (int i = 0; i < slices.length; i++)
        if (slices[i].value > 0) i,
    ];
    if (visible.isEmpty) return;

    final total = visible.fold<int>(0, (sum, i) => sum + slices[i].value);
    final gap = visible.length > 1 ? _gap : 0.0;
    // กันไม่ให้ช่องว่างกินพื้นที่จนส่วนที่เล็กสุดหาย
    final available = 2 * math.pi - gap * visible.length;
    final focus = _focus;

    // เริ่มที่ 12 นาฬิกาแล้วกวาดตามเข็ม
    double start = -math.pi / 2 + gap / 2;

    for (final i in visible) {
      final full = available * slices[i].value / total;
      final growth = _growthOf(i);
      final paint = _slicePaints[i];

      paint.strokeWidth = stroke + 2 * _grow * growth;
      if (focus > 0) {
        final alpha = 1 - focus * (1 - (_dim + (1 - _dim) * growth));
        paint.color = slices[i].color.withValues(alpha: alpha);
      }

      canvas.drawArc(rect, start, full * progress, false, paint);
      start += full + gap;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.highlight != highlight ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.previousIndex != previousIndex ||
      oldDelegate.stroke != stroke ||
      oldDelegate.trackColor != trackColor ||
      !_DonutChartState._sameValues(oldDelegate.slices, slices);
}
