import 'package:flutter/material.dart';

import 'package:claim/page/repair/repair_api.dart';
import 'package:claim/page/repair/repair_style.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/widgets/app_card.dart';

class RepairStatGrid extends StatelessWidget {
  final List<RepairTicket> tickets;

  final RepairStatus? filter;

  final ValueChanged<RepairStatus?> onPick;

  const RepairStatGrid({
    super.key,
    required this.tickets,
    required this.filter,
    required this.onPick,
  });

  int _countOf(RepairStatus status) =>
      tickets.where((t) => t.status == status).length;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'ใบทั้งหมด',
                icon: Icons.receipt_long_outlined,
                count: tickets.length,
                color: scheme.onSurface,
                footer: 'ทุกสถานะรวมกัน',
                selected: filter == null,
                onTap: () => onPick(null),
              ),
            ),
            const SizedBox(width: AppSizes.gap),
            Expanded(child: _statusCard(context, RepairStatus.pending)),
          ],
        ),
        const SizedBox(height: AppSizes.gap),
        Row(
          children: [
            Expanded(child: _statusCard(context, RepairStatus.inProgress)),
            const SizedBox(width: AppSizes.gap),
            Expanded(child: _statusCard(context, RepairStatus.completed)),
          ],
        ),
      ],
    );
  }

  Widget _statusCard(BuildContext context, RepairStatus status) {
    final scheme = Theme.of(context).colorScheme;
    final count = _countOf(status);

    return _StatCard(
      title: status.label,
      icon: _iconOf(status),
      count: count,
      color: count == 0
          ? scheme.onSurfaceVariant
          : repairStatusColor(status, scheme),
      footer: count == 0 ? 'ไม่มีงานค้าง' : 'ดูเฉพาะสถานะนี้',
      selected: filter == status,
      onTap: () => onPick(status),
    );
  }

  IconData _iconOf(RepairStatus status) => switch (status) {
    RepairStatus.pending => Icons.notifications_none,
    RepairStatus.inProgress => Icons.handyman_outlined,
    RepairStatus.completed => Icons.check_circle_outline,
  };
}

class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;
  final Color color;
  final String footer;
  final bool selected;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.icon,
    required this.count,
    required this.color,
    required this.footer,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      onTap: onTap,
      clipContent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 3, color: selected ? color : Colors.transparent),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(icon, size: 18, color: scheme.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: color,
                  ),
                ),
                Text(
                  footer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RepairShortcuts extends StatelessWidget {
  final VoidCallback onAssets;

  const RepairShortcuts({super.key, required this.onAssets});

  @override
  Widget build(BuildContext context) => _Shortcut(
    icon: Icons.devices_other,
    title: 'ทะเบียนเครื่อง',
    subtitle: 'ข้อมูลเครื่องทั้งหมดในระบบ',
    onTap: onAssets,
  );
}

class _Shortcut extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Shortcut({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.repairBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: AppColors.brandText),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class RepairListHeading extends StatelessWidget {
  const RepairListHeading({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppColors.repairBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.assignment_outlined,
            size: 18,
            color: AppColors.brandText,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'รายการและประวัติการแจ้งซ่อม',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
