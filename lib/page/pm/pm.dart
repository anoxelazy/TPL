// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';

// class PMPage extends StatefulWidget {
//   const PMPage({super.key});

//   @override
//   State<PMPage> createState() => _PMPageState();
// }

// class _PMPageState extends State<PMPage> {
//   final ImagePicker _picker = ImagePicker();

//   List<Map<String, dynamic>> computerList = [
//     {
//       'no': '1',
//       'name': 'PC-001',
//       'asset': 'FA1001',
//       'employee': 'สมชาย ใจดี',
//       'location': 'สำนักงานใหญ่',
//       'remark': 'ใช้งานปกติ',
//       'performance': 'OK',
//       'myComputer': 'OK',
//       'clearTemp': 'OK',
//       'updateWinAv': 'OK',
//       'scanVirus': 'OK',
//       'beforeImage': null,
//       'afterImage': null,
//     },
//     {
//       'no': '2',
//       'name': 'PC-002',
//       'asset': 'FA1002',
//       'employee': 'สมหญิง สุขใจ',
//       'location': 'คลังสินค้า',
//       'remark': 'ต้องเปลี่ยนคีย์บอร์ด',
//       'performance': 'Slow',
//       'myComputer': 'OK',
//       'clearTemp': 'Pending',
//       'updateWinAv': 'Pending',
//       'scanVirus': 'OK',
//       'beforeImage': null,
//       'afterImage': null,
//     },
//   ];

//   List<Map<String, dynamic>> filteredList = [];

//   @override
//   void initState() {
//     super.initState();
//     filteredList = List.from(computerList);
//   }

//   void _filterComputers(String query) {
//     final lowerQuery = query.toLowerCase();
//     setState(() {
//       filteredList = computerList.where((computer) {
//         final combined = [
//           computer['no'] ?? '',
//           computer['name'] ?? '',
//           computer['asset'] ?? '',
//           computer['employee'] ?? '',
//           computer['location'] ?? '',
//           computer['remark'] ?? '',
//         ].join(' ').toLowerCase();
//         return combined.contains(lowerQuery);
//       }).toList();
//     });
//   }

//   Future<File?> _pickImageSource(ImageSource source) async {
//     final XFile? picked = await _picker.pickImage(
//       source: source,
//       imageQuality: 80,
//     );
//     if (picked == null) return null;
//     return File(picked.path);
//   }

//   void _editComputer(int index) {
//     String performance = computerList[index]['performance'] ?? 'OK';
//     String myComputer = computerList[index]['myComputer'] ?? 'OK';
//     String clearTemp = computerList[index]['clearTemp'] ?? 'OK';
//     String updateWinAv = computerList[index]['updateWinAv'] ?? 'OK';
//     String scanVirus = computerList[index]['scanVirus'] ?? 'OK';

//     Map<String, File?> beforeImages = {
//       'performance': computerList[index]['beforePerformanceImage'],
//       'myComputer': computerList[index]['beforeMyComputerImage'],
//       'clearTemp': computerList[index]['beforeClearTempImage'],
//       'updateWinAv': computerList[index]['beforeUpdateWinAvImage'],
//       'scanVirus': computerList[index]['beforeScanVirusImage'],
//     };
//     Map<String, File?> afterImages = {
//       'performance': computerList[index]['afterPerformanceImage'],
//       'myComputer': computerList[index]['afterMyComputerImage'],
//       'clearTemp': computerList[index]['afterClearTempImage'],
//       'updateWinAv': computerList[index]['afterUpdateWinAvImage'],
//       'scanVirus': computerList[index]['afterScanVirusImage'],
//     };

//     final TextEditingController remarkController = TextEditingController(
//       text: computerList[index]['remark'] ?? '',
//     );

//     showDialog(
//       context: context,
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, dialogSetState) {
//             Future<void> _pickForDialog(bool isBefore, String task) async {
//               showModalBottomSheet(
//                 context: context,
//                 builder: (ctx) {
//                   return SafeArea(
//                     child: Wrap(
//                       children: [
//                         ListTile(
//                           leading: const Icon(Icons.photo_library),
//                           title: const Text('เลือกจากคลังรูป'),
//                           onTap: () async {
//                             Navigator.pop(ctx);
//                             final f = await _pickImageSource(
//                               ImageSource.gallery,
//                             );
//                             if (f != null) {
//                               dialogSetState(() {
//                                 if (isBefore) {
//                                   beforeImages[task] = f;
//                                 } else {
//                                   afterImages[task] = f;
//                                 }
//                               });
//                             }
//                           },
//                         ),
//                         ListTile(
//                           leading: const Icon(Icons.camera_alt),
//                           title: const Text('ถ่ายรูปด้วยกล้อง'),
//                           onTap: () async {
//                             Navigator.pop(ctx);
//                             final f = await _pickImageSource(
//                               ImageSource.camera,
//                             );
//                             if (f != null) {
//                               dialogSetState(() {
//                                 if (isBefore) {
//                                   beforeImages[task] = f;
//                                 } else {
//                                   afterImages[task] = f;
//                                 }
//                               });
//                             }
//                           },
//                         ),
//                       ],
//                     ),
//                   );
//                 },
//               );
//             }

//             Widget buildTaskRow(
//               String label,
//               String taskKey,
//               String currentValue,
//               List<String> options,
//             ) {
//               return Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   DropdownButtonFormField<String>(
//                     value: currentValue,
//                     decoration: InputDecoration(labelText: label),
//                     items: options
//                         .map((e) => DropdownMenuItem(value: e, child: Text(e)))
//                         .toList(),
//                     onChanged: (v) {
//                       dialogSetState(() {
//                         switch (taskKey) {
//                           case 'performance':
//                             performance = v ?? performance;
//                             break;
//                           case 'myComputer':
//                             myComputer = v ?? myComputer;
//                             break;
//                           case 'clearTemp':
//                             clearTemp = v ?? clearTemp;
//                             break;
//                           case 'updateWinAv':
//                             updateWinAv = v ?? updateWinAv;
//                             break;
//                           case 'scanVirus':
//                             scanVirus = v ?? scanVirus;
//                             break;
//                         }
//                       });
//                     },
//                   ),
//                   const SizedBox(height: 8),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: Column(
//                           children: [
//                             const Text(
//                               'ก่อนทำ',
//                               style: TextStyle(fontWeight: FontWeight.w500),
//                             ),
//                             const SizedBox(height: 6),
//                             beforeImages[taskKey] != null
//                                 ? Image.file(
//                                     beforeImages[taskKey]!,
//                                     width: 120,
//                                     height: 80,
//                                     fit: BoxFit.cover,
//                                   )
//                                 : Container(
//                                     width: 120,
//                                     height: 80,
//                                     color: Theme.of(context).colorScheme.surfaceVariant,
//                                     child: Icon(
//                                       Icons.image,
//                                       size: 36,
//                                       color: Theme.of(context).colorScheme.onSurfaceVariant,
//                                     ),
//                                   ),
//                             IconButton(
//                               icon: Icon(
//                                 Icons.add_a_photo,
//                                 color: Theme.of(context).colorScheme.primary,
//                               ),
//                               onPressed: () => _pickForDialog(true, taskKey),
//                             ),
//                           ],
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: Column(
//                           children: [
//                             const Text(
//                               'หลังทำ',
//                               style: TextStyle(fontWeight: FontWeight.w500),
//                             ),
//                             const SizedBox(height: 6),
//                             afterImages[taskKey] != null
//                                 ? Image.file(
//                                     afterImages[taskKey]!,
//                                     width: 120,
//                                     height: 80,
//                                     fit: BoxFit.cover,
//                                   )
//                                 : Container(
//                                     width: 120,
//                                     height: 80,
//                                     color: Theme.of(context).colorScheme.surfaceVariant,
//                                     child: Icon(
//                                       Icons.image,
//                                       size: 36,
//                                       color: Theme.of(context).colorScheme.onSurfaceVariant,
//                                     ),
//                                   ),
//                             IconButton(
//                               icon: Icon(
//                                 Icons.add_a_photo,
//                                 color: Theme.of(context).colorScheme.secondary,
//                               ),
//                               onPressed: () => _pickForDialog(false, taskKey),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 16),
//                 ],
//               );
//             }

//             return Dialog(
//               insetPadding: const EdgeInsets.all(10),
//               child: Container(
//                 width: double.infinity,
//                 height: MediaQuery.of(context).size.height * 0.9,
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         const Text(
//                           'รายการซ่อม/ตรวจเช็ค',
//                           style: TextStyle(
//                             fontSize: 22,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         IconButton(
//                           icon: const Icon(Icons.close),
//                           onPressed: () => Navigator.pop(context),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 12),
//                     Expanded(
//                       child: SingleChildScrollView(
//                         child: Column(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Row(
//                               children: [
//                                 Expanded(
//                                   child: Text(
//                                     'Computer: ${computerList[index]['name']}',
//                                   ),
//                                 ),
//                                 const SizedBox(width: 15),
//                                 Text(
//                                   'No ${computerList[index]['no']}',
//                                   style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 12),

//                             buildTaskRow(
//                               'Task(Performance) and My Computer',
//                               'performance',
//                               performance,
//                               [],
//                             ),
//                             buildTaskRow(
//                               'Clear Temp',
//                               'myComputer',
//                               myComputer,
//                               [],
//                             ),
//                             buildTaskRow(
//                               'Update Windows And AntiVirus',
//                               'clearTemp',
//                               clearTemp,
//                               [],
//                             ),
//                             buildTaskRow(
//                               'Scan Virus',
//                               'updateWinAv',
//                               updateWinAv,
//                               [],
//                             ),
//                             buildTaskRow(
//                               'สภาพคอมพิวเตอร์',
//                               'scanVirus',
//                               scanVirus,
//                               [],
//                             ),

//                             TextField(
//                               controller: remarkController,
//                               maxLines: 2,
//                               decoration: const InputDecoration(
//                                 labelText: 'Remark',
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),

//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.end,
//                       children: [
//                         TextButton(
//                           onPressed: () => Navigator.pop(context),
//                           child: const Text('ยกเลิก'),
//                         ),
//                         const SizedBox(width: 8),
//                         ElevatedButton(
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Theme.of(context).colorScheme.primary,
//                           ),
//                           onPressed: () {
//                             setState(() {
//                               computerList[index]['performance'] = performance;
//                               computerList[index]['myComputer'] = myComputer;
//                               computerList[index]['clearTemp'] = clearTemp;
//                               computerList[index]['updateWinAv'] = updateWinAv;
//                               computerList[index]['scanVirus'] = scanVirus;

//                               computerList[index]['beforePerformanceImage'] =
//                                   beforeImages['performance'];
//                               computerList[index]['afterPerformanceImage'] =
//                                   afterImages['performance'];
//                               computerList[index]['beforeMyComputerImage'] =
//                                   beforeImages['myComputer'];
//                               computerList[index]['afterMyComputerImage'] =
//                                   afterImages['myComputer'];
//                               computerList[index]['beforeClearTempImage'] =
//                                   beforeImages['clearTemp'];
//                               computerList[index]['afterClearTempImage'] =
//                                   afterImages['clearTemp'];
//                               computerList[index]['beforeUpdateWinAvImage'] =
//                                   beforeImages['updateWinAv'];
//                               computerList[index]['afterUpdateWinAvImage'] =
//                                   afterImages['updateWinAv'];
//                               computerList[index]['beforeScanVirusImage'] =
//                                   beforeImages['scanVirus'];
//                               computerList[index]['afterScanVirusImage'] =
//                                   afterImages['scanVirus'];

//                               computerList[index]['remark'] = remarkController.text;
//                             });
//                             Navigator.pop(context);
//                           },
//                           child: const Text('บันทึก'),
//                         ),
//                       ],
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

//   void _showAddComputerDialog() {
//     final noController = TextEditingController();
//     final nameController = TextEditingController();
//     final assetController = TextEditingController();
//     final employeeController = TextEditingController();
//     final locationController = TextEditingController();
//     final remarkController = TextEditingController();

//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: const Text('เพิ่มคอมพิวเตอร์ใหม่'),
//           content: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 TextField(controller: noController, decoration: const InputDecoration(labelText: 'No')),
//                 TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Computer Name')),
//                 TextField(controller: assetController, decoration: const InputDecoration(labelText: 'Fix Asset')),
//                 TextField(controller: employeeController, decoration: const InputDecoration(labelText: 'Employee Use')),
//                 TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Location')),
//                 TextField(controller: remarkController, decoration: const InputDecoration(labelText: 'Remark')),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('ยกเลิก'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 if (noController.text.trim().isEmpty ||
//                     nameController.text.trim().isEmpty) {
//                   return;
//                 }
//                 setState(() {
//                   final newComputer = {
//                     'no': noController.text.trim(),
//                     'name': nameController.text.trim(),
//                     'asset': assetController.text.trim(),
//                     'employee': employeeController.text.trim(),
//                     'location': locationController.text.trim(),
//                     'remark': remarkController.text.trim(),
//                     'performance': 'OK',
//                     'myComputer': 'OK',
//                     'clearTemp': 'OK',
//                     'updateWinAv': 'OK',
//                     'scanVirus': 'OK',
//                     'beforeImage': null,
//                     'afterImage': null,
//                   };
//                   computerList.add(newComputer);
//                   filteredList = List.from(computerList);
//                 });
//                 Navigator.pop(context);
//               },
//               child: const Text('บันทึก'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   @override
// Widget build(BuildContext context) {
//   return Scaffold(
//     appBar: AppBar(
//       backgroundColor: Theme.of(context).colorScheme.surface,
//       foregroundColor: Theme.of(context).colorScheme.onSurface,
//       title: Row(
//         children: [
//           Expanded(
//             flex: 1,
//             child: Text(
//               'ตรวจสอบสภาพคอมพิวเตอร์',
//               style: TextStyle(
//                 fontSize: 18,
//                 color: Theme.of(context).colorScheme.onSurface,
//               ),
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//           Expanded(
//             flex: 1,
//             child: SizedBox(
//               height: 36,
//               child: TextField(
//                 onChanged: _filterComputers,
//                 decoration: InputDecoration(
//                   isDense: true,
//                   contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
//                   hintText: 'ค้นหา',
//                   hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
//                   filled: true,
//                   fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
//                   prefixIcon: Icon(
//                     Icons.search,
//                     size: 18,
//                     color: Theme.of(context).colorScheme.onSurfaceVariant,
//                   ),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                     borderSide: BorderSide.none,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     ),
//     floatingActionButton: FloatingActionButton(
//       onPressed: _showAddComputerDialog,
//       tooltip: 'เพิ่มคอมพิวเตอร์',
//       backgroundColor: Theme.of(context).colorScheme.primary,
//       foregroundColor: Theme.of(context).colorScheme.onPrimary,
//       child: Icon(Icons.add),
//     ),
//     body: SingleChildScrollView(
//       scrollDirection: Axis.horizontal,
//       child: DataTable(
//         headingRowColor: MaterialStateProperty.all(Theme.of(context).colorScheme.primaryContainer),
//         columns: [
//           DataColumn(
//             label: Container(
//               decoration: BoxDecoration(
//                 border: Border(
//                   right: BorderSide(color: Theme.of(context).colorScheme.outline, width: 1),
//                 ),
//               ),
//               padding: EdgeInsets.symmetric(horizontal: 8),
//               child: Center(child: Text('แก้ไข')),
//             ),
//           ),
//           DataColumn(
//             label: Container(
//               decoration: BoxDecoration(
//                 border: Border(
//                   right: BorderSide(color: Theme.of(context).colorScheme.outline, width: 1),
//                 ),
//               ),
//               padding: EdgeInsets.symmetric(horizontal: 8),
//               child: Center(child: Text('No')),
//             ),
//           ),
//           DataColumn(
//             label: Container(
//               decoration: BoxDecoration(
//                 border: Border(
//                   right: BorderSide(color: Colors.grey.shade400, width: 1),
//                 ),
//               ),
//               padding: EdgeInsets.symmetric(horizontal: 8),
//               child: Center(child: Text('Computer Name')),
//             ),
//           ),
//           DataColumn(
//             label: Container(
//               decoration: BoxDecoration(
//                 border: Border(
//                   right: BorderSide(color: Colors.grey.shade400, width: 1),
//                 ),
//               ),
//               padding: EdgeInsets.symmetric(horizontal: 8),
//               child: Center(child: Text('Fix Asset')),
//             ),
//           ),
//           DataColumn(
//             label: Container(
//               decoration: BoxDecoration(
//                 border: Border(
//                   right: BorderSide(color: Colors.grey.shade400, width: 1),
//                 ),
//               ),
//               padding: EdgeInsets.symmetric(horizontal: 8),
//               child: Center(child: Text('Employee Use')),
//             ),
//           ),
//           DataColumn(
//             label: Container(
//               decoration: BoxDecoration(
//                 border: Border(
//                   right: BorderSide(color: Colors.grey.shade400, width: 1),
//                 ),
//               ),
//               padding: EdgeInsets.symmetric(horizontal: 8),
//               child: Center(child: Text('Location')),
//             ),
//           ),
//           DataColumn(
//             label: Container(
//               padding: EdgeInsets.symmetric(horizontal: 8),
//               child: Center(child: Text('Remark')),
//             ),
//           ),
//         ],

//         rows: List.generate(filteredList.length, (index) {
//           final data = filteredList[index];
//           return DataRow(
//             cells: [
//               DataCell(
//                 IconButton(
//                   icon: Icon(
//                     Icons.edit,
//                     color: Theme.of(context).colorScheme.primary,
//                   ),
//                   onPressed: () {
//                     _editComputer(computerList.indexOf(data));
//                   },
//                 ),
//               ),
//               DataCell(Center(child: Text(data['no'] ?? ''))),
//               DataCell(Center(child: Text(data['name'] ?? ''))),
//               DataCell(Center(child: Text(data['asset'] ?? ''))),
//               DataCell(Center(child: Text(data['employee'] ?? ''))),
//               DataCell(Center(child: Text(data['location'] ?? ''))),
//               DataCell(Center(child: Text(data['remark'] ?? ''))),
//             ],
//           );
//         }),
//       ),
//     ),
//   );
// }

// }
