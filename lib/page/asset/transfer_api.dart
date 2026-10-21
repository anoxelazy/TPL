/// เรียก API ใบโอนย้ายทรัพย์สิน 10 เส้นในกลุ่ม AssetTransfer
///
/// แยกไฟล์จาก [asset_api.dart] เพราะเป็นคนละเรื่องกัน — อันนั้นคือทะเบียนของ
/// (ของชิ้นนี้คืออะไร อยู่ไหน) อันนี้คือเอกสารการเคลื่อนย้าย (ใครขอย้าย ใคร
/// อนุมัติ ส่งถึงหรือยัง)
///
/// ทุกเส้นต้องมี Bearer token เหมือนกลุ่มอื่น และใช้ตัวช่วยแปลง response
/// ชุดเดียวกัน ([unwrapMobileResponse], [assetMessageOf])
library;

import 'package:claim/page/asset/asset_api.dart';
import 'package:claim/page/asset/asset_json.dart';
import 'package:claim/page/asset/asset_models.dart';
import 'package:claim/page/asset/transfer_models.dart';
import 'package:claim/utils/mobile_api.dart';

const String _transfersPath = '/api/AssetTransfer/transfers';
const String _transferPath = '/api/AssetTransfer/transfer';
const String _pendingPath = '/api/AssetTransfer/transfers/pending';
const String _agingPath = '/api/AssetTransfer/transfers/aging';

String _docPath(String transferNo) =>
    '$_transferPath/${Uri.encodeComponent(transferNo.trim())}';

String _actionPath(String transferNo, String action) =>
    '${_docPath(transferNo)}/$action';

const MobileApiException _noSession = MobileApiException(
  'ยังไม่ได้เชื่อมต่อระบบทรัพย์สิน กรุณาเข้าสู่ระบบใหม่',
  needLogin: true,
);

/// ค้นใบโอนย้าย กรองและแบ่งหน้าฝั่งเซิร์ฟเวอร์ทั้งหมด
Future<AssetTransferSearchResult> fetchTransfers(
  AssetTransferQuery query,
) async {
  final options = MobileSession.I.authOptions(
    receiveTimeout: const Duration(seconds: 60),
  );
  if (options == null) throw _noSession;

  try {
    final response = await mobileDio.get(
      _transfersPath,
      queryParameters: query.toParams(),
      options: options,
    );

    final data = unwrapMobileResponse(response);
    if (data is Map) {
      return AssetTransferSearchResult.fromJson(
        Map<String, dynamic>.from(data),
      );
    }

    // เผื่อวันหนึ่งเส้นนี้ตอบเป็น array เปล่า ๆ แบบ /transfers/pending
    final rows = decodeAssetList(data);
    return AssetTransferSearchResult(
      items: [
        for (final row in rows) AssetTransferItem.fromJson(row),
      ].where((e) => e.transferNo.isNotEmpty).toList(),
      page: query.page,
      pageSize: query.pageSize,
      total: rows.length,
      totalPages: 1,
    );
  } on MobileApiException catch (e) {
    // ค้นแล้วไม่เจอไม่ใช่ความผิดพลาด หน้าจอควรขึ้นว่าไม่พบ ไม่ใช่ปุ่มลองใหม่
    if (!e.needLogin && e.message.contains('ไม่พบ')) {
      return AssetTransferSearchResult(
        page: query.page,
        pageSize: query.pageSize,
      );
    }
    rethrow;
  } catch (e) {
    throw MobileApiException(mobileNetworkMessage(e));
  }
}

/// ใบโอนย้ายใบเดียวแบบเต็ม คืน null เมื่อไม่มีเลขนี้
Future<AssetTransferDoc?> fetchTransfer(String transferNo) async {
  final options = MobileSession.I.authOptions();
  if (options == null) throw _noSession;

  try {
    final response = await mobileDio.get(
      _docPath(transferNo),
      options: options,
    );
    final data = unwrapMobileResponse(response);

    // รับทั้ง object เดี่ยวและลิสต์สมาชิกเดียว แบบเดียวกับ fetchAsset
    final rows = decodeAssetList(data);
    if (rows.isNotEmpty) return AssetTransferDoc.fromJson(rows.first);

    if (data is Map) {
      return AssetTransferDoc.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  } on MobileApiException catch (e) {
    if (!e.needLogin && e.message.contains('ไม่พบ')) return null;
    rethrow;
  } catch (e) {
    throw MobileApiException(mobileNetworkMessage(e));
  }
}

/// ใบที่รอให้คนที่ล็อกอินอยู่ทำอะไรสักอย่าง (อนุมัติ/ส่ง/รับ)
///
/// เซิร์ฟเวอร์คัดมาให้ตามสิทธิ์ของคนเรียกเอง แอปไม่ต้องกรองซ้ำ
Future<List<AssetTransferItem>> fetchPendingTransfers({int take = 50}) =>
    _getRows(
      _pendingPath,
      params: {'take': take},
      parse: AssetTransferItem.fromJson,
      keep: (item) => item.transferNo.isNotEmpty,
    );

/// ของที่ส่งออกไปแล้วเกินกำหนดแต่ยังไม่มีใครรับ
///
/// [minDaysOverdue] 1 = เลยกำหนดตั้งแต่หนึ่งวันขึ้นไป ตรงกับ default ของ API
Future<List<AssetTransitAging>> fetchTransitAging({
  String toSiteId = '',
  int minDaysOverdue = 1,
}) => _getRows(
  _agingPath,
  params: {
    if (toSiteId.trim().isNotEmpty) 'toSiteId': toSiteId.trim(),
    'minDaysOverdue': minDaysOverdue,
  },
  parse: AssetTransitAging.fromJson,
  keep: (row) => row.transferNo.isNotEmpty,
);

/// สร้างใบโอนย้ายใหม่ คืนเลขที่ใบที่เพิ่งสร้าง
///
/// ต่างจากเส้นอื่นตรงที่ต้องได้เลขใบกลับมา ไม่ใช่แค่ข้อความ เพราะหน้าจอต้อง
/// พาไปเปิดใบนั้นต่อทันที เลขอยู่ในช่อง `id` ของ `responseResult`
/// คนนี้สร้างใบโอนย้ายได้ไหม ดูจาก `permissions` ของ `/me`
///
/// ถาม `/me` ไม่ได้ (เน็ตหลุด ยังไม่ล็อกอิน) ให้ถือว่าได้ไว้ก่อน ปุ่มจะยังอยู่
/// แล้วเซิร์ฟเวอร์ตีกลับเองถ้าไม่มีสิทธิ์จริง ดีกว่าซ่อนปุ่มจากคนที่มีสิทธิ์
/// เพียงเพราะเน็ตช้า
Future<bool> canCreateTransfer() async {
  try {
    final me = await fetchAssetProfile();
    return me.can(kAssetPermTransferCreate);
  } on MobileApiException {
    return true;
  }
}

Future<String> createTransfer({
  required String toDeptCode,
  required String toSiteId,
  required DateTime expectedArrival,
  required String reason,
  required List<String> assetIds,
  String toCustodian = '',
  String crNo = '',
}) async {
  final options = MobileSession.I.authOptions();
  if (options == null) throw _noSession;

  try {
    final response = await mobileDio.post(
      _transferPath,
      data: buildTransferCreatePayload(
        toDeptCode: toDeptCode,
        toSiteId: toSiteId,
        expectedArrival: expectedArrival,
        reason: reason,
        assetIds: assetIds,
        toCustodian: toCustodian,
        crNo: crNo,
      ),
      options: options,
    );

    final data = _checkResult(unwrapMobileResponse(response));
    if (data is Map) {
      final id = jsonPick(Map<String, dynamic>.from(data), const ['id']);
      if (id.isNotEmpty) return id;
    }
    throw const MobileApiException(
      'สร้างใบโอนย้ายแล้วแต่ไม่ได้เลขที่ใบกลับมา กรุณาเปิดดูในรายการ',
    );
  } on MobileApiException {
    rethrow;
  } catch (e) {
    throw MobileApiException(mobileNetworkMessage(e));
  }
}

/// ส่งใบให้ผู้อนุมัติ
Future<String> submitTransfer(String transferNo) =>
    _action(transferNo, 'submit', fallback: 'ส่งใบให้ผู้อนุมัติแล้ว');

/// อนุมัติหรือไม่อนุมัติ
///
/// [reason] บังคับในทางปฏิบัติเมื่อไม่อนุมัติ — ฝั่ง schema ไม่ได้บังคับ แต่การ
/// ตีกลับโดยไม่บอกเหตุผลทำให้คนขอไม่รู้ว่าต้องแก้อะไร หน้าจอเป็นคนบังคับเอง
Future<String> approveTransfer(
  String transferNo, {
  required bool approve,
  String reason = '',
}) => _action(
  transferNo,
  'approve',
  body: buildTransferApprovePayload(approve: approve, reason: reason),
  fallback: approve ? 'อนุมัติใบโอนย้ายแล้ว' : 'ตีกลับใบโอนย้ายแล้ว',
);

/// บันทึกการส่งของออกจากต้นทาง
Future<String> dispatchTransfer(
  String transferNo, {
  String courierName = '',
  String trackingNo = '',
  String conditionOut = '',
}) => _action(
  transferNo,
  'dispatch',
  body: buildTransferDispatchPayload(
    courierName: courierName,
    trackingNo: trackingNo,
    conditionOut: conditionOut,
  ),
  fallback: 'บันทึกการส่งออกแล้ว',
);

/// รับของทีละชิ้น
///
/// ใบที่มีของหลายชิ้นต้องเรียกหลายครั้ง ชิ้นละครั้ง เซิร์ฟเวอร์เป็นคนปิดใบเองเมื่อ
/// รับครบ — แอปไม่ต้องเรียกอะไรเพิ่มตอนชิ้นสุดท้าย
Future<String> receiveTransferLine(
  String transferNo, {
  required String assetId,
  required String outcome,
  String note = '',
  String conditionIn = '',
  String photoPath = '',
}) => _action(
  transferNo,
  'receive',
  body: buildTransferReceivePayload(
    assetId: assetId,
    outcome: outcome,
    note: note,
    conditionIn: conditionIn,
    photoPath: photoPath,
  ),
  fallback: 'บันทึกการรับแล้ว',
);

/// ยกเลิกใบ
Future<String> cancelTransfer(String transferNo, {required String reason}) =>
    _action(
      transferNo,
      'cancel',
      body: buildTransferCancelPayload(reason: reason),
      fallback: 'ยกเลิกใบโอนย้ายแล้ว',
    );

/// ดึงลิสต์แล้วแปลงเป็นโมเดล ท่าเดียวกับทุกเส้น GET ที่ตอบเป็น array
Future<List<T>> _getRows<T>(
  String path, {
  required Map<String, dynamic> params,
  required T Function(Map<String, dynamic>) parse,
  required bool Function(T) keep,
}) async {
  final options = MobileSession.I.authOptions(
    receiveTimeout: const Duration(seconds: 60),
  );
  if (options == null) throw _noSession;

  try {
    final response = await mobileDio.get(
      path,
      queryParameters: params,
      options: options,
    );

    return [
      for (final row in decodeAssetList(unwrapMobileResponse(response)))
        parse(row),
    ].where(keep).toList();
  } on MobileApiException catch (e) {
    if (!e.needLogin && e.message.contains('ไม่พบ')) return const [];
    rethrow;
  } catch (e) {
    throw MobileApiException(mobileNetworkMessage(e));
  }
}

/// ขั้นตอนหนึ่งของใบ ทุกขั้นเป็น POST ที่คืน `responseResult` เหมือนกันหมด
Future<String> _action(
  String transferNo,
  String action, {
  Map<String, dynamic>? body,
  required String fallback,
}) async {
  final options = MobileSession.I.authOptions();
  if (options == null) throw _noSession;

  try {
    final response = await mobileDio.post(
      _actionPath(transferNo, action),
      data: body,
      options: options,
    );

    return assetMessageOf(
      _checkResult(unwrapMobileResponse(response)),
      fallback: fallback,
    );
  } on MobileApiException {
    rethrow;
  } catch (e) {
    throw MobileApiException(mobileNetworkMessage(e));
  }
}

/// `responseResult` มีช่อง `success` ของมันเอง ถ้าเซิร์ฟเวอร์ตอบ 2xx แต่
/// `success: false` ต้องถือว่าไม่สำเร็จ ไม่งั้นหน้าจอจะขึ้นว่าทำแล้วทั้งที่ใบไม่ขยับ
dynamic _checkResult(dynamic data) {
  if (data is Map) {
    final raw = jsonRaw(Map<String, dynamic>.from(data), const ['success']);
    if (raw != null && !jsonBool(raw, fallback: true)) {
      throw MobileApiException(
        assetMessageOf(data, fallback: 'ทำรายการไม่สำเร็จ'),
      );
    }
  }
  return data;
}
