import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:claim/utils/app_colors.dart';
import 'package:claim/widgets/remote_image.dart';
import 'package:claim/page/scan/scan_api.dart';
import 'package:claim/utils/app_icons.dart';

/// การ์ดแสดงผลการตรวจบาร์โค้ด
///
/// ซ่อนตัวเองเมื่อยังไม่เคยเช็ค หรือเช็คแล้วเจอแต่ไม่มีรูป
/// (ไม่มีอะไรให้ผู้ใช้ดู แสดงการ์ดเปล่าจะกินที่บนจอเปล่า ๆ)
class ScanCheckCard extends StatelessWidget {
  final bool checking;
  final ScanCheckResult? result;

  const ScanCheckCard({
    super.key,
    required this.checking,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    if (checking) return const _CheckingCard();

    final data = result;
    if (data == null) return const SizedBox.shrink();

    switch (data.status) {
      case ScanCheckStatus.found:
        // เคยถ่ายแล้วแต่ดึงรูปไม่ได้ ต้องบอกผู้ใช้ ไม่ใช่เงียบจนดูเหมือนแอปพัง
        if (!data.hasImages) {
          return _NoticeCard(
            color: AppColors.stageOrigin,
            icon: Icons.image_not_supported_outlined,
            text:
                data.message ??
                'บาร์โค้ดนี้เคยถ่ายรูปไว้แล้ว แต่ดึงรูปมาแสดงไม่ได้',
          );
        }
        return _FoundCard(result: data);
      case ScanCheckStatus.notFound:
        return _NoticeCard(
          color: AppColors.pending,
          icon: Icons.info_outline,
          // ใช้ข้อความจากเซิร์ฟเวอร์ ไม่ hard-code ทับ
          text: data.message ?? 'ไม่พบข้อมูลรูปของบาร์โค้ดนี้',
        );
      case ScanCheckStatus.error:
        return _NoticeCard(
          color: AppColors.danger,
          icon: Icons.error_outline,
          text: data.message ?? 'เซิร์ฟเวอร์มีปัญหา กรุณาติดต่อเจ้าหน้าที่',
        );
    }
  }
}

class _CheckingCard extends StatelessWidget {
  const _CheckingCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return _CardShell(
      color: scheme.outline,
      child: Row(
        children: const [
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text('กำลังตรวจสอบบาร์โค้ด...', style: TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _NoticeCard({
    required this.color,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      color: color,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _FoundCard extends StatelessWidget {
  final ScanCheckResult result;

  const _FoundCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      color: AppColors.stageOrigin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.image_outlined,
                size: 18,
                color: AppColors.stageOrigin,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.message ?? 'บาร์โค้ดนี้เคยถ่ายรูปไว้แล้ว',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: result.images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final source = result.images[index];
                return _Thumb(source: source, index: index);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String source;
  final int index;

  const _Thumb({required this.source, required this.index});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => showFullScreenImage(
        context,
        source: source,
        title: 'รูปที่ ${index + 1}',
      ),
      child: Container(
        width: 140,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
          color: scheme.surfaceContainerHighest,
        ),
        child: RemoteImage(source: source),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final Color color;
  final Widget child;

  const _CardShell({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        // ขอบต้องสีเดียวกันทุกด้าน ถ้าใส่ borderRadius คู่กับขอบหลายสี
        // Flutter จะ assert ตอน paint แล้วการ์ดทั้งใบไม่ถูกวาดเลย
        // (layout ยังผ่าน กดโดนอยู่ แต่มองไม่เห็น)
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Stack(
        children: [
          // แถบสีซ้ายวาดแยกแทนการทำเป็นขอบ อ่านสถานะออกจากหางตาได้เหมือนเดิม
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: ColoredBox(color: color),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// กรอบถ่ายรูปหลักฐาน มี 3 สถานะตามความพร้อมของฟอร์ม
class ScanPhotoBox extends StatelessWidget {
  /// ยังไม่มีบาร์โค้ด กดไม่ได้
  final bool hasBarcode;

  /// กำลังส่งรูป โชว์ preview + overlay
  final bool uploading;

  /// รูปที่กำลังส่ง
  final File? uploadingFile;

  final VoidCallback onTap;

  const ScanPhotoBox({
    super.key,
    required this.hasBarcode,
    required this.uploading,
    required this.uploadingFile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = hasBarcode && !uploading;

    final Color borderColor;
    if (uploading) {
      borderColor = AppColors.stageOrigin;
    } else if (hasBarcode) {
      borderColor = AppColors.success;
    } else {
      borderColor = scheme.outlineVariant;
    }

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 180,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: hasBarcode ? 1.5 : 1),
          color: hasBarcode
              ? AppColors.success.withValues(alpha: 0.06)
              : scheme.surfaceContainerHighest,
        ),
        child: uploading ? _sending() : _idle(context),
      ),
    );
  }

  Widget _sending() {
    final file = uploadingFile;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (file != null) Image.file(file, fit: BoxFit.cover),
        // overlay ดำโปร่งให้เห็นว่ารูปนี้กำลังส่ง ยังกดอะไรไม่ได้
        ColoredBox(
          color: Colors.black.withValues(alpha: 0.5),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 12),
                Text(
                  'กำลังส่ง...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _idle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (!hasBarcode) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _IconBubble(icon: AppIcons.scan, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'สแกนบาร์โค้ดก่อน',
              style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _IconBubble(
            icon: Icons.photo_camera_outlined,
            color: AppColors.success,
          ),
          SizedBox(height: 12),
          Text(
            'ถ่ายรูปบาร์สินค้า(เท่านั้น)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.success,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'ถ่ายรูปใหม่หรือเลือกรูปบาร์จากคลังรูป',
            style: TextStyle(fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

/// ไอคอนในวงกลมสีจาง ให้ไอคอนกลางกรอบไม่ลอยโดด
class _IconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBubble({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 30, color: color),
    );
  }
}

/// ให้ผู้ใช้เลือกกล้องหรือคลังรูป คืน null เมื่อยกเลิก
///
/// ต้องมีตัวเลือกคลังรูป เพราะหน้างานบางเคสถ่ายไว้ล่วงหน้าแล้ว
Future<File?> pickScanImage(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'รูปหลักฐาน',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('ถ่ายรูป'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('คลังรูปภาพ'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (source == null) return null;

  final picked = await ImagePicker().pickImage(
    source: source,
    imageQuality: 85,
  );
  if (picked == null) return null;

  return File(picked.path);
}
