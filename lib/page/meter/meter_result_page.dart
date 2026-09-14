import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:claim/utils/app_colors.dart';
import 'package:claim/widgets/app_card.dart';
import 'package:claim/page/meter/meter_api.dart';
import 'package:claim/page/meter/meter_widgets.dart';
import 'package:claim/widgets/remote_image.dart';

/// สรุปผลการชดเชยค่าน้ำมัน ทุกตัวเลขมาจาก response ของ /InputMeter
/// ไม่มีการคำนวณซ้ำในแอป
class MeterResultPage extends StatelessWidget {
  final MeterResult result;

  const MeterResultPage({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ผลการชดเชยค่าน้ำมัน')),
      body: SafeArea(
        child: ListView(
          padding: AppSizes.pagePadding,
          children: [
            _IdentityCard(result: result),
            const SizedBox(height: AppSizes.gap),
            _CalculationCard(result: result),
            const SizedBox(height: AppSizes.gap),
            _MeterImagesCard(result: result),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('เสร็จสิ้น'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  final MeterResult result;

  const _IdentityCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recDate = result.recDate;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Highlight(
                  label: 'รหัสคนขับ',
                  value: result.driverId.isEmpty ? '-' : result.driverId,
                ),
              ),
              Expanded(
                child: _Highlight(
                  label: 'หมายเลขรถ',
                  value: result.truckId.isEmpty ? '-' : result.truckId,
                ),
              ),
            ],
          ),
          if (result.truckLicense.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'ทะเบียนรถ ${result.truckLicense}',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
          if (recDate != null) ...[
            const SizedBox(height: 6),
            Text(
              'บันทึกเมื่อ ${DateFormat('d MMM y HH:mm', 'th').format(recDate)}',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  final String label;
  final String value;

  const _Highlight({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// รายการคำนวณเรียงตามลำดับที่ตกลงกับฝั่งบัญชี
/// บรรทัดสุดท้ายคืออัตราชดเชยที่ผู้ใช้ต้องเห็นชัดที่สุด
class _CalculationCard extends StatelessWidget {
  final MeterResult result;

  const _CalculationCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ที่มาของการคำนวณ',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          _CalcRow(
            label: 'อัตราสิ้นเปลืองมาตรฐาน',
            value: result.fuelConsumptionRate,
            unit: 'กม./ลิตร',
          ),
          _CalcRow(
            label: 'ราคาน้ำมันมาตรฐาน',
            value: result.standardFuelPrice,
            unit: 'บาท/ลิตร',
          ),
          _CalcRow(
            label: 'ราคาน้ำมันวันนี้',
            value: result.currentFuelPrice,
            unit: 'บาท/ลิตร',
          ),
          _CalcRow(
            label: 'ส่วนต่างราคาน้ำมัน',
            value: result.fuelPriceDifference,
            unit: 'บาท/ลิตร',
            // ส่วนต่างราคาเป็นตัวตั้งของเงินชดเชย เน้นให้เห็น
            emphasize: true,
          ),
          _CalcRow(
            label: 'ระยะทางส่วนต่าง',
            value: result.distanceDifference,
            unit: 'กม.',
            emphasize: true,
          ),
          _CalcRow(
            label: 'ปริมาณน้ำมันที่ชดเชย',
            value: result.fuelCompensation,
            unit: 'ลิตร',
            emphasize: true,
          ),
          const Divider(height: 24),
          _TotalRow(value: result.compensationRate),
        ],
      ),
    );
  }
}

class _CalcRow extends StatelessWidget {
  final String label;
  final double value;
  final String unit;

  /// ค่าที่เป็นตัวตั้งของเงินชดเชย ตัวเลขเข้มกว่าบรรทัดอ้างอิงทั่วไป
  final bool emphasize;

  const _CalcRow({
    required this.label,
    required this.value,
    required this.unit,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: emphasize ? null : scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatDecimal(value),
            style: TextStyle(
              fontSize: emphasize ? 17 : 15,
              fontWeight: emphasize ? FontWeight.bold : FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 66,
            child: Text(
              unit,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final double value;

  const _TotalRow({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.moneyBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.moneyBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Expanded(
            child: Text(
              'ราคาอัตราชดเชยน้ำมัน',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.moneyText,
              ),
            ),
          ),
          Text(
            formatDecimal(value),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.moneyText,
            ),
          ),
          const SizedBox(width: 6),
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'บาท',
              style: TextStyle(fontSize: 13, color: AppColors.moneyText),
            ),
          ),
        ],
      ),
    );
  }
}

/// รูปไมล์ใช้ URL จากเซิร์ฟเวอร์เสมอ
/// เคสเย็นไฟล์รูปไมล์ต้นไม่ได้อยู่ในเครื่องแล้ว
class _MeterImagesCard extends StatelessWidget {
  final MeterResult result;

  const _MeterImagesCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'รูปหน้าปัดไมล์',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Thumb(
                  title: 'ไมล์ต้นวัน',
                  meter: result.startMeter,
                  url: result.startMeterUrl,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Thumb(
                  title: 'ไมล์ปลายวัน',
                  meter: result.endMeter,
                  url: result.endMeterUrl,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String title;
  final int meter;
  final String? url;

  const _Thumb({required this.title, required this.meter, required this.url});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final link = url;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 4),
        Text(
          '${formatThousands(meter)} กม.',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: link == null
              ? null
              : () => showFullScreenImage(context, source: link, title: title),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 120,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant),
              color: scheme.surfaceContainerHighest,
            ),
            child: link == null
                ? Center(
                    child: Text(
                      'ไม่มีรูป',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : Image.network(
                    link,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, _, __) => const Center(
                      child: Text(
                        'โหลดรูปไม่ได้',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
