import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'image_utils.dart';

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
      final thumbnail = await generateThumbnail(widget.imageFile, size: 720);
      if (mounted) {
        setState(() {
          _thumbnailFile = thumbnail;
          _isLoading = false;
        });
      }
    } catch (e) {
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

  ClaimFormResult({
    required this.docNumber,
    required this.type,
    required this.carCode,
    required this.timestamp,
    required this.images,
    required this.empId,
    this.remarkType,
  });
}

Future<ClaimFormResult?> showClaimFormDialog(
  BuildContext context, {
  String initialDocNumber = '',
  String initialType = 'เสียหาย',
  String initialCarCode = '',
  DateTime? initialTimestamp,
  List<File>? initialImages,
  String? initialRemark,
  required String empId,
  required Future<String?> Function(BuildContext, TextEditingController)
      onScanBarcode,
}) async {
  final TextEditingController docNumberController =
      TextEditingController(text: initialDocNumber);
  final TextEditingController carCodeController =
      TextEditingController(text: initialCarCode);
  final TextEditingController remarkController =
      TextEditingController(text: initialRemark ?? '');
  String selectedType = initialType;
  DateTime selectedDate = initialTimestamp ?? DateTime.now();
  List<File> claimImages = List<File>.from(initialImages ?? []);
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

  Future<void> _addImage(File file, StateSetter setStateDialog, BuildContext dialogContext) async {
    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('กำลังประมวลผลรูปภาพกรุณารอสักครู่'),
              ],
            ),
          ),
        );
      },
    );

    try {
      debugPrint('Processing image with maxSize: 720');
      final resized = await resizeImage(file, maxSize: 720, useCache: true);
      debugPrint('Image processed successfully, final size will be determined by aspect ratio');
      setStateDialog(() {
        claimImages.add(resized);
      });
    } catch (e) {
      if (dialogContext.mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการประมวลผลรูปภาพ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (Navigator.canPop(dialogContext)) {
        Navigator.of(dialogContext).pop();
      }
    }
  }

  final result = await showDialog<ClaimFormResult>(
    context: context,
    useRootNavigator: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'สร้าง/แก้ไข Claim',
                      style: Theme.of(context).textTheme.titleLarge,
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
                              const Text('วันที่: '),
                              TextButton.icon(
                                onPressed: () => _selectDate(setStateDialog),
                                icon: const Icon(Icons.calendar_today),
                                label: Text(
                                  DateFormat('dd/MM/yyyy').format(selectedDate),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
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
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.qr_code_scanner_outlined),
                                onPressed: () => onScanBarcode(context, docNumberController),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: selectedType,
                            items: const [
                              DropdownMenuItem(value: 'เสียหาย', child: Text('เสียหาย')),
                              DropdownMenuItem(value: 'สูญหาย', child: Text('สูญหาย')),
                              DropdownMenuItem(value: 'ไม่ครบล็อต', child: Text('ไม่ครบล็อต')),
                            ],
                            onChanged: (value) {
                              if (value != null) setStateDialog(() => selectedType = value);
                            },
                            decoration: InputDecoration(
                              label: Text(
                                'ประเภทสินค้า',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (selectedType == 'ไม่ครบล็อต') ...[
                            TextField(
                              controller: remarkController,
                              decoration: InputDecoration(
                                label: Text(
                                  'รายละเอียดเพิ่มเติม (จำนวนที่หาย ฯลฯ)',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextField(
                            controller: carCodeController,
                            decoration: InputDecoration(
                              label: Text(
                                'รหัสรถ (เช่น TP XXXX)',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.qr_code_scanner_outlined),
                                onPressed: () => onScanBarcode(context, carCodeController),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (claimImages.isNotEmpty) ...[
                            const Divider(),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 140,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: claimImages.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        FastImagePreview(
                                          imageFile: claimImages[index],
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                        ),
                                        Positioned(
                                          top: -10,
                                          right: -10,
                                          child: IconButton(
                                            icon: const Icon(Icons.cancel, color: Colors.red),
                                            onPressed: () {
                                              setStateDialog(() => claimImages.removeAt(index));
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final XFile? image = await picker.pickImage(source: ImageSource.camera);
                                  if (image != null) await _addImage(File(image.path), setStateDialog, context);
                                },
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('ถ่ายรูป'),
                              ),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final List<XFile>? images = await picker.pickMultiImage();
                                  if (images != null && images.isNotEmpty) {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (BuildContext context) {
                                        return Dialog(
                                          child: Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                ),
                                                const SizedBox(width: 16),
                                                Text('กำลังประมวลผลรูปภาพ ${images.length} รูป...'),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );

                                    try {
                                      debugPrint('Batch processing ${images.length} images with maxSize: 720');
                                      final fileList = images.map((img) => File(img.path)).toList();
                                      final processedImages = await processImagesBatch(fileList, maxSize: 720);
                                      debugPrint('Batch processing completed for ${processedImages.length} images');

                                      setStateDialog(() {
                                        claimImages.addAll(processedImages);
                                      });
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('เกิดข้อผิดพลาดในการประมวลผลรูปภาพ: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    } finally {
                                      if (Navigator.canPop(context)) {
                                        Navigator.of(context).pop();
                                      }
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
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                                  content: const Text('กรุณากรอก เลขเอกสาร และ รหัสรถ ให้ครบก่อนทำรายการ'),
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
                                remarkType: selectedType == 'ไม่ครบล็อต'
                                    ? remarkController.text.trim()
                                    : null,
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
          );
        },
      );
    },
  );

  return result;
}


