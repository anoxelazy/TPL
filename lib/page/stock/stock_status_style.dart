import 'package:flutter/material.dart';

import 'package:claim/page/stock/stock_api.dart';
import 'package:claim/utils/app_colors.dart';

/// สีวนใช้กับสถานะต่าง ๆ (ไม่รวมสีเหลืองที่ล็อกไว้ให้สถานะที่อยู่ในระยะ "พักสินค้า")
const List<Color> _statusPalette = [
  AppColors.stageOrigin,
  AppColors.stageWarehouse,
  AppColors.stageDelivering,
  AppColors.success,
  AppColors.danger,
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
  Color(0xFFF97316),
  Color(0xFF64748B),
];

/// สีของแต่ละสถานะ ใช้ทั้งบนกราฟ ปุ่มกรอง และป้ายบนการ์ดให้ตรงกัน
///
/// กำหนดจากลำดับของสถานะในรายการจาก API จึงคงที่ ไม่เปลี่ยนตามว่ามีบิลสถานะไหนอยู่
Color stockStatusColor(String? jobStatusId, ColorScheme scheme) {
  final id = jobStatusId?.trim() ?? '';
  if (id.isEmpty) return scheme.onSurfaceVariant;
  if (shipmentStageFromJobStatus(id) == ShipmentStage.parked) {
    return AppColors.pending;
  }

  final order = jobStatusOrder(id);
  final index = order < (1 << 20) ? order : id.hashCode.abs();
  return _statusPalette[index % _statusPalette.length];
}

/// ชื่อสถานะบนปุ่มกรองและกราฟ ไม่มี jobstatusid = "ไม่ทราบสถานะ"
String stockStatusLabel(String key) {
  if (key.isEmpty) return 'ไม่ทราบสถานะ';
  return jobStatusOf(key)?.name ?? key;
}

/// หัวการ์ดของบิล: เลขบิล + "สถานะสินค้า: รหัส" ทางซ้าย ป้ายชื่อสถานะทางขวา
///
/// ชื่อสถานะจาก API ยาวได้ถึงสี่สิบตัวอักษร ป้ายจึงจำกัดความกว้างเท่าที่เหลือและ
/// ย่อด้วย … บรรทัดเดียว ไม่ดันเลขบิลหรือทำให้แถวล้น ใช้ทั้งการ์ดรายการ
/// (มีลูกศร [trailing]) และหน้ารายละเอียด
class StockBillHeader extends StatelessWidget {
  final BillStockItem item;
  final Widget? trailing;

  const StockBillHeader({super.key, required this.item, this.trailing});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = stockStatusColor(item.jobStatusId, scheme);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // เลขบิลต้องเห็นครบเสมอ ไม่ย่อด้วย … ถ้าที่แคบจริงให้ลดขนาดลงเอง
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  item.billCode,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'สถานะสินค้า: ',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    TextSpan(
                      text: item.jobStatusId ?? '-',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // ป้ายกินที่ได้ไม่เกินราวครึ่งแถว ที่เหลือเป็นของเลขบิล
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.4,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                item.displayStatus,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 4), trailing!],
      ],
    );
  }
}
