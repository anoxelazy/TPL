import 'package:flutter/material.dart';

import 'package:claim/page/repair/repair_api.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/widgets/app_card.dart';

/// แถวเครื่อง 1 เครื่องในทะเบียน
///
/// ใช้ร่วมกันทั้งหน้าทะเบียนเครื่องและหน้าเลือกเครื่องตอนแจ้งซ่อม
/// ให้เครื่องเดียวกันหน้าตาเหมือนกันทุกที่ ไม่ต้องไล่แก้สองแห่ง
class AssetTile extends StatelessWidget {
  final RepairAsset asset;
  final VoidCallback onTap;

  const AssetTile({super.key, required this.asset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.repairBg,
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: asset.imageUrl.isEmpty
                ? const Icon(
                    Icons.desktop_windows_outlined,
                    size: 22,
                    color: AppColors.repairIcon,
                  )
                : Image.network(
                    asset.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const Icon(
                      Icons.desktop_windows_outlined,
                      size: 22,
                      color: AppColors.repairIcon,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (asset.assetCode.isNotEmpty) asset.assetCode,
                    if (asset.sn.isNotEmpty) 'S/N ${asset.sn}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (asset.department.isNotEmpty ||
                    asset.employeeName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (asset.department.isNotEmpty) asset.department,
                      if (asset.employeeName.isNotEmpty) asset.employeeName,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
