/// ไทม์ไลน์สถานะแนวตั้งของหน้าเช็คสถานะพัสดุ
///
/// แยกออกจาก tracking_screen.dart เพื่อให้เทสต์วิดเจ็ตได้ตรง ๆ
/// โดยไม่ต้องผ่านการยิง API และกันไม่ให้ไฟล์หน้าจอบวมเกินอ่านไหว
library;

import 'package:flutter/material.dart';

import 'package:claim/page/tracking/models.dart';
import 'package:claim/page/tracking/tracking_style.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/widgets/remote_image.dart';

/// ไทม์ไลน์แนวตั้ง ใหม่สุดอยู่บน เรียงตามที่เก็บใน [TrackingResult]
///
/// เดิมเป็นแถบแนวนอนที่ต้องแตะทีละช่องถึงจะเห็นรายละเอียด ผู้ใช้หน้างาน
/// ไม่รู้ว่าต้องแตะ และต้องเลื่อนซ้ายขวาไล่หา จึงเปลี่ยนเป็นแนวตั้งที่
/// กางรายละเอียดของทุกสถานะไว้เลย อ่านจากบนลงล่างได้ทีเดียวจบ
class TrackingTimeline extends StatelessWidget {
  final List<TrackingEvent> events;

  const TrackingTimeline({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < events.length; i++)
          _TimelineEntry(
            event: events[i],
            isLatest: i == 0,
            isLast: i == events.length - 1,
          ),
      ],
    );
  }
}

/// สถานะ 1 แถว: จุดกับเส้นทางซ้าย รายละเอียดทางขวา
class _TimelineEntry extends StatelessWidget {
  final TrackingEvent event;
  final bool isLatest;
  final bool isLast;

  /// ความกว้างของช่องจุดทางซ้าย เส้นลากผ่านกึ่งกลางช่องนี้
  static const double _rail = 18;
  static const double _dot = 10;

  const _TimelineEntry({
    required this.event,
    required this.isLatest,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // สถานะเก่าใช้สีจาง ให้สายตาไปจบที่สถานะล่าสุดก่อน
    final color = isLatest
        ? trackingStatusColor(event.statusId, scheme)
        : scheme.outline;
    final date = formatTrackingDate(event.statusDate);
    final images = event.allImages;

    // เส้นเป็นขอบซ้ายของกล่อง ไม่ต้องวัดความสูงเนื้อหาเอง
    // แถวสุดท้ายไม่มีเส้น จะได้ไม่ยื่นเลยจุดล่างสุด
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(left: _rail / 2),
          padding: const EdgeInsets.only(left: _rail / 2 + 6, bottom: 12),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(
                    left: BorderSide(color: scheme.outlineVariant, width: 2),
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                // ชื่อสถานะจาก API ห้าม hardcode
                event.statusName,
                style: TextStyle(
                  fontSize: isLatest ? 14 : 13,
                  height: 1.3,
                  fontWeight: isLatest ? FontWeight.w700 : FontWeight.w600,
                  color: isLatest ? color : scheme.onSurface,
                ),
              ),
              if (date != null) ...[
                const SizedBox(height: 2),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              _Details(event: event),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 4),
                _Thumbnails(images: images, title: event.statusName),
              ],
            ],
          ),
        ),
        Positioned(
          left: (_rail - _dot) / 2 - (isLatest ? 2 : 0),
          top: isLatest ? 2 : 4,
          child: Container(
            width: _dot + (isLatest ? 4 : 0),
            height: _dot + (isLatest ? 4 : 0),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              // วงจาง ๆ รอบจุดล่าสุด ให้รู้ทันทีว่าพัสดุอยู่ขั้นไหน
              border: isLatest
                  ? Border.all(color: color.withValues(alpha: 0.3), width: 2)
                  : Border.all(color: scheme.surface, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// รายละเอียดของสถานะ แต่ละบรรทัดซ่อนเองเมื่อไม่มีค่า
///
/// ใช้บรรทัดขนาดเล็กของตัวเอง ไม่ใช้ InfoRow กลาง เพราะไทม์ไลน์มีหลายสถานะ
/// ต่อกัน ถ้าตัวหนังสือเท่าการ์ดทั่วไปรายการจะยาวจนต้องเลื่อนไกล
class _Details extends StatelessWidget {
  final TrackingEvent event;

  const _Details({required this.event});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailLine(icon: Icons.location_on_outlined, value: event.location),
        _DetailLine(
          icon: Icons.person_outline,
          // ชื่อคนขับกับเบอร์ เป็นข้อความอย่างเดียว กดโทรไม่ได้
          value: event.driver == null || event.tel == null
              ? event.driver
              : '${event.driver!} (${event.tel!})',
        ),
        _DetailLine(
          icon: Icons.error_outline,
          value: event.reasonTh,
          color: AppColors.pending,
        ),
        _DetailLine(icon: Icons.sticky_note_2_outlined, value: event.remark),
        _DetailLine(icon: Icons.my_location, value: event.coordinates),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String? value;

  /// ใส่มาเมื่อบรรทัดนี้ต้องเด่นกว่าปกติ เช่น เหตุผลที่ส่งไม่สำเร็จ
  final Color? color;

  const _DetailLine({required this.icon, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final text = value;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 13, color: color ?? muted),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, height: 1.3, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// รูปหลักฐานและลายเซ็นเรียงแถว แตะแล้วเปิดเต็มจอและปัดดูรูปอื่นต่อได้
class _Thumbnails extends StatelessWidget {
  final List<String> images;
  final String title;

  const _Thumbnails({required this.images, required this.title});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < images.length; i++)
          InkWell(
            // เปิดที่รูปที่แตะ แล้วปัดดูรูปอื่นของสถานะเดียวกันต่อได้
            // ไม่ต้องปิดออกมาแตะรูปถัดไปทีละใบ
            onTap: () => showFullScreenGallery(
              context,
              sources: images,
              initialIndex: i,
              title: title,
            ),
            borderRadius: BorderRadius.circular(AppSizes.innerRadius),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.innerRadius),
              child: SizedBox(
                width: 52,
                height: 52,
                child: RemoteImage(source: images[i]),
              ),
            ),
          ),
      ],
    );
  }
}
