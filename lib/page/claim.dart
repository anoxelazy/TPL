import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/config.dart';

class ClaimPage extends StatefulWidget {
  const ClaimPage({super.key});

  @override
  State<ClaimPage> createState() => _ClaimPageState();
}

class _ClaimPageState extends State<ClaimPage> {
  int claimCount = 0;
  List<Map<String, dynamic>> claims = [];

  void _resetCount() {
    setState(() {
      claimCount = 0;
      claims.clear();
    });
  }

  Future<void> _scanBarcode(TextEditingController controller) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('สแกนบาร์โค้ด')),
          body: MobileScanner(
            onDetect: (BarcodeCapture capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                Navigator.pop(context, barcodes.first.rawValue);
              }
            },
          ),
        ),
      ),
    );

    if (result != null && result is String) {
      setState(() {
        controller.text = result;
      });
    }
  }

  Future<void> _showClaimDialog({int? editIndex}) async {
    final TextEditingController docNumberController = TextEditingController();
    String selectedType = 'เสียหาย';
    final TextEditingController carCodeController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    List<File> claimImages = [];
    final ImagePicker picker = ImagePicker();

    if (editIndex != null) {
      final claim = claims[editIndex];
      docNumberController.text = claim['docNumber'] ?? '';
      selectedType = claim['type'] ?? 'เสียหาย';
      carCodeController.text = claim['carCode'] ?? '';
      selectedDate = claim['timestamp'] ?? DateTime.now();
      claimImages = List<File>.from(claim['images'] ?? []);
    }

    Future<void> _selectDate(BuildContext context, StateSetter setStateDialog) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (picked != null && picked != selectedDate) {
        setStateDialog(() {
          selectedDate = picked;
        });
      }
    }

    void _addImageFromCamera(StateSetter setStateDialog) async {
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setStateDialog(() {
          claimImages.add(File(image.path));
        });
      }
    }

    void _addImageFromGallery(StateSetter setStateDialog) async {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setStateDialog(() {
          claimImages.add(File(image.path));
        });
      }
    }

    await showDialog(
      context: context,
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
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        editIndex == null ? 'สร้างรายการ Claim ใหม่' : 'แก้ไขรายการ Claim',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                                  onPressed: () => _selectDate(context, setStateDialog),
                                  icon: const Icon(Icons.calendar_today, color: Colors.blue),
                                  label: Text(
                                    DateFormat('dd/MM/yyyy').format(selectedDate),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (claimImages.isNotEmpty)
                              SizedBox(
                                height: 80,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: claimImages.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Stack(
                                        children: [
                                          Image.file(
                                            claimImages[index],
                                            width: 70,
                                            height: 70,
                                            fit: BoxFit.cover,
                                          ),
                                          Positioned(
                                            top: -10,
                                            right: -10,
                                            child: IconButton(
                                              icon: const Icon(Icons.cancel, color: Colors.red),
                                              onPressed: () {
                                                setStateDialog(() {
                                                  claimImages.removeAt(index);
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: docNumberController,
                              decoration: InputDecoration(
                                labelText: 'เลขเอกสาร',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.qr_code_scanner_outlined),
                                  onPressed: () => _scanBarcode(docNumberController),
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
                                if (value != null) {
                                  setStateDialog(() {
                                    selectedType = value;
                                  });
                                }
                              },
                              decoration: const InputDecoration(labelText: 'ประเภทสินค้า'),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: carCodeController,
                              decoration: InputDecoration(
                                labelText: 'รหัสรถ (เช่น TP XXXX)',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.qr_code_scanner_outlined),
                                  onPressed: () => _scanBarcode(carCodeController),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _addImageFromCamera(setStateDialog),
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text('ถ่ายรูป'),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _addImageFromGallery(setStateDialog),
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
                            onPressed: () {
                              if (docNumberController.text.trim().isEmpty ||
                                  carCodeController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('กรุณากรอกข้อมูลให้ครบทุกช่อง'),
                                  ),
                                );
                                return;
                              }
                              setState(() {
                                final newClaim = {
                                  'docNumber': docNumberController.text.trim(),
                                  'type': selectedType,
                                  'carCode': carCodeController.text.trim(),
                                  'timestamp': selectedDate,
                                  'images': List<File>.from(claimImages),
                                };
                                if (editIndex == null) {
                                  claims.add(newClaim);
                                } else {
                                  claims[editIndex] = newClaim;
                                }
                                claimCount = claims.length;
                              });
                              Navigator.pop(context);
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
  }

  // =================== API ส่งรูป ===================
  Future<void> sendClaimToAPI({
    required String a1No,
    required String empId,
    required String folderName,
    required String imageName,
    required File imageFile,
    required double lat,
    required double lon,
    required String bearerToken,
  }) async {
    final url = Uri.parse("${AppConfig.apiBaseUrl}/api/GETImageLink_Folder");

    String base64Image = base64Encode(await imageFile.readAsBytes());

    final body = {
      "A1": a1No,
      "IsStempText": false,
      "image1": base64Image,
      "lat": lat,
      "lon": lon,
      "refCode": "trackinkcustomer",
      "EmpID": empId,
      "FolderName": folderName,
      "ImageName": imageName,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $bearerToken",
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        print("ส่งรูปสำเร็จ ✅: ${response.body}");
      } else {
        print("ส่งรูปล้มเหลว ❌: ${response.statusCode}, ${response.body}");
      }
    } catch (e) {
      print("เกิดข้อผิดพลาดในการส่งรูป: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Claim สินค้า'),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, size: 28),
                  tooltip: 'รีเซ็ต',
                  onPressed: claimCount > 0 ? _resetCount : null,
                  color: claimCount > 0 ? Colors.red : Colors.grey,
                ),
                if (claimCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      child: Text(
                        '$claimCount',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: claims.isEmpty
          ? const Center(
              child: Text(
                'ไม่มีรายการ Claim',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: claims.length,
              itemBuilder: (context, index) {
                final claim = claims[index];
                DateTime timestamp = claim['timestamp'] ?? DateTime.now();
                return ListTile(
                  leading: const Icon(Icons.local_shipping),
                  title: Text('เลขเอกสาร: ${claim['docNumber']}'),
                  subtitle: Text(
                    'ประเภท: ${claim['type']}\nรหัสรถ: ${claim['carCode']}\nวันที่: ${DateFormat('dd/MM/yyyy').format(timestamp)}',
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 12,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.photo),
                        tooltip: 'ดู/เพิ่มรูปภาพ',
                        onPressed: () => _showClaimDialog(editIndex: index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        tooltip: 'แก้ไขข้อมูล',
                        onPressed: () => _showClaimDialog(editIndex: index),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Claim'),
        backgroundColor: Colors.green,
        onPressed: () => _showClaimDialog(),
      ),
    );
  }
}
