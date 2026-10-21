import 'package:flutter/material.dart';

import 'package:claim/utils/app_colors.dart';
import 'package:claim/widgets/app_card.dart';

/// แถบสรุปบนสุดของหน้ารายการสินค้าเสียหาย: ส่งสำเร็จ / รอส่ง / ไม่สำเร็จ
///
/// แถบสีด้านบนแบ่งสัดส่วนตามจำนวนจริง เห็นทีเดียวว่าวันนี้ไปถึงไหนแล้ว
/// ตัวเลขข้างล่างบอกค่าเป๊ะ ๆ ตัวเลขมาจากรายการในเครื่องซึ่งเป็นของวันนี้
/// เท่านั้น ขึ้นวันใหม่รายการเก่าถูกล้าง ตัวเลขจึงเริ่มจากศูนย์เอง
class ClaimSummaryBar extends StatelessWidget {
  final int sent;
  final int pending;
  final int failed;

  const ClaimSummaryBar({
    super.key,
    required this.sent,
    required this.pending,
    required this.failed,
  });

  int get total => sent + pending + failed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'สรุปวันนี้',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  'ทั้งหมด $total รายการ',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ProportionBar(
              parts: [
                (sent, AppColors.success),
                (pending, AppColors.pending),
                (failed, AppColors.danger),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'ส่งสำเร็จ',
                    value: sent,
                    color: AppColors.success,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'รอส่ง',
                    value: pending,
                    color: AppColors.pending,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'ไม่สำเร็จ',
                    value: failed,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// แถบสีแบ่งสัดส่วน ช่องที่เป็นศูนย์ไม่กินที่
class _ProportionBar extends StatelessWidget {
  final List<(int, Color)> parts;

  const _ProportionBar({required this.parts});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = parts.where((p) => p.$1 > 0).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.pillRadius),
      child: SizedBox(
        height: 10,
        child: shown.isEmpty
            ? ColoredBox(color: scheme.surfaceContainerHighest)
            : Row(
                // ช่องสีไม่มีลูก ถ้าไม่ยืดจะสูงศูนย์จนแถบหายไปทั้งเส้น
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < shown.length; i++) ...[
                    // เว้นเส้นขาวบาง ๆ ระหว่างช่อง สองสีที่ติดกันจะได้ไม่กลืน
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      flex: shown[i].$1,
                      child: ColoredBox(color: shown[i].$2),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// ตัวเลขหนึ่งช่องใต้แถบ: จุดสี + ชื่อ แล้วตัวเลขตัวใหญ่
class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}
