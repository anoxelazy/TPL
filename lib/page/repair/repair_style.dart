import 'package:flutter/material.dart';

import 'package:claim/page/repair/repair_api.dart';
import 'package:claim/utils/app_colors.dart';

/// สีประจำสถานะ ใช้กับป้ายสถานะและแถบความคืบหน้า
///
/// ยังไม่รับงานใช้สีเทากลาง ๆ เพราะการ์ดของสถานะนี้เป็นพื้นขาว
/// ถ้าใช้สีจัดจะแย่งสายตากับใบที่รับงานแล้ว
Color repairStatusColor(RepairStatus status, ColorScheme scheme) {
  switch (status) {
    case RepairStatus.pending:
      return scheme.onSurfaceVariant;
    case RepairStatus.inProgress:
      return AppColors.pending;
    case RepairStatus.completed:
      return AppColors.success;
  }
}

/// สีพื้นการ์ด: ยังไม่รับงานพื้นปกติ รับแล้วเหลือง ปิดงานเขียว
///
/// ผสมกับสีพื้นผิวให้ทึบ ไม่ใช้สีโปร่งใสตรง ๆ ไม่งั้นจะเห็นพื้นหลังหน้าจอ
/// ทะลุขึ้นมาและสีเพี้ยนเวลาการ์ดวางซ้อนบนพื้นคนละสี
Color repairCardColor(RepairStatus status, ColorScheme scheme) {
  switch (status) {
    case RepairStatus.pending:
      return scheme.surface;
    case RepairStatus.inProgress:
      return Color.alphaBlend(
        AppColors.pending.withValues(alpha: 0.14),
        scheme.surface,
      );
    case RepairStatus.completed:
      return Color.alphaBlend(
        AppColors.success.withValues(alpha: 0.13),
        scheme.surface,
      );
  }
}

/// ป้ายสถานะบนการ์ดและหัวหน้ารายละเอียด
class RepairStatusChip extends StatelessWidget {
  final RepairStatus status;

  const RepairStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = repairStatusColor(status, Theme.of(context).colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
