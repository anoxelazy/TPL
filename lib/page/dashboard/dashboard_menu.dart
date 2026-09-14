import 'package:flutter/material.dart';

import 'package:claim/page/claim/claim.dart';
import 'package:claim/page/meter/meter_api.dart' show meterModule;
import 'package:claim/page/meter/meter_form_page.dart';
import 'package:claim/page/plan/plan_api.dart' show planModule;
import 'package:claim/page/plan/plan_page.dart';
import 'package:claim/page/pm/pm_page.dart';
import 'package:claim/page/repair/repair_page.dart';
import 'package:claim/page/scan/scan_api.dart' show scanModule;
import 'package:claim/page/scan/scan_page.dart';
import 'package:claim/page/stock/stock_api.dart' show stockModule;
import 'package:claim/page/stock/stock_status_page.dart';
import 'package:claim/page/tracking/tracking_screen.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/permission_service.dart';
import 'package:claim/utils/pm_access_service.dart';
import 'package:claim/utils/app_icons.dart';

/// เมนู 1 รายการบนหน้าหลัก
class DashboardMenuItem {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color iconBg;

  /// null เมื่อยังไม่มีหน้าให้ไป
  final VoidCallback? onTap;

  /// เห็นเมนูได้ แต่ยังไม่มีสิทธิ์เข้าใช้งาน
  final bool locked;

  /// เมนูที่วางไว้ก่อน ยังไม่ได้ทำหน้าจอ
  final bool comingSoon;

  const DashboardMenuItem({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.iconBg,
    this.onTap,
    this.locked = false,
    this.comingSoon = false,
  });

  /// กดเข้าไม่ได้ ไม่ว่าจะเพราะไม่มีสิทธิ์หรือยังไม่ได้ทำหน้าจอ
  bool get isBlocked => locked || onTap == null;
}

List<DashboardMenuItem> buildDashboardMenu(BuildContext context) {
  final bool canAccessPlan = PermissionService.I.canAccess(planModule);
  final bool canAccessStock = PermissionService.I.canAccess(stockModule);
  final bool canAccessMeter = PermissionService.I.canAccess(meterModule);
  final bool canAccessScan = PermissionService.I.canAccess(scanModule);
  final String? branchId = PermissionService.I.getBranchId();
  final bool hasBranch = branchId != null && branchId.isNotEmpty;

  void go(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  final items = <DashboardMenuItem>[
    DashboardMenuItem(
      icon: Icons.archive_outlined,
      label: 'บันทึกสินค้าเสียหาย',
      iconColor: AppColors.claimIcon,
      iconBg: AppColors.claimBg,
      onTap: () => go(const ClaimPage()),
    ),
    DashboardMenuItem(
      icon: Icons.warehouse_outlined,
      label: 'คลังสินค้า ${hasBranch ? branchId : '-'}',
      iconColor: AppColors.stockIcon,
      iconBg: AppColors.stockBg,
      locked: !canAccessStock,
      onTap: () => go(const StockStatusPage()),
    ),
    DashboardMenuItem(
      icon: Icons.local_shipping_outlined,
      label: 'เช็คสถานะพัสดุ',
      iconColor: AppColors.trackingIcon,
      iconBg: AppColors.trackingBg,
      // อ่านอย่างเดียว ไม่ผูกสิทธิ์ module ใคร login เข้ามาก็เช็คได้
      onTap: () => go(const TrackingPage()),
    ),
    DashboardMenuItem(
      icon: Icons.assignment_outlined,
      label: 'แผนรถของคุณ',
      iconColor: AppColors.planIcon,
      iconBg: AppColors.planBg,
      locked: !canAccessPlan,
      onTap: () => go(const PlanPage()),
    ),
    DashboardMenuItem(
      icon: AppIcons.scan,
      label: 'ถ่ายบาร์โค้ด',
      iconColor: AppColors.scanIcon,
      iconBg: AppColors.scanBg,
      locked: !canAccessScan,
      onTap: () => go(const ScanPage()),
    ),
    DashboardMenuItem(
      icon: Icons.local_gas_station_outlined,
      label: 'ชดเชยค่าน้ำมัน',
      iconColor: AppColors.meterIcon,
      iconBg: AppColors.meterBg,
      locked: !canAccessMeter,
      onTap: () => go(const MeterPage()),
    ),
    DashboardMenuItem(
      icon: Icons.build_outlined,
      label: 'แจ้งซ่อม',
      iconColor: AppColors.repairIcon,
      iconBg: AppColors.repairBg,
      onTap: () => go(const RepairPage()),
    ),
    DashboardMenuItem(
      icon: Icons.swap_horiz,
      label: 'โอนย้ายทรัพย์สิน',
      iconColor: AppColors.assetIcon,
      iconBg: AppColors.assetBg,
      comingSoon: true,
    ),
    DashboardMenuItem(
      icon: Icons.handyman_outlined,
      label: 'PM เฉพาะ IT',
      iconColor: AppColors.pmIcon,
      iconBg: AppColors.pmBg,
      locked: !PmAccessService.I.allowed.value,
      onTap: () => go(const PmPage()),
    ),
  ];

  return _byAvailability(items);
}

/// เรียงเมนูที่ใช้ได้จริงขึ้นก่อน แล้วตัวที่ยังไม่มีสิทธิ์ ปิดท้ายด้วยตัวที่ยังไม่เปิด
///
/// คนที่เปิดสิทธิ์ไว้ไม่กี่โมดูลจะได้ไม่ต้องเลื่อนผ่านเมนูที่กดไม่ได้
/// พ่วง index เดิมไปด้วย ลำดับภายในกลุ่มเดียวกันจึงไม่สลับไปมาเอง
List<DashboardMenuItem> _byAvailability(List<DashboardMenuItem> items) {
  final ranked = <MapEntry<int, DashboardMenuItem>>[
    for (var i = 0; i < items.length; i++) MapEntry(i, items[i]),
  ];

  ranked.sort((a, b) {
    final byRank = _rank(a.value).compareTo(_rank(b.value));
    return byRank != 0 ? byRank : a.key.compareTo(b.key);
  });

  return [for (final entry in ranked) entry.value];
}

/// 0 = กดเข้าได้ 1 = ยังไม่มีสิทธิ์ 2 = ยังไม่ได้ทำหน้าจอ
int _rank(DashboardMenuItem item) {
  if (item.comingSoon) return 2;
  if (item.isBlocked) return 1;
  return 0;
}

void openDashboardMenu(BuildContext context, DashboardMenuItem item) {
  if (!item.isBlocked) {
    item.onTap!();
    return;
  }

  final message = item.locked
      ? 'ยังไม่มีสิทธิ์เข้าใช้งาน "${item.label}"'
      : 'เมนู "${item.label}" ยังไม่เปิดใช้งาน';

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
  );
}

List<DashboardMenuItem> filterDashboardMenu(
  List<DashboardMenuItem> items,
  String query,
) {
  final keyword = query.trim().toLowerCase();
  if (keyword.isEmpty) return items;
  return items
      .where((item) => item.label.toLowerCase().contains(keyword))
      .toList();
}
