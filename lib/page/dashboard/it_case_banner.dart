import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:claim/page/dashboard/dashboard_banner.dart';
import 'package:claim/page/itcase/itcase_form_page.dart';
import 'package:claim/utils/app_colors.dart';

/// แถบแจ้งเคสเต็มความกว้าง วางแยกออกมาจากตารางเมนู
///
/// แยกออกมาเพราะเป็นงานคนละแบบกับเมนูอื่น เมนูในตารางคือเครื่องมือที่สาขา
/// เปิดดูข้อมูลเอง แต่อันนี้คือการส่งเรื่องตรงถึงทีม IT มีคนปลายทางรออยู่
/// ยุบรวมเข้าไปในตารางแล้วจะกลายเป็นไอคอนที่ 9 ที่หาไม่เจอตอนเครื่องมีปัญหา
///
/// หน้าตาอยู่ที่ [DashboardBanner] ใช้ร่วมกับแถบโอนย้ายทรัพย์สิน
class ItCaseBanner extends StatelessWidget {
  /// ดู [DashboardBanner.framed]
  final bool framed;

  const ItCaseBanner({super.key, this.framed = true});

  @override
  Widget build(BuildContext context) {
    return DashboardBanner(
      framed: framed,
      icon: PhosphorIconsDuotone.headset,
      color: AppColors.caseIcon,
      background: AppColors.caseBg,
      title: 'แจ้งเคสถึงทีม IT',
      subtitle: 'คอมพิวเตอร์ ระบบ โปรแกรมTPS',
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ItCaseFormPage())),
    );
  }
}
