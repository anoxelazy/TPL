import 'package:flutter/material.dart';

import 'package:claim/utils/app_icons.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/theme.dart';
import 'package:claim/widgets/app_card.dart';

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

  /// วาดการ์ดของตัวเองไหม
  ///
  /// หน้าหลักเอาหลายแถบไปเรียงในการ์ดใบเดียวกัน ([DashboardBannerGroup])
  /// แถบในกลุ่มจึงไม่ต้องมีกรอบกับแถบสีซ้ายของตัวเอง ไม่งั้นจะเป็นกล่องซ้อนกล่อง
  final bool framed;

  const DashboardBanner({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeCount = 0,
    this.framed = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppSizes.cardRadius);

    if (!framed) {
      return InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: _content(scheme),
          ),
        ),
      );
    }

    return Material(
      color: AppTheme.cardColor(scheme),
      borderRadius: radius,
      // แถบสีด้านซ้ายต้องโดนตัดตามมุมโค้ง ไม่งั้นมุมจะแหลมโผล่ออกมา
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          // การ์ดขาวขอบเทาบาง ๆ ไม่ไล่สีพื้น สีของแถบเหลือแค่เส้นซ้ายกับไอคอน
          // พอให้รู้ว่าเป็นของที่ต้องกด โดยไม่กลายเป็นก้อนสีบนหน้าหลัก
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: scheme.outlineVariant,
              width: AppSizes.cardBorder,
            ),
          ),
          child: Row(
            children: [
              // แถบสีชิดขอบซ้าย เป็นตัวบอกว่าแถวนี้ไม่ใช่การ์ดธรรมดา
              Container(width: 4, height: 76, color: color),
              const SizedBox(width: 13),
              Expanded(child: _content(scheme)),
            ],
          ),
        ),
      ),
    );
  }

  /// ไอคอน ชื่อ คำอธิบาย ตัวเลข และลูกศร ใช้เหมือนกันทั้งแบบมีกรอบและในกลุ่ม
  Widget _content(ColorScheme scheme) {
    return Row(
      children: [
        // ไอคอนเส้นล้วนแบบเดียวกับตารางเมนู ให้ทั้งหน้าเป็นชุดเดียวกัน
        SizedBox(
          width: 46,
          height: 46,
          child: AppIcons.duotone(icon, size: 32, color: color),
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
        // ลูกศรบอกว่ากดแล้วไปต่อ ไม่ใช่ป้ายประกาศเฉย ๆ
        Icon(
          Icons.chevron_right_rounded,
          size: 24,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
      ],
    );
  }
}

/// การ์ดใบเดียวที่รวมแถบหลายอันไว้ด้วยกัน คั่นด้วยเส้นบาง ๆ
///
/// แถบที่ต่างคนต่างเป็นการ์ดของตัวเองวางเรียงกันแล้วดูเป็นกล่องลอย ๆ หลายกล่อง
/// รวมไว้ใบเดียว หน้าหลักจะเหลือก้อนน้อยลงและอ่านออกว่าเป็นกลุ่มเดียวกัน
/// ลูกที่ส่งมาควรเป็นแถบที่ตั้ง `framed: false`
class DashboardBannerGroup extends StatelessWidget {
  final List<Widget> children;

  const DashboardBannerGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      clipContent: true,
      color: AppTheme.cardColor(scheme),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            // เส้นคั่นเริ่มตรงตัวหนังสือ ไม่ลากผ่านไอคอน แบบรายการในตั้งค่ามือถือ
            if (i > 0)
              Divider(
                height: 1,
                thickness: AppSizes.cardBorder,
                indent: 74,
                color: scheme.outlineVariant,
              ),
            children[i],
          ],
        ],
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
