/// ทะเบียนทรัพย์สินอยู่บน Mobile API ตัวใหม่ (HTTPS) เหมือนระบบ PM กับแจ้งเคส
///
/// ทุก endpoint ต้องแนบ Bearer token ที่ได้จาก `/api/Auth/login` ยังไม่มี token
/// จะโยน [MobileApiException] ที่ตั้ง needLogin ไว้ หน้าจอจะได้บอกให้ล็อกอินใหม่
/// แทนที่จะบอกให้กดลองใหม่ซึ่งกดกี่ทีก็ไม่ผ่าน
library;

import 'dart:convert';

import 'package:claim/page/asset/asset_models.dart';
import 'package:claim/utils/mobile_api.dart';

const String _statusListPath = '/api/AssetTransfer/statuslist';
const String _typeListPath = '/api/AssetTransfer/assettypelist';
const String _insertTypePath = '/api/AssetTransfer/assettype';
const String _insertAssetPath = '/api/AssetTransfer/asset';

/// ประเภททรัพย์สินทั้งหมดที่มีให้เลือก
Future<List<AssetLookup>> fetchAssetTypes() => _fetchLookups(_typeListPath);

/// สถานะทรัพย์สินทั้งหมดที่มีให้เลือก
Future<List<AssetLookup>> fetchAssetStatuses() =>
    _fetchLookups(_statusListPath);

/// เพิ่มประเภททรัพย์สินใหม่ คืนข้อความที่เซิร์ฟเวอร์ตอบมา
Future<String> insertAssetType({
  required String typeId,
  required String descTh,
  required String descEn,
}) => _post(
  _insertTypePath,
  buildAssetTypePayload(typeId: typeId, descTh: descTh, descEn: descEn),
  fallback: 'เพิ่มประเภททรัพย์สินแล้ว',
);

/// ลงทะเบียนทรัพย์สิน 1 ชิ้น คืนข้อความที่เซิร์ฟเวอร์ตอบมา
///
/// รับค่าดิบจากฟอร์มแล้วให้ [buildAssetPayload] เป็นคนตัดช่องว่างกับคัดช่องที่
/// ไม่ได้กรอกทิ้ง ผู้เรียกไม่ต้องจัดการเอง
Future<String> insertAsset({
  required String assetId,
  required String assetName,
  required String assetType,
  String serialNo = '',
  String brand = '',
  String model = '',
  String statusId = '',
  String siteId = '',
  String custodian = '',
  String remark = '',
  DateTime? acceptDate,
  DateTime? purchaseDate,
  DateTime? warrantyExpireDate,
  double? purchasePrice,
}) => _post(
  _insertAssetPath,
  buildAssetPayload(
    assetId: assetId,
    assetName: assetName,
    assetType: assetType,
    serialNo: serialNo,
    brand: brand,
    model: model,
    statusId: statusId,
    siteId: siteId,
    custodian: custodian,
    remark: remark,
    acceptDate: acceptDate,
    purchaseDate: purchaseDate,
    warrantyExpireDate: warrantyExpireDate,
    purchasePrice: purchasePrice,
  ),
  fallback: 'บันทึกทรัพย์สินแล้ว',
);

Future<List<AssetLookup>> _fetchLookups(String path) async {
  final options = MobileSession.I.authOptions();
  if (options == null) throw _noSession;

  try {
    final response = await mobileDio.get(path, options: options);
    final rows = decodeAssetList(unwrapMobileResponse(response));

    return [
      for (final row in rows) AssetLookup.fromJson(row),
    ].where((e) => e.code.isNotEmpty).toList();
  } on MobileApiException catch (e) {
    // ตารางยังไม่มีข้อมูลสักแถว backend ตอบ 404 พร้อมข้อความไทย ไม่ใช่ลิสต์ว่าง
    // (ทำแบบเดียวกับ joblist ของระบบแจ้งเคส) กรณีนี้ไม่ใช่ความผิดพลาด
    if (!e.needLogin && e.message.contains('ไม่พบ')) return const [];
    rethrow;
  } catch (e) {
    throw MobileApiException(mobileNetworkMessage(e));
  }
}

Future<String> _post(
  String path,
  Map<String, dynamic> body, {
  required String fallback,
}) async {
  final options = MobileSession.I.authOptions();
  if (options == null) throw _noSession;

  try {
    final response = await mobileDio.post(path, data: body, options: options);
    return assetMessageOf(unwrapMobileResponse(response), fallback: fallback);
  } on MobileApiException {
    rethrow;
  } catch (e) {
    throw MobileApiException(mobileNetworkMessage(e));
  }
}

const MobileApiException _noSession = MobileApiException(
  'ยังไม่ได้เชื่อมต่อระบบทรัพย์สิน กรุณาเข้าสู่ระบบใหม่',
  needLogin: true,
);

/// แกะ response ที่เป็นลิสต์ออกเป็นรายการของแถว
///
/// เผื่อไว้สามแบบเพราะยังไม่เคยเห็นของจริง (ยิงแล้วติด 401): เป็น JSON array
/// ปกติ, เป็นสตริง JSON ที่ต้อง decode ซ้ำ (กลุ่ม ITRepair ตอบแบบนี้บางตัว)
/// และเป็นลิสต์ของข้อความล้วนที่ไม่มีชื่อช่องกำกับ
List<Map<String, dynamic>> decodeAssetList(dynamic data) {
  dynamic decoded = data;

  if (decoded is String) {
    final text = decoded.trim();
    if (text.isEmpty) return const [];
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return const [];
    }
  }

  if (decoded is! List) return const [];

  return [
    for (final item in decoded)
      if (item is Map)
        Map<String, dynamic>.from(item)
      else if (item != null && item is! Iterable)
        {'code': item.toString()},
  ];
}

/// ข้อความที่เอาไปโชว์หลังบันทึก
///
/// บาง endpoint ของ API ตัวนี้ตอบข้อความเปล่า ๆ บางอันห่อเป็น JSON มา
/// เอา `toString()` ของ Map ไปโชว์ตรง ๆ ผู้ใช้จะเห็นวงเล็บปีกกาติดมาทั้งก้อน
String assetMessageOf(dynamic data, {required String fallback}) {
  dynamic decoded = data;

  if (decoded is String) {
    final text = decoded.trim();
    if (text.isEmpty) return fallback;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return text;
    }
  }

  if (decoded is Map) {
    for (final key in const ['message', 'msg', 'result', 'description']) {
      for (final entry in decoded.entries) {
        if (entry.key.toString().toLowerCase() != key) continue;
        final text = entry.value?.toString().trim() ?? '';
        if (text.isNotEmpty) return text;
      }
    }
    return fallback;
  }

  final text = decoded?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

const String _assetListPath = '/api/AssetTransfer/assets';

String _assetPath(String assetId) =>
    '/api/AssetTransfer/asset/${Uri.encodeComponent(assetId.trim())}';

/// ค้นทะเบียนทรัพย์สิน กรองและแบ่งหน้าฝั่งเซิร์ฟเวอร์ทั้งหมด
///
/// ไม่โหลดทั้งก้อนมากรองในเครื่องแบบระบบ PM เพราะ endpoint นี้มีตัวกรองกับ
/// แบ่งหน้าให้ครบ และทะเบียนทรัพย์สินโตขึ้นเรื่อย ๆ ไม่มีเพดาน
Future<AssetSearchResult> fetchAssets(AssetQuery query) async {
  final options = MobileSession.I.authOptions(
    receiveTimeout: const Duration(seconds: 60),
  );
  if (options == null) throw _noSession;

  try {
    final response = await mobileDio.get(
      _assetListPath,
      queryParameters: query.toParams(),
      options: options,
    );

    return parseAssetSearch(
      unwrapMobileResponse(response),
      page: query.page,
      pageSize: query.pageSize,
    );
  } on MobileApiException catch (e) {
    // ค้นแล้วไม่เจอไม่ใช่ความผิดพลาด หน้าจอควรขึ้นว่า "ไม่พบ" ไม่ใช่ปุ่มลองใหม่
    if (!e.needLogin && e.message.contains('ไม่พบ')) {
      return AssetSearchResult(
        items: const [],
        page: query.page,
        pageSize: query.pageSize,
        total: 0,
      );
    }
    rethrow;
  } catch (e) {
    throw MobileApiException(mobileNetworkMessage(e));
  }
}

/// รายละเอียดทรัพย์สินชิ้นเดียว คืน null เมื่อไม่มีรหัสนี้ในระบบ
Future<Asset?> fetchAsset(String assetId) async {
  final options = MobileSession.I.authOptions();
  if (options == null) throw _noSession;

  try {
    final response = await mobileDio.get(_assetPath(assetId), options: options);
    final data = unwrapMobileResponse(response);

    // บาง endpoint ของ API ตัวนี้ตอบของชิ้นเดียวมาเป็นลิสต์ที่มีสมาชิกตัวเดียว
    // (jobdetails ของระบบแจ้งเคสเป็นแบบนั้น) จึงรับทั้งสองรูป
    final rows = decodeAssetList(data);
    if (rows.isNotEmpty) return Asset.fromJson(rows.first);

    if (data is Map) return Asset.fromJson(Map<String, dynamic>.from(data));
    return null;
  } on MobileApiException catch (e) {
    if (!e.needLogin && e.message.contains('ไม่พบ')) return null;
    rethrow;
  } catch (e) {
    throw MobileApiException(mobileNetworkMessage(e));
  }
}

/// ประวัติการเปลี่ยนแปลงของทรัพย์สินชิ้นนี้ ใหม่สุดขึ้นก่อน
///
/// ไม่ไว้ใจลำดับที่ API ส่งมา endpoint อื่นของระบบนี้ก็ไม่ได้เรียงมาให้
Future<List<AssetLogEntry>> fetchAssetLog(
  String assetId, {
  int take = kAssetLogTake,
}) async {
  final options = MobileSession.I.authOptions();
  if (options == null) throw _noSession;

  try {
    final response = await mobileDio.get(
      '${_assetPath(assetId)}/log',
      queryParameters: {'take': take},
      options: options,
    );

    final entries = [
      for (final row in decodeAssetList(unwrapMobileResponse(response)))
        AssetLogEntry.fromJson(row),
    ].where((e) => e.isUsable).toList();

    sortAssetLog(entries);
    return entries;
  } on MobileApiException catch (e) {
    // ของที่เพิ่งลงทะเบียนยังไม่เคยถูกแก้ ประวัติว่างเป็นเรื่องปกติ
    if (!e.needLogin && e.message.contains('ไม่พบ')) return const [];
    rethrow;
  } catch (e) {
    throw MobileApiException(mobileNetworkMessage(e));
  }
}

/// เรียงประวัติใหม่สุดขึ้นก่อน แถวที่ไม่มีวันที่ไปต่อท้าย
void sortAssetLog(List<AssetLogEntry> entries) {
  entries.sort((a, b) {
    final left = a.at;
    final right = b.at;

    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return right.compareTo(left);
  });
}

/// แก้ไขทรัพย์สิน — ตัวเดียวกับที่ใช้โอนย้าย
///
/// การโอนย้ายในระบบนี้คือการเปลี่ยน `current_site_id` / `current_custodian`
/// ของชิ้นนั้น ไม่มี endpoint แยก เหตุผลที่กรอก ([changeNote]) กับเลขเอกสาร
/// อ้างอิง ([refNo]) จะไปโผล่ใน `/log` ให้ตรวจย้อนหลังได้
///
/// [next] คือสถานะที่อยากให้เป็นทั้งก้อน ไม่ใช่เฉพาะช่องที่แก้
Future<String> updateAsset({
  required String assetId,
  required Asset next,
  required String changeNote,
  String refNo = '',
}) async {
  final options = MobileSession.I.authOptions();
  if (options == null) throw _noSession;

  try {
    final response = await mobileDio.put(
      _assetPath(assetId),
      data: buildAssetUpdatePayload(
        next: next,
        changeNote: changeNote,
        refNo: refNo,
      ),
      options: options,
    );

    return assetMessageOf(
      unwrapMobileResponse(response),
      fallback: 'บันทึกการเปลี่ยนแปลงแล้ว',
    );
  } on MobileApiException {
    rethrow;
  } catch (e) {
    throw MobileApiException(mobileNetworkMessage(e));
  }
}

/// แกะผลค้นหาออกเป็นรายการ + ยอดรวม
///
/// รับสองรูปเพราะยังไม่เคยเห็นของจริง: ตอบเป็น array เปล่า ๆ (ยอดรวมไม่รู้)
/// หรือห่อมาเป็น object ที่มีทั้งรายการและยอดรวม ซึ่ง endpoint ที่มี `page`
/// กับ `page_size` มักทำแบบหลัง
AssetSearchResult parseAssetSearch(
  dynamic data, {
  required int page,
  required int pageSize,
}) {
  dynamic decoded = data;

  if (decoded is String) {
    final text = decoded.trim();
    if (text.isEmpty) {
      return AssetSearchResult(items: const [], page: page, pageSize: pageSize);
    }
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return AssetSearchResult(items: const [], page: page, pageSize: pageSize);
    }
  }

  dynamic rows = decoded;
  int? total;

  if (decoded is Map) {
    final byKey = {
      for (final entry in decoded.entries)
        entry.key.toString().toLowerCase().replaceAll(RegExp('[^a-z0-9]'), ''):
            entry.value,
    };

    for (final key in const [
      'items',
      'data',
      'list',
      'rows',
      'records',
      'result',
      'assets',
    ]) {
      final value = byKey[key];
      if (value is List) {
        rows = value;
        break;
      }
    }

    for (final key in const [
      'total',
      'totalcount',
      'totalrecords',
      'totalitems',
      'recordcount',
      'count',
    ]) {
      final value = byKey[key];
      final parsed = value is num ? value.toInt() : int.tryParse('$value');
      if (parsed != null) {
        total = parsed;
        break;
      }
    }
  }

  final items = [
    for (final row in decodeAssetList(rows)) Asset.fromJson(row),
  ].where((e) => e.id.isNotEmpty).toList();

  return AssetSearchResult(
    items: items,
    page: page,
    pageSize: pageSize,
    total: total,
  );
}

/// ── ไดเรกทอรี: สาขา พนักงาน ผู้อนุมัติ และตัวตนของคนที่ล็อกอิน ──────────
///
/// สี่ endpoint กลุ่มนี้เป็นตัวที่ทำให้ช่อง "สาขา" กับ "ผู้ครอบครอง" เลิกเป็น
/// ช่องพิมพ์รหัสเปล่า ๆ ได้ พิมพ์ผิดหนึ่งตัวแปลว่าทรัพย์สินไปอยู่สาขาที่ไม่มีจริง
/// แล้วไม่มีอะไรฟ้อง เพราะ schema ฝั่งส่งเช็คแค่ความยาวไม่ได้เช็คว่ามีอยู่จริง

const String _mePath = '/api/AssetTransfer/me';
const String _branchPath = '/api/AssetTransfer/branch';
const String _employeePath = '/api/AssetTransfer/employee';

/// ตัวตนและสิทธิ์ของคนที่ล็อกอินอยู่ในระบบทรัพย์สิน
Future<AssetProfile> fetchAssetProfile() async {
  final options = MobileSession.I.authOptions();
  if (options == null) throw _noSession;

  try {
    final response = await mobileDio.get(_mePath, options: options);
    final data = unwrapMobileResponse(response);

    // endpoint นี้ตอบ object เดี่ยว แต่รับลิสต์สมาชิกเดียวไว้ด้วยแบบ fetchAsset
    // เพราะ endpoint อื่นบน API ตัวเดียวกันตอบของชิ้นเดียวมาเป็นลิสต์ก็มี
    final rows = decodeAssetList(data);
    if (rows.isNotEmpty) return AssetProfile.fromJson(rows.first);

    if (data is Map) {
      return AssetProfile.fromJson(Map<String, dynamic>.from(data));
    }
    throw const MobileApiException('อ่านข้อมูลผู้ใช้ระบบทรัพย์สินไม่สำเร็จ');
  } on MobileApiException {
    rethrow;
  } catch (e) {
    throw MobileApiException(mobileNetworkMessage(e));
  }
}

/// สาขาทั้งหมดที่เลือกเป็นปลายทางได้
///
/// [staffedOnly] ตัดสาขาที่ไม่มีคนประจำทิ้ง (260 เหลือ 60) ไม่ได้เปิดเป็นค่า
/// ตั้งต้นเพราะของก็ย้ายไปเก็บที่สาขาที่ยังไม่มีคนได้
Future<List<AssetBranch>> fetchAssetBranches({
  String keyword = '',
  int? branchTypeId,
  bool staffedOnly = false,
}) async {
  final options = MobileSession.I.authOptions(
    receiveTimeout: const Duration(seconds: 60),
  );
  if (options == null) throw _noSession;

  try {
    final response = await mobileDio.get(
      _branchPath,
      queryParameters: {
        if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
        if (branchTypeId != null) 'branchTypeId': branchTypeId,
        if (staffedOnly) 'staffedOnly': true,
      },
      options: options,
    );

    return [
      for (final row in decodeAssetList(unwrapMobileResponse(response)))
        AssetBranch.fromJson(row),
    ].where((e) => e.id.isNotEmpty).toList();
  } on MobileApiException catch (e) {
    if (!e.needLogin && e.message.contains('ไม่พบ')) return const [];
    rethrow;
  } catch (e) {
    throw MobileApiException(mobileNetworkMessage(e));
  }
}

/// ค้นพนักงาน ค้นได้ทั้งรหัสพนักงานและชื่อไทยผ่าน [keyword]
///
/// ค้นฝั่งเซิร์ฟเวอร์เพราะพนักงานทั้งบริษัทเกิน 500 คน โหลดมาทั้งก้อนเพื่อกรอง
/// ในเครื่องแบบลิสต์สาขาไม่คุ้ม
Future<List<AssetEmployee>> searchAssetEmployees({
  String keyword = '',
  String branchId = '',
  String deptCode = '',
  String permCode = '',
  int take = kAssetEmployeeTake,
}) async {
  final options = MobileSession.I.authOptions();
  if (options == null) throw _noSession;

  try {
    final response = await mobileDio.get(
      _employeePath,
      queryParameters: {
        if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
        if (branchId.trim().isNotEmpty) 'branchId': branchId.trim(),
        if (deptCode.trim().isNotEmpty) 'deptCode': deptCode.trim(),
        if (permCode.trim().isNotEmpty) 'permCode': permCode.trim(),
        'take': take,
      },
      options: options,
    );

    return [
      for (final row in decodeAssetList(unwrapMobileResponse(response)))
        AssetEmployee.fromJson(row),
    ].where((e) => e.id.isNotEmpty).toList();
  } on MobileApiException catch (e) {
    // ค้นแล้วไม่เจอไม่ใช่ความผิดพลาด ช่องค้นหาควรขึ้นว่าไม่พบ ไม่ใช่ปุ่มลองใหม่
    if (!e.needLogin && e.message.contains('ไม่พบ')) return const [];
    rethrow;
  } catch (e) {
    throw MobileApiException(mobileNetworkMessage(e));
  }
}

/// ลิสต์สาขาที่โหลดมาแล้วในรอบนี้ของแอป
///
/// สาขาเปลี่ยนแปลงปีละไม่กี่ครั้ง แต่ช่องเลือกสาขาถูกเปิดบ่อยมากในหนึ่งรอบงาน
/// (ลงทะเบียนของทีละสิบชิ้น) โหลดใหม่ทุกครั้งคือดาวน์โหลด 66 KB ซ้ำ ๆ บน 4G
/// ของสาขา เก็บไว้ในหน่วยความจำอย่างเดียว ปิดแอปแล้วหาย — ไม่ลง disk เพราะ
/// ข้อมูลพนักงาน/สาขาไม่ควรค้างในเครื่องที่ใช้ร่วมกันหลายคน
List<AssetBranch>? _branchCache;

/// ดัชนีรหัสสาขา → สาขา สร้างพร้อม [_branchCache]
///
/// มีไว้ให้ [assetBranchNameOf] อ่านแบบ O(1) จาก `build()` ของหน้าที่วาดหลาย
/// สิบแถว ไล่หาในลิสต์ 260 ตัวต่อแถวคือ 13,000 รอบต่อการวาดหนึ่งครั้ง
Map<String, AssetBranch> _branchById = const {};

/// ชื่อพนักงานที่เคยหามาแล้วในรอบนี้ เก็บ null ไว้ด้วยแปลว่า "หาแล้วไม่มีจริง"
///
/// ไม่ใช่แค่ประหยัดรอบยิง — รหัสผู้ครอบครองซ้ำกันเยอะมาก (ของสิบชิ้นในสาขา
/// เดียวมักถือโดยคนเดียวกัน) ไม่แคชคือยิง `/employee` ซ้ำรหัสเดิมสิบครั้ง
final Map<String, AssetEmployee?> _employeeById = {};

/// สาขาทั้งหมดแบบใช้ของที่โหลดไว้แล้วถ้ามี
///
/// [refresh] บังคับโหลดใหม่ ใช้ตอนผู้ใช้ดึงรีเฟรชเอง
Future<List<AssetBranch>> loadAssetBranches({bool refresh = false}) async {
  final cached = _branchCache;
  if (!refresh && cached != null) return cached;

  final branches = await fetchAssetBranches();
  _branchCache = branches;
  _branchById = {for (final branch in branches) branch.id: branch};
  return branches;
}

/// ชื่อสาขาจากลิสต์ที่โหลดไว้แล้ว คืนค่าว่างเมื่อยังไม่ได้โหลดหรือไม่มีรหัสนี้
///
/// ตั้งใจให้ไม่เป็น async เพื่อเรียกจาก `build()` ได้ หน้าที่ใช้ต้อง await
/// [loadAssetBranches] ให้เสร็จสักครั้งก่อน แล้วค่อย setState ให้วาดใหม่
String assetBranchNameOf(String branchId) {
  final id = branchId.trim();
  if (id.isEmpty) return '';
  return _branchById[id]?.name ?? '';
}

/// ทิ้งไดเรกทอรีที่จำไว้ ต้องเรียกตอนออกจากระบบ ไม่งั้นคนถัดไปที่ล็อกอิน
/// บนเครื่องเดียวกันจะเห็นชื่อสาขาและชื่อพนักงานที่คนก่อนโหลดไว้
void clearAssetDirectoryCache() {
  _branchCache = null;
  _branchById = const {};
  _deptCache = null;
  _deptByCode = const {};
  _employeeById.clear();
}

/// หาสาขาจากรหัส ใช้ลิสต์ที่โหลดไว้แล้ว คืน null เมื่อไม่มีรหัสนี้
///
/// ทรัพย์สินเก็บแค่ `current_site_id` ไม่มีชื่อสาขาติดมา หน้าจอที่อยากโชว์ชื่อ
/// ต้องมาเทียบเอง
Future<AssetBranch?> findAssetBranch(String branchId) async {
  final id = branchId.trim();
  if (id.isEmpty) return null;

  final branches = await loadAssetBranches();
  for (final branch in branches) {
    if (branch.id == id) return branch;
  }
  return null;
}

/// หาพนักงานจากรหัส คืน null เมื่อไม่มีรหัสนี้
///
/// `/employee` ไม่มีตัวดึงทีละคน ใช้ `keyword` เป็นรหัสแล้วคัดเอาแถวที่รหัสตรง
/// เป๊ะ เพราะ keyword เป็นการค้นแบบมีบางส่วนก็เจอ `681` จะได้ทุกคนที่รหัสมี 681
///
/// จำผลไว้ทั้งที่เจอและไม่เจอ ([_employeeById]) รหัสเดิมถามซ้ำไม่ยิงใหม่
Future<AssetEmployee?> findAssetEmployee(String empId) async {
  final id = empId.trim();
  if (id.isEmpty) return null;
  if (_employeeById.containsKey(id)) return _employeeById[id];

  final rows = await searchAssetEmployees(keyword: id);

  // เก็บทุกคนที่ติดมากับผลค้น ไม่ใช่แค่คนที่ถาม — ค้น "681" ได้มาสิบคน
  // อีกเก้าคนนั้นมีโอกาสถูกถามต่อในหน้าเดียวกัน
  for (final employee in rows) {
    _employeeById.putIfAbsent(employee.id, () => employee);
  }
  _employeeById.putIfAbsent(id, () => null);

  return _employeeById[id];
}

/// ชื่อพนักงานที่เคยหามาแล้ว คืนค่าว่างเมื่อยังไม่เคยหาหรือไม่มีรหัสนี้
///
/// คู่กับ [assetBranchNameOf] — อ่านแบบไม่ async ไว้ใช้ใน `build()`
String assetEmployeeNameOf(String empId) {
  final id = empId.trim();
  if (id.isEmpty) return '';
  return _employeeById[id]?.fullName ?? '';
}

/// ── ตั้งผู้อนุมัติต่อแผนก ──────────────────────────────────────────────
///
/// ⚠️ `/deptlist` กับ `/approvers/summary` **ตัดผลที่ 100 แถวก่อนกรอง** ยืนยัน
/// เมื่อ 24 ก.ย. 2026: มี 101 แผนกที่มีผู้อนุมัติ แต่ `deptlist?withApproverOnly`
/// คืนมา 92 — ถ้ากรองก่อนตัดต้องได้ 100 และ `keyword=B0000` คืนลิสต์ว่างทั้งที่
/// ฝ่ายบัญชีมีอยู่จริงใน `/approvers` แปลว่าค้นของที่ถูกตัดไปแล้วไม่เจอ
///
/// ผลคือ **ห้ามใช้ `keyword` ฝั่งเซิร์ฟเวอร์** ต้องโหลดมาแล้วกรองในเครื่อง และ
/// ต้องเอา `/approvers` (ไม่ถูกตัด) มาเติมแผนกที่หายไป ดู [loadApproverBoard]

const String _approverRowsPath = '/api/AssetTransfer/approvers';
const String _approverSummaryPath = '/api/AssetTransfer/approvers/summary';
const String _approverPostPath = '/api/AssetTransfer/approver';

String _approverRowPath(String deptCode, String approverId) =>
    '/api/AssetTransfer/approver'
    '/${Uri.encodeComponent(deptCode.trim())}'
    '/${Uri.encodeComponent(approverId.trim())}';

/// ผู้อนุมัติทุกแถวในระบบ หรือเฉพาะแผนก/คนที่ระบุ
///
/// [includeInactive] ดึงแถวที่ถูกปิดใช้งานมาด้วย — ยังพิสูจน์ไม่ได้ว่าทำงาน
/// เพราะตอนนี้ยังไม่มีแถว inactive สักแถวในระบบ
Future<List<AssetApprover>> fetchApproverRows({
  String deptCode = '',
  String approverId = '',
  bool includeInactive = false,
}) => _getList(
  _approverRowsPath,
  params: {
    if (deptCode.trim().isNotEmpty) 'deptCode': deptCode.trim(),
    if (approverId.trim().isNotEmpty) 'approverId': approverId.trim(),
    if (includeInactive) 'includeInactive': true,
  },
  parse: AssetApprover.fromJson,
  keep: (approver) => approver.id.isNotEmpty,
);

/// แผนกพร้อมผู้อนุมัติทั้งชุดในคำขอเดียว
///
/// ไม่ส่ง `notReadyOnly` ไป เพราะมันกรองด้วย `has_backup` ไม่ใช่ `is_ready`
/// (คืน 99 จาก 100 แถว ทั้งที่ `is_ready:false` มีแค่ 14) กรองในเครื่องเอง
Future<List<AssetDeptApprovers>> fetchApproverSummary() => _getList(
  _approverSummaryPath,
  params: const {},
  parse: AssetDeptApprovers.fromJson,
  keep: (dept) => dept.deptCode.isNotEmpty,
);

/// ทุกแผนกที่ตั้งผู้อนุมัติได้ เรียงแผนกที่ยังไม่พร้อมขึ้นก่อน
///
/// ประกอบจากสองเส้นเพราะเส้นเดียวไม่พอ: `/summary` ให้ข้อมูลครบแต่ถูกตัดที่ 100
/// แถว ส่วน `/approvers` ไม่ถูกตัดแต่มีเฉพาะแผนกที่ตั้งผู้อนุมัติไว้แล้ว
/// รวมกันแล้วยังไม่ครบทุกแผนกในบริษัท แต่ครอบคลุมกว่าใช้เส้นใดเส้นเดียว
///
/// แผนกที่มาจาก `/approvers` อย่างเดียวจะไม่มี `staff_count` เพราะเส้นนั้น
/// ไม่ได้ส่งมา — โชว์เป็น 0 ดีกว่าไม่โชว์แผนกนั้นเลย
Future<List<AssetDeptApprovers>> loadApproverBoard() async {
  final summary = await fetchApproverSummary();
  final byDept = {for (final dept in summary) dept.deptCode: dept};

  // เติมแผนกที่ /summary ตัดทิ้งไป จัดกลุ่มแถวผู้อนุมัติตามแผนกเอง
  final missing = <String, List<AssetApprover>>{};
  for (final row in await fetchApproverRows()) {
    if (row.deptCode.isEmpty || byDept.containsKey(row.deptCode)) continue;
    missing.putIfAbsent(row.deptCode, () => []).add(row);
  }

  for (final entry in missing.entries) {
    final rows = entry.value..sort((a, b) => a.order.compareTo(b.order));
    final effective = rows.where((e) => e.isActive && e.isEffective);

    byDept[entry.key] = AssetDeptApprovers(
      deptCode: entry.key,
      deptName: rows.first.deptName,
      approverCount: effective.length,
      hasPrimary: effective.any((e) => e.isPrimary),
      hasBackup: effective.any((e) => !e.isPrimary),
      isReady: effective.any((e) => e.isPrimary),
      approvers: rows,
    );
  }

  final board = byDept.values.toList();
  sortApproverBoard(board);
  return board;
}

/// เรียงแผนกที่ยังไม่พร้อมขึ้นก่อน แล้วค่อยแผนกที่ขาดตัวสำรอง
///
/// หน้าจอนี้มีไว้ตามเก็บของที่ยังไม่ครบ ไม่ใช่ไว้เปิดดูเฉย ๆ เรียงตามชื่อแผนก
/// แปลว่าคนต้องเลื่อนหาเองว่าแผนกไหนยังขาด
void sortApproverBoard(List<AssetDeptApprovers> board) {
  int rank(AssetDeptApprovers dept) {
    if (!dept.isReady) return 0;
    if (!dept.hasBackup) return 1;
    return 2;
  }

  board.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;

    // ในกลุ่มเดียวกัน แผนกที่คนเยอะกระทบคนเยอะกว่า จัดการก่อน
    final byStaff = b.staffCount.compareTo(a.staffCount);
    if (byStaff != 0) return byStaff;

    return a.deptCode.compareTo(b.deptCode);
  });
}

/// ตั้งผู้อนุมัติใหม่ให้แผนกหนึ่ง คืนข้อความที่เซิร์ฟเวอร์ตอบมา
Future<String> insertApprover({
  required String deptCode,
  required String approverId,
  int order = kApproverOrderMin,
  DateTime? validFrom,
  DateTime? validTo,
  String remark = '',
}) => _post(
  _approverPostPath,
  buildApproverInsertPayload(
    deptCode: deptCode,
    approverId: approverId,
    order: order,
    validFrom: validFrom,
    validTo: validTo,
    remark: remark,
  ),
  fallback: 'เพิ่มผู้อนุมัติแล้ว',
);

/// แก้ผู้อนุมัติที่มีอยู่ ส่งเฉพาะช่องที่ตั้งใจแก้
Future<String> updateApprover({
  required String deptCode,
  required String approverId,
  int? order,
  DateTime? validFrom,
  DateTime? validTo,
  bool? isActive,
  String? remark,
}) => _send(
  _approverRowPath(deptCode, approverId),
  method: 'PUT',
  body: buildApproverUpdatePayload(
    order: order,
    validFrom: validFrom,
    validTo: validTo,
    isActive: isActive,
    remark: remark,
  ),
  fallback: 'บันทึกการเปลี่ยนแปลงแล้ว',
);

/// ดึงลิสต์แล้วแปลงเป็นโมเดล ท่าเดียวกับที่ทุกเส้น GET ในไฟล์นี้ใช้
Future<List<T>> _getList<T>(
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

/// PUT ที่คืนข้อความผลลัพธ์ คู่กับ [_post] ที่มีอยู่แล้ว
///
/// รับ [method] แทนที่จะฮาร์ดโค้ด 'PUT' ไว้เพราะ `DELETE /approver/…` มีอยู่จริง
/// แต่ยังไม่ได้เรียก — ตอนนี้มันเป็น soft delete ที่ผลเหมือน `is_active: false`
/// เป๊ะ ถ้า backend แก้ให้ลบจริงเมื่อไหร่ ต่อเพิ่มได้ทันทีโดยไม่ต้องรื้อตรงนี้
Future<String> _send(
  String path, {
  required String method,
  required String fallback,
  Map<String, dynamic>? body,
}) async {
  final options = MobileSession.I.authOptions();
  if (options == null) throw _noSession;

  try {
    final response = await mobileDio.request(
      path,
      data: body,
      // copyWith ไม่ใช่สร้าง Options ใหม่ เพราะ authOptions ตั้ง
      // validateStatus ให้รับทุกสถานะไว้ ทิ้งไปแล้ว dio จะโยน 404/401 เป็น
      // exception ของตัวเองแทนที่จะให้ unwrapMobileResponse แปลเป็นข้อความไทย
      options: options.copyWith(method: method),
    );

    return assetMessageOf(unwrapMobileResponse(response), fallback: fallback);
  } on MobileApiException {
    rethrow;
  } catch (e) {
    throw MobileApiException(mobileNetworkMessage(e));
  }
}

/// ── แผนก: ที่อยู่ของทรัพย์สิน ─────────────────────────────────────────
///
/// ช่อง `current_site_id` ของทรัพย์สินเก็บ**รหัสแผนก** ไม่ใช่รหัสสาขา แม้ชื่อ
/// ช่องจะอ่านว่า site — ยืนยันกับผู้ใช้เมื่อ 8 ต.ค. 2026 ตัวเลือกที่อยู่ในหน้า
/// เพิ่ม/แก้ทรัพย์สินจึงดึงจาก `/deptlist` ไม่ใช่ `/branch`
///
/// ส่วน `to_site_id` ของ**ใบโอนย้าย**ยังเป็นรหัสสาขาอยู่ (เซิร์ฟเวอร์แปลเป็น
/// ชื่อสาขาให้ในผลลัพธ์) สองช่องนี้คนละความหมายกันทั้งที่ชื่อคล้ายกัน

const String _deptListPath = '/api/AssetTransfer/deptlist';

/// รายชื่อแผนกทั้งหมดเท่าที่ API ยอมให้เห็น
///
/// ประกอบจากสองเส้นเพราะ `/deptlist` ตัดผลที่ 100 แถวก่อนกรอง (ดูหัวหมวด
/// ตั้งผู้อนุมัติ) ส่วน `/approvers` ไม่ถูกตัดและมีชื่อแผนกติดมาด้วย รวมกันแล้ว
/// ครอบคลุมกว่าใช้เส้นใดเส้นเดียว แผนกที่ยังไม่มีผู้อนุมัติและไม่ติดร้อยแถวแรก
/// จะยังมองไม่เห็น — รอ backend แก้เพดาน
Future<List<AssetDept>> fetchAssetDepts() async {
  final byCode = <String, AssetDept>{};

  for (final dept in await _getList(
    _deptListPath,
    params: const {},
    parse: AssetDept.fromJson,
    keep: (dept) => dept.code.isNotEmpty,
  )) {
    byCode[dept.code] = dept;
  }

  // เติมแผนกที่ /deptlist ตัดทิ้ง เอาเฉพาะรหัสกับชื่อ ไม่มีจำนวนคนติดมา
  try {
    for (final row in await fetchApproverRows()) {
      if (row.deptCode.isEmpty || byCode.containsKey(row.deptCode)) continue;
      byCode[row.deptCode] = AssetDept(code: row.deptCode, name: row.deptName);
    }
  } on MobileApiException {
    // เติมไม่ได้ก็ใช้เท่าที่ /deptlist ให้มา ดีกว่าไม่มีลิสต์ให้เลือกเลย
  }

  final depts = byCode.values.toList()
    ..sort((a, b) => a.code.compareTo(b.code));
  return depts;
}

/// ลิสต์แผนกที่โหลดไว้แล้วในรอบนี้ของแอป เหตุผลเดียวกับ [_branchCache]
List<AssetDept>? _deptCache;
Map<String, AssetDept> _deptByCode = const {};

Future<List<AssetDept>> loadAssetDepts({bool refresh = false}) async {
  final cached = _deptCache;
  if (!refresh && cached != null) return cached;

  final depts = await fetchAssetDepts();
  _deptCache = depts;
  _deptByCode = {for (final dept in depts) dept.code: dept};
  return depts;
}

/// ชื่อแผนกจากลิสต์ที่โหลดไว้แล้ว คู่กับ [assetBranchNameOf]
String assetDeptNameOf(String deptCode) {
  final code = deptCode.trim();
  if (code.isEmpty) return '';
  return _deptByCode[code]?.name ?? '';
}

/// หาแผนกจากรหัส คืน null เมื่อไม่มีรหัสนี้
Future<AssetDept?> findAssetDept(String deptCode) async {
  final code = deptCode.trim();
  if (code.isEmpty) return null;

  await loadAssetDepts();
  return _deptByCode[code];
}
