import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../page/claim/image_utils.dart';
import 'package:claim/utils/app_colors.dart';

class _ProcessImagesParams {
  final List<File> images;
  final int maxSize;

  _ProcessImagesParams(this.images, this.maxSize);
}

Future<List<File>> _processImagesInBackground(
  _ProcessImagesParams params,
) async {
  return processImagesBatch(params.images, maxSize: params.maxSize);
}

class ClaimFormResult {
  final String docNumber;
  final String type;
  final String carCode;
  final DateTime timestamp;
  final List<File> images;
  final String empId;
  final String? remarkType;
  final bool fromFrontStore;
  final bool isDraft;

  ClaimFormResult({
    required this.docNumber,
    required this.type,
    required this.carCode,
    required this.timestamp,
    required this.images,
    required this.empId,
    this.remarkType,
    this.fromFrontStore = false,
    this.isDraft = false,
  });
}

/// รูปตัวอย่างในฟอร์ม แสดงจากไฟล์รูปโดยตรง
///
/// เดิมสร้างไฟล์ thumbnail ขนาด 720 แยกอีกไฟล์ก่อนแสดง ซึ่งต้องถอดรหัสรูป
/// ซ้ำอีกรอบ (มีตัวหมุนค้างบนช่องรูป) ทั้งที่รูปถูกย่อเหลือ 720 ไว้แล้วตอนเพิ่ม
/// และช่องแสดงกว้างแค่ราว 120 จุด ตอนนี้ให้ Flutter ถอดรหัสเป็นขนาดเท่าช่อง
/// ([Image.cacheWidth]) ตอนวาดเลย ไม่ต้องเขียนไฟล์ใหม่ ไม่ต้องรอ
class FastImagePreview extends StatelessWidget {
  final File imageFile;
  final double width;
  final double height;
  final BoxFit fit;

  const FastImagePreview({
    super.key,
    required this.imageFile,
    this.width = 120,
    this.height = 120,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.innerRadius),
      child: Image.file(
        imageFile,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: (width * dpr).round(),
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => Container(
          width: width,
          height: height,
          color: scheme.surfaceContainerHighest,
          child: Icon(Icons.broken_image, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class ImageListWidget extends StatefulWidget {
  final List<File> images;
  final Function(int) onDeleteImage;

  const ImageListWidget({
    Key? key,
    required this.images,
    required this.onDeleteImage,
  }) : super(key: key);

  @override
  State<ImageListWidget> createState() => _ImageListWidgetState();
}

class _ImageListWidgetState extends State<ImageListWidget> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: List.generate(
          widget.images.length,
          (index) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                children: [
                  FastImagePreview(
                    imageFile: widget.images[index],
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        debugPrint('Deleting image at index: $index');
                        widget.onDeleteImage(index);
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
