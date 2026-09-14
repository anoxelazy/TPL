import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:claim/page/claim/claim_form_page.dart';
import 'package:claim/widgets/image_widgets.dart';
import 'package:claim/page/claim/claim_api.dart' as claim_api;
import 'package:claim/page/claim/claim_dialogs.dart' as claim_dialogs;
import 'package:claim/page/claim/claim_scan.dart';
import 'package:claim/page/claim/image_utils.dart';
import 'package:claim/page/claim/claim_card.dart';
import 'package:claim/utils/app_logger.dart';
import 'package:claim/utils/claim_store.dart';

class _SimpleHttpResponse {
  final int statusCode;
  final String body;
  final bool noResponse;
  _SimpleHttpResponse(this.statusCode, this.body, {this.noResponse = false});
}

class ClaimPage extends StatefulWidget {
  final ValueNotifier<bool>? dialogOpenNotifier;
  final ValueNotifier<int>? unsentCountNotifier;

  const ClaimPage({
    super.key,
    this.dialogOpenNotifier,
    this.unsentCountNotifier,
  });

  @override
  State<ClaimPage> createState() => ClaimPageState();
}

String _normalizeUrl(String url) {
  final parts = url.split('://');
  if (parts.length != 2) return url;
  final protocol = parts[0];
  final rest = parts[1].replaceAll(RegExp(r'/+'), '/');
  return '$protocol://$rest';
}

class ClaimPageState extends State<ClaimPage> {
  final String _sheetEndpoint =
      'https://script.google.com/macros/s/AKfycbzMTA6IlcjnwwXWjO7-GA8NyfnX7rWvuqxKTnP0Vjs0iHEFZFswQsVl0CUwZeQR07up/exec';
  final String _sheetKey = '1407f066-e252-49aa-9099-a3f0942f319c';
  bool _isSendingAll = false;
  String? _userId;
  String? _userName;
  final Map<String, int> _a1SendCount = {};
  static const String _a1SendCountKey = 'a1_send_count';

  DateTime? _lastOperationTime;
  static const int _maxConcurrentOperations = 3;

  Future<void> _handleError(
    String operation,
    dynamic error, {
    StackTrace? stackTrace,
  }) async {
    debugPrint('Error in $operation: $error');
    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }

    await AppLogger.I.log(
      'claim_error',
      data: {
        'operation': operation,
        'error': error.toString(),
        'stackTrace': stackTrace?.toString(),
      },
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: ${error.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'ลองใหม่',
            textColor: Colors.white,
            onPressed: () {},
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
      debugPrint(
        'Operation $operation completed in ${duration.inMilliseconds}ms',
      );
      _lastOperationTime = null;
    }
  }

  void _closeAllDialogs() {
    Navigator.of(
      context,
      rootNavigator: true,
    ).popUntil((route) => route is PageRoute);
  }

  Future<void> _scanBarcode(TextEditingController controller) async {
    final String? value = await openBarcodeScanner(context);
    if (value != null) setState(() => controller.text = value);
  }

  Future<void> _showClaimDialog({int? editIndex}) async {
    widget.dialogOpenNotifier?.value = true;
    final Map<String, dynamic> initial = editIndex == null
        ? {
            'docNumber': '',
            'type': 'เสียหาย',
            'carCode': '',
            'timestamp': DateTime.now(),
            'images': <File>[],
            'empID': '',
            'remarkType': null,
            'isSent': false,
            'fromFrontStore': false,
          }
        : ClaimStore.I.claims[editIndex];

    final result = await Navigator.push<ClaimFormResult>(
      context,
      MaterialPageRoute(
        builder: (context) => ClaimFormPage(
          initialClaim: initial,
          empId: _userId ?? '',
          empName: _userName,
          onScanBarcode: (ctx, controller) async {
            final String? value = await openBarcodeScanner(ctx);
            if (value != null) controller.text = value;
            return value;
          },
        ),
      ),
    );

    widget.dialogOpenNotifier?.value = false;

    if (result == null) return;

    // คัดลอกรูปไปโฟลเดอร์ถาวรก่อน เพื่อให้รายการไม่หายเมื่อปิดแอป
    final Map<String, dynamic> newClaim = await ClaimStore.I.prepareClaim(
      {
        'docNumber': result.docNumber,
        'type': result.type,
        'carCode': result.carCode,
        'timestamp': result.timestamp,
        'images': List<File>.from(result.images),
        'empID': result.empId,
        'remarkType': result.remarkType,
        'fromFrontStore': result.fromFrontStore,
        'isSent': editIndex != null
            ? ClaimStore.I.claims[editIndex]['isSent'] ?? false
            : false,
      },
      id: editIndex != null
          ? ClaimStore.I.claims[editIndex]['id']?.toString()
          : null,
    );

    if (!mounted) return;

    setState(() {
      if (editIndex == null) {
        ClaimStore.I.addClaim(newClaim);
      } else {
        ClaimStore.I.updateClaim(editIndex, newClaim);
      }
      widget.unsentCountNotifier?.value = ClaimStore.I.unsentCount;
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
      debugPrint(
        'Multipart upload failed for $imageName, trying base64 fallback',
      );
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
    return _SimpleHttpResponse(
      resp.statusCode,
      resp.body,
      noResponse: resp.noResponse,
    );
  }

  Future<List<String>> _uploadImagesForClaim(
    Map<String, dynamic> claim,
    String token,
    String empId,
  ) async {
    final List<File> images = List<File>.from(claim['images'] ?? []);
    if (images.isEmpty) return [];

    final String a1No = claim['docNumber'] ?? '';
    final int sendCount = _a1SendCount[a1No] ?? 0;
    _a1SendCount[a1No] = sendCount + 1;
    await _saveA1SendCount();

    final ValueNotifier<int> uploadedCount = ValueNotifier<int>(0);
    final ValueNotifier<String> currentStatus = ValueNotifier<String>(
      'กำลังเตรียมรูปภาพ...',
    );

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
        final String baseName = 'image${i + 1}';
        final String fileName = sendCount > 0
            ? '$baseName($sendCount)'
            : baseName;
        uploadFutures.add(
          _uploadImageWithRetry(
            a1No: a1No,
            empId: empId,
            folderName: "Claim/$a1No",
            imageName: fileName,
            imageFile: imageFile,
            token: token,
            maxRetries: 3,
          ),
        );
      }

      final List<String?> results = await Future.wait(uploadFutures);
      final List<String> uploadedLinks = [];

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
        currentStatus.value =
            'อัพโหลดสำเร็จ ${uploadedLinks.length}/${images.length} รูป';
      } else {
        currentStatus.value = 'อัพโหลดล้มเหลวทั้งหมด';
      }

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      return uploadedLinks;
    } catch (e) {
      await _handleError('image_upload', e);
      currentStatus.value = 'เกิดข้อผิดพลาด: $e';
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        await _showResultDialog(
          title: 'ผิดพลาด',
          message: 'อัปโหลดรูปภาพล้มเหลว: ${e.toString()}',
        );
      }
      return [];
    }
  }

  Future<String?> _submitClaimToSheet(Map<String, dynamic> claim) async {
    try {
      final payload = await _buildSheetPayload(claim);
      final String a1No = payload['a1_no'] ?? '';
      final List imageLinks = payload['images'] ?? [];

      if (a1No.isEmpty) {
        debugPrint('A1 No is missing, skipping Google Sheet submission');
        return 'A1 No ไม่มีข้อมูล';
      }
      if (imageLinks.isEmpty) {
        debugPrint(
          'No image links available, skipping Google Sheet submission',
        );
        return 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ไม่มีลิงก์รูปภาพ ติดต่อเจ้าหน้าที่';
      }

      final uri = Uri.parse('$_sheetEndpoint?key=$_sheetKey');
      final String body = jsonEncode(payload);
      final _SimpleHttpResponse resp = await _postJsonPreserveRedirect(
        uri,
        body,
      );

      debugPrint('Sheet POST: ${resp.statusCode} ${resp.body}');

      if (resp.noResponse) {
        // ไม่ได้รับคำตอบ ≠ ล้มเหลว: Apps Script อาจเขียนข้อมูลลง Sheet
        // สำเร็จไปแล้วแต่ตอบกลับไม่ทัน จึงไม่บอกว่าล้มเหลวไปตรง ๆ
        await AppLogger.I.log(
          'claim_sheet_no_response',
          data: {'docNumber': a1No, 'detail': resp.body},
        );
        return 'ไม่ได้รับการยืนยันจากเซิร์ฟเวอร์ (เน็ตช้าหรือหมดเวลารอ)\n'
            'ข้อมูลอาจถูกบันทึกแล้ว กรุณาตรวจสอบใน Google Sheet ก่อนส่งซ้ำ';
      }

      return (resp.statusCode >= 200 && resp.statusCode < 400) ||
              resp.statusCode == 405
          ? null
          : 'ส่งข้อมูลไปยัง Google Sheet ล้มเหลว (Status: ${resp.statusCode})';
    } catch (e) {
      return 'เกิดข้อผิดพลาดในการส่ง: $e';
    }
  }

  Future<String?> _sendClaimToGoogleSheet(Map<String, dynamic> claim) async {
    _startOperation('sendClaimToGoogleSheet');

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final empId = prefs.getString('driverID') ?? '';

      final uploadedLinks = await _uploadImagesForClaim(claim, token, empId);

      claim['uploadedLinks'] = uploadedLinks;
      claim['empId'] = empId;
      claim['empID'] = empId;

      final result = await _submitClaimToSheet(claim);

      _endOperation('sendClaimToGoogleSheet');
      return result;
    } catch (e) {
      _endOperation('sendClaimToGoogleSheet');
      return 'เกิดข้อผิดพลาดในการส่ง: $e';
    }
  }

  Future<void> _showLoadingDialog({
    String message = 'กำลังส่งข้อมูล...',
  }) async {
    await claim_dialogs.showLoadingDialog(context, message: message);
  }

  Future<void> _showResultDialog({
    String title = 'สำเร็จ',
    String message = 'ทำรายการสำเร็จ',
  }) async {
    await claim_dialogs.showResultDialog(
      context,
      title: title,
      message: message,
    );
  }

  Future<void> _sendAllClaimsToGoogleSheet() async {
    await AppLogger.I.log(
      'claim_send_all_clicked',
      data: {'count': ClaimStore.I.count},
    );
    if (ClaimStore.I.claims.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ไม่มีรายการข้อมูลให้ส่ง')));
      return;
    }

    final bool hasSentClaims = ClaimStore.I.claims.any(
      (c) => c['isSent'] == true,
    );

    if (hasSentClaims) {
      final bool confirmed = await claim_dialogs.showConfirmResendDialog(
        context,
        message:
            'มีรายการที่ได้ส่งไปแล้ว คุณแน่ใจว่าต้องการส่งอีกครั้งหรือไม่?',
      );

      if (!confirmed) return;
    }

    setState(() {
      _isSendingAll = true;
    });

    try {
      _showLoadingDialog(message: 'กำลังส่งข้อมูลทั้งหมด...');
      for (final claim in ClaimStore.I.claims) {
        await AppLogger.I.log(
          'claim_sending_item',
          data: {'docNumber': claim['docNumber']},
        );
        await _sendClaimToGoogleSheet(claim);
      }

      if (!mounted) return;
      setState(() {
        _isSendingAll = false;
        for (var i = 0; i < ClaimStore.I.claims.length; i++) {
          ClaimStore.I.markAsSent(i);
        }
        widget.unsentCountNotifier?.value = ClaimStore.I.unsentCount;
      });
      _closeAllDialogs();
      await _showResultDialog(
        title: 'สำเร็จ',
        message: 'ส่งข้อมูลสำเร็จทั้งหมด',
      );
      await AppLogger.I.log('claim_send_all_success');
    } catch (e) {
      setState(() {
        _isSendingAll = false;
      });
      _closeAllDialogs();
      await _showResultDialog(title: 'ผิดพลาด', message: 'เกิดข้อผิดพลาด: $e');
      await AppLogger.I.log(
        'claim_send_all_error',
        data: {'error': e.toString()},
      );
    }
  }

  Future<void> _sendSingleClaim(int index) async {
    final bool isAlreadySent = ClaimStore.I.claims[index]['isSent'] ?? false;

    if (isAlreadySent) {
      final bool confirmed = await claim_dialogs.showConfirmResendDialog(
        context,
      );

      if (!confirmed) return;
    }

    try {
      await AppLogger.I.log(
        'claim_send_one_clicked',
        data: {
          'index': index,
          'docNumber': ClaimStore.I.claims[index]['docNumber'],
        },
      );

      final statusNotifier = await claim_dialogs.showSmartLoadingDialog(
        context,
        message: 'กำลังส่งรายการ...',
      );

      final error = await _sendClaimToGoogleSheet(ClaimStore.I.claims[index]);

      if (error == null) {
        statusNotifier.value = claim_dialogs.SendingStatus.success;

        setState(() {
          ClaimStore.I.markAsSent(index);
          widget.unsentCountNotifier?.value = ClaimStore.I.unsentCount;
        });
        await AppLogger.I.log('claim_send_one_success', data: {'index': index});

        await Future.delayed(const Duration(seconds: 2));
        _closeAllDialogs();
      } else {
        statusNotifier.value = claim_dialogs.SendingStatus.error;
        await Future.delayed(const Duration(seconds: 2));
        _closeAllDialogs();

        await AppLogger.I.log('claim_send_one_failed', data: {'index': index});
        await _showResultDialog(title: 'ผิดพลาด', message: error);
      }
    } catch (e) {
      await AppLogger.I.log(
        'claim_send_one_exception',
        data: {'error': e.toString()},
      );
      _closeAllDialogs();
      await _showResultDialog(title: 'ผิดพลาด', message: 'เกิดข้อผิดพลาด: $e');
    }
  }

  Future<void> _refreshClaims() async {
    await AppLogger.I.log('claim_refresh');
    setState(() {});
  }

  Future<void> _deleteClaim(int index) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ยืนยันการลบ'),
            content: const Text('คุณแน่ใจหรือว่าต้องการลบรายการนี้?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ลบ'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed && mounted) {
      ClaimStore.I.removeClaim(index);
      widget.unsentCountNotifier?.value = ClaimStore.I.unsentCount;
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ลบรายการเรียบร้อย')));
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserId();
    clearOldImageCache();
    _restoreClaims();
    ClaimStore.I.revision.addListener(_onStoreChanged);
  }

  /// โหลดรายการที่ค้างไว้จากครั้งก่อน (กรณีปิดแอปไปแล้วยังไม่ได้ส่ง)
  Future<void> _restoreClaims() async {
    await ClaimStore.I.init();
    if (!mounted) return;
    setState(() {});
    widget.unsentCountNotifier?.value = ClaimStore.I.unsentCount;
  }

  /// รายการถูกเปลี่ยนจากภายนอกหน้านี้ (ถูกลบเพราะหมดอายุตอนเที่ยงคืน)
  void _onStoreChanged() {
    if (!mounted) return;
    setState(() {});
    widget.unsentCountNotifier?.value = ClaimStore.I.unsentCount;

    final int purged = ClaimStore.I.lastPurgedCount;
    if (purged > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ขึ้นวันใหม่แล้ว ลบรายการของวันก่อนหน้าออก $purged รายการ',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  void dispose() {
    ClaimStore.I.revision.removeListener(_onStoreChanged);
    super.dispose();
  }

  Future<void> _loadUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userId = prefs.getString('driverID') ?? '';
        _userName = prefs.getString('driverName');
      });
      await AppLogger.I.log(
        'claim_loaded_user',
        data: {'driverID': _userId, 'driverName': _userName},
      );

      final countJson = prefs.getString(_a1SendCountKey);
      if (countJson != null) {
        final Map<String, dynamic> countMap = Map<String, dynamic>.from(
          jsonDecode(countJson) as Map,
        );
        _a1SendCount.clear();
        countMap.forEach((key, value) {
          _a1SendCount[key] = value as int;
        });
      }
    } catch (e) {
      debugPrint('Load user id failed: $e');
      await AppLogger.I.log(
        'claim_load_user_error',
        data: {'error': e.toString()},
      );
    }
  }

  Future<void> _saveA1SendCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final countJson = jsonEncode(_a1SendCount);
      await prefs.setString(_a1SendCountKey, countJson);
    } catch (e) {
      debugPrint('Save A1 send count failed: $e');
    }
  }

  Future<void> _uploadAllClaims() async {
    if (ClaimStore.I.claims.isEmpty) {
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
      for (final claim in ClaimStore.I.claims) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สินค้าเสียหาย/สูญหาย')),
      body: RefreshIndicator(
        onRefresh: _refreshClaims,
        child: ClaimStore.I.claims.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height - 100,
                    child: Center(
                      child: Text(
                        'ไม่มีรายการบันทึกสินค้า',
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: ClaimStore.I.claims.length,
                itemBuilder: (context, index) => ClaimListItem(
                  claim: ClaimStore.I.claims[index],
                  index: index,
                  onEdit: () => _showClaimDialog(editIndex: index),
                  onSend: () => _sendSingleClaim(index),
                  onDelete: () => _deleteClaim(index),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('สินค้าเสียหาย/สูญหาย'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        onPressed: () => _showClaimDialog(),
      ),
    );
  }
}
// เพิ่มด้านล่างไฟล์ claim.dart

class ClaimListItem extends StatelessWidget {
  final Map<String, dynamic> claim;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onSend;
  final VoidCallback onDelete;

  const ClaimListItem({
    super.key,
    required this.claim,
    required this.index,
    required this.onEdit,
    required this.onSend,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey(claim['docNumber'] ?? index),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: Colors.red,
            icon: Icons.delete,
            label: 'ลบ',
          ),
        ],
      ),
      child: ClaimCard(
        claim: claim,
        index: index,
        onEdit: onEdit,
        onSend: onSend,
      ),
    );
  }
}
