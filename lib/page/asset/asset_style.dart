/// หน้าตาร่วมของหน้าทรัพย์สินทั้งหมด
///
/// **สีเป็นของธีมรวม** แถบหัวเรื่องเขียวแบรนด์เหมือนทุกหน้าในแอป ไม่มีสีประจำ
/// โมดูลแยกแบบแจ้งซ่อม (เขียว LINE) หรือแจ้งเคส (ม่วง)
///
/// ที่โมดูลนี้ต่างจากหน้าอื่นคือ **โครงเนื้อหา** ไม่ใช่สี: ใช้ป้ายกำกับกลุ่มกับ
/// เส้นคั่นแทนการ์ดที่มีขอบรอบด้าน เพราะหน้าพวกนี้เป็นทะเบียนที่มีรหัส ชื่อ
/// สาขา ผู้ถือ สถานะ เรียงกันแน่น ๆ การ์ดกินความสูงต่อชิ้นเกือบเท่าตัวโดยไม่ได้
/// บอกอะไรเพิ่ม และสีในเนื้อหาเก็บไว้ใช้เฉพาะตอนที่มันมีความหมายจริง
/// (ประกันหมดแล้ว) ของที่เหลือจึงไม่ต้องแย่งสายตากัน
library;

import 'package:flutter/material.dart';

/// แถบหัวเรื่องของหน้าทรัพย์สิน
///
/// ใช้สีจากธีมรวม จึงไม่ต้องตั้ง systemOverlayStyle เองเหมือน [repairAppBar]
/// กับ [itCaseAppBar] ที่เปลี่ยนสีแถบไปจากธีม
PreferredSizeWidget assetAppBar(
  BuildContext context, {
  required String title,
  List<Widget>? actions,
}) => AppBar(title: Text(title), actions: actions);

/// หัวข้อกลุ่มของฟอร์มและหน้ารายละเอียด
///
/// ตัวเล็ก สีจาง เว้นช่องไฟ ให้ทำหน้าที่เป็นป้ายกำกับ ไม่ใช่แย่งความเด่นกับ
/// เนื้อหาข้างใต้ ไม่มีไอคอนนำหน้าเพราะไอคอนสีสันคือสิ่งที่ตั้งใจตัดออก
class AssetSectionTitle extends StatelessWidget {
  final String title;

  /// ข้อความช่วยอธิบายใต้หัวข้อ ใส่เมื่อกลุ่มนั้นมีกติกาที่ต้องบอก
  final String? note;

  const AssetSectionTitle(this.title, {super.key, this.note});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              note!,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// กลุ่มเนื้อหาหนึ่งชุด: ป้ายกำกับ + ของข้างใน + เส้นคั่นปิดท้าย
///
/// แทนการ์ดที่มีขอบรอบด้าน ได้หน้าที่เดิม (บอกว่าของกลุ่มไหนอยู่ด้วยกัน)
/// โดยไม่ต้องมีกล่องซ้อนกล่องเต็มหน้าจอ
///
/// ส่ง [expanded] มาจะกลายเป็นกลุ่มที่พับได้ ใช้กับกลุ่มที่ไม่มีช่องบังคับสัก
/// ช่อง หน้าจะได้ไม่ยาวเป็นพรืดตั้งแต่เปิดมา สถานะพับ/กางเก็บที่หน้าที่เรียก
/// เพราะหน้านั้นต้องสั่งกางเองได้เวลามีช่องที่กรอกผิดซ่อนอยู่ข้างใน
class AssetSection extends StatelessWidget {
  final String title;
  final String? note;
  final List<Widget> children;

  /// เส้นปิดท้ายกลุ่ม ปิดได้เมื่อเป็นกลุ่มสุดท้ายก่อนปุ่ม
  final bool divider;

  /// null = กลุ่มธรรมดากางค้างตลอด ไม่ null = กลุ่มที่พับได้และตอนนี้กางอยู่ไหม
  final bool? expanded;

  /// ข้อความสั้น ๆ ท้ายหัวข้อตอนพับอยู่ บอกว่าข้างในมีอะไรกรอกไว้แล้วบ้าง
  final String? summary;

  final VoidCallback? onToggle;

  const AssetSection({
    super.key,
    required this.title,
    required this.children,
    this.note,
    this.divider = true,
    this.expanded,
    this.summary,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final open = expanded ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (expanded == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: AssetSectionTitle(title, note: note),
          )
        else
          _header(context, open),
        // ตอนพับ ของข้างในยังอยู่ในต้นไม้ แค่ไม่ถูกวาด ถ้าถอดออกไปเลย ช่องกรอก
        // ที่ซ่อนอยู่จะหลุดจาก Form แล้ว validator ของมันจะไม่ถูกเรียกตอนบันทึก
        Offstage(
          offstage: !open,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final child in children)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: child,
                ),
            ],
          ),
        ),
        if (divider)
          Padding(
            padding: EdgeInsets.only(top: open ? 16 : 0),
            child: Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
      ],
    );
  }

  /// หัวข้อของกลุ่มที่พับได้ กดที่แถบทั้งแถบได้ ไม่ใช่กดได้แค่ลูกศร
  Widget _header(BuildContext context, bool open) {
    final scheme = Theme.of(context).colorScheme;
    final hint = summary ?? '';

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
        child: Row(
          children: [
            // คำอธิบายใต้หัวข้อเก็บไว้ให้เห็นตอนกางเท่านั้น ตอนพับมีบรรทัดสรุป
            // ทำหน้าที่แทนอยู่แล้ว
            Expanded(child: AssetSectionTitle(title, note: open ? note : null)),
            if (!open && hint.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  hint,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            Icon(
              open ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// บรรทัดข้อมูลในหน้ารายละเอียด: ป้ายซ้าย ค่าขวา
///
/// ไม่ใช้ไอคอนนำหน้าแบบ [InfoRow] ของหน้าอื่น เพราะไอคอนชุดหนึ่งต่อหนึ่งบรรทัด
/// ทำให้หน้าที่มีสิบกว่าบรรทัดดูรกกว่าการเขียนชื่อช่องไปตรง ๆ
///
/// ซ่อนตัวเองเมื่อไม่มีค่า หน้าที่เรียกจึงไม่ต้องเช็ค null เอง
class AssetInfoLine extends StatelessWidget {
  final String label;
  final String? value;

  /// สีของค่า ใส่เมื่อค่านั้นเป็นคำเตือน เช่นประกันหมดแล้ว
  final Color? valueColor;

  const AssetInfoLine({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final text = value;
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? scheme.onSurface,
                fontWeight: valueColor == null
                    ? FontWeight.w500
                    : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ป้ายสถานะแบบไม่มีสีพื้น
///
/// เป็นตัวหนังสือเล็กในกรอบบาง ๆ สีเทา ไม่ใช่แคปซูลสีทึบ เพราะในลิสต์หนึ่งหน้า
/// มีป้ายนี้ห้าสิบอัน ถ้าทุกอันมีสีพื้น หน้าจะกลายเป็นแถบสีเรียงกันทั้งหน้า
class AssetTag extends StatelessWidget {
  final String label;

  /// ใส่เมื่อป้ายนี้เป็นคำเตือนจริง ๆ ไม่ใส่จะเป็นสีเทากลาง
  final Color? color;

  const AssetTag(this.label, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tint.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: tint,
        ),
      ),
    );
  }
}
