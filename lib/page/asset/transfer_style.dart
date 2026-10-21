/// หน้าตาร่วมของหน้าจอใบโอนย้าย
///
/// ใช้ภาษาภาพชุดเดียวกับหน้าอื่นในแอป (แจ้งเคส IT แจ้งซ่อม): การ์ดขาวบนพื้นเทา
/// หัวข้อกลุ่มสีเขียวแบรนด์ ป้ายสถานะทรงแคปซูล เดิมหน้านี้เป็นแถวแบน ๆ คั่น
/// เส้นแบบหน้าทะเบียน วางคู่กับหน้าอื่นแล้วดูเป็นคนละแอป
library;

import 'package:flutter/material.dart';

import 'package:claim/page/asset/transfer_models.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/widgets/app_card.dart';

/// สีประจำสถานะใบ
///
/// สถานะของใบตาม cheat sheet ของ backend:
/// DRAFT → PENDING → APPROVED → DISPATCHED → RECEIVED / DISCREPANCY
/// และ CANCELLED ระหว่างทาง ไม่อนุมัติไม่ได้มีสถานะของตัวเอง ใบกลับเป็น DRAFT
///
/// `IN_TRANSIT` เป็นสถานะของ**ทรัพย์สิน** ไม่ใช่ของใบ เคยใส่ไว้ตรงนี้ผิดที่
/// ตัวที่ไม่รู้จักได้สีเหลืองรอ เผื่อ backend เพิ่มสถานะใหม่
///
/// ส่งออกแล้วเคยเป็นม่วง ([AppColors.stageDelivering]) ซึ่งเป็นสีที่ทั้งแอป
/// เลิกใช้ไปแล้ว (ดูหมายเหตุของ [AppColors.caseIcon]) จึงเปลี่ยนเป็นน้ำเงิน
/// ส่วนอนุมัติแล้วขยับไปเป็นเขียวอมฟ้า ทั้งสองสีอยู่ในชุดสีระยะการเดินทาง
Color transferStatusColor(String status, ColorScheme scheme) {
  switch (status.toUpperCase()) {
    case 'RECEIVED':
      return AppColors.success;
    case 'DISPATCHED':
      return AppColors.stageOrigin;
    case 'APPROVED':
      return AppColors.stageWarehouse;
    case 'PENDING':
      return AppColors.pending;
    // ปิดแล้วแต่มีของชำรุด หาย หรือถูกปฏิเสธ ต้องมีคนตามเรื่องต่อ
    case 'DISCREPANCY':
    case 'CANCELLED':
      return AppColors.danger;
    case 'DRAFT':
      return scheme.onSurfaceVariant;
    default:
      return AppColors.pending;
  }
}

/// ชื่อขั้นของใบตามลำดับ ใช้กับแถบขั้นตอนบนหน้ารายละเอียด
const List<String> kTransferSteps = [
  'สร้างใบ',
  'ส่งอนุมัติ',
  'อนุมัติ',
  'ส่งออก',
  'รับของ',
];

/// ใบผ่านมาถึงขั้นไหนแล้ว (ตำแหน่งใน [kTransferSteps] ของขั้นล่าสุดที่จบ)
///
/// null = ไม่ต้องวาดแถบขั้นตอน คือใบที่ยกเลิกไปแล้ว หรือสถานะที่ยังไม่รู้จัก
/// ใช้แค่วาดภาพ ไม่ได้ใช้ตัดสินว่ากดปุ่มไหนได้ อันนั้นเป็นของ `can_*`
int? transferStepOf(String status) => switch (status.toUpperCase()) {
  'DRAFT' => 0,
  'PENDING' => 1,
  'APPROVED' => 2,
  'DISPATCHED' => 3,
  'RECEIVED' || 'DISCREPANCY' => 4,
  _ => null,
};

/// "ชื่อ (รหัส)" ถ้ามีอย่างเดียวก็โชว์อย่างนั้น ว่างทั้งคู่คืน null
String? transferPlaceText(String name, String code) {
  if (code.isEmpty && name.isEmpty) return null;
  if (name.isEmpty) return code;
  if (code.isEmpty) return name;
  return '$name ($code)';
}

/// ป้ายสถานะของใบ ทรงแคปซูลมีขอบ แบบเดียวกับป้ายบนการ์ดเคส IT
class TransferStatusChip extends StatelessWidget {
  final AssetTransferItem item;

  const TransferStatusChip(this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = transferStatusColor(item.status, scheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.pillRadius),
        border: Border.all(color: tint),
      ),
      child: Text(
        item.statusText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.25,
          color: tint,
        ),
      ),
    );
  }
}

/// ป้ายบอกว่าเลยกำหนดรับมากี่วัน ไม่เลยกำหนดก็ไม่กินที่
class TransferOverdueTag extends StatelessWidget {
  final int? daysOverdue;

  const TransferOverdueTag(this.daysOverdue, {super.key});

  @override
  Widget build(BuildContext context) {
    final days = daysOverdue ?? 0;
    if (days <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(AppSizes.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 12, color: AppColors.dangerText),
          const SizedBox(width: 4),
          Text(
            'เลยกำหนด $days วัน',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.dangerText,
            ),
          ),
        ],
      ),
    );
  }
}

/// ข้อมูลประกอบสั้น ๆ มีไอคอนเล็กนำหน้า แบบเดียวกับบรรทัดล่างของการ์ดเคส IT
class TransferMeta extends StatelessWidget {
  final IconData icon;
  final String text;

  const TransferMeta({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// การ์ดหนึ่งกลุ่มพร้อมหัวข้อ หน้าตาเดียวกับกลุ่มในหน้ารายละเอียดเคส IT
class TransferSection extends StatelessWidget {
  final String title;

  /// ข้อความสั้น ๆ ชิดขวาของหัวข้อ เช่น "รอรับ 2 ชิ้น"
  final String? trailing;

  /// ข้อความช่วยอธิบายใต้หัวข้อ ใส่เมื่อกลุ่มนั้นมีกติกาที่ต้องบอก
  final String? note;

  final List<Widget> children;

  const TransferSection({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tail = trailing ?? '';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandText,
                  ),
                ),
              ),
              if (tail.isNotEmpty)
                Text(
                  tail,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                note!,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          Divider(height: 20, color: scheme.outlineVariant),
          ...children,
        ],
      ),
    );
  }
}

/// หัวข้อกับค่าในการ์ด วางเป็นสองคอลัมน์ให้หัวข้อตรงกันทุกบรรทัด
class TransferInfoLine extends StatelessWidget {
  final String label;

  /// ว่างหรือ null = ไม่ต้องวาดบรรทัดนี้เลย
  final String? value;

  const TransferInfoLine({super.key, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// แถบห้าขั้นของใบ จุดที่ผ่านแล้วทึบพร้อมเครื่องหมายถูก ขั้นถัดไปเป็นวงขอบ
///
/// ใบที่ยกเลิกหรือสถานะไม่รู้จักไม่วาดอะไร ([transferStepOf] คืน null)
class TransferStepper extends StatelessWidget {
  final String status;

  const TransferStepper({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final done = transferStepOf(status);
    if (done == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final color = transferStatusColor(status, scheme);
    final idle = scheme.outlineVariant;
    final last = kTransferSteps.length - 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i <= last; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == 0
                            ? Colors.transparent
                            : (i <= done ? color : idle),
                      ),
                    ),
                    _dot(i, done, color, idle, scheme),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == last
                            ? Colors.transparent
                            : (i < done ? color : idle),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  kTransferSteps[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: i == done + 1 || (i == done && i == last)
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: i <= done || i == done + 1
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dot(int i, int done, Color color, Color idle, ColorScheme scheme) {
    final passed = i <= done;
    final next = i == done + 1;

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: passed ? color : scheme.surface,
        border: Border.all(color: passed || next ? color : idle, width: 2),
      ),
      child: passed
          ? const Icon(Icons.check, size: 12, color: Colors.white)
          : null,
    );
  }
}

/// หนึ่งเหตุการณ์ในไทม์ไลน์การดำเนินการของใบ
class TransferEvent {
  final IconData icon;
  final String title;

  /// ใครทำเมื่อไหร่ ว่างได้
  final String detail;

  /// บรรทัดเสริม เช่นเหตุผลที่ตีกลับ ผู้ขนส่ง
  final List<String> extras;

  final Color? color;

  const TransferEvent({
    required this.icon,
    required this.title,
    this.detail = '',
    this.extras = const [],
    this.color,
  });
}

/// ไทม์ไลน์แนวตั้ง จุดไอคอนเรียงลงมาต่อกันด้วยเส้น
class TransferTimeline extends StatelessWidget {
  final List<TransferEvent> events;

  const TransferTimeline({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (events[i].color ?? AppColors.brand)
                              .withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          events[i].icon,
                          size: 15,
                          color: events[i].color ?? AppColors.brandText,
                        ),
                      ),
                      if (i < events.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            color: scheme.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 4,
                      bottom: i < events.length - 1 ? 14 : 0,
                    ),
                    child: _body(events[i], scheme),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _body(TransferEvent event, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          event.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: event.color ?? scheme.onSurface,
          ),
        ),
        if (event.detail.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              event.detail,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        for (final extra in event.extras)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              extra,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: scheme.onSurface,
              ),
            ),
          ),
      ],
    );
  }
}
