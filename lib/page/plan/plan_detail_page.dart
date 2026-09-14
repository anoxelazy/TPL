import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:claim/page/plan/plan_api.dart';
import 'package:claim/page/plan/plan_bill_list_page.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/widgets/app_card.dart';
import 'package:claim/widgets/pulse_ring.dart';

final NumberFormat _money = NumberFormat('#,##0.00');

/// หน้าสรุปแผนรถ 1 รอบส่ง กด "ทำต่อ" เพื่อดูบิลทั้งหมดในรอบ
class PlanDetailPage extends StatelessWidget {
  final PlanJobItem plan;

  const PlanDetailPage({super.key, required this.plan});

  void _openBills(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PlanBillListPage(plan: plan)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = plan.datePlan;

    return Scaffold(
      appBar: AppBar(title: const Text('แผนรถ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.local_shipping, size: 28, color: scheme.onSurface),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  plan.truckSendId,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          if (date != null) ...[
            const SizedBox(height: 8),
            Text(
              'วันที่จัดส่ง ${DateFormat('d MMMM y', 'th').format(date)}',
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 20),
          _MoneyBox(cod: plan.cod, delivery: plan.priceDelivery),
          const SizedBox(height: 20),
          _StatusCard(plan: plan, onContinue: () => _openBills(context)),
        ],
      ),
    );
  }
}

/// กล่องส้มสรุปยอดเก็บเงินของรอบส่ง
class _MoneyBox extends StatelessWidget {
  final double cod;
  final double delivery;

  const _MoneyBox({required this.cod, required this.delivery});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.moneyBg,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: AppColors.moneyBorder, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.savings, size: 48, color: AppColors.moneyText),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'เก็บเงินรวม ${_money.format(cod + delivery)} บาท',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.moneyText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'COD ${_money.format(cod)} บาท',
                  style: TextStyle(
                    fontSize: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'ขนส่ง ${_money.format(delivery)} บาท',
                  style: TextStyle(
                    fontSize: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// การ์ดสถานะของรอบส่ง รวม สำเร็จ / คงเหลือ / ไม่สำเร็จ ไว้ที่เดียว
///
/// สถานะที่มีของอยู่จะขยับ: สำเร็จเด้งเข้ามา คงเหลือกระเพื่อม ไม่สำเร็จสั่นเตือน
/// สถานะที่นับได้ 0 จะเทาและอยู่นิ่ง
class _StatusCard extends StatefulWidget {
  final PlanJobItem plan;
  final VoidCallback onContinue;

  const _StatusCard({required this.plan, required this.onContinue});

  @override
  State<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<_StatusCard>
    with TickerProviderStateMixin {
  late final AnimationController _loop;
  late final AnimationController _pop;
  late final Animation<double> _successScale;
  late final Animation<double> _failShake;

  PlanJobItem get _plan => widget.plan;

  @override
  void initState() {
    super.initState();

    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _successScale = CurvedAnimation(parent: _pop, curve: Curves.elasticOut);

    // สั่นสั้น ๆ ต้นรอบแล้วนิ่งจนจบรอบ ใช้ controller ตัวเดียวกับวงแหวน
    _failShake = CurvedAnimation(
      parent: _loop,
      curve: const Interval(0, 0.22, curve: Curves.easeOut),
    );

    if (_plan.billRemain > 0 || _plan.billFail > 0) _loop.repeat();
    if (_plan.billSuccess > 0) _pop.forward();
  }

  @override
  void dispose() {
    _loop.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'สถานะการส่ง',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Text(
                'รวม ${_plan.billTotal} รายการ',
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _RatioBar(plan: _plan),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StatusNode(
                  icon: Icons.check_circle_outline,
                  label: BillStatus.success.label,
                  count: _plan.billSuccess,
                  color: AppColors.success,
                  scale: _plan.billSuccess > 0 ? _successScale : null,
                ),
              ),
              Expanded(
                child: _StatusNode(
                  icon: Icons.pending_actions,
                  label: BillStatus.remaining.label,
                  count: _plan.billRemain,
                  color: AppColors.pending,
                  pulse: _plan.billRemain > 0 ? _loop : null,
                ),
              ),
              Expanded(
                child: _StatusNode(
                  icon: Icons.error_outline,
                  label: BillStatus.failed.label,
                  count: _plan.billFail,
                  color: AppColors.danger,
                  shake: _plan.billFail > 0 ? _failShake : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // ใช้สไตล์ปุ่มจากธีมกลาง คุมแค่ให้เต็มความกว้างการ์ด
          FilledButton(
            onPressed: widget.onContinue,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('ทำต่อ'),
          ),
        ],
      ),
    );
  }
}

/// แถบสัดส่วนของรอบส่ง เรียงตามความคืบหน้า สำเร็จ -> ไม่สำเร็จ -> คงเหลือ
class _RatioBar extends StatelessWidget {
  final PlanJobItem plan;

  const _RatioBar({required this.plan});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final counted = plan.billSuccess + plan.billFail + plan.billRemain;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: counted == 0
            ? ColoredBox(color: scheme.surfaceContainerHighest)
            : Row(
                children: [
                  if (plan.billSuccess > 0)
                    Expanded(
                      flex: plan.billSuccess,
                      child: const ColoredBox(color: AppColors.success),
                    ),
                  if (plan.billFail > 0)
                    Expanded(
                      flex: plan.billFail,
                      child: const ColoredBox(color: AppColors.danger),
                    ),
                  if (plan.billRemain > 0)
                    Expanded(
                      flex: plan.billRemain,
                      child: const ColoredBox(color: AppColors.pending),
                    ),
                ],
              ),
      ),
    );
  }
}

const double _nodeSize = 46;

/// ตัวเลข 1 สถานะในการ์ด ใส่ animation ได้ทีละแบบตามสถานะ
class _StatusNode extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  /// วงแหวนกระเพื่อม ใช้กับของที่ยังค้างอยู่
  final Animation<double>? pulse;

  /// เด้งเข้ามาตอนเปิดหน้า ใช้กับของที่ส่งเสร็จแล้ว
  final Animation<double>? scale;

  /// สั่นซ้ายขวา ใช้กับของที่ส่งไม่สำเร็จ
  final Animation<double>? shake;

  const _StatusNode({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    this.pulse,
    this.scale,
    this.shake,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = count > 0;

    final Color background;
    final Color foreground;
    if (active) {
      background = color;
      // สีเหลืองต้องใช้ไอคอนสีเข้มถึงจะอ่านออก ต่างจากเขียว/แดงที่ใช้ขาว
      foreground =
          ThemeData.estimateBrightnessForColor(color) == Brightness.dark
          ? Colors.white
          : Colors.black87;
    } else {
      background = scheme.surfaceContainerHighest;
      foreground = scheme.onSurfaceVariant;
    }

    Widget circle = Container(
      width: _nodeSize,
      height: _nodeSize,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: 24, color: foreground),
    );

    final ring = pulse;
    if (ring != null) {
      circle = PulseRing(
        animation: ring,
        color: color,
        grow: 18,
        child: circle,
      );
    }

    final pop = scale;
    if (pop != null) {
      circle = ScaleTransition(scale: pop, child: circle);
    }

    final nudge = shake;
    if (nudge != null) {
      circle = AnimatedBuilder(
        animation: nudge,
        child: circle,
        builder: (context, child) => Transform.translate(
          offset: Offset(math.sin(nudge.value * math.pi * 3) * 3, 0),
          child: child,
        ),
      );
    }

    return Column(
      children: [
        circle,
        const SizedBox(height: 8),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: active ? color : scheme.onSurfaceVariant,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: active ? scheme.onSurface : scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
