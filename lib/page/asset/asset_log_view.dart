/// ไทม์ไลน์ประวัติการเปลี่ยนแปลงของทรัพย์สิน
///
/// แยกออกมาจากหน้ารายละเอียดเพราะเป็นส่วนที่มีตรรกะการแสดงผลเยอะที่สุดของหน้า
/// (ยุบแถว แปลชื่อช่อง แปลค่ารหัส) และอยากทดสอบได้โดยไม่ต้องต่อเน็ต
///
/// สิ่งที่ `/log` ส่งมาคือชื่อคอลัมน์กับค่าดิบล้วน ๆ เช่น
/// `status_id: IN_TRANSIT → IN_USE` เอาไปโชว์ตรง ๆ คนอ่านไม่รู้เรื่อง วิดเจ็ตนี้
/// แปลงทั้งชื่อช่องและค่าให้เป็นภาษาคนก่อนเสมอ
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:claim/page/asset/asset_api.dart';
import 'package:claim/page/asset/asset_models.dart';
import 'package:claim/utils/app_colors.dart';

class AssetLogTimeline extends StatelessWidget {
  /// ใหม่สุดอยู่บนสุด (ผู้เรียกเรียงมาก่อนด้วย [sortAssetLog])
  final List<AssetLogEvent> events;

  /// ตารางแปลรหัสสถานะเป็นชื่อ ว่างได้ — จะโชว์รหัสดิบแทน
  final Map<String, String> statusNames;

  const AssetLogTimeline({
    super.key,
    required this.events,
    this.statusNames = const {},
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'ยังไม่มีประวัติ ของชิ้นนี้ยังไม่เคยถูกแก้หรือโอนย้าย',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < events.length; i++)
          _event(context, events[i], isLast: i == events.length - 1),
      ],
    );
  }

  /// หนึ่งเหตุการณ์
  ///
  /// ซ้ายเป็นรางเวลา (จุด + เส้นต่อลงไปหาเหตุการณ์ถัดไป) ขวาเป็นเนื้อหา
  /// เหตุการณ์สุดท้ายไม่ลากเส้นต่อ ไม่งั้นจะเหมือนยังมีของต่อข้างล่างอีก
  Widget _event(
    BuildContext context,
    AssetLogEvent event, {
    required bool isLast,
  }) {
    final scheme = Theme.of(context).colorScheme;

    // โอนย้ายเป็นเหตุการณ์ที่คนตามหาบ่อยสุดเวลาเปิดประวัติ (ของหายไปไหน)
    // ให้สีแบรนด์ของเมนูทรัพย์สิน ส่วนการแก้ข้อมูลทั่วไปเป็นสีเทากลาง
    final tint = event.isTransfer ? AppColors.assetIcon : scheme.outline;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rail(context, tint, isLast: isLast),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context, event, tint),
                  if (event.note.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      event.note,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ],
                  if (event.visibleChanges.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _changeTable(context, event.visibleChanges),
                  ],
                  if (_meta(event).isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _meta(event),
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rail(BuildContext context, Color tint, {required bool isLast}) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 10,
      child: Column(
        children: [
          const SizedBox(height: 4),
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          ),
          if (!isLast)
            Expanded(
              child: Container(width: 1.5, color: scheme.outlineVariant),
            ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, AssetLogEvent event, Color tint) {
    final scheme = Theme.of(context).colorScheme;

    // สองช่องนี้ยืดหดได้ทั้งคู่ ไม่ใช้ Spacer คั่น เพราะบนจอแคบชื่อเหตุการณ์กับ
    // วันเวลารวมกันยาวเกินบรรทัดได้ แล้ว Spacer จะดันจนล้นขอบ
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            event.actionLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: tint,
            ),
          ),
        ),
        if (event.at != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              assetDateTimeLabel(event.at!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ],
    );
  }

  /// ตารางช่องที่เปลี่ยน — ชื่อช่องทางซ้าย ค่าเก่า→ค่าใหม่ทางขวา
  ///
  /// จัดเป็นคอลัมน์ให้ชื่อช่องตรงกันทุกบรรทัด เพราะการแก้ครั้งเดียวมักกระทบ
  /// หลายช่อง กวาดตาหาช่องที่สนใจได้เร็วกว่าอ่านเป็นประโยคเรียงกัน
  Widget _changeTable(BuildContext context, List<AssetLogEntry> changes) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppSizes.innerRadius),
      ),
      child: Column(
        children: [
          for (final change in changes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      change.fieldLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(child: _values(context, change)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// ค่าเก่า → ค่าใหม่
  ///
  /// ใช้ Wrap ไม่ใช่ Row เพราะชื่อสาขาเต็ม ๆ สองอันวางเรียงกันยาวเกินจอมือถือ
  Widget _values(BuildContext context, AssetLogEntry change) {
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 2,
      children: [
        Text(
          logValueLabel(change.field, change.oldValue),
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        Icon(Icons.arrow_forward, size: 12, color: scheme.outline),
        Text(
          logValueLabel(change.field, change.newValue),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  String _meta(AssetLogEvent event) {
    final name = assetEmployeeNameOf(event.by);
    final by = event.by.isEmpty
        ? ''
        : (name.isEmpty ? event.by : '$name (${event.by})');

    return [
      if (by.isNotEmpty) 'โดย $by',
      if (event.refNo.isNotEmpty) 'เอกสาร ${event.refNo}',
    ].join(' · ');
  }

  /// ค่าดิบในประวัติแปลงเป็นสิ่งที่คนอ่านออก
  ///
  /// ค่าว่าง (`null` ในฐานข้อมูล) แปลว่า "ยังไม่เคยกรอก" ไม่ใช่สตริงว่าง
  /// โชว์เป็นขีดจะได้ไม่เห็นลูกศรชี้ไปที่ความว่างเปล่า
  ///
  /// รหัสสาขา/พนักงานอ่านจากแคชที่หน้าจอโหลดไว้ ยังไม่มีในแคชก็โชว์รหัสไปก่อน
  @visibleForTesting
  String logValueLabel(String field, String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '—';

    // ค่าขยะจากคนกดทดสอบผ่าน swagger ปนอยู่ในฐานข้อมูลจริง โชว์คำว่า "string"
    // ให้คนอ่านคือทำให้เขาคิดว่าระบบพัง ทั้งที่มันคือข้อมูลที่ไม่มีความหมาย
    if (assetLogValueIsPlaceholder(value)) return '—';

    switch (_normalizedField(field)) {
      case 'statusid':
        return statusNames[value] ?? value;
      case 'currentsiteid':
        final name = assetDeptNameOf(value);
        return name.isEmpty ? value : name;
      case 'currentcustodian':
        final name = assetEmployeeNameOf(value);
        return name.isEmpty ? value : name;
      case 'acceptdate':
      case 'purchasedate':
      case 'warrantyexpiredate':
        final date = assetDateOf(value);
        return date == null ? value : assetDateLabel(date);
      case 'purchaseprice':
        final price = assetPriceOf(value);
        return price == null ? value : '${_money.format(price)} บาท';
      default:
        return value;
    }
  }

  static final _money = NumberFormat('#,##0.##');

  String _normalizedField(String field) =>
      field.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
}
