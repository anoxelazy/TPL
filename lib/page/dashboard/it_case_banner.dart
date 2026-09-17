import 'package:flutter/material.dart';

import 'package:claim/page/itcase/itcase_form_page.dart';
import 'package:claim/utils/app_colors.dart';

/// แถบแจ้งเคสเต็มความกว้าง วางแยกออกมาจากตารางเมนู
///
/// แยกออกมาเพราะเป็นงานคนละแบบกับเมนูอื่น เมนูในตารางคือเครื่องมือที่สาขา
/// เปิดดูข้อมูลเอง แต่อันนี้คือการส่งเรื่องตรงถึงทีม IT มีคนปลายทางรออยู่
/// ยุบรวมเข้าไปในตารางแล้วจะกลายเป็นไอคอนที่ 9 ที่หาไม่เจอตอนเครื่องมีปัญหา
///
/// หน้าตาใช้ของเดิมของแอปทั้งหมด (มุมโค้ง ขอบ สีคู่ไอคอน-พื้น แบบเดียวกับ
/// ปุ่มในตาราง) ต่างแค่รูปทรงที่เป็นแถวยาว จึงเด่นโดยไม่หลุดธีม
class ItCaseBanner extends StatelessWidget {
  const ItCaseBanner({super.key});

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
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ItCaseFormPage())),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: AppColors.caseIcon.withValues(alpha: 0.28),
              width: AppSizes.cardBorder,
            ),
            // ไล่สีจาง ๆ จากซ้ายไปขวา พอให้ต่างจากการ์ดขาวของตารางเมนู
            // แต่ไม่ถึงกับเป็นบล็อกสีทึบที่ตีกับแบนเนอร์ด้านบน
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.caseIcon.withValues(alpha: 0.13),
                AppColors.caseIcon.withValues(alpha: 0.03),
              ],
            ),
          ),
          child: Row(
            children: [
              // แถบสีชิดขอบซ้าย เป็นตัวบอกว่าแถวนี้ไม่ใช่การ์ดธรรมดา
              Container(width: 5, height: 78, color: AppColors.caseIcon),
              const SizedBox(width: 13),
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.caseBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.support_agent,
                  size: 26,
                  color: AppColors.caseIcon,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'แจ้งเคสถึงทีม IT',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'คอมพิวเตอร์ ระบบ โปรแกรมTPS',
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
              // วงลูกศรทึบ บอกชัดว่ากดแล้วไปต่อ ไม่ใช่ป้ายประกาศเฉย ๆ
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.caseIcon,
                  shape: BoxShape.circle,
                ),
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
