import 'package:flutter/material.dart';

import 'package:claim/page/repair/repair_api.dart';
import 'package:claim/page/repair/repair_style.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/widgets/app_card.dart';

/// การ์ดใบแจ้งซ่อม ใช้ทั้งหน้ารายการรวมและหน้าประวัติของเครื่อง
///
/// หน้าตาตามหน้าเว็บของระบบเดียวกัน แบ่งเป็นสองชั้นคั่นด้วยเส้น
///
/// **ชั้นบนคือตัวใบ** เลขที่ใบ วันที่แจ้ง วันที่ปิด และสถานะ
/// **ชั้นล่างคือของที่เสีย** ชื่อเครื่อง S/N อาการ แล้วปิดท้ายด้วยชิปบอกที่มา
///
/// แบ่งแบบนี้เพราะสองเรื่องนี้ตอบคนละคำถาม (ใบนี้ถึงไหนแล้ว / ใบนี้เรื่องอะไร)
/// ของเดิมเทกองรวมกันเป็นไอคอนห้าอันใน Wrap ที่ตัดบรรทัดไม่ซ้ำกันสักใบ
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

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: _header(scheme),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: _device(scheme),
          ),
        ],
      ),
    );
  }

  /// ชั้นบน: เลขที่ใบซ้าย สถานะขวา วันที่อยู่ใต้ของตัวเอง
  Widget _header(ColorScheme scheme) {
    final created = ticket.createdAt;
    final completed = ticket.completedAt;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _ticketNo,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: scheme.onSurface,
                ),
              ),
              if (created != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'แจ้งเมื่อ ${repairDateLabel(created)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            RepairStatusChip(status: ticket.status),
            if (completed != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'เสร็จ ${repairDateLabel(completed)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// ชั้นล่าง: เครื่องที่เสียกับอาการ
  Widget _device(ColorScheme scheme) {
    final chips = _chips;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ticket.deviceName.isEmpty ? '-' : ticket.deviceName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        if (ticket.sn.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              ticket.sn,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                // เขียวเข้มพอจะอ่านออกบนพื้นขาว ไม่ใช่เขียวแบรนด์สด
                color: AppColors.brandText,
              ),
            ),
          ),
        if (ticket.issueDescription.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              ticket.issueDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: scheme.onSurface,
              ),
            ),
          ),
        if (chips.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(spacing: 6, runSpacing: 6, children: chips),
          ),
      ],
    );
  }

  /// เลขที่ใบ ใช้ id ของแถวเป็นเลขเดียวกับที่เว็บเรียก `#TK-28`
  ///
  /// ⚠️ ข้อสมมติ: เว็บเอา id ของใบมาต่อท้าย TK- ตรง ๆ ถ้าหลังบ้านมีคอลัมน์
  /// เลขที่ใบแยกต่างหาก ต้องเปลี่ยนมาอ่านจากคอลัมน์นั้นแทน ไม่งั้นเลขบนแอปกับ
  /// บนเว็บจะเป็นคนละใบกัน ใบที่ไม่มี id (ยังไม่เคยเจอ) ถอยไปใช้ชื่อเครื่อง
  String get _ticketNo {
    final id = ticket.id;
    if (id != null) return '#TK-$id';

    return ticket.deviceName.isEmpty ? 'ใบแจ้งซ่อม' : ticket.deviceName;
  }

  /// ชิปบอกที่มาของใบ ตัวไหนไม่มีข้อมูลก็ไม่ต้องมีชิป
  List<Widget> get _chips => [
    if (ticket.branch.isNotEmpty)
      RepairInfoChip(
        icon: Icons.store_mall_directory_outlined,
        label: ticket.branch,
      ),
    if (ticket.requesterName.isNotEmpty)
      RepairInfoChip(icon: Icons.person_outline, label: ticket.requesterName),
    if (ticket.technicianName.isNotEmpty)
      RepairInfoChip(
        icon: Icons.engineering_outlined,
        label: ticket.technicianName,
      ),
  ];
}
