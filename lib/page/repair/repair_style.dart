import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:claim/page/repair/repair_api.dart';
import 'package:claim/utils/app_colors.dart';

/// วันที่บนการ์ดใบแจ้งซ่อม เขียนแบบเดียวกับหน้าเว็บของระบบนี้: `21 ก.ย. 69`
///
/// ใช้ปี พ.ศ. สองหลักตามเว็บ คนที่ดูทั้งสองที่จะได้ไม่ต้องแปลงปีในหัวไปมา
/// (intl ของ locale th ให้ปี ค.ศ. มา จึงต้องบวกเอง)
String repairDateLabel(DateTime time) {
  final buddhistYear = (time.year + 543) % 100;

  return '${DateFormat('d MMM', 'th').format(time)} '
      '${buddhistYear.toString().padLeft(2, '0')}';
}

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
///
/// มีจุดนำหน้าเหมือนหน้าเว็บของระบบนี้ จุดทำให้ป้ายอ่านออกว่าเป็น "สถานะ"
/// ตั้งแต่ยังไม่ทันอ่านตัวหนังสือ และกันสับสนกับชิปข้อมูลเทา ๆ บนการ์ดเดียวกัน
class RepairStatusChip extends StatelessWidget {
  final RepairStatus status;

  const RepairStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = repairStatusColor(status, Theme.of(context).colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// ชิปข้อมูลเล็ก ๆ ใต้ชื่อเครื่อง (สาขา ผู้แจ้ง ช่าง) แบบเดียวกับบนเว็บ
///
/// เทาล้วนทั้งชุด ไม่มีสีประจำแต่ละอัน สีบนการ์ดใบนี้จองไว้ให้สถานะอย่างเดียว
class RepairInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const RepairInfoChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
