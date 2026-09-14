import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:claim/page/repair/repair_api.dart';
import 'package:claim/page/repair/repair_style.dart';
import 'package:claim/widgets/app_card.dart';

/// การ์ดใบแจ้งซ่อม ใช้ทั้งหน้ารายการรวมและหน้าประวัติของเครื่อง
class RepairTicketCard extends StatelessWidget {
  final RepairTicket ticket;
  final VoidCallback onTap;

  const RepairTicketCard({
    super.key,
    required this.ticket,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final created = ticket.createdAt;

    return AppCard(
      onTap: onTap,
      color: repairCardColor(ticket.status, scheme),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  ticket.deviceName.isEmpty ? '-' : ticket.deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RepairStatusChip(status: ticket.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            ticket.issueDescription.isEmpty ? '-' : ticket.issueDescription,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: scheme.onSurface),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (ticket.sn.isNotEmpty) _meta(scheme, Icons.tag, ticket.sn),
              if (ticket.branch.isNotEmpty)
                _meta(
                  scheme,
                  Icons.store_mall_directory_outlined,
                  ticket.branch,
                ),
              if (ticket.requesterName.isNotEmpty)
                _meta(scheme, Icons.person_outline, ticket.requesterName),
              if (ticket.technicianName.isNotEmpty)
                _meta(
                  scheme,
                  Icons.engineering_outlined,
                  ticket.technicianName,
                ),
              if (created != null)
                _meta(
                  scheme,
                  Icons.schedule,
                  DateFormat('d MMM y HH:mm', 'th').format(created),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(ColorScheme scheme, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
