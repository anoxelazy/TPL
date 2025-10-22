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
  // List of employee IDs that should show "มาจากคลังหน้าบ้าน" option
  const Set<String> frontStoreEmployeeIds = {
    '2547', '67057', '67176', '67177', '67217', '68015', '68069', '68089',
    '68102', '68124', '68145', '68194', '80354', '80412', '80653', '80899',
    '81725', '81881', '81990', '82005'
  };

  // Check if current user should see the front store option
  final bool shouldShowFrontStoreOption = frontStoreEmployeeIds.contains(userId);
  final Map<String, dynamic> draft = {
    'docNumber': initialClaim?['docNumber'] ?? '',
    'type': initialClaim?['type'] ?? 'เสียหาย',
    'carCode': initialClaim?['carCode'] ?? '',
    'timestamp': initialClaim?['timestamp'] ?? DateTime.now(),
    'images': List<File>.from(initialClaim?['images'] ?? <File>[]),
    'empID': userId,
    'fromFrontStore': initialClaim?['fromFrontStore'] ?? false,
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
  bool fromFrontStore = draft['fromFrontStore'];
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
                          ? 'สร้างรายการใหม่'
                          : 'แก้ไขรายการ',
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
                                icon: Icon(
                                  Icons.calendar_today,
                                  color: Theme.of(context).colorScheme.primary,
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
                              labelText: 'รหัสรถที่บรรทุกสินค้าเสียหาย',
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
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: claimImages.isEmpty
                                ? Theme.of(context).colorScheme.surface
                                : Color.lerp(Colors.yellow[100], Colors.green[100], claimImages.length / 6.0),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: claimImages.isEmpty
                                  ? Theme.of(context).colorScheme.outline
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
                                          top: 4,
                                          right: 4,
                                          child: GestureDetector(
                                            onTap: () {
                                              setStateDialog(
                                                () => claimImages.removeAt(index),
                                              );
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
                                onPressed: claimImages.length >= 6
                                    ? null
                                    : () async {
                                        final XFile? image = await picker
                                            .pickImage(
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
                                onPressed: claimImages.length >= 6
                                    ? null
                                    : () async {
                                        final List<XFile>? images = await picker
                                            .pickMultiImage();
                                        if (images != null) {
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
                                          for (var imgFile in imagesToProcess) {
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
                              'fromFrontStore': fromFrontStore,
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
