import 'package:flutter/material.dart';
import 'package:claim/page/stock/stock_api.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/widgets/pulse_ring.dart';

/// แถบแสดงเส้นทางของบิล: ต้นทาง -> คลัง -> ลูกค้า
///
/// ช่วงที่ผ่านแล้วเป็นเส้นทึบ ช่วงที่กำลังวิ่งจะมีรถวิ่งวนไปเรื่อย ๆ
/// ช่วงที่ยังไม่ถึงเป็นเส้นประ
///
/// ทุก animation ในไฟล์นี้วาดผ่าน CustomPainter ที่ผูก `repaint: animation`
/// ไม่ใช้ AnimatedBuilder เพราะจะ rebuild widget ทั้งกิ่งทุกเฟรม
/// ทำให้ list กระตุกเวลามีการ์ดหลายใบวิ่งพร้อมกัน
class ShipmentProgress extends StatefulWidget {
  /// ระยะที่ไปถึงแล้ว null = jobstatusid ที่ยังไม่รู้จัก (ไม่ระบายเส้นใด ๆ)
  final ShipmentStage? stage;

  const ShipmentProgress({super.key, required this.stage});

  @override
  State<ShipmentProgress> createState() => _ShipmentProgressState();
}

class _ShipmentProgressState extends State<ShipmentProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// ช่วงที่ต้องขยับ: ของกำลังเดินทาง หรือพักค้างอยู่ (เต้นเป็นจังหวะ)
  /// ไม่รวมตอนอยู่ที่คลังตามคิวปกติกับตอนส่งถึงแล้ว
  bool get _isMoving =>
      widget.stage == ShipmentStage.origin ||
      widget.stage == ShipmentStage.delivering ||
      widget.stage == ShipmentStage.returned ||
      widget.stage == ShipmentStage.parked;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (_isMoving) _controller.repeat();
  }

  @override
  void didUpdateWidget(ShipmentProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stage == oldWidget.stage) return;
    if (_isMoving) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.stage;

    // ตีกลับ = ของวิ่งย้อนจากลูกค้ากลับเข้าคลัง ใช้สีเตือนแยกจากขาไปปกติ
    final bool isReturned = stage == ShipmentStage.returned;

    // พักสินค้า = จอดค้างในคลัง ยังไม่เข้าคิวจัดส่ง แยกหน้าตาจากอยู่ที่คลังปกติ
    final bool isParked = stage == ShipmentStage.parked;

    // ผ่านคลังไปแล้วนับตั้งแต่ตอนออกจากคลัง
    final bool leftWarehouse =
        stage == ShipmentStage.delivering || stage == ShipmentStage.delivered;
    final bool reachedWarehouse =
        stage == ShipmentStage.warehouse ||
        isParked ||
        leftWarehouse ||
        isReturned;
    final bool reachedOrigin = stage != null;

    final Color accent = isReturned ? AppColors.danger : AppColors.success;
    final Color warehouseAccent = isParked ? AppColors.pending : accent;

    return RepaintBoundary(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StageNode(
            icon: Icons.person_outline,
            label: 'ต้นทาง',
            reached: reachedOrigin,
            current: stage == ShipmentStage.origin,
            accent: accent,
          ),
          Expanded(
            child: _Segment(
              done: reachedWarehouse,
              animation: stage == ShipmentStage.origin ? _controller : null,
              accent: accent,
            ),
          ),
          _StageNode(
            icon: isParked
                ? Icons.pause_circle_outline
                : Icons.warehouse_outlined,
            label: isParked ? 'พักสินค้า' : 'คลังสินค้า',
            reached: reachedWarehouse,
            current: stage == ShipmentStage.warehouse || isParked || isReturned,
            accent: warehouseAccent,
            pulse: isParked ? _controller : null,
          ),
          Expanded(
            child: _Segment(
              done: stage == ShipmentStage.delivered,
              animation: stage == ShipmentStage.delivering || isReturned
                  ? _controller
                  : null,
              reverse: isReturned,
              accent: accent,
            ),
          ),
          _StageNode(
            icon: Icons.person_pin_circle_outlined,
            label: 'ลูกค้า',
            reached: stage == ShipmentStage.delivered,
            current: stage == ShipmentStage.delivered,
            accent: accent,
          ),
        ],
      ),
    );
  }
}

const double _nodeSize = 34;
const double _nodeWidth = 58;
const double _segmentHeight = 20;

class _StageNode extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool reached;
  final bool current;
  final Color accent;

  /// ใส่มาเมื่อต้องการวงกลมกระเพื่อมรอบ node เช่นตอนพักสินค้า
  final Animation<double>? pulse;

  const _StageNode({
    required this.icon,
    required this.label,
    required this.reached,
    required this.current,
    required this.accent,
    this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Color background;
    final Color foreground;
    if (reached) {
      background = accent;
      // สีเหลืองต้องใช้ไอคอนสีเข้มถึงจะอ่านออก ต่างจากเขียว/แดงที่ใช้ขาว
      foreground =
          ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
          ? Colors.white
          : Colors.black87;
    } else {
      background = scheme.surfaceContainerHighest;
      foreground = scheme.onSurfaceVariant;
    }

    Widget circle = Container(
      width: _nodeSize,
      height: _nodeSize,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: current ? Border.all(color: accent, width: 2) : null,
      ),
      child: Icon(icon, size: 17, color: foreground),
    );

    final ring = pulse;
    if (ring != null) {
      circle = PulseRing(animation: ring, color: accent, child: circle);
    }

    return SizedBox(
      width: _nodeWidth,
      child: Column(
        children: [
          circle,
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: current ? FontWeight.w700 : FontWeight.w400,
              color: reached ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final bool done;
  final Color accent;

  /// ใส่มาเมื่อช่วงนี้กำลังเดินทาง null = อยู่นิ่ง
  final Animation<double>? animation;

  /// วิ่งจากขวาไปซ้าย ใช้ตอนของถูกตีกลับ
  final bool reverse;

  const _Segment({
    required this.done,
    required this.accent,
    this.animation,
    this.reverse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // จัดเส้นให้อยู่กลางวงกลมของ node
      padding: const EdgeInsets.only(top: (_nodeSize - _segmentHeight) / 2),
      child: SizedBox(
        height: _segmentHeight,
        child: CustomPaint(
          painter: _SegmentPainter(
            animation: animation,
            doneProgress: done ? 1 : 0,
            accent: accent,
            pendingColor: Theme.of(context).colorScheme.outlineVariant,
            reverse: reverse,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _SegmentPainter extends CustomPainter {
  /// ไม่ null คือช่วงนี้กำลังวิ่ง สัดส่วนที่ระบายอ่านจาก animation
  final Animation<double>? animation;

  /// สัดส่วนที่ระบายตอนอยู่นิ่ง (0 หรือ 1)
  final double doneProgress;
  final Color accent;
  final Color pendingColor;

  /// ระบายจากขวาเข้าซ้าย ใช้ตอนของถูกตีกลับ
  final bool reverse;

  static const double _dash = 5;
  static const double _dashGap = 4;

  late final Paint _pendingPaint;
  late final Paint _donePaint;

  /// ไอคอนรถวาดผ่าน TextPainter ที่สร้างครั้งเดียวตอนสร้าง painter
  /// paint() ถูกเรียกทุกเฟรม จึงต้องไม่สร้าง object ใหม่ในนั้น
  late final TextPainter? _truck;

  _SegmentPainter({
    required this.animation,
    required this.doneProgress,
    required this.accent,
    required this.pendingColor,
    required this.reverse,
  }) : super(repaint: animation) {
    _pendingPaint = Paint()
      ..color = pendingColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    _donePaint = Paint()
      ..color = accent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    _truck = animation == null ? null : _buildTruck(accent);
  }

  static TextPainter _buildTruck(Color color) {
    const icon = Icons.local_shipping;
    return TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 16,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;

    for (double x = 0; x < size.width; x += _dash + _dashGap) {
      final end = (x + _dash).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, y), Offset(end, y), _pendingPaint);
    }

    final anim = animation;
    final double progress = anim?.value ?? doneProgress;
    if (progress <= 0) return;

    final filled = size.width * progress;
    if (reverse) {
      canvas.drawLine(
        Offset(size.width - filled, y),
        Offset(size.width, y),
        _donePaint,
      );
    } else {
      canvas.drawLine(Offset(0, y), Offset(filled, y), _donePaint);
    }

    final truck = _truck;
    if (anim == null || truck == null) return;

    final t = anim.value;
    final travel = (size.width - truck.width).clamp(0.0, size.width);
    final x = travel * (reverse ? 1 - t : t);
    final top = (size.height - truck.height) / 2;

    if (reverse) {
      // พลิกไอคอนให้หัวรถชี้ไปทางที่วิ่ง
      canvas.save();
      canvas.translate(x + truck.width, top);
      canvas.scale(-1, 1);
      truck.paint(canvas, Offset.zero);
      canvas.restore();
    } else {
      truck.paint(canvas, Offset(x, top));
    }
  }

  @override
  bool shouldRepaint(_SegmentPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.doneProgress != doneProgress ||
      oldDelegate.accent != accent ||
      oldDelegate.pendingColor != pendingColor ||
      oldDelegate.reverse != reverse;
}
