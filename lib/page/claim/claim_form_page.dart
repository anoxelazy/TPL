import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/app_icons.dart';
import 'image_utils.dart';
import '../camera/custom_camera.dart';
import 'claim_form.dart';
import 'claim_dialogs.dart' as claim_dialogs;
import '../../widgets/image_widgets.dart';

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
                          color: AppColors.danger.withValues(alpha: 0.8),
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

class ClaimFormPage extends StatefulWidget {
  final Map<String, dynamic>? initialClaim;
  final String empId;
  final Future<String?> Function(BuildContext, TextEditingController)
  onScanBarcode;

  const ClaimFormPage({
    Key? key,
    this.initialClaim,
    required this.empId,
    required this.onScanBarcode,
    required empName,
  }) : super(key: key);

  @override
  State<ClaimFormPage> createState() => _ClaimFormPageState();
}

class _ClaimFormPageState extends State<ClaimFormPage> {
  final TextEditingController docNumberController = TextEditingController();
  final TextEditingController carCodeController = TextEditingController();
  final TextEditingController remarkController = TextEditingController();
  String selectedType = 'เสียหาย';
  DateTime selectedDate = DateTime.now();
  List<File> claimImages = [];
  bool fromFrontStore = false;
  final ImagePicker picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.initialClaim != null) {
      docNumberController.text = widget.initialClaim!['docNumber'] ?? '';
      selectedType = widget.initialClaim!['type'] ?? 'เสียหาย';
      carCodeController.text = widget.initialClaim!['carCode'] ?? '';
      selectedDate = widget.initialClaim!['timestamp'] ?? DateTime.now();
      claimImages = List<File>.from(widget.initialClaim!['images'] ?? []);
      remarkController.text = widget.initialClaim!['remarkType'] ?? '';
      fromFrontStore = widget.initialClaim!['fromFrontStore'] ?? false;
    }
    _initial = _snapshot();
  }

  /// ค่าทุกช่องตอนเปิดฟอร์ม ใช้เทียบว่ากรอก/แก้อะไรไปแล้วหรือยัง
  late final List<Object?> _initial;

  /// ค่าทุกช่องตอนนี้ วันที่เทียบแค่วัน ไม่สนเวลา รูปเทียบด้วย path
  List<Object?> _snapshot() => [
    docNumberController.text.trim(),
    carCodeController.text.trim(),
    remarkController.text.trim(),
    selectedType,
    DateUtils.dateOnly(selectedDate),
    claimImages.map((f) => f.path).join('|'),
    fromFrontStore,
  ];

  /// มีอะไรเปลี่ยนจากตอนเปิดฟอร์มไหม
  ///
  /// ฟอร์มใหม่ที่ยังไม่ได้แตะอะไรเลย (หรือแก้ไขรายการเดิมแต่ยังไม่ได้แก้)
  /// กดกลับแล้วออกได้เลย ไม่ต้องถาม ถามเฉพาะตอนมีของจะหาย
  @visibleForTesting
  bool get hasChanges => !listEquals(_snapshot(), _initial);

  /// กดกลับ (ปุ่มลูกศรบนแถบ หรือปุ่มย้อนกลับของเครื่อง)
  Future<void> _handleBack() async {
    if (!hasChanges) {
      Navigator.of(context).pop();
      return;
    }

    final discard = await claim_dialogs.showDiscardChangesDialog(
      context,
      editing: widget.initialClaim != null,
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  /// ปล่อยโฟกัสจากช่องกรอกก่อนเปิดกล้องหรือแกลเลอรี
  ///
  /// ถ้าช่องไหนยังโฟกัสค้าง พอกลับจากหน้ากล้อง/แกลเลอรี Flutter จะคืนโฟกัส
  /// ให้ช่องนั้น แป้นพิมพ์เลยเด้งขึ้นมาทับรูปที่เพิ่งเลือก ทั้งที่ไม่มีใครจะพิมพ์
  void _dropFocus() => FocusManager.instance.primaryFocus?.unfocus();

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _addImage(File file) async {
    try {
      debugPrint('Processing single image with maxSize: 720');

      final resized = await resizeImage(file, maxSize: 720, useCache: true)
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              debugPrint('Image processing timeout - using original file');
              return file;
            },
          );

      debugPrint('Image processed successfully');
      setState(() {
        claimImages.add(resized);
      });
    } catch (e) {
      debugPrint('Image processing error: $e');
      setState(() {
        claimImages.add(file);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Set<String> frontStoreEmployeeIds = {
      '2547',
      '67057',
      '67176',
      '67177',
      '67217',
      '68015',
      '68069',
      '68089',
      '68102',
      '68124',
      '68145',
      '68194',
      '80354',
      '80412',
      '80653',
      '80899',
      '81725',
      '81881',
      '81990',
      '82005',
    };

    final bool shouldShowFrontStoreOption = frontStoreEmployeeIds.contains(
      widget.empId,
    );

    // กันการกดกลับไว้ก่อนเสมอ แล้วตัดสินใน [_handleBack] ว่าออกเลยหรือถามก่อน
    // ปุ่มบันทึกปิดหน้าด้วย Navigator.pop ตรง ๆ ซึ่งไม่ผ่านตัวกันนี้ (didPop)
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.initialClaim == null ? 'สร้าง/แก้ไข' : 'แก้ไขรายการ',
          ),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
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
                      onPressed: _selectDate,
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
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(AppIcons.scan),
                      onPressed: () =>
                          widget.onScanBarcode(context, docNumberController),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: carCodeController,
                  decoration: InputDecoration(
                    label: Text(
                      'รหัสรถที่บรรทุกสินค้าเสียหาย',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(AppIcons.scan),
                      onPressed: () =>
                          widget.onScanBarcode(context, carCodeController),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: const [
                    DropdownMenuItem(value: 'เสียหาย', child: Text('เสียหาย')),
                    DropdownMenuItem(value: 'สูญหาย', child: Text('สูญหาย')),
                    DropdownMenuItem(
                      value: 'ไม่ครบล็อต',
                      child: Text('ไม่ครบล็อต'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => selectedType = value);
                  },
                  decoration: InputDecoration(
                    label: Text(
                      'ประเภทสินค้า',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (shouldShowFrontStoreOption) ...[
                  CheckboxListTile(
                    title: const Text('มาจากคลังหน้าบ้าน'),
                    value: fromFrontStore,
                    onChanged: (bool? value) {
                      setState(() {
                        fromFrontStore = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 12),
                ],
                if (selectedType == 'เสียหาย' ||
                    selectedType == 'สูญหาย' ||
                    selectedType == 'ไม่ครบล็อต') ...[
                  TextField(
                    controller: remarkController,
                    decoration: InputDecoration(
                      label: Text(
                        selectedType == 'เสียหาย'
                            ? 'ให้ถ่ายภาพหลังตู้แสดงว่าไม่มีสินค้าในตู้แล้ว(กรอกรายละเอียด)'
                            : selectedType == 'สูญหาย'
                            ? 'รายละเอียดการสูญหาย'
                            : 'รายละเอียดเพิ่มเติม (ใส่เลขกล่อง ที่หาย)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    maxLines: 3,
                  ),
                ],

                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    // ยิ่งรูปครบ สียิ่งไล่จากสีรอ (ยังไม่พอ) ไปสีสำเร็จ
                    color: claimImages.isEmpty
                        ? Theme.of(context).colorScheme.surface
                        : Color.lerp(
                            AppColors.pending.withValues(alpha: 0.12),
                            AppColors.success.withValues(alpha: 0.12),
                            claimImages.length / 6.0,
                          ),
                    borderRadius: BorderRadius.circular(AppSizes.innerRadius),
                    border: Border.all(
                      color: claimImages.isEmpty
                          ? Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.3)
                          : Color.lerp(
                              AppColors.pending.withValues(alpha: 0.4),
                              AppColors.success.withValues(alpha: 0.4),
                              claimImages.length / 6.0,
                            )!,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info,
                        color: claimImages.isEmpty
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Color.lerp(
                                AppColors.pending,
                                AppColors.success,
                                claimImages.length / 6.0,
                              ),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'สามารถอัปโหลดรูปภาพได้สูงสุด 6 รูป (${claimImages.length}/6)',
                        style: TextStyle(
                          color: claimImages.isEmpty
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              // ตัวหนังสือใช้สีสถานะเวอร์ชันเข้ม ส้ม/เขียวสด
                              // บนพื้นอ่อนอ่านยากที่ขนาด 14
                              : Color.lerp(
                                  AppColors.pendingText,
                                  AppColors.successText,
                                  claimImages.length / 6.0,
                                ),
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
                    key: ValueKey(claimImages.length),
                    images: claimImages,
                    onDeleteImage: (index) {
                      debugPrint(
                        'Deleting image at index: $index, current list length: ${claimImages.length}',
                      );
                      setState(() {
                        claimImages.removeAt(index);
                        debugPrint(
                          'After deletion, list length: ${claimImages.length}',
                        );
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
                              _dropFocus();
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
                                                Text(
                                                  'กำลังประมวลผล ${images.length} รูป',
                                                ),
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

                                      setState(() {
                                        claimImages.addAll(processedImages);
                                      });

                                      if (Navigator.canPop(context)) {
                                        Navigator.of(context).pop();
                                      }
                                    } catch (e) {
                                      if (Navigator.canPop(context)) {
                                        Navigator.of(context).pop();
                                      }
                                      debugPrint(
                                        'Camera image processing error: $e',
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'เกิดข้อผิดพลาดในการประมวลผลรูปภาพ',
                                            ),
                                            backgroundColor: AppColors.danger,
                                            duration: const Duration(
                                              seconds: 3,
                                            ),
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
                                      content: const Text(
                                        'เกิดข้อผิดพลาดในการเปิดกล้อง',
                                      ),
                                      backgroundColor: AppColors.danger,
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
                              _dropFocus();
                              try {
                                final List<XFile>?
                                images = await picker.pickMultiImage(
                                  // ให้ระบบย่อรูปตั้งแต่ตอนเลือก (ตัวถอดรหัสของเครื่อง เร็วกว่าย่อเองในแอปมาก)
                                  // ด้านยาวไม่เกิน 720 ตรงกับขนาดที่ส่งจริง ขั้นประมวลผลต่อจากนี้จึงข้ามไปได้
                                  maxWidth: 720,
                                  maxHeight: 720,
                                  imageQuality: 85,
                                );
                                if (images != null && images.isNotEmpty) {
                                  final int remainingSlots =
                                      6 - claimImages.length;
                                  final List<XFile> imagesToProcess = images
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
                                          backgroundColor: AppColors.pending,
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
                                              Text(
                                                'กำลังประมวลผล ${imagesToProcess.length} รูป',
                                              ),
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
                                    final processedImages =
                                        await compute(
                                          _processImagesInBackground,
                                          _ProcessImagesParams(fileList, 720),
                                        ).timeout(
                                          const Duration(
                                            seconds: 45,
                                          ), // Reduced timeout for mobile performance
                                          onTimeout: () {
                                            debugPrint(
                                              'Batch processing timeout - using original files',
                                            );
                                            // Return original files instead of throwing error
                                            return fileList;
                                          },
                                        );

                                    debugPrint(
                                      'Batch processing completed for ${processedImages.length} images',
                                    );

                                    setState(() {
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'เกิดข้อผิดพลาดในการประมวลผลรูปภาพ',
                                          ),
                                          backgroundColor: AppColors.danger,
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
                                      content: const Text(
                                        'เกิดข้อผิดพลาดในการเลือกภาพ',
                                      ),
                                      backgroundColor: AppColors.danger,
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
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // TextButton(
              //   onPressed: () => Navigator.pop(context),
              //   child: const Text('ยกเลิก'),
              // ),
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
                  Navigator.of(context).pop(
                    ClaimFormResult(
                      docNumber: docNumberController.text.trim(),
                      type: selectedType,
                      carCode: carCodeController.text.trim(),
                      timestamp: selectedDate,
                      images: List<File>.from(claimImages),
                      empId: widget.empId,
                      remarkType:
                          (selectedType == 'เสียหาย' ||
                              selectedType == 'สูญหาย' ||
                              selectedType == 'ไม่ครบล็อต')
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
      ),
    );
  }
}
