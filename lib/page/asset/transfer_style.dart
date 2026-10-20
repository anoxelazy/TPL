/// หน้าตาร่วมของหน้าจอใบโอนย้าย
library;

import 'package:flutter/material.dart';

import 'package:claim/page/asset/transfer_models.dart';
import 'package:claim/utils/app_colors.dart';

/// สีประจำสถานะใบ
///
/// สถานะของใบตาม cheat sheet ของ backend:
/// DRAFT → PENDING → APPROVED → DISPATCHED → RECEIVED / DISCREPANCY
/// และ CANCELLED ระหว่างทาง ไม่อนุมัติไม่ได้มีสถานะของตัวเอง ใบกลับเป็น DRAFT
///
/// `IN_TRANSIT` เป็นสถานะของ**ทรัพย์สิน** ไม่ใช่ของใบ เคยใส่ไว้ตรงนี้ผิดที่
/// ตัวที่ไม่รู้จักได้สีเหลืองรอ เผื่อ backend เพิ่มสถานะใหม่
Color transferStatusColor(String status, ColorScheme scheme) {
  switch (status.toUpperCase()) {
    case 'RECEIVED':
      return AppColors.success;
    case 'DISPATCHED':
      return AppColors.stageDelivering;
    case 'APPROVED':
      return AppColors.stageOrigin;
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

/// ป้ายสถานะของใบ
class TransferStatusChip extends StatelessWidget {
  final AssetTransferItem item;

  const TransferStatusChip(this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = transferStatusColor(item.status, scheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        item.statusText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        'เลยกำหนด $days วัน',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.danger,
        ),
      ),
    );
  }
}

/// หัวข้อกับค่าในหน้ารายละเอียดใบ วางเป็นสองคอลัมน์ให้หัวข้อตรงกันทุกบรรทัด
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
