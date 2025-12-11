import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../page/claim/image_utils.dart';

class _ProcessImagesParams {
  final List<File> images;
  final int maxSize;

  _ProcessImagesParams(this.images, this.maxSize);
}

Future<List<File>> _processImagesInBackground(_ProcessImagesParams params) async {
  return processImagesBatch(params.images, maxSize: params.maxSize);
}

class _ThumbnailParams {
  final File imageFile;
  final int size;

  _ThumbnailParams(this.imageFile, this.size);
}

Future<File> _generateThumbnailInBackground(_ThumbnailParams params) async {
  return generateThumbnail(params.imageFile, size: params.size);
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

  ClaimFormResult({
    required this.docNumber,
    required this.type,
    required this.carCode,
    required this.timestamp,
    required this.images,
    required this.empId,
    this.remarkType,
    this.fromFrontStore = false,
  });
}

class FastImagePreview extends StatefulWidget {
  final File imageFile;
  final double width;
  final double height;
  final BoxFit fit;

  const FastImagePreview({
    Key? key,
    required this.imageFile,
    this.width = 120,
    this.height = 120,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  State<FastImagePreview> createState() => _FastImagePreviewState();
}

class _FastImagePreviewState extends State<FastImagePreview> {
  File? _thumbnailFile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    try {
      final thumbnail = await compute(
        _generateThumbnailInBackground,
        _ThumbnailParams(widget.imageFile, 720),
      );
      if (mounted) {
        setState(() {
          _thumbnailFile = thumbnail;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Thumbnail generation error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey[200],
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        _thumbnailFile ?? widget.imageFile,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, color: Colors.grey),
          );
        },
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
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
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