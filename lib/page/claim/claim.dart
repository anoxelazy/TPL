import 'dart:io';
import 'dart:convert';
// ignore: unused_import
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/page/claim/claim_history_page.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/page/claim/claim_form.dart';
import 'package:flutter_application_1/page/claim/claim_api.dart' as claim_api;
import 'package:flutter_application_1/page/claim/claim_dialogs.dart' as claim_dialogs;
import 'package:flutter_application_1/page/claim/claim_scan.dart';
import 'package:flutter_application_1/utils/app_logger.dart';

class _SimpleHttpResponse {
  final int statusCode;
  final String body;
  _SimpleHttpResponse(this.statusCode, this.body);
}

class ClaimPage extends StatefulWidget {
  const ClaimPage({super.key});

  @override
  State<ClaimPage> createState() => _ClaimPageState();
}

String _normalizeUrl(String url) {
  final parts = url.split('://');
  if (parts.length != 2) return url;
  final protocol = parts[0];
  final rest = parts[1].replaceAll(RegExp(r'/+'), '/');
  return '$protocol://$rest';
}

class _ClaimPageState extends State<ClaimPage> {
  int claimCount = 0;
  List<Map<String, dynamic>> claims = [];
  final String _sheetEndpoint =
      'https://script.google.com/macros/s/AKfycbxdGLxrCcnAi2eWhO5s4RHIVWqMRxbX7kfQJKoHWd2Y35RUwzraogdkrfueUmOZ14Jd/exec';
  final String _sheetKey = '91d3acfb-0b47-49b4-9667-ed359ecda9e5';
  bool _isSendingAll = false;
  String? _userId;

  DateTime? _lastOperationTime;
  static const int _maxConcurrentOperations = 3;

  void _resetCount() {
    AppLogger.I.log('claim_reset_clicked', data: {'count': claimCount});
    setState(() {
      claimCount = 0;
      claims.clear();
    });
  }

  Future<void> _handleError(String operation, dynamic error, {StackTrace? stackTrace}) async {
    debugPrint('Error in $operation: $error');
    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }

    await AppLogger.I.log('claim_error', data: {
      'operation': operation,
      'error': error.toString(),
      'stackTrace': stackTrace?.toString(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: ${error.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'ลองใหม่',
            textColor: Colors.white,
            onPressed: () {
            },
          ),
        ),
      );
    }
  }

  void _startOperation(String operation) {
    _lastOperationTime = DateTime.now();
    debugPrint('Starting operation: $operation');
  }

  void _endOperation(String operation) {
    if (_lastOperationTime != null) {
      final duration = DateTime.now().difference(_lastOperationTime!);
      debugPrint('Operation $operation completed in ${duration.inMilliseconds}ms');
      _lastOperationTime = null;
    }
  }

  bool _isLoading = false;

  void _closeAllDialogs() {
    Navigator.of(context, rootNavigator: true)
        .popUntil((route) => route is PageRoute);
  }

  Future<void> _scanBarcode(TextEditingController controller) async {
    final String? value = await openBarcodeScanner(context);
    if (value != null) setState(() => controller.text = value);
  }

  Map<String, dynamic> _draftClaim = {
    'docNumber': '',
    'type': 'เสียหาย',
    'carCode': '',
    'timestamp': DateTime.now(),
    'images': <File>[],
    'empID': '',
    'remarkType': null,
  };

  Future<void> _showClaimDialog({int? editIndex}) async {
    final Map<String, dynamic> initial = editIndex == null
        ? _draftClaim
        : claims[editIndex];

    final result = await showClaimFormDialog(
      context,
      initialDocNumber: (initial['docNumber'] ?? '').toString(),
      initialType: (initial['type'] ?? 'เสียหาย').toString(),
      initialCarCode: (initial['carCode'] ?? '').toString(),
      initialTimestamp: initial['timestamp'] ?? DateTime.now(),
      initialImages: List<File>.from(initial['images'] ?? []),
      initialRemark: initial['remark']?.toString(),
      empId: _userId ?? '',
      onScanBarcode: (ctx, controller) async {
        final String? value = await openBarcodeScanner(ctx);
        if (value != null) controller.text = value;
        return value;
      },
    );

    if (result == null) return;

    setState(() {
      final newClaim = {
        'docNumber': result.docNumber,
        'type': result.type,
        'carCode': result.carCode,
        'timestamp': result.timestamp,
        'images': List<File>.from(result.images),
        'empID': result.empId,
        'remarkType': result.remarkType,
      };
      if (editIndex == null) {
        claims.add(newClaim);
      } else {
        claims[editIndex] = newClaim;
      }
      claimCount = claims.length;
      _draftClaim = Map<String, dynamic>.from(newClaim);
    });
  }

  Future<String?> sendClaimToAPI({
    required String a1No,
    required String empId,
    required String folderName,
    required String imageName,
    required File imageFile,
    required double lat,
    required double lon,
    required String bearerToken,
  }) async {
    debugPrint('Attempting multipart upload for $imageName');
    final result = await claim_api.sendClaimToAPIMultipart(
      a1No: a1No,
      empId: empId,
      folderName: folderName,
      imageName: imageName,
      imageFile: imageFile,
      lat: lat,
      lon: lon,
      bearerToken: bearerToken,
    );

    if (result == null) {
      debugPrint('Multipart upload failed for $imageName, trying base64 fallback');
      return claim_api.sendClaimToAPI(
        a1No: a1No,
        empId: empId,
        folderName: folderName,
        imageName: imageName,
        imageFile: imageFile,
        lat: lat,
        lon: lon,
        bearerToken: bearerToken,
      );
    }

    debugPrint('Multipart upload successful for $imageName');
    return result;
  }

  Future<String?> _uploadImageWithRetry({
    required String a1No,
    required String empId,
    required String folderName,
    required String imageName,
    required File imageFile,
    required String token,
    required int maxRetries,
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        final result = await sendClaimToAPI(
          a1No: a1No,
          empId: empId,
          folderName: folderName,
          imageName: imageName,
          imageFile: imageFile,
          lat: 0.0,
          lon: 0.0,
          bearerToken: token,
        );

        if (result != null) {
          return result; 
        }

        attempts++;
        if (attempts < maxRetries) {
          await Future.delayed(Duration(seconds: attempts * 2));
        }
      } catch (e) {
        attempts++;
        debugPrint('Upload attempt ${attempts} failed: $e');

        if (attempts < maxRetries) {
          await Future.delayed(Duration(seconds: attempts * 2));
        }
      }
    }

    debugPrint('Failed to upload image after $maxRetries attempts');
    return null;
  }

  Future<Map<String, dynamic>> _buildSheetPayload(
    Map<String, dynamic> claim,
  ) async {
    return claim_api.buildSheetPayload(claim);
  }

  Future<_SimpleHttpResponse> _postJsonPreserveRedirect(
    Uri uri,
    String jsonBody,
  ) async {
    final resp = await claim_api.postJsonPreserveRedirect(uri, jsonBody);
    return _SimpleHttpResponse(resp.statusCode, resp.body);
  }

  Future<bool> _sendClaimToGoogleSheet(Map<String, dynamic> claim) async {
    _startOperation('sendClaimToGoogleSheet');

    try {
      final uri = Uri.parse('$_sheetEndpoint?key=$_sheetKey');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final empId = prefs.getString('driverID') ?? '';

      final List<File> images = List<File>.from(claim['images'] ?? []);
      List<String> uploadedLinks = [];

      if (images.isNotEmpty) {
        final ValueNotifier<int> uploadedCount = ValueNotifier<int>(0);
        final ValueNotifier<String> currentStatus = ValueNotifier<String>('กำลังเตรียมรูปภาพ...');

        claim_dialogs.showImageUploadDialog(
          context,
          totalImages: images.length,
          uploadedCount: uploadedCount,
          currentStatus: currentStatus,
        );

        try {
          final List<Future<String?>> uploadFutures = [];
          for (int i = 0; i < images.length; i++) {
            final File imageFile = images[i];
            final String fileName = 'image${i + 1}';
            uploadFutures.add(_uploadImageWithRetry(
              a1No: claim['docNumber'] ?? '',
              empId: empId,
              folderName: "Claim/${claim['docNumber'] ?? ''}",
              imageName: fileName,
              imageFile: imageFile,
              token: token,
              maxRetries: 3,
            ));
          }

          final List<String?> results = await Future.wait(uploadFutures);

          for (int i = 0; i < results.length; i++) {
            currentStatus.value = 'กำลังอัพโหลดรูปที่ ${i + 1}...';
            uploadedCount.value = i + 1;

            final link = results[i];
            if (link != null) {
              uploadedLinks.add(_normalizeUrl(link));
            } else {
              debugPrint('Failed to upload image ${i + 1}');
            }
          }

          if (uploadedLinks.length == images.length) {
            currentStatus.value = 'อัพโหลดสำเร็จทั้งหมด!';
          } else if (uploadedLinks.isNotEmpty) {
            currentStatus.value = 'อัพโหลดสำเร็จ ${uploadedLinks.length}/${images.length} รูป';
          } else {
            currentStatus.value = 'อัพโหลดล้มเหลวทั้งหมด';
          }

        } catch (e) {
          await _handleError('image_upload', e);
          currentStatus.value = 'เกิดข้อผิดพลาด: $e';
        } finally {
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        }
      }

      claim['uploadedLinks'] = uploadedLinks;
      claim['empId'] = empId;
      claim['empID'] = empId;
      claim['created_at'] = DateTime.now().toIso8601String();

      final payload = await _buildSheetPayload(claim);
      final String body = jsonEncode(payload);

      final _SimpleHttpResponse resp = await _postJsonPreserveRedirect(
        uri,
        body,
      );

      debugPrint('Sheet POST: ${resp.statusCode} ${resp.body}');

      final key = 'claim_history_$empId';
      List<String> savedClaims = prefs.getStringList(key) ?? [];
      savedClaims.add(body);
      await prefs.setStringList(key, savedClaims);
      _endOperation('sendClaimToGoogleSheet');
      return (resp.statusCode >= 200 && resp.statusCode < 400) ||
          resp.statusCode == 405;
    } catch (e) {
      await _handleError('sendClaimToGoogleSheet', e);
      _endOperation('sendClaimToGoogleSheet');
      return false;
    }
  }

  Future<void> _showLoadingDialog({String message = 'กำลังส่งข้อมูล...'}) async {
    await claim_dialogs.showLoadingDialog(context, message: message);
  }

  Future<void> _showResultDialog({
    String title = 'สำเร็จ',
    String message = 'ทำรายการสำเร็จ',
  }) async {
    await claim_dialogs.showResultDialog(context, title: title, message: message);
  }

  Future<void> _loadClaimHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> savedClaims = prefs.getStringList('claim_history') ?? [];

    final now = DateTime.now();
    final filteredClaims = savedClaims.where((e) {
      try {
        final Map<String, dynamic> claim = jsonDecode(e);
        final DateTime timestamp =
            DateTime.tryParse(claim['created_at'] ?? '') ?? now;
        return now.difference(timestamp).inDays <= 30;
      } catch (_) {
        return false;
      }
    }).toList();

    await prefs.setStringList('claim_history', filteredClaims);

    setState(() {
      var claimHistory = filteredClaims
          .map((e) => jsonDecode(e) as Map<String, dynamic>)
          .toList();
    });
  }

  Future<void> _sendAllClaimsToGoogleSheet() async {
    await AppLogger.I.log('claim_send_all_clicked', data: {'count': claims.length});
    if (claims.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ไม่มีรายการ Claim ให้ส่ง')));
      return;
    }

    setState(() {
      _isSendingAll = true;
    });

    try {
      _showLoadingDialog(message: 'กำลังส่ง Claim ทั้งหมด...');
      for (final claim in claims) {
        await AppLogger.I.log('claim_sending_item', data: {'docNumber': claim['docNumber']});
        await _sendClaimToGoogleSheet(claim);
      }

      if (!mounted) return;
      setState(() {
        _isSendingAll = false;
      });
      _closeAllDialogs();
      await _showResultDialog(
        title: 'สำเร็จ',
        message: 'ส่ง Claim สำเร็จทั้งหมด',
      );
      await AppLogger.I.log('claim_send_all_success');
    } catch (e) {
      setState(() {
        _isSendingAll = false;
      });
      _closeAllDialogs();
      await _showResultDialog(
        title: 'ผิดพลาด',
        message: 'เกิดข้อผิดพลาด: $e',
      );
      await AppLogger.I.log('claim_send_all_error', data: {'error': e.toString()});
    }
  }

  Future<void> _sendSingleClaim(int index) async {
    try {
      await AppLogger.I.log('claim_send_one_clicked', data: {'index': index, 'docNumber': claims[index]['docNumber']});
      _showLoadingDialog(message: 'กำลังส่งรายการ...');
      final ok = await _sendClaimToGoogleSheet(claims[index]);
      _closeAllDialogs();
      if (ok) {
        await AppLogger.I.log('claim_send_one_success', data: {'index': index});
        await _showResultDialog(
          title: 'สำเร็จ',
          message: 'ส่งรายการสำเร็จ',
        );
      } else {
        await AppLogger.I.log('claim_send_one_failed', data: {'index': index});
        await _showResultDialog(
          title: 'ผิดพลาด',
          message: 'ส่งรายการล้มเหลว',
        );
      }
    } catch (e) {
      await AppLogger.I.log('claim_send_one_exception', data: {'error': e.toString()});
      _closeAllDialogs();
      await _showResultDialog(
        title: 'ผิดพลาด',
        message: 'เกิดข้อผิดพลาด: $e',
      );
    }
  }


  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userId = prefs.getString('driverID') ?? '';
      });
      await AppLogger.I.log('claim_loaded_user', data: {'driverID': _userId});
    } catch (e) {
      debugPrint('Load user id failed: $e');
      await AppLogger.I.log('claim_load_user_error', data: {'error': e.toString()});
    }
  }

  // ignore: unused_element
  Future<void> _uploadAllClaims() async {
    if (claims.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ไม่มีรายการ Claim ให้ส่ง')));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final empId = prefs.getString('driverID');

    if (token == null || empId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบข้อมูลผู้ใช้ กรุณาเข้าสู่ระบบใหม่')),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('กำลังส่งข้อมูล Claim...')));

    try {
      for (final claim in claims) {
        final String a1No = (claim['docNumber'] ?? '').toString();
        final List<File> images = List<File>.from(claim['images'] ?? []);

        List<String> uploadedLinks = [];

        for (int i = 0; i < images.length; i++) {
          final File imageFile = images[i];
          final String imageName = 'image${i + 1}';

          final link = await sendClaimToAPI(
            a1No: a1No,
            empId: empId,
            folderName: "$a1No",
            imageName: imageName,
            imageFile: imageFile,
            lat: 0.0,
            lon: 0.0,
            bearerToken: token,
          );

          if (link != null) {
            uploadedLinks.add(link);
          }
        }

        claim['uploadedLinks'] = uploadedLinks;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ส่ง Claim สำเร็จ')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  // Future<File> resizeImage(File file, {int maxSize = 1080}) async {
  //   final bytes = await file.readAsBytes();
  //   final image = img.decodeImage(bytes);
  //   if (image == null) return file;

  //   final resized = img.copyResize(
  //     image,
  //     width: image.width > image.height ? maxSize : null,
  //     height: image.height >= image.width ? maxSize : null,
  //   );

  //   final newBytes = img.encodeJpg(resized, quality: 90);
  //   final newFile = await file.writeAsBytes(newBytes, flush: true);
  //   return newFile;
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        title: Text(
          'Claim สินค้า',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: _isSendingAll
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload, size: 28),
            tooltip: 'ส่งทั้งหมดไป Google Sheet',
            onPressed: (claims.isNotEmpty && !_isSendingAll)
                ? _sendAllClaimsToGoogleSheet
                : null,
          ),

          IconButton(
            icon: const Icon(Icons.history, size: 28),
            tooltip: 'ดูประวัติการเคลม',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClaimHistoryPage(userId: _userId ?? ''),
                ),
              );
            },
          ),

          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, size: 28),
                  tooltip: 'รีเซ็ต',
                  onPressed: claimCount > 0 ? _resetCount : null,
                  color: claimCount > 0
                      ? Theme.of(context).colorScheme.error
                      : null,
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
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        '$claimCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
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
                  title: Text(
                    'เลขเอกสาร: ${claim['docNumber']}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ประเภท: ${claim['type']}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'รหัสรถ: ${claim['carCode']}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (claim['type'] == 'ไม่ครบล็อต' && claim['remarkType'] != null && claim['remarkType'].toString().isNotEmpty)
                        Text(
                          'รายละเอียดเพิ่มเติม: ${claim['remarkType']}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontStyle: FontStyle.italic),
                        ),
                      Text(
                        'วันที่: ${DateFormat('dd/MM/yyyy').format(timestamp)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 12,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        tooltip: 'แก้ไขข้อมูล',
                        onPressed: () => _showClaimDialog(editIndex: index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.green),
                        tooltip: 'ส่งรายการนี้ไป Google Sheet',
                        onPressed: () => _sendSingleClaim(index),
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
