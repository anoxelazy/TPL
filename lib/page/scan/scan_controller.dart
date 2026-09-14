import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:claim/page/scan/scan_api.dart';

/// ผลของการส่งรูป 1 ครั้ง
class ScanUploadOutcome {
  final bool success;

  /// บาร์โค้ดใบที่ส่งจริง ไม่ใช่ค่าที่อยู่ในช่องตอนนี้
  /// ผู้ใช้อาจพิมพ์ทับช่องระหว่างที่รูปยังอัปโหลดอยู่
  final String barcode;

  /// ไบต์ของรูปที่ส่งสำเร็จ เอาไปบันทึกสำเนาลงคลังรูป
  final Uint8List? bytes;

  /// ข้อความสำหรับผู้ใช้เมื่อส่งไม่สำเร็จ
  final String? errorMessage;

  const ScanUploadOutcome.success(this.barcode, this.bytes)
    : success = true,
      errorMessage = null;

  const ScanUploadOutcome.failed(this.barcode, this.errorMessage)
    : success = false,
      bytes = null;
}

class ScanController extends ChangeNotifier {
  static const Duration checkDebounce = Duration(milliseconds: 400);

  String? _token;
  String _empId = '';

  String barcode = '';

  bool checking = false;

  /// null = ยังไม่เคยเช็ค (ซ่อนการ์ด)
  ScanCheckResult? checkResult;

  bool uploading = false;

  /// รูปที่กำลังส่ง ใช้โชว์ preview ในกรอบระหว่างอัปโหลด
  File? uploadingFile;

  /// เพิ่มขึ้นทุกครั้งที่เริ่มเช็คใหม่ ผลที่ seq ไม่ตรงคือของใบเก่า ทิ้งไป
  ///
  /// ยกเลิก timer เพียว ๆ ไม่พอ เพราะ request ที่ยิงออกไปแล้วยกเลิกไม่ได้
  /// แล้วผลใบเก่าจะกลับมาทับผลใบใหม่
  int _checkSeq = 0;

  Timer? _debounce;
  bool _disposed = false;

  bool get busy => checking || uploading;

  /// ถ่ายรูปได้เมื่อมีบาร์โค้ดแล้วและไม่ได้กำลังส่งอยู่
  bool get canTakePhoto => barcode.isNotEmpty && !uploading;

  @override
  void dispose() {
    _disposed = true;
    // ออกจากหน้าแล้วผลที่ค้างอยู่ต้องไม่ถูกนำมาใช้
    _checkSeq++;
    _debounce?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadSession() async {
    try {
      _token = await loadScanToken();
      _empId = await loadScanEmpId();
    } on ScanApiException catch (e) {
      checkResult = ScanCheckResult(
        status: ScanCheckStatus.error,
        message: e.message,
      );
    }
    _notify();
  }

  // ------------------------------------------------------------- เช็คบาร์โค้ด

  /// ผูกกับช่องบาร์โค้ด นิ่งครบ [checkDebounce] แล้วเช็คเอง ไม่ต้องกดปุ่ม
  void onBarcodeChanged(String value) {
    final next = value.trim();
    if (next == barcode) return;

    barcode = next;
    _debounce?.cancel();

    // เปลี่ยนบาร์โค้ดแล้ว ผลของใบก่อนหน้าใช้ไม่ได้อีก
    _checkSeq++;
    checking = false;
    checkResult = null;

    if (barcode.isEmpty) {
      _notify();
      return;
    }

    _debounce = Timer(checkDebounce, check);
    _notify();
  }

  /// เช็คทันที ใช้ตอนเติมค่าจากหน้าสแกนกล้องหรือกดลองใหม่
  Future<void> check() async {
    final target = barcode;
    if (target.isEmpty) return;

    final token = _token;
    if (token == null) {
      await loadSession();
      if (_token == null) return;
    }

    final seq = ++_checkSeq;
    checking = true;
    checkResult = null;
    _notify();

    final result = await checkIsTakeBar(barcode: target, token: _token!);

    // บาร์โค้ดเปลี่ยนไปแล้ว (หรือออกจากหน้าไปแล้ว) ระหว่างรอ response
    if (seq != _checkSeq || _disposed) return;

    checking = false;
    checkResult = result;
    _notify();
  }

  // -------------------------------------------------------------------- ส่งรูป

  /// ส่งรูปทันทีที่ได้มา ไม่มีปุ่มยืนยัน
  ///
  /// คืน null เมื่อถูก ignore (กำลังส่งอยู่ หรือช่องบาร์โค้ดว่าง)
  Future<ScanUploadOutcome?> upload(File file) async {
    if (uploading || barcode.isEmpty) return null;

    // จำบาร์โค้ดตอนเริ่มส่ง ใช้ค่านี้ทั้งใน request และในข้อความ error
    // เพราะผู้ใช้อาจพิมพ์ทับช่องระหว่างที่รูปยังอัปโหลดอยู่
    final sentBarcode = barcode;

    final token = _token;
    if (token == null) {
      await loadSession();
      if (_token == null) {
        return ScanUploadOutcome.failed(
          sentBarcode,
          'กรุณาถ่ายใหม่ $sentBarcode ส่งไม่สำเร็จ',
        );
      }
    }

    uploading = true;
    uploadingFile = file;
    _notify();

    try {
      final bytes = await uploadTrackingImage(
        barcode: sentBarcode,
        file: file,
        empId: _empId,
        token: _token!,
      );
      return ScanUploadOutcome.success(sentBarcode, bytes);
    } on ScanApiException catch (e) {
      // รายละเอียดทางเทคนิคไว้ให้ dev เท่านั้น ไม่โชว์บนจอ
      debugPrint('TrackingImg failed: ${e.debugDetail ?? e.message}');
      return ScanUploadOutcome.failed(sentBarcode, e.message);
    } finally {
      uploading = false;
      uploadingFile = null;
      _notify();
    }
  }

  /// เคลียร์ช่องเพื่อยิงใบถัดไป เรียกเฉพาะตอนส่งสำเร็จ
  void clearForNext() {
    _debounce?.cancel();
    _checkSeq++;
    barcode = '';
    checking = false;
    checkResult = null;
    _notify();
  }
}
