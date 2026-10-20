import 'package:flutter/material.dart';

import 'package:claim/utils/app_colors.dart';

/// แถบเมนูเต็มความกว้างบนหน้าหลัก ใช้กับงานที่ต้องเด่นกว่าช่องในตารางเมนู
///
/// เดิมมีแค่แถบแจ้งเคสที่เขียนไว้ตรง ๆ ในไฟล์ของตัวเอง พอมีตัวที่สองต้องเด่น
/// เท่ากัน จึงยกหน้าตาออกมาไว้ที่เดียว ไม่งั้นอีกหน่อยสองแถบจะค่อย ๆ เพี้ยน
/// ไปคนละทางเวลาแก้ทีละที่
///
/// หน้าตาใช้ของเดิมของแอปทั้งหมด (มุมโค้ง ขอบ สีคู่ไอคอน-พื้น แบบเดียวกับ
/// ปุ่มในตาราง) ต่างแค่รูปทรงที่เป็นแถวยาว จึงเด่นโดยไม่หลุดธีม
class DashboardBanner extends StatelessWidget {
  final IconData icon;

  /// สีประจำเมนูนั้น ใช้ทั้งแถบซ้าย ไอคอน ขอบ และวงลูกศร
  final Color color;

  /// สีพื้นอ่อนคู่กับ [color] ใช้เป็นวงหลังไอคอน
  final Color background;

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// จำนวนงานที่รอคนคนนี้อยู่ 0 = ไม่มีอะไรรอ ไม่ต้องวาดอะไรเลย
  ///
  /// มีไว้ให้คนเปิดแอปมาเห็นตั้งแต่หน้าแรกว่ามีของรอให้กด ไม่ต้องเข้าไปดูเอง
  /// ว่ามีไหม — งานที่ไม่มีใครรู้ว่ารออยู่คืองานที่ไม่มีใครทำ
  final int badgeCount;

  const DashboardBanner({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppSizes.cardRadius);

    return Material(
      color: scheme.surface,
      borderRadius: radius,
      // แถบสีด้านซ้ายต้องโดนตัดตามมุมโค้ง ไม่งั้นมุมจะแหลมโผล่ออกมา
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: color.withValues(alpha: 0.28),
              width: AppSizes.cardBorder,
            ),
            // ไล่สีจาง ๆ จากซ้ายไปขวา พอให้ต่างจากการ์ดขาวของตารางเมนู
            // แต่ไม่ถึงกับเป็นบล็อกสีทึบที่ตีกับแบนเนอร์ด้านบน
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                color.withValues(alpha: 0.13),
                color.withValues(alpha: 0.03),
              ],
            ),
          ),
          child: Row(
            children: [
              // แถบสีชิดขอบซ้าย เป็นตัวบอกว่าแถวนี้ไม่ใช่การ์ดธรรมดา
              Container(width: 5, height: 78, color: color),
              const SizedBox(width: 13),
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 26, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (badgeCount > 0) ...[
                _Badge(count: badgeCount, color: color),
                const SizedBox(width: 10),
              ],
              // วงลูกศรทึบ บอกชัดว่ากดแล้วไปต่อ ไม่ใช่ป้ายประกาศเฉย ๆ
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}

/// ตัวเลขงานค้างบนแถบ
///
/// ใช้สีประจำเมนูแบบทึบ ไม่ใช่สีแดงเตือนภัย เพราะมีงานรออยู่เป็นเรื่องปกติของ
/// การทำงาน ไม่ใช่ความผิดพลาด สีแดงทุกวันจะกลายเป็นสีที่ไม่มีใครมองอีกเลย
class _Badge extends StatelessWidget {
  final int count;
  final Color color;

  const _Badge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    // เกิน 99 ไม่ต้องรู้จำนวนเป๊ะ รู้ว่า "เยอะมาก" พอ และเลขสามหลักจะดันแถบเบี้ยว
    final label = count > 99 ? '99+' : '$count';

    return Container(
      constraints: const BoxConstraints(minWidth: 26),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 1.2,
          color: Colors.white,
        ),
      ),
    );
  }
}
