import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;

Future<File> _resizeImage(File file, {int maxSize = 720}) async {
  final bytes = await file.readAsBytes();
  final image = img.decodeImage(bytes);
  if (image == null) return file;

  final resized = img.copyResize(
    image,
    width: image.width > image.height ? maxSize : null,
    height: image.height >= image.width ? maxSize : null,
    interpolation: img.Interpolation.cubic,
  );

  final newBytes = img.encodeJpg(resized, quality: 78);
  final newFile = await file.writeAsBytes(newBytes, flush: true);
  return newFile;
}

Future<Map<String, dynamic>?> openClaimFormDialog(
  BuildContext context, {
  Map<String, dynamic>? initialClaim,
  required String userId,
  Future<String?> Function(TextEditingController controller)? onScan,
}) async {
  final Map<String, dynamic> draft = {
    'docNumber': initialClaim?['docNumber'] ?? '',
    'type': initialClaim?['type'] ?? 'เสียหาย',
    'carCode': initialClaim?['carCode'] ?? '',
    'timestamp': initialClaim?['timestamp'] ?? DateTime.now(),
    'images': List<File>.from(initialClaim?['images'] ?? <File>[]),
    'empID': userId,
  };

  final TextEditingController docNumberController = TextEditingController(
    text: draft['docNumber'],
  );
  final TextEditingController carCodeController = TextEditingController(
    text: draft['carCode'],
  );
  final TextEditingController remarkController = TextEditingController(
    text: initialClaim?['remarkType'] ?? '',
  );
  String selectedType = draft['type'];
  DateTime selectedDate = draft['timestamp'];
  List<File> claimImages = List<File>.from(draft['images']);
  final ImagePicker picker = ImagePicker();

  Future<void> selectDate(StateSetter setStateDialog) async {
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

  Future<void> addImage(File file, StateSetter setStateDialog) async {
    debugPrint('Processing image in dialog with maxSize: 720');
    file = await _resizeImage(file, maxSize: 720);
    debugPrint('Image processed in dialog, ready for upload');
    setStateDialog(() {
      claimImages.add(file);
    });
  }

  final result = await showDialog<Map<String, dynamic>>(
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
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      initialClaim == null
                          ? 'สร้างรายการ Claim ใหม่'
                          : 'แก้ไขรายการ Claim',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
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
                              const Text('วันที่: '),
                              TextButton.icon(
                                onPressed: () => selectDate(setStateDialog),
                                icon: const Icon(
                                  Icons.calendar_today,
                                  color: Colors.blue,
                                ),
                                label: Text(
                                  DateFormat('dd/MM/yyyy').format(selectedDate),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: docNumberController,
                            decoration: InputDecoration(
                              labelText: 'เลขเอกสาร',
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.qr_code_scanner_outlined,
                                ),
                                onPressed: onScan == null
                                    ? null
                                    : () async {
                                        await onScan(docNumberController);
                                      },
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
                              if (value != null) {
                                setStateDialog(() {
                                  selectedType = value;
                                });
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'ประเภทสินค้า',
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (selectedType == 'ไม่ครบล็อต') ...[
                            TextField(
                              controller: remarkController,
                              decoration: const InputDecoration(
                                labelText:
                                    'รายละเอียดเพิ่มเติม (จำนวนที่หาย ฯลฯ)',
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          const SizedBox(height: 12),
                          TextField(
                            controller: carCodeController,
                            decoration: InputDecoration(
                              labelText: 'รหัสรถ (เช่น TP XXXX)',
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.qr_code_scanner_outlined,
                                ),
                                onPressed: onScan == null
                                    ? null
                                    : () async {
                                        await onScan(carCodeController);
                                      },
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                            icon: const Icon(
                                              Icons.cancel,
                                              color: Colors.red,
                                            ),
                                            onPressed: () {
                                              setStateDialog(
                                                () =>
                                                    claimImages.removeAt(index),
                                              );
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
                                  final XFile? image = await picker.pickImage(
                                    source: ImageSource.camera,
                                  );
                                  if (image != null)
                                    await addImage(
                                      File(image.path),
                                      setStateDialog,
                                    );
                                },
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('ถ่ายรูป'),
                              ),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final List<XFile>? images = await picker
                                      .pickMultiImage();
                                  if (images != null) {
                                    for (var imgFile in images) {
                                      await addImage(
                                        File(imgFile.path),
                                        setStateDialog,
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

                            final newClaim = {
                              'docNumber': docNumberController.text.trim(),
                              'type': selectedType,
                              'carCode': carCodeController.text.trim(),
                              'timestamp': selectedDate,
                              'images': List<File>.from(claimImages),
                              'empID': userId,
                              'remarkType': selectedType == 'ไม่ครบล็อต'
                                  ? remarkController.text.trim()
                                  : null,
                            };

                            Navigator.pop(context, newClaim);
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
