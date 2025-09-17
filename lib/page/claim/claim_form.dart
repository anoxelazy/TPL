import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'image_utils.dart';

class ClaimFormResult {
  final String docNumber;
  final String type;
  final String carCode;
  final DateTime timestamp;
  final List<File> images;
  final String empId;
  final String? remark;

  ClaimFormResult({
    required this.docNumber,
    required this.type,
    required this.carCode,
    required this.timestamp,
    required this.images,
    required this.empId,
    this.remark,
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

  Future<void> _addImage(File file, StateSetter setStateDialog) async {
    final resized = await resizeImage(file, maxSize: 1080);
    setStateDialog(() {
      claimImages.add(resized);
    });
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
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.file(
                                            claimImages[index],
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover,
                                          ),
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
                                  if (image != null) await _addImage(File(image.path), setStateDialog);
                                },
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('ถ่ายรูป'),
                              ),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final List<XFile>? images = await picker.pickMultiImage();
                                  if (images != null) {
                                    for (var imgFile in images) {
                                      await _addImage(File(imgFile.path), setStateDialog);
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
                                remark: selectedType == 'ไม่ครบล็อต' 
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


