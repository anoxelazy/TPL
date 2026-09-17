import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:claim/page/itcase/itcase_api.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/widgets/app_card.dart';

/// สีประจำขั้นของเคส ใช้กับป้ายสถานะ แถบความคืบหน้า และหัวหน้ารายละเอียด
///
/// ใช้ชุดเดียวกับหน้าแจ้งซ่อม (เทา = ยังไม่มีใครรับ, เหลือง = กำลังทำ,
/// เขียว = จบ) คนใช้แอปจะได้ไม่ต้องจำสองชุด เพิ่มมาขั้นเดียวคือ "รอตรวจรับ"
/// ที่ใช้น้ำเงิน เพราะเป็นขั้นที่ลูกบอลอยู่ฝั่งผู้แจ้ง ไม่ใช่ฝั่ง IT
Color itCaseStageColor(ItCaseStage stage, ColorScheme scheme) {
  switch (stage) {
    case ItCaseStage.waiting:
      return scheme.onSurfaceVariant;
    case ItCaseStage.working:
      return AppColors.pending;
    case ItCaseStage.review:
      return AppColors.stageOrigin;
    case ItCaseStage.done:
      return AppColors.success;
  }
}

/// การ์ดเคสหนึ่งใบในหน้ารายการเคสที่เคยแจ้ง
///
/// โชว์แค่ห้าอย่าง: เลขเคส สถานะฝั่งผู้แจ้งพร้อม % ความคืบหน้า รายละเอียด
/// ผู้รับงาน และเวลาที่แจ้ง ประเภทปัญหากับโปรแกรมไปดูในหน้ารายละเอียดเอา
/// การ์ดในรายการมีไว้ให้กวาดตาหาเคสที่ต้องการ ไม่ใช่อ่านทุกอย่างตรงนี้
class ItCaseJobCard extends StatelessWidget {
  final ItCaseJob job;

  /// รายการสถานะ ใช้แปลรหัสเป็นข้อความฝั่งผู้แจ้ง
  ///
  /// โหลดไม่สำเร็จก็ส่งรายการเปล่ามาได้ การ์ดจะโชว์รหัสดิบแทน ยังอ่านออก
  final List<ItCaseStatus> statuses;

  /// กดแล้วไปหน้ารายละเอียด ปล่อยว่างได้เมื่อเอาการ์ดไปโชว์เฉย ๆ
  final VoidCallback? onTap;

  const ItCaseJobCard({
    super.key,
    required this.job,
    required this.statuses,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = itCaseStageColor(job.stage, scheme);
    final created = job.createdAt;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  job.id.isEmpty ? 'ไม่มีเลขเคส' : job.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.caseIcon,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(text: job.statusTextFrom(statuses), color: color),
            ],
          ),

          _Progress(percent: job.progress, color: color),

          if (job.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              job.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: scheme.onSurface,
              ),
            ),
          ],

          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (job.officer.isNotEmpty)
                _meta(scheme, Icons.engineering_outlined, job.officer),
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

/// แถบความคืบหน้าพร้อมตัวเลข % ใช้ทั้งบนการ์ดและหน้ารายละเอียด
///
/// [percent] เป็น 0 แปลว่าไม่รู้ว่าเคสเดินไปถึงไหน (รหัสสถานะที่ยังไม่รู้จัก)
/// ซ่อนแถบไปเลยดีกว่าโชว์แถบเปล่า ๆ ที่อ่านได้ว่ายังไม่เริ่มทำอะไร
///
/// แถบไหลไปหาค่าใหม่แทนที่จะกระโดด เพราะหน้ารายละเอียดดึงข้อมูลใหม่เงียบ ๆ
/// เป็นระยะ ถ้าเลขเปลี่ยนแบบไม่มีการเคลื่อนไหว คนที่ไม่ได้จ้องจอจะไม่ทันเห็น
/// ว่าเคสเดินหน้าไปแล้ว
class ItCaseProgressBar extends StatelessWidget {
  final int percent;
  final Color color;

  const ItCaseProgressBar({
    super.key,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (percent <= 0) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final value = percent / 100;

    // begin เท่ากับ end มีผลแค่ครั้งแรกที่วาด คือขึ้นค่าจริงทันทีไม่ต้องรอไต่
    // จาก 0 ส่วนรอบถัดไป TweenAnimationBuilder ไหลจากค่าที่ค้างอยู่ไปหาค่าใหม่
    // ให้เอง จึงเห็นการเคลื่อนไหวเฉพาะตอนเคสเดินหน้าจริง ซึ่งเป็นตอนที่อยากให้
    // สังเกตเห็นพอดี
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: value, end: value),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, shown, _) => Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: shown,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // เลขวิ่งตามแถบ ไม่ใช่กระโดดไปค่าใหม่ตั้งแต่เฟรมแรก
          Text(
            '${(shown * 100).round()}%',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  final int percent;
  final Color color;

  const _Progress({required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    if (percent <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ItCaseProgressBar(percent: percent, color: color),
    );
  }
}

/// ป้ายสถานะมุมขวาบนของการ์ด
///
/// ข้อความสถานะของระบบนี้ยาว (เช่น "แก้ไขเสร็จสิ้น กรุณาตรวจสอบความเรียบร้อย")
/// จึงจำกัดความกว้างไว้ครึ่งจอ แล้วให้ตัดบรรทัดเอง ไม่ใช่ดันเลขเคสจนหาย
class _StatusChip extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.45,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Text(
          text.isEmpty ? '-' : text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.25,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// ข้อความของช่องที่ยังไม่รู้จัก จัดวันที่ให้อ่านง่ายถ้าค่าเป็นวันที่
///
/// backend ส่งวันที่มาเป็น `2026-09-15T10:30:00` ซึ่งยาวและอ่านยากกว่าที่
/// ทั้งแอปใช้อยู่ ช่องที่ไม่ใช่วันที่ก็คืนค่าเดิมไป
String itCaseFieldText(ItCaseField field) {
  final at = itCaseDateOf(field.value);
  if (at == null) return field.value;

  // มีแต่วันที่ ไม่มีเวลา ก็ไม่ต้องโชว์ 00:00 ให้งง
  final format = at.hour == 0 && at.minute == 0
      ? DateFormat('d MMM y', 'th')
      : DateFormat('d MMM y HH:mm', 'th');

  return format.format(at);
}
