// import 'dart:io';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
// import 'package:http/http.dart' as http;

// class ClaimPage extends StatefulWidget {
//   const ClaimPage({super.key});

//   @override
//   State<ClaimPage> createState() => _ClaimPageState();
// }

// class _ClaimPageState extends State<ClaimPage> {
//   List<Map<String, dynamic>> claims = [];

//   void _resetClaims() {
//     setState(() {
//       claims.clear();
//     });
//   }

//   Future<String> imageToBase64(File image) async {
//     final bytes = await image.readAsBytes();
//     return base64Encode(bytes);
//   }

//   Future<String> uploadClaimImage({
//     required String docNumber,
//     required File image,
//     required double lat,
//     required double lon,
//     required String empId,
//     required String folderName,
//     required String imageName,
//   }) async {
//     final url = Uri.parse('{{baseUrl}}/api/GETImageLink_Folder');
//     final base64Image = await imageToBase64(image);

//     final body = {
//       "A1": docNumber,
//       "IsStempText": true,
//       "image1": base64Image,
//       "lat": lat,
//       "lon": lon,
//       "refCode": "trackinkcustomer",
//       "EmpID": empId,
//       "FolderName": folderName,
//       "ImageName": imageName,
//     };

//     final response = await http.post(
//       url,
//       headers: {
//         'Content-Type': 'application/json',
//         'Authorization': 'Bearer {{bearerToken}}',
//       },
//       body: jsonEncode(body),
//     );

//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       return data['imageUrl']; 
//     } else {
//       throw Exception('Upload รูปล้มเหลว: ${response.body}');
//     }
//   }

//   Future<void> sendClaimToGoogleSheet({
//     required String date,
//     required String a1No,
//     required String claimType,
//     required String truckNo,
//     required String userId,
//     required List<String> imageUrls,
//   }) async {
//     final url = Uri.parse('https://script.google.com/macros/s/AKfycbxdGLxrCcnAi2eWhO5s4RHIVWqMRxbX7kfQJKoHWd2Y35RUwzraogdkrfueUmOZ14Jd/exec?key=91d3acfb-0b47-49b4-9667-ed359ecda9e5'); // ใส่ URL จริง

//     final data = {
//       "date": date,
//       "a1_no": a1No,
//       "claim_type": claimType,
//       "truck_no": truckNo,
//       "user_id": userId,
//       "images": imageUrls,
//     };

//     final response = await http.post(
//       url,
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode(data),
//     );

//     if (response.statusCode == 200) {
//       print('ส่งข้อมูลสำเร็จ: ${response.body}');
//     } else {
//       print('ส่งข้อมูลล้มเหลว: ${response.statusCode} - ${response.body}');
//     }
//   }

//   Future<void> _scanBarcode(TextEditingController controller) async {
//     final result = await Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => Scaffold(
//           appBar: AppBar(title: const Text('สแกนบาร์โค้ด')),
//           body: MobileScanner(
//             onDetect: (capture) {
//               final barcodes = capture.barcodes;
//               if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
//                 Navigator.pop(context, barcodes.first.rawValue);
//               }
//             },
//           ),
//         ),
//       ),
//     );

//     if (result != null && result is String) {
//       setState(() {
//         controller.text = result;
//       });
//     }
//   }

//   Future<void> _showClaimDialog({int? editIndex}) async {
//     final TextEditingController docNumberController = TextEditingController();
//     final TextEditingController carCodeController = TextEditingController();
//     String selectedType = 'เสียหาย';
//     DateTime selectedDate = DateTime.now();
//     List<File> claimImages = [];
//     final ImagePicker picker = ImagePicker();

//     if (editIndex != null) {
//       final claim = claims[editIndex];
//       docNumberController.text = claim['docNumber'] ?? '';
//       carCodeController.text = claim['carCode'] ?? '';
//       selectedType = claim['type'] ?? 'เสียหาย';
//       selectedDate = claim['timestamp'] ?? DateTime.now();
//       claimImages = List<File>.from(claim['images'] ?? []);
//     }

//     await showDialog(
//       context: context,
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setStateDialog) {
//             Future<void> _selectDate() async {
//               final DateTime? picked = await showDatePicker(
//                 context: context,
//                 initialDate: selectedDate,
//                 firstDate: DateTime(2000),
//                 lastDate: DateTime(2100),
//               );
//               if (picked != null) setStateDialog(() => selectedDate = picked);
//             }

//             Future<void> _addImageFromCamera() async {
//               final XFile? image = await picker.pickImage(source: ImageSource.camera);
//               if (image != null) setStateDialog(() => claimImages.add(File(image.path)));
//             }

//             Future<void> _addImageFromGallery() async {
//               final XFile? image = await picker.pickImage(source: ImageSource.gallery);
//               if (image != null) setStateDialog(() => claimImages.add(File(image.path)));
//             }

//             return Dialog(
//               insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
//               child: SizedBox(
//                 width: MediaQuery.of(context).size.width * 0.9,
//                 height: MediaQuery.of(context).size.height * 0.85,
//                 child: Column(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.all(16),
//                       child: Text(
//                         editIndex == null ? 'สร้าง Claim ใหม่' : 'แก้ไข Claim',
//                         style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                       ),
//                     ),
//                     Expanded(
//                       child: SingleChildScrollView(
//                         padding: const EdgeInsets.symmetric(horizontal: 16),
//                         child: Column(
//                           children: [
//                             Row(
//                               children: [
//                                 const Text('วันที่: '),
//                                 TextButton(
//                                   onPressed: _selectDate,
//                                   child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
//                                 ),
//                               ],
//                             ),
//                             TextField(
//                               controller: docNumberController,
//                               decoration: InputDecoration(
//                                 labelText: 'เลขเอกสาร',
//                                 suffixIcon: IconButton(
//                                   icon: const Icon(Icons.qr_code_scanner_outlined),
//                                   onPressed: () => _scanBarcode(docNumberController),
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(height: 12),
//                             DropdownButtonFormField<String>(
//                               value: selectedType,
//                               items: const [
//                                 DropdownMenuItem(value: 'เสียหาย', child: Text('เสียหาย')),
//                                 DropdownMenuItem(value: 'สูญหาย', child: Text('สูญหาย')),
//                                 DropdownMenuItem(value: 'ไม่ครบล็อต', child: Text('ไม่ครบล็อต')),
//                               ],
//                               onChanged: (value) {
//                                 if (value != null) setStateDialog(() => selectedType = value);
//                               },
//                               decoration: const InputDecoration(labelText: 'ประเภทสินค้า'),
//                             ),
//                             const SizedBox(height: 12),
//                             TextField(
//                               controller: carCodeController,
//                               decoration: InputDecoration(
//                                 labelText: 'รหัสรถ',
//                                 suffixIcon: IconButton(
//                                   icon: const Icon(Icons.qr_code_scanner_outlined),
//                                   onPressed: () => _scanBarcode(carCodeController),
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(height: 12),
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                               children: [
//                                 ElevatedButton.icon(
//                                   onPressed: _addImageFromCamera,
//                                   icon: const Icon(Icons.camera_alt),
//                                   label: const Text('ถ่ายรูป'),
//                                 ),
//                                 ElevatedButton.icon(
//                                   onPressed: _addImageFromGallery,
//                                   icon: const Icon(Icons.photo_library),
//                                   label: const Text('เลือกรูป'),
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 12),
//                             if (claimImages.isNotEmpty)
//                               SizedBox(
//                                 height: 80,
//                                 child: ListView.builder(
//                                   scrollDirection: Axis.horizontal,
//                                   itemCount: claimImages.length,
//                                   itemBuilder: (context, index) {
//                                     return Padding(
//                                       padding: const EdgeInsets.only(right: 8),
//                                       child: Stack(
//                                         children: [
//                                           Image.file(
//                                             claimImages[index],
//                                             width: 70,
//                                             height: 70,
//                                             fit: BoxFit.cover,
//                                           ),
//                                           Positioned(
//                                             top: -10,
//                                             right: -10,
//                                             child: IconButton(
//                                               icon: const Icon(Icons.cancel, color: Colors.red),
//                                               onPressed: () {
//                                                 setStateDialog(() => claimImages.removeAt(index));
//                                               },
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     );
//                                   },
//                                 ),
//                               ),
//                           ],
//                         ),
//                       ),
//                     ),
//                     Padding(
//                       padding: const EdgeInsets.all(16),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.end,
//                         children: [
//                           TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
//                           const SizedBox(width: 8),
//                           ElevatedButton(
//                             onPressed: () async {
//                               if (docNumberController.text.trim().isEmpty || carCodeController.text.trim().isEmpty) {
//                                 ScaffoldMessenger.of(context).showSnackBar(
//                                   const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบทุกช่อง')),
//                                 );
//                                 return;
//                               }

//                               List<String> imageUrls = [];
//                               for (int i = 0; i < claimImages.length; i++) {
//                                 final url = await uploadClaimImage(
//                                   docNumber: docNumberController.text.trim(),
//                                   image: claimImages[i],
//                                   lat: 2.5,
//                                   lon: 5.55,
//                                   empId: '63205',
//                                   folderName: 'Claim',
//                                   imageName: 'IMG_${i + 1}',
//                                 );
//                                 imageUrls.add(url);
//                               }
//                               await sendClaimToGoogleSheet(
//                                 date: DateFormat('yyyy-MM-dd').format(selectedDate),
//                                 a1No: docNumberController.text.trim(),
//                                 claimType: selectedType == 'เสียหาย' ? 'damage' : selectedType,
//                                 truckNo: carCodeController.text.trim(),
//                                 userId: 'user_abc',
//                                 imageUrls: imageUrls,
//                               );

//                               setState(() {
//                                 final newClaim = {
//                                   'docNumber': docNumberController.text.trim(),
//                                   'type': selectedType,
//                                   'carCode': carCodeController.text.trim(),
//                                   'timestamp': selectedDate,
//                                   'images': claimImages,
//                                 };
//                                 if (editIndex == null) {
//                                   claims.add(newClaim);
//                                 } else {
//                                   claims[editIndex] = newClaim;
//                                 }
//                               });

//                               Navigator.pop(context);
//                             },
//                             child: const Text('Save'),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Claim สินค้า'),
//         backgroundColor: Colors.white,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             color: claims.isEmpty ? Colors.grey : Colors.red,
//             onPressed: claims.isEmpty ? null : _resetClaims,
//           ),
//         ],
//       ),
//       body: claims.isEmpty
//           ? const Center(child: Text('ไม่มีรายการ Claim'))
//           : ListView.builder(
//               itemCount: claims.length,
//               itemBuilder: (context, index) {
//                 final claim = claims[index];
//                 final timestamp = claim['timestamp'] ?? DateTime.now();
//                 return ListTile(
//                   leading: const Icon(Icons.local_shipping),
//                   title: Text('เลขเอกสาร: ${claim['docNumber']}'),
//                   subtitle: Text(
//                     'ประเภท: ${claim['type']}\nรหัสรถ: ${claim['carCode']}\nวันที่: ${DateFormat('dd/MM/yyyy').format(timestamp)}',
//                   ),
//                   trailing: Wrap(
//                     spacing: 8,
//                     children: [
//                       IconButton(
//                         icon: const Icon(Icons.edit, color: Colors.blue),
//                         onPressed: () => _showClaimDialog(editIndex: index),
//                       ),
//                     ],
//                   ),
//                 );
//               },
//             ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () => _showClaimDialog(),
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }
