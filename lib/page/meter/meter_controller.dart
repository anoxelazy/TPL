import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:claim/utils/app_logger.dart';
import 'package:claim/utils/location_service.dart';
import 'package:claim/page/meter/meter_api.dart';

/// ช่วงของวันที่ฟอร์มกำลังให้กรอก ตัดสินจากผลของ /getmeter
enum MeterPhase {
  /// ยังไม่มีไมล์ต้น กรอกไมล์ต้น + ถ่ายรูป แล้วบันทึกจบที่ dialog
  morning,

  /// มีไมล์ต้นครบแล้ว กรอกได้แค่ไมล์ปลาย บันทึกแล้วไปหน้าสรุปผล
  evening,

  /// มีทั้งไมล์ต้นและไมล์ปลาย บันทึกซ้ำไม่ได้ ดูผลย้อนหลังได้
  complete,
}

/// เหตุที่ขอพิกัดไม่ได้ ส่งให้หน้าจอไปขึ้น snackbar
class MeterGpsError {
  final LocationFailure failure;

  const MeterGpsError(this.failure);

  String get message =>
      'ไม่สามารถรับพิกัด GPS ได้ กรุณาถ่ายรูปใหม่หลังจากรับพิกัดเสร็จ';
}

/// สถานะของรูปไมล์ 1 ช่วง: ไฟล์ที่เลือกในเครื่อง + URL หลังอัปโหลด + พิกัด
class MeterImageState {
  /// ไฟล์ที่ผู้ใช้เพิ่งถ่าย/เลือก null เมื่อรูปมาจากข้อมูลเดิมบนเซิร์ฟเวอร์
  File? localFile;

  /// URL หลังอัปโหลดสำเร็จ หรือที่อ่านมาจาก /getmeter
  String? url;

  /// พิกัดตอนถ่ายรูปนี้ แต่ละช่วงเก็บแยกคนละคู่
  GeoPoint? gps;

  bool uploading = false;

  /// เลือกรูปแล้วแต่ยังไม่ได้ URL = ยังบันทึกไม่ได้
  bool get isPending => uploading || (localFile != null && url == null);

  bool get hasUrl => url != null;

  void clearLocal() {
    localFile = null;
    uploading = false;
  }
}

/// สมองของฟอร์มบันทึกไมล์: state machine, debounce, อัปโหลด, validate, บันทึก
///
/// แยกออกมาจาก widget เพื่อไม่ให้ network กับ validation ไปปนกับ UI
/// หน้าจอแค่ฟัง notifyListeners แล้ววาดตาม
class MeterController extends ChangeNotifier {
  MeterController();

  /// กันยิง /getmeter รัวทุกตัวอักษรที่พิมพ์
  static const Duration checkDebounce = Duration(milliseconds: 500);

  MeterSession? _session;

  String driverId = '';
  String truckId = '';

  int startMeter = 0;
  int endMeter = 0;

  final MeterImageState startImage = MeterImageState();
  final MeterImageState endImage = MeterImageState();

  /// TranDate ของ record วันนี้ ต้องส่งกลับตอนบันทึกไม่งั้นได้ record ใหม่
  DateTime? tranDate;

  MeterPhase phase = MeterPhase.morning;

  /// ข้อมูลเดิมของวันนี้ที่อ่านมาได้ ใช้ล็อกช่องไมล์ต้นในเคสเย็น
  MeterDay? existing;

  bool checking = false;
  bool saving = false;

  /// ข้อความ error ของการเช็คข้อมูลเดิม (แสดงใต้ช่องกรอก)
  String? checkError;

  /// true เมื่อ error ล่าสุดคือ token หมดอายุ หน้าจอจะชวนไป login ใหม่
  bool sessionExpired = false;

  Timer? _debounce;
  int _checkSeq = 0;
  bool _disposed = false;

  bool get uploading => startImage.uploading || endImage.uploading;

  bool get busy => checking || saving || uploading;

  /// ไมล์ต้นล็อกเมื่อเซิร์ฟเวอร์มีข้อมูลครบของช่วงนั้นแล้ว
  bool get startLocked => existing?.start.isComplete == true;

  bool get endLocked => existing?.end.isComplete == true;

  /// ระยะทางไว้ให้ผู้ใช้ดูคร่าว ๆ ในฟอร์มเท่านั้น
  /// ตัวเลขเงินทุกตัวมาจาก response ของ /InputMeter ห้ามคิดเองในแอป
  int get previewDistance {
    if (endMeter <= 0 || startMeter <= 0) return 0;
    final diff = endMeter - startMeter;
    return diff > 0 ? diff : 0;
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// โหลด token/ชื่อ/สาขา ครั้งเดียวตอนเปิดหน้า
  Future<MeterSession> session() async {
    return _session ??= await loadMeterSession();
  }

  Future<void> loadSession() async {
    try {
      await session();
      sessionExpired = false;
    } on MeterApiException catch (e) {
      checkError = e.message;
      sessionExpired = e.isUnauthorized;
    }
    _notify();
  }

  String get recorderName => _session?.name ?? '';

  // ---------------------------------------------------------------- ข้อมูลเดิม

  /// ผูกกับช่องรหัสคนขับและหมายเลขรถ ครบทั้งคู่แล้วเช็คเองหลัง debounce
  void onIdentityChanged({String? driver, String? truck}) {
    if (driver != null) driverId = driver.trim();
    if (truck != null) truckId = truck.trim();

    _debounce?.cancel();

    // ข้อมูลที่โหลดมาเป็นของคนขับ/รถคู่ก่อนหน้า ห้ามค้างไว้ให้บันทึกข้ามคู่
    // แต่ถ้ายังไม่เคยโหลดอะไรมา สิ่งที่อยู่ในฟอร์มคือของที่ผู้ใช้กรอกเอง
    // (เช่นแก้หมายเลขรถหลังพิมพ์เลขไมล์ไปแล้ว) ต้องไม่ล้างทิ้ง
    if (existing != null) {
      _clearLoaded();
    } else {
      _checkSeq++;
      checking = false;
      checkError = null;
      phase = MeterPhase.morning;
    }

    if (driverId.isEmpty || truckId.isEmpty) {
      _notify();
      return;
    }

    _debounce = Timer(checkDebounce, checkExisting);
    _notify();
  }

  /// ยิง /getmeter ทันที ใช้ตอนกลับจากหน้าสรุปผลหรือกดลองใหม่
  Future<void> checkExisting() async {
    if (driverId.isEmpty || truckId.isEmpty) return;

    final seq = ++_checkSeq;
    checking = true;
    checkError = null;
    _notify();

    try {
      final s = await session();
      final day = await fetchTodayMeter(
        driverId: driverId,
        truckId: truckId,
        session: s,
      );

      // ผู้ใช้เปลี่ยนคนขับ/รถระหว่างรอ ผลชุดนี้ไม่ใช้แล้ว
      if (seq != _checkSeq) return;

      _applyExisting(day);
      await AppLogger.I.log(
        'meter_check_existing',
        data: {
          'driverId': driverId,
          'truckId': truckId,
          'phase': phase.name,
          'found': day != null,
        },
      );
    } on MeterApiException catch (e) {
      if (seq != _checkSeq) return;
      checkError = e.message;
      sessionExpired = e.isUnauthorized;
    } finally {
      if (seq == _checkSeq) {
        checking = false;
        _notify();
      }
    }
  }

  /// ล้างทุกอย่างที่มาจากข้อมูลของคนขับ/รถคู่ก่อนหน้า
  void _clearLoaded() {
    _checkSeq++;
    existing = null;
    tranDate = null;
    phase = MeterPhase.morning;
    checkError = null;
    checking = false;
    startMeter = 0;
    endMeter = 0;
    startImage
      ..localFile = null
      ..url = null
      ..gps = null
      ..uploading = false;
    endImage
      ..localFile = null
      ..url = null
      ..gps = null
      ..uploading = false;
  }

  void _applyExisting(MeterDay? day) {
    existing = day;
    tranDate = day?.tranDate;

    if (day == null) {
      phase = MeterPhase.morning;
      return;
    }

    // เติมค่าเดิมกลับเข้าฟอร์ม ผู้ใช้เปิดแอปใหม่จะเห็นของเดิมเด้งขึ้นมา
    if (day.start.hasMeter) startMeter = day.start.meter;
    if (day.start.hasImage) {
      startImage
        ..localFile = null
        ..url = day.start.imageUrl
        ..gps = day.start.gps?.toPoint();
    }

    if (day.end.hasMeter) endMeter = day.end.meter;
    if (day.end.hasImage) {
      endImage
        ..localFile = null
        ..url = day.end.imageUrl
        ..gps = day.end.gps?.toPoint();
    }

    phase = phaseFor(day);
  }

  /// ตัดสินช่วงของวันจากข้อมูลที่เซิร์ฟเวอร์มี
  ///
  /// "มีข้อมูลแล้ว" ต้องเข้ม คือมีทั้งเลขไมล์ > 0 และรูปที่ใช้งานได้
  /// เลขไมล์มาแต่ไม่มีรูปยังไม่นับ ให้ผู้ใช้กลับมาเติมรูปได้
  static MeterPhase phaseFor(MeterDay? day) {
    if (day == null) return MeterPhase.morning;
    if (!day.start.isComplete) return MeterPhase.morning;
    if (!day.end.isComplete) return MeterPhase.evening;
    return MeterPhase.complete;
  }

  // -------------------------------------------------------------------- ตัวเลข

  void setStartMeter(int value) {
    if (startMeter == value) return;
    startMeter = value;
    _notify();
  }

  void setEndMeter(int value) {
    if (endMeter == value) return;
    endMeter = value;
    _notify();
  }

  // --------------------------------------------------------------------- รูป

  /// ถ่ายรูปแล้ว: ขอพิกัดก่อน ได้พิกัดจึงอัปโหลด
  ///
  /// ขอพิกัดไม่ได้จะยกเลิกทั้งหมดและทิ้งไฟล์ที่เลือก เพื่อไม่ให้เหลือรูป
  /// ที่ไม่มี URL ค้างไว้บล็อกปุ่มบันทึก คืน error ให้หน้าจอไปแจ้งผู้ใช้
  Future<Object?> attachImage(MeterSideKind side, File file) async {
    final state = side == MeterSideKind.start ? startImage : endImage;

    state
      ..localFile = file
      ..uploading = true;
    _notify();

    final location = await LocationService.I.current();
    if (!location.isSuccess) {
      state
        ..clearLocal()
        ..gps = null;
      _notify();
      await AppLogger.I.log(
        'meter_gps_failed',
        data: {'side': side.slug, 'reason': location.failure!.name},
      );
      return MeterGpsError(location.failure!);
    }

    state.gps = location.point;
    _notify();

    try {
      final s = await session();
      final url = await uploadMeterImage(
        driverId: driverId,
        file: file,
        side: side,
        session: s,
      );

      // ผู้ใช้เลือกรูปใหม่ทับระหว่างที่รูปนี้ยังอัปโหลดอยู่ ผลนี้ทิ้งไป
      if (state.localFile?.path != file.path) return null;

      state
        ..url = url
        ..uploading = false;
      _notify();
      return null;
    } on MeterApiException catch (e) {
      if (state.localFile?.path == file.path) {
        state.clearLocal();
        _notify();
      }
      sessionExpired = e.isUnauthorized;
      return e;
    }
  }

  // -------------------------------------------------------------- validate

  /// เช็คก่อนบันทึกตามลำดับที่ตกลงไว้ คืนข้อความแรกที่ไม่ผ่าน
  ///
  /// [asDialog] = true คือควรขึ้น dialog, false คือ snackbar เตือนเฉย ๆ
  MeterValidation? validate() {
    if (uploading || startImage.isPending || endImage.isPending) {
      return const MeterValidation(
        'กรุณารอให้อัปโหลดรูปเสร็จก่อน',
        asDialog: false,
      );
    }

    if (startMeter <= 0) {
      return const MeterValidation('กรุณากรอกเลขไมล์ต้นก่อนบันทึก');
    }

    if (!startImage.hasUrl) {
      return const MeterValidation(
        'กรุณาถ่ายรูปไมล์ต้นและรออัปโหลดให้เสร็จก่อนบันทึก',
      );
    }

    if (phase == MeterPhase.complete) {
      return const MeterValidation(
        'ข้อมูลครบแล้ว ใช้ปุ่มดูรายละเอียดการชดเชยน้ำมันได้เลย',
        asDialog: false,
      );
    }

    if (phase == MeterPhase.evening) {
      if (endMeter <= 0) {
        return const MeterValidation('กรุณากรอกเลขไมล์ปลายก่อนบันทึกช่วงเย็น');
      }
      if (!endImage.hasUrl) {
        return const MeterValidation(
          'กรุณาถ่ายรูปไมล์ปลายและรออัปโหลดให้เสร็จก่อนบันทึก',
        );
      }
    }

    return null;
  }

  // ----------------------------------------------------------------- บันทึก

  /// บันทึกไมล์ คืนผลคำนวณจากเซิร์ฟเวอร์
  ///
  /// ช่วงเช้ายังไม่มีไมล์ปลาย จะส่ง EndMeter เป็น 0 / "" / null ตามที่
  /// เซิร์ฟเวอร์รับ และหน้าจอจะไม่พาไปหน้าสรุปผลเพราะยังไม่มีอะไรให้คำนวณ
  ///
  /// เคสข้อมูลครบแล้วก็เรียกตัวนี้เพื่อขอผลย้อนหลัง เพราะ /InputMeter เป็น
  /// endpoint เดียวที่คืนตัวเลขเงิน และส่ง TranDate เดิมไปจึงทับ record เดิม
  /// ไม่ได้สร้างใหม่
  Future<MeterResult> save() async {
    saving = true;
    _notify();

    try {
      final s = await session();
      final includeEnd = endMeter > 0 && endImage.hasUrl;

      final result = await saveMeter(
        driverId: driverId,
        truckId: truckId,
        session: s,
        tranDate: tranDate,
        startMeter: startMeter,
        startImageUrl: startImage.url,
        startGps: startImage.gps,
        endMeter: includeEnd ? endMeter : 0,
        endImageUrl: includeEnd ? endImage.url : null,
        endGps: includeEnd ? endImage.gps : null,
      );

      await AppLogger.I.log(
        'meter_saved',
        data: {
          'driverId': driverId,
          'truckId': truckId,
          'phase': phase.name,
          'startMeter': startMeter,
          'endMeter': includeEnd ? endMeter : 0,
        },
      );

      return result;
    } on MeterApiException catch (e) {
      sessionExpired = e.isUnauthorized;
      rethrow;
    } finally {
      saving = false;
      _notify();
    }
  }
}

/// ข้อความที่ต้องแจ้งผู้ใช้เมื่อ validate ไม่ผ่าน
class MeterValidation {
  final String message;

  /// spec กำหนดว่าบางข้อขึ้น dialog บางข้อเตือนเฉย ๆ
  final bool asDialog;

  const MeterValidation(this.message, {this.asDialog = true});
}
