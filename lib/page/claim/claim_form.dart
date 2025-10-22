import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'image_utils.dart';
import '../camera/custom_camera.dart';


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

Future<ClaimFormResult?> showClaimFormDialog(
  BuildContext context, {
  String initialDocNumber = '',
  String initialType = 'เสียหาย',
  String initialCarCode = '',
  DateTime? initialTimestamp,
  List<File>? initialImages,
  String? initialRemark,
  bool initialFromFrontStore = false,
  required String empId,
  required Future<String?> Function(BuildContext, TextEditingController)
  onScanBarcode,
}) async {
  const Set<String> frontStoreEmployeeIds = {
    '2547', '67057', '67176', '67177', '67217', '68015', '68069', '68089',
    '68102', '68124', '68145', '68194', '80354', '80412', '80653', '80899',
    '81725', '81881', '81990', '82005'
  };

  final bool shouldShowFrontStoreOption = frontStoreEmployeeIds.contains(empId);
  final TextEditingController docNumberController = TextEditingController(
    text: initialDocNumber,
  );
  final TextEditingController carCodeController = TextEditingController(
    text: initialCarCode,
  );
  final TextEditingController remarkController = TextEditingController(
    text: initialRemark ?? '',
  );
  String selectedType = initialType;
  DateTime selectedDate = initialTimestamp ?? DateTime.now();
  List<File> claimImages = List<File>.from(initialImages ?? []);
  bool fromFrontStore = initialFromFrontStore;
  final ImagePicker picker = ImagePicker();

  Future<void> _selectDate(StateSetter setStateDialog) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setStateDialog(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _addImage(
    File file,
    StateSetter setStateDialog,
    BuildContext dialogContext,
  ) async {
    try {
      debugPrint('Processing single image with maxSize: 720');

      final resized = await resizeImage(file, maxSize: 720, useCache: true).timeout(
        const Duration(seconds: 20), 
        onTimeout: () {
          debugPrint('Image processing timeout - using original file');
          // Return original file instead of throwing error for better UX
          return file;
        },
      );

      debugPrint('Image processed successfully');
      setStateDialog(() {
        claimImages.add(resized);
      });
    } catch (e) {
      debugPrint('Image processing error: $e');
      // For single image processing, be more lenient and just add the original file
      setStateDialog(() {
        claimImages.add(file);
      });
    }
  }

  final result = await showDialog<ClaimFormResult>(
    context: context,
    useRootNavigator: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 40,
            ),
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.85,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'สร้าง/แก้ไข',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'วันที่: ',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _selectDate(setStateDialog),
                                  icon: Icon(
                                    Icons.calendar_today,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  label: Text(
                                    DateFormat('dd/MM/yyyy').format(selectedDate),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: docNumberController,
                              decoration: InputDecoration(
                                label: Text(
                                  'เลขเอกสาร',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.qr_code_scanner_outlined,
                                  ),
                                  onPressed: () =>
                                      onScanBarcode(context, docNumberController),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: carCodeController,
                              decoration: InputDecoration(
                                label: Text(
                                  'รหัสรถที่บรรทุกสินค้าเสียหาย',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.qr_code_scanner_outlined,
                                  ),
                                  onPressed: () =>
                                      onScanBarcode(context, carCodeController),
                                ),
                              ),
                            ),
 
 
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: selectedType,
                              items: const [
                                DropdownMenuItem(
                                  value: 'เสียหาย',
                                  child: Text('เสียหาย'),
                                ),
                                DropdownMenuItem(
                                  value: 'สูญหาย',
                                  child: Text('สูญหาย'),
                                ),
                                DropdownMenuItem(
                                  value: 'ไม่ครบล็อต',
                                  child: Text('ไม่ครบล็อต'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null)
                                  setStateDialog(() => selectedType = value);
                              },
                              decoration: InputDecoration(
                                label: Text(
                                  'ประเภทสินค้า',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (shouldShowFrontStoreOption) ...[
                              CheckboxListTile(
                                title: const Text('มาจากคลังหน้าบ้าน'),
                                value: fromFrontStore,
                                onChanged: (bool? value) {
                                  setStateDialog(() {
                                    fromFrontStore = value ?? false;
                                  });
                                },
                                controlAffinity: ListTileControlAffinity.leading,
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (selectedType == 'เสียหาย' || selectedType == 'สูญหาย' || selectedType == 'ไม่ครบล็อต') ...[
                              TextField(
                                controller: remarkController,
                                decoration: InputDecoration(
                                  label: Text(
                                    selectedType == 'เสียหาย'
                                        ? 'ให้ถ่ายภาพหลังตู้แสดงว่าไม่มีสินค้าในตู้แล้ว(กรอกรายละเอียด)'
                                        : selectedType == 'สูญหาย'
                                            ? 'รายละเอียดการสูญหาย'
                                            : 'รายละเอียดเพิ่มเติม (ใส่เลขกล่อง ที่หาย)',
                                    style: Theme.of(context).textTheme.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                maxLines: 3,
                              ),
                            ],

                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: claimImages.isEmpty
                                  ? Theme.of(context).colorScheme.surface
                                  : Color.lerp(Colors.yellow[100], Colors.green[100], claimImages.length / 6.0),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: claimImages.isEmpty
                                    ? Theme.of(context).colorScheme.outline.withOpacity(0.3)
                                    : Color.lerp(Colors.yellow[300]!, Colors.green[300]!, claimImages.length / 6.0)!,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.info,
                                    color: claimImages.isEmpty
                                      ? Theme.of(context).colorScheme.onSurfaceVariant
                                      : Color.lerp(Colors.orange[600], Colors.green[700], claimImages.length / 6.0),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'สามารถอัปโหลดรูปภาพได้สูงสุด 6 รูป (${claimImages.length}/6)',
                                    style: TextStyle(
                                      color: claimImages.isEmpty
                                        ? Theme.of(context).colorScheme.onSurfaceVariant
                                        : Color.lerp(Colors.orange[700], Colors.green[700], claimImages.length / 6.0),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),
                            if (claimImages.isNotEmpty) ...[
                              const Divider(),
                              const SizedBox(height: 12),
                              ImageListWidget(
                                key: ValueKey(claimImages.length), // Force rebuild when list changes
                                images: claimImages,
                                onDeleteImage: (index) {
                                  debugPrint('Deleting image at index: $index, current list length: ${claimImages.length}');
                                  setStateDialog(() {
                                    claimImages.removeAt(index);
                                    debugPrint('After deletion, list length: ${claimImages.length}');
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              const Divider(),
                            ],

                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: claimImages.length >= 6
                                      ? null
                                      : () async {
                                          try {
                                            final initialCount = claimImages.length;
                                            await openMultiImageCamera(
                                              context,
                                              (List<File> images) async {
                                                // Show loading dialog while processing images
                                                if (context.mounted) {
                                                  showDialog(
                                                    context: context,
                                                    barrierDismissible: false,
                                                    builder: (BuildContext context) {
                                                      return AlertDialog(
                                                        content: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const CircularProgressIndicator(),
                                                            const SizedBox(width: 16),
                                                            Text('กำลังประมวลผล ${images.length} รูป'),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  );
                                                }

                                                try {
                                                  // Process images in background isolate to prevent UI lag
                                                  final processedImages = await compute(
                                                    _processImagesInBackground,
                                                    _ProcessImagesParams(images, 720),
                                                  );

                                                  setStateDialog(() {
                                                    claimImages.addAll(processedImages);
                                                  });

                                                  if (Navigator.canPop(context)) {
                                                    Navigator.of(context).pop();
                                                  }
                                                } catch (e) {
                                                  if (Navigator.canPop(context)) {
                                                    Navigator.of(context).pop();
                                                  }
                                                  debugPrint('Camera image processing error: $e');
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('เกิดข้อผิดพลาดในการประมวลผลรูปภาพ'),
                                                        backgroundColor: Colors.red,
                                                        duration: const Duration(seconds: 3),
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
                                              maxImages: 6,
                                              currentImageCount: claimImages.length,
                                            );
                                          } catch (e) {
                                            debugPrint('Camera error: $e');
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: const Text('เกิดข้อผิดพลาดในการเปิดกล้อง'),
                                                  backgroundColor: Colors.red,
                                                  duration: const Duration(seconds: 2),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                  icon: const Icon(Icons.camera),
                                  label: const Text('ถ่ายรูป'),
                                ),
                                ElevatedButton.icon(
                                  onPressed: claimImages.length >= 6
                                      ? null
                                      : () async {
                                          try {
                                            final List<XFile>? images = await picker
                                                .pickMultiImage();
                                            if (images != null &&
                                                images.isNotEmpty) {
                                              final int remainingSlots =
                                                  6 - claimImages.length;
                                              final List<XFile> imagesToProcess =
                                                  images
                                                      .take(remainingSlots)
                                                      .toList();
                                              if (imagesToProcess.isEmpty) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'ไม่สามารถเพิ่มรูปภาพได้อีกแล้ว (จำกัด 6 รูป)',
                                                      ),
                                                      backgroundColor:
                                                          Colors.orange,
                                                    ),
                                                  );
                                                }
                                                return;
                                              }
                                              // Show loading dialog while processing images
                                              if (context.mounted) {
                                                showDialog(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  builder: (BuildContext context) {
                                                    return AlertDialog(
                                                      content: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const CircularProgressIndicator(),
                                                          const SizedBox(width: 16),
                                                          Text('กำลังประมวลผล ${imagesToProcess.length} รูป'),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                );
                                              }

                                              try {
                                                debugPrint(
                                                  'Batch processing ${imagesToProcess.length} images with maxSize: 720',
                                                );

                                                // Process images with timeout
                                                final fileList = imagesToProcess
                                                    .map((img) => File(img.path))
                                                    .toList();

                                                // Process images in background isolate to prevent UI lag
                                                final processedImages = await compute(
                                                  _processImagesInBackground,
                                                  _ProcessImagesParams(fileList, 720),
                                                ).timeout(
                                                  const Duration(seconds: 45), // Reduced timeout for mobile performance
                                                  onTimeout: () {
                                                    debugPrint('Batch processing timeout - using original files');
                                                    // Return original files instead of throwing error
                                                    return fileList;
                                                  },
                                                );

                                                debugPrint(
                                                  'Batch processing completed for ${processedImages.length} images',
                                                );

                                                setStateDialog(() {
                                                  claimImages.addAll(processedImages);
                                                });

                                                // Close loading dialog
                                                if (Navigator.canPop(context)) {
                                                  Navigator.of(context).pop();
                                                }
                                              } catch (e) {
                                                // Close loading dialog on error
                                                if (Navigator.canPop(context)) {
                                                  Navigator.of(context).pop();
                                                }

                                                debugPrint('Batch processing error: $e');
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('เกิดข้อผิดพลาดในการประมวลผลรูปภาพ'),
                                                      backgroundColor: Colors.red,
                                                      duration: const Duration(seconds: 3),
                                                    ),
                                                  );
                                                }
                                              }
                                            }
                                          } catch (e) {
                                            debugPrint('Gallery picker error: $e');
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: const Text('เกิดข้อผิดพลาดในการเลือกภาพ'),
                                                  backgroundColor: Colors.red,
                                                  duration: const Duration(seconds: 2),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                  icon: const Icon(Icons.photo_library),
                                  label: const Text('เลือกรูป'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('ยกเลิก'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              if (docNumberController.text.trim().isEmpty ||
                                  carCodeController.text.trim().isEmpty) {
                                await showDialog<void>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('กรอกข้อมูลไม่ครบ'),
                                    content: const Text(
                                      'กรุณากรอก เลขเอกสาร และ รหัสรถ ให้ครบก่อนทำรายการ',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('ตกลง'),
                                      ),
                                    ],
                                  ),
                                );
                                return;
                              }
                              if (remarkController.text.trim().isEmpty) {
                                await showDialog<void>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('กรุณากรอกรายละเอียด'),
                                    content: const Text(
                                      'กรุณากรอกรายละเอียดในช่อง remark ก่อนทำรายการ',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('ตกลง'),
                                      ),
                                    ],
                                  ),
                                );
                                return;
                              }
                              if (claimImages.isEmpty) {
                                await showDialog<void>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('กรุณาเพิ่มรูปภาพ'),
                                    content: const Text(
                                      'กรุณาเพิ่มรูปภาพอย่างน้อย 1-6 รูปเพื่อยืนยันการส่ง',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('ตกลง'),
                                      ),
                                    ],
                                  ),
                                );
                                return;
                              }
                              Navigator.of(context, rootNavigator: true).pop(
                                ClaimFormResult(
                                  docNumber: docNumberController.text.trim(),
                                  type: selectedType,
                                  carCode: carCodeController.text.trim(),
                                  timestamp: selectedDate,
                                  images: List<File>.from(claimImages),
                                  empId: empId,
                                  remarkType: (selectedType == 'เสียหาย' || selectedType == 'สูญหาย' || selectedType == 'ไม่ครบล็อต')
                                      ? remarkController.text.trim()
                                      : null,
                                  fromFrontStore: fromFrontStore,
                                ),
                              );
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  return result;
}
