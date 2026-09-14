import 'package:flutter/material.dart';

/// บรรทัดข้อมูลในการ์ด: ไอคอนซ้าย ข้อความขวา
///
/// ซ่อนตัวเองเมื่อไม่มีค่า หน้าที่เรียกจึงไม่ต้องเช็ค null เอง
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String? value;

  const InfoRow({super.key, required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = value;
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

/// ป้ายสถานะทรงแคปซูล สีตามความหมายของสถานะ
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// chip กรองรายการตามสถานะ ตอนเลือกอยู่จะย้อมสีของสถานะนั้น
///
/// ใช้ร่วมกันทั้งหน้าสถานะคลังและหน้ารายการบิลในแผน ให้ chip ของสถานะ
/// เดียวกันหน้าตาตรงกันทุกหน้า ไม่ต้องไปไล่แก้ทีละที่
class StatusFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;

  /// สีของสถานะ ปล่อย null สำหรับ chip "ทั้งหมด" ที่ไม่ผูกกับสถานะใด
  final Color? color;

  final VoidCallback onSelected;

  const StatusFilterChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color;

    return ChoiceChip(
      label: Text(
        '$label $count',
        style: TextStyle(
          color: selected && accent != null ? accent : scheme.onSurface,
        ),
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: accent?.withValues(alpha: 0.16),
      side: BorderSide(
        color: selected && accent != null ? accent : scheme.outlineVariant,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
