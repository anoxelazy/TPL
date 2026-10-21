import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:claim/page/asset/asset_list_page.dart';
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

class DashboardMenuItem {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color iconBg;

  final VoidCallback? onTap;

  final bool locked;

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
      icon: PhosphorIconsDuotone.boxArrowDown,
      label: 'สินค้าเสียหาย',
      iconColor: AppColors.claimIcon,
      iconBg: AppColors.claimBg,
      onTap: () => go(const ClaimPage()),
    ),
    DashboardMenuItem(
      icon: PhosphorIconsDuotone.warehouse,
      label: 'คลัง${hasBranch ? branchId : '-'}',
      iconColor: AppColors.stockIcon,
      iconBg: AppColors.stockBg,
      locked: !canAccessStock,
      onTap: () => go(const StockStatusPage()),
    ),
    DashboardMenuItem(
      icon: PhosphorIconsDuotone.truck,
      label: 'เช็คสถานะ',
      iconColor: AppColors.trackingIcon,
      iconBg: AppColors.trackingBg,
      onTap: () => go(const TrackingPage()),
    ),
    DashboardMenuItem(
      icon: PhosphorIconsDuotone.mapTrifold,
      label: 'แผนรถ',
      iconColor: AppColors.planIcon,
      iconBg: AppColors.planBg,
      locked: !canAccessPlan,
      onTap: () => go(const PlanPage()),
    ),
    DashboardMenuItem(
      icon: PhosphorIconsDuotone.barcode,
      label: 'สแกนบาร์โค้ด',
      iconColor: AppColors.scanIcon,
      iconBg: AppColors.scanBg,
      locked: !canAccessScan,
      onTap: () => go(const ScanPage()),
    ),
    DashboardMenuItem(
      icon: PhosphorIconsDuotone.gasPump,
      label: 'ชดเชยน้ำมัน',
      iconColor: AppColors.meterIcon,
      iconBg: AppColors.meterBg,
      locked: !canAccessMeter,
      onTap: () => go(const MeterPage()),
    ),
    DashboardMenuItem(
      icon: PhosphorIconsDuotone.wrench,
      label: 'แจ้งซ่อม',
      iconColor: AppColors.repairMenuIcon,
      iconBg: AppColors.repairMenuBg,
      onTap: () => go(const RepairPage()),
    ),
    DashboardMenuItem(
      icon: PhosphorIconsDuotone.archive,
      label: 'ทรัพย์สินทั้งหมด',
      iconColor: AppColors.assetIcon,
      iconBg: AppColors.assetBg,
      onTap: () => go(const AssetListPage()),
    ),
    DashboardMenuItem(
      icon: PhosphorIconsDuotone.toolbox,
      label: 'PM IT',
      iconColor: AppColors.pmIcon,
      iconBg: AppColors.pmBg,
      locked: !PmAccessService.I.allowed.value,
      onTap: () => go(const PmPage()),
    ),
  ];

  return _byAvailability(items);
}

List<DashboardMenuItem> unlockedMenu(List<DashboardMenuItem> items) =>
    items.where((item) => !item.isBlocked).toList();

List<DashboardMenuItem> lockedMenu(List<DashboardMenuItem> items) =>
    items.where((item) => item.isBlocked).toList();

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
