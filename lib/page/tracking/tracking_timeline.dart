/// แถบไทม์ไลน์สถานะแนวนอนของหน้าเช็คสถานะพัสดุ
///
/// แยกออกจาก tracking_screen.dart เพื่อให้เทสต์วิดเจ็ตได้ตรง ๆ
/// โดยไม่ต้องผ่านการยิง API และกันไม่ให้ไฟล์หน้าจอบวมเกินอ่านไหว
library;

import 'package:flutter/material.dart';

import 'package:claim/page/tracking/models.dart';
import 'package:claim/page/tracking/tracking_style.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/widgets/app_card.dart';
import 'package:claim/widgets/info_row.dart';
import 'package:claim/widgets/remote_image.dart';

/// ไทม์ไลน์แนวนอน เลื่อนดูได้ เรียงเก่า → ใหม่ จากซ้ายไปขวา
///
/// สลับทิศจากที่เก็บใน [TrackingResult] (ใหม่ → เก่า) เพราะแนวนอนคนอ่านจาก
/// ซ้ายไปขวาเป็นทิศของความคืบหน้า ถ้าเอาใหม่ไว้ซ้ายจะเหมือนพัสดุเดินถอยหลัง
///
/// รายละเอียดของแต่ละสถานะ (คนขับ หมายเหตุ พิกัด รูป) ยัดลงคอลัมน์แคบ ๆ
/// ไม่ได้ จึงให้แตะเลือกสถานะแล้วแสดงรายละเอียดของอันที่เลือกไว้ใต้แถบ
class TrackingTimeline extends StatefulWidget {
  final List<TrackingEvent> events;

  const TrackingTimeline({super.key, required this.events});

  @override
  State<TrackingTimeline> createState() => _TrackingTimelineState();
}

class _TrackingTimelineState extends State<TrackingTimeline> {
  final ScrollController _scroll = ScrollController();

  /// ลำดับที่เลือก นับตามลำดับที่แสดง (เก่า → ใหม่)
  late int _selected;

  /// เก่า → ใหม่ ตามที่แสดงบนแถบ
  List<TrackingEvent> get _shown => widget.events.reversed.toList();

  @override
  void initState() {
    super.initState();
    // เริ่มที่สถานะล่าสุด คนเปิดดูอยากรู้ก่อนว่าตอนนี้พัสดุอยู่ไหน
    _selected = widget.events.length - 1;

    // แถบยาวเกินจอ ต้องเลื่อนไปสุดขวาให้เห็นสถานะล่าสุดทันทีที่เปิด
    // ไม่งั้นจะเห็นแต่ "คีย์เอกสาร" เมื่อหลายวันก่อนแล้วเข้าใจผิดว่าค้างอยู่
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    if (shown.isEmpty) return const SizedBox.shrink();

    final index = _selected.clamp(0, shown.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          // เลื่อนแถบแล้วลดคีย์บอร์ดให้ด้วย เหมือนการเลื่อนรายการผลลัพธ์
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < shown.length; i++)
                _TimelineStep(
                  event: shown[i],
                  isFirst: i == 0,
                  isLast: i == shown.length - 1,
                  selected: i == index,
                  onTap: () => setState(() => _selected = i),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.gap),
        _StepDetailCard(event: shown[index]),
      ],
    );
  }
}

/// สถานะ 1 ช่องบนแถบแนวนอน
class _TimelineStep extends StatelessWidget {
  final TrackingEvent event;
  final bool isFirst;
  final bool isLast;
  final bool selected;
  final VoidCallback onTap;

  /// กว้างพอให้ชื่อสถานะยาว ๆ ขึ้นได้ 3 บรรทัดโดยไม่ต้องย่อจนอ่านไม่รู้เรื่อง
  static const double _width = 116;

  const _TimelineStep({
    required this.event,
    required this.isFirst,
    required this.isLast,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = trackingStatusColor(event.statusId);
    final date = formatTrackingDate(event.statusDate);

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: _width,
        child: Column(
          children: [
            // เส้นครึ่งซ้ายกับครึ่งขวาของแต่ละช่องมาต่อกันเป็นเส้นเดียว
            // ช่องหัวกับท้ายเว้นด้านนอกไว้ เส้นจะได้ไม่ยื่นเลยจุดแรก/จุดสุดท้าย
            SizedBox(
              height: 22,
              child: Row(
                children: [
                  Expanded(
                    child: isFirst
                        ? const SizedBox.shrink()
                        : Container(height: 2, color: scheme.outlineVariant),
                  ),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      // วงจาง ๆ รอบจุดที่เลือกอยู่ ให้รู้ว่ารายละเอียดใต้แถบ
                      // เป็นของช่องไหน
                      border: selected
                          ? Border.all(
                              color: color.withValues(alpha: 0.3),
                              width: 4,
                            )
                          : null,
                    ),
                  ),
                  Expanded(
                    child: isLast
                        ? const SizedBox.shrink()
                        : Container(height: 2, color: scheme.outlineVariant),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Column(
                children: [
                  Text(
                    // ชื่อสถานะจาก API ห้าม hardcode
                    event.statusName,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? color : scheme.onSurface,
                    ),
                  ),
                  if (date != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      date,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  // ไอคอนเล็ก ๆ บอกว่าช่องนี้มีรูปให้ดู ไม่ต้องแตะไล่หาทุกช่อง
                  if (event.allImages.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Icon(
                      Icons.photo_library_outlined,
                      size: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// รายละเอียดของสถานะที่เลือกอยู่บนแถบ
class _StepDetailCard extends StatelessWidget {
  final TrackingEvent event;

  const _StepDetailCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = trackingStatusColor(event.statusId);
    final images = event.allImages;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(trackingStatusIcon(event.statusId), color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.statusName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InfoRow(
            icon: Icons.schedule,
            value: formatTrackingDate(event.statusDate),
          ),
          InfoRow(icon: Icons.location_on_outlined, value: event.location),
          if (event.driver != null)
            InfoRow(
              icon: Icons.person_outline,
              // ชื่อคนขับกับเบอร์ เป็นข้อความอย่างเดียว กดโทรไม่ได้
              value: event.tel == null
                  ? event.driver
                  : '${event.driver!} (${event.tel!})',
            ),
          if (event.reasonTh != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: AppColors.pending,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      event.reasonTh!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.pending,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          InfoRow(icon: Icons.sticky_note_2_outlined, value: event.remark),
          InfoRow(icon: Icons.my_location, value: event.coordinates),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 6),
            _Thumbnails(images: images, title: event.statusName),
          ],
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
            borderRadius: BorderRadius.circular(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 76,
                height: 76,
                child: RemoteImage(source: images[i]),
              ),
            ),
          ),
      ],
    );
  }
}
