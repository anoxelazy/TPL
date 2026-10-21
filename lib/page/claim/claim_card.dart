import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:claim/utils/app_colors.dart';
import 'package:claim/widgets/app_card.dart';

class ClaimCard extends StatelessWidget {
  final Map<String, dynamic> claim;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onSend;

  const ClaimCard({
    super.key,
    required this.claim,
    required this.index,
    required this.onEdit,
    required this.onSend,
  });

  /// สีตัวหนังสือและไอคอนบนการ์ด
  ///
  /// พื้นการ์ดเป็นส้มหรือเขียวอ่อนเสมอ (ทั้งธีมสว่างและมืด) จึงใช้หมึกเข้ม
  /// ตายตัว ไม่ใช้สีจากธีม เขียวแบรนด์บนพื้นเขียวจะกลืนหายไป
  static const Color _ink = AppColors.ink;
  static final Color _inkMuted = AppColors.ink.withValues(alpha: 0.7);

  @override
  Widget build(BuildContext context) {
    final DateTime timestamp = claim['timestamp'] ?? DateTime.now();
    final bool isSent = claim['isSent'] ?? false;
    // ส่งสำเร็จแล้วรอบหลังพลาดไม่นับ ข้อมูลขึ้น Sheet ไปตั้งแต่รอบแรกแล้ว
    final bool failed = !isSent && claim['sendFailed'] == true;
    final String type = claim['type'] ?? '';
    final String remarkType = claim['remarkType']?.toString() ?? '';

    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: _inkMuted,
    );
    final valueStyle = textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: _ink,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: AppCard(
        // ยังไม่ส่ง = ส้ม ส่งแล้ว = เขียว ส่งไม่สำเร็จ/เซิร์ฟเวอร์ไม่ตอบ = แดง
        // ดูสีการ์ดก็รู้ว่ารายการไหนยังค้าง และใบไหนต้องกดส่งใหม่
        color: isSent
            ? AppColors.claimSentBg
            : failed
            ? AppColors.claimFailedBg
            : AppColors.claimPendingBg,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(
                    icon: Icons.description_outlined,
                    label: 'เลขเอกสาร: ',
                    value: claim['docNumber']?.toString() ?? '',
                    labelStyle: labelStyle,
                    valueStyle: valueStyle,
                  ),
                  const SizedBox(height: 8),
                  _field(
                    icon: Icons.local_shipping_outlined,
                    label: 'รหัสรถ: ',
                    value: claim['carCode']?.toString() ?? '',
                    labelStyle: labelStyle,
                    valueStyle: valueStyle,
                  ),
                  const SizedBox(height: 8),
                  _field(
                    icon: Icons.report_problem_outlined,
                    label: 'ประเภท: ',
                    value: claim['type']?.toString() ?? '',
                    labelStyle: labelStyle,
                    valueStyle: valueStyle,
                  ),
                  if ((type == 'เสียหาย' ||
                          type == 'สูญหาย' ||
                          type == 'ไม่ครบล็อต') &&
                      remarkType.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        type == 'เสียหาย'
                            ? 'รายละเอียดความเสียหาย: $remarkType'
                            : type == 'สูญหาย'
                            ? 'รายละเอียดการสูญหาย: $remarkType'
                            : 'รายละเอียดเพิ่มเติม: $remarkType',
                        style: textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: _inkMuted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'วันที่: ${DateFormat('dd/MM/yyyy').format(timestamp)}',
                    style: textTheme.bodySmall?.copyWith(color: _inkMuted),
                  ),
                  // ส่งรอบก่อนไม่ผ่าน บอกไว้บนการ์ดว่าใบนี้ต้องกดส่งใหม่
                  // ตัวเลขบนแถบสรุปบอกแค่จำนวน ไม่ได้บอกว่าใบไหน
                  if (failed) ...[
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: AppColors.dangerText,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'ส่งไม่สำเร็จ กดส่งอีกครั้ง',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dangerText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RoundButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'แก้ไขข้อมูล',
                  onPressed: onEdit,
                  // พื้นส้มทึบ ไอคอนหมึก ส้มตัวนี้เป็นไอคอนบนพื้นขาวจะจางจนมองไม่เห็น
                  fill: AppColors.claimEditFill,
                ),
                const SizedBox(height: 8),
                _SendButton(isSent: isSent, failed: failed, onSend: onSend),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// แถวไอคอน + ป้าย + ค่า เช่น "เลขเอกสาร: 123"
  Widget _field({
    required IconData icon,
    required String label,
    required String value,
    required TextStyle? labelStyle,
    required TextStyle? valueStyle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: _ink),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(text: label, style: labelStyle),
                TextSpan(text: value, style: valueStyle),
              ],
            ),
            softWrap: true,
            overflow: TextOverflow.visible,
          ),
        ),
      ],
    );
  }
}

/// ปุ่มกลมบนการ์ด พื้นขาวโปร่งให้เด่นขึ้นมาจากพื้นการ์ดสี
class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// สีพื้นวงกลม ไม่ส่งมา = ขาวโปร่งกลืนกับการ์ด
  final Color? fill;

  /// สีไอคอน ไม่ส่งมา = หมึกเข้ม
  final Color iconColor;

  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.fill,
    this.iconColor = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: fill ?? Colors.white.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor, size: 22),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }
}

/// ปุ่มส่งรายการไป Google Sheet
///
/// ส่งแล้วเปลี่ยนเป็นปุ่มวนซ้ำพร้อมคำว่า "ส่งซ้ำ" ใต้ปุ่ม คนจะได้รู้ว่า
/// รายการนี้ขึ้น Sheet ไปแล้ว และกดอีกทีคือการส่งซ้ำ ไม่ใช่ส่งครั้งแรก
/// (กดแล้วยังมีหน้าต่างให้ยืนยันก่อนส่งซ้ำเหมือนเดิม)
///
/// ส่งไม่สำเร็จก็เป็นปุ่มวนซ้ำเหมือนกัน แต่เขียนว่า "ส่งใหม่" เพราะรอบก่อน
/// ข้อมูลยังไม่ขึ้น Sheet (กดแล้วส่งเลย ไม่ต้องยืนยันแบบส่งซ้ำ)
///
/// ปุ่มส่งครั้งแรกเป็นวงขาวโปร่ง ส่วนปุ่มวนซ้ำ (ส่งซ้ำ / ส่งใหม่) เป็นแดงทึบ
/// ให้เห็นทันทีว่ากดแล้วคือส่งอีกรอบ ไม่ใช่ส่งครั้งแรก
class _SendButton extends StatelessWidget {
  final bool isSent;
  final bool failed;
  final VoidCallback onSend;

  const _SendButton({
    required this.isSent,
    required this.failed,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final retry = isSent || failed;
    // ส่งซ้ำ (ส่งแล้ว) ใช้แดงอ่อนกว่า ส่งใหม่ (ส่งพัง ต้องรีบกด) ใช้แดงเข้ม
    // สองสถานะจะได้ไม่ดูเหมือนกันทุกอย่าง
    final Color? retryColor = isSent
        ? AppColors.danger
        : failed
        ? AppColors.dangerText
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundButton(
          icon: retry ? Icons.refresh_rounded : Icons.send_outlined,
          tooltip: isSent
              ? 'ส่งไป Google Sheet แล้ว กดเพื่อส่งซ้ำ'
              : failed
              ? 'ส่งรอบก่อนไม่สำเร็จ กดเพื่อส่งใหม่'
              : 'ส่งรายการนี้ไป Google Sheet',
          onPressed: onSend,
          // ปุ่มวนซ้ำ (ส่งซ้ำ / ส่งใหม่) เป็นแดงทึบ แยกให้ออกจากปุ่มส่งครั้งแรก
          fill: retryColor,
          iconColor: retry ? Colors.white : AppColors.ink,
        ),
        if (retry) ...[
          const SizedBox(height: 2),
          Text(
            isSent ? 'ส่งซ้ำ' : 'ส่งใหม่',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: retryColor ?? AppColors.ink,
            ),
          ),
        ],
      ],
    );
  }
}
