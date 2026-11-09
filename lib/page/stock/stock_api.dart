import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:claim/utils/dio_service.dart';

const String stockModule = 'stock';

class JobStatusInfo {
  final String id;

  final String rawName;

  const JobStatusInfo({required this.id, required this.rawName});

  String get name {
    final stripped = rawName.replaceFirst(RegExp(r'^\s*\([^)]*\)\s*'), '').trim();
    return stripped.isEmpty ? rawName.trim() : stripped;
  }
}

const String kJobStatusesPath = '/warehouse/job-statuses';
const String _kStatusCacheKey = 'job_statuses_json';


Map<String, JobStatusInfo> _jobStatuses = const {};

Map<String, JobStatusInfo> get kJobStatuses => _jobStatuses;

JobStatusInfo? jobStatusOf(String? jobStatusId) {
  if (jobStatusId == null) return null;
  return _jobStatuses[jobStatusId.trim()];
}

int jobStatusOrder(String? jobStatusId) {
  if (jobStatusId == null) return 1 << 20;
  final index = _jobStatuses.keys.toList().indexOf(jobStatusId.trim());
  return index < 0 ? 1 << 20 : index;
}

/// ใส่รายการสถานะให้เทสต์โดยไม่ต้องยิง API จริง (id -> ชื่อ)
///
/// ตัวจริงโหลดจากเน็ต ในเทสต์จึงว่างเสมอ
@visibleForTesting
void setJobStatusesForTest(Map<String, String> names) {
  _jobStatuses = Map.unmodifiable({
    for (final e in names.entries)
      e.key: JobStatusInfo(id: e.key, rawName: e.value),
  });
}

/// โหลดรายการสถานะจาก API ไม่ throw โหลดไม่ได้ก็ใช้ของที่แคชไว้รอบก่อนต่อ
Future<void> loadJobStatuses() async {
  SharedPreferences? prefs;

  try {
    prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      throw Exception('ไม่พบ token');
    }

    final response = await dio.get(
      kJobStatusesPath,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        receiveTimeout: const Duration(seconds: 20),
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final body = response.data is String
        ? response.data as String
        : jsonEncode(response.data);

    final parsed = _parseJobStatuses(body);
    if (parsed == null) throw Exception('รูปแบบข้อมูลไม่ถูกต้อง');

    _jobStatuses = parsed;
    await prefs.setString(_kStatusCacheKey, body);
  } catch (e) {
    // ออฟไลน์ / token หมดอายุ ฯลฯ ใช้ของที่แคชไว้รอบก่อน
    debugPrint('job-statuses error: $e');

    final cached = prefs?.getString(_kStatusCacheKey);
    final parsed = cached == null ? null : _parseJobStatuses(cached);
    if (parsed != null) _jobStatuses = parsed;
  }
}

/// รูปแบบ { isSuccess, items: [ { jobstatusid, jobstatusname, ... } ] }
Map<String, JobStatusInfo>? _parseJobStatuses(String body) {
  try {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;

    final decoded = jsonDecode(trimmed);
    final items = decoded is Map ? decoded['items'] : decoded;
    if (items is! List) return null;

    final result = <String, JobStatusInfo>{};
    for (final item in items) {
      if (item is! Map) continue;
      final id = item['jobstatusid']?.toString().trim() ?? '';
      final name = item['jobstatusname']?.toString().trim() ?? '';
      if (id.isEmpty || name.isEmpty) continue;
      result[id] = JobStatusInfo(id: id, rawName: name);
    }

    return result.isEmpty ? null : result;
  } catch (e) {
    debugPrint('job-statuses parse error: $e');
    return null;
  }
}

enum ShipmentStage {
  origin('ต้นทาง'),
  warehouse('อยู่ที่คลัง'),
  parked('พักสินค้า'),
  delivering('กำลังจัดส่ง'),
  delivered('ส่งถึงลูกค้า'),
  returned('ตีกลับสินค้า');

  final String label;
  const ShipmentStage(this.label);
}

/// ระยะของบิลสำหรับแถบ animation เท่านั้น เลือกจาก [jobStatusId] ที่ API ส่งมา
///
/// ห้ามใช้ตัดสินว่าจะแสดงข้อความอะไร ชื่อสถานะมาจาก /warehouse/job-statuses
/// เสมอ (แบบเดียวกับ trackingStatusColor ของหน้าเช็คสถานะพัสดุ)
/// รหัสที่ไม่รู้จักได้ null แถบจะไม่ระบายเส้นใด ๆ ไม่พัง
ShipmentStage? shipmentStageFromJobStatus(String? jobStatusId) {
  switch (jobStatusId?.trim()) {
    case '2':
    case '2-2':
      return ShipmentStage.origin;
    case '3':
    case '5':
      return ShipmentStage.warehouse;
    case '6-1':
      return ShipmentStage.parked;
    case '4':
    case '6':
    case '7':
    case '9':
      return ShipmentStage.delivering;
    case '7-3':
      return ShipmentStage.returned;
    default:
      return null;
  }
}

class BillStockItem {
  final Map<String, dynamic> raw;

  BillStockItem(this.raw);

  String? _pick(List<String> candidates) {
    for (final key in candidates) {
      final normalized = _normalizeKey(key);
      for (final entry in raw.entries) {
        if (_normalizeKey(entry.key) != normalized) continue;
        final value = entry.value;
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isEmpty || text == 'null') continue;
        return text;
      }
    }
    return null;
  }

  static String _normalizeKey(String key) =>
      key.toLowerCase().replaceAll(RegExp(r'[_\s-]'), '');

  /// เลขบิลหลักที่ใช้แสดงหัวการ์ด
  String get billCode =>
      _pick([
        'bill_code',
        'billCode',
        'billNo',
        'bill_no',
        'billID',
        'a1No',
        'a1_no',
        'docNo',
        'documentNo',
        'no',
      ]) ??
      '-';

  /// รหัสสถานะงาน เก็บเป็น string เพราะมีค่าอย่าง 2-2
  String? get jobStatusId =>
      _pick(['jobstatusid', 'job_status_id', 'jobStatusID', 'jobStatus']);

  /// สถานะงานตามตารางจาก /warehouse/job-statuses null = ยังไม่รู้จัก
  /// (ตารางโหลดไม่ได้หรือไม่มี jobstatusid นี้)
  JobStatusInfo? get jobStatus => jobStatusOf(jobStatusId);

  /// ระยะที่บิลไปถึงแล้ว null = jobstatusid ที่ยังไม่รู้จักในตารางระยะ
  ShipmentStage? get stage => shipmentStageFromJobStatus(jobStatusId);

  /// บิลนี้พักสถานะอยู่แล้วหรือไม่ ใช้กันไม่ให้พักซ้ำ
  ///
  /// ดูระยะก่อนเพราะแม่นที่สุด ถ้าตารางระยะโหลดไม่ได้และไม่มีแคช [stage] จะเป็น null
  /// ทั้งที่บิลพักอยู่จริง จึงมีทางสำรองอ่านจากชื่อสถานะที่ API ส่งมาเอง
  bool get isParked {
    if (stage != null) return stage == ShipmentStage.parked;

    final text = jobStatus?.name ?? status;
    return text != '-' && text.contains('พัก');
  }

  String get status =>
      _pick(['statusName', 'status', 'statusText', 'stockStatus', 'state']) ??
      '-';

  /// สถานะที่เอาไปโชว์: ชื่อจากตารางสถานะ (ตรงกับปุ่มกรอง) ก่อน
  /// ไม่รู้จักค่อยใช้ชื่อที่แถวส่งมาเอง
  String get displayStatus => jobStatus?.name ?? status;

  String? get statusCode => _pick(['statusID', 'statusCode', 'stockStatusID']);

  String? get branchId =>
      _pick(['branchID', 'branch', 'branchName', 'branchCode']);

  String? get customer => _pick([
    'customerName',
    'customer',
    'receiverName',
    'senderName',
    'custName',
  ]);

  /// เบอร์ติดต่อลูกค้า
  String? get phone => _pick([
    'tel',
    'tel1',
    'telephone',
    'phone',
    'mobile',
    'contactTel',
    'customerTel',
    'receiverTel',
  ]);

  /// ที่อยู่จัดส่ง
  String? get address => _pick([
    'address',
    'addr',
    'fullAddress',
    'customerAddress',
    'receiverAddress',
    'deliveryAddress',
    'sendAddress',
  ]);

  /// มีข้อมูลลูกค้าให้แสดงบ้างไหม ใช้ตัดสินว่าจะขึ้นการ์ดหรือซ่อนไปเลย
  ///
  /// จำเป็นเพราะไม่รู้แน่ว่า Bill_Stock ส่งฟิลด์ไหนมาบ้างในแต่ละแถว
  bool get hasCustomerInfo =>
      customer != null || phone != null || address != null;

  String? get quantity =>
      _pick(['qty', 'quantity', 'amount', 'pieces', 'totalQty']);

  String? get dateText => _pick([
    'billDate',
    'date',
    'createDate',
    'createdAt',
    'stockDate',
    'updateDate',
    'dateTime',
  ]);

  String? get remark => _pick(['remark', 'remarks', 'note', 'description']);

  /// ฟิลด์ที่เหลือทั้งหมด สำหรับกางดูตอนกดขยายการ์ด
  List<MapEntry<String, String>> get details {
    final entries = <MapEntry<String, String>>[];
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isEmpty || text == 'null') continue;
      entries.add(MapEntry(entry.key, text));
    }
    return entries;
  }

  /// ข้อความที่ใช้ค้นหาในหน้าจอ
  String get searchIndex => details.map((e) => e.value).join(' ').toLowerCase();
}

Future<List<BillStockItem>> fetchBillStock({required String branchId}) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  if (token == null || token.isEmpty) {
    throw Exception('ไม่พบ token กรุณาเข้าสู่ระบบใหม่');
  }

  try {
    final response = await dio.post(
      '/api/Bill_Stock',
      queryParameters: {'branchID': branchId},
      data: const <String, dynamic>{},
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        receiveTimeout: const Duration(seconds: 60),
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('ดึงข้อมูลไม่สำเร็จ (HTTP ${response.statusCode})');
    }

    return _parseBillStock(response.data);
  } on DioException catch (e) {
    debugPrint('Bill_Stock error: ${e.type} ${e.message}');

    if (e.response?.statusCode == 401) {
      throw Exception('token หมดอายุ กรุณาเข้าสู่ระบบใหม่');
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw Exception('เชื่อมต่อเซิร์ฟเวอร์หมดเวลา กรุณาลองใหม่');
    }

    throw Exception('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาลองใหม่');
  }
}

List<BillStockItem> _parseBillStock(dynamic data) {
  dynamic decoded = data;

  if (decoded is String) {
    final trimmed = decoded.trim();
    if (trimmed.isEmpty) return [];
    decoded = jsonDecode(trimmed);
  }

  final list = _extractList(decoded);

  return list
      .whereType<Map>()
      .map((e) => BillStockItem(Map<String, dynamic>.from(e)))
      .toList();
}

List<dynamic> _extractList(dynamic decoded) {
  if (decoded is List) return decoded;

  if (decoded is Map) {
    const wrapperKeys = [
      'data',
      'Data',
      'result',
      'Result',
      'items',
      'Items',
      'list',
      'List',
    ];
    for (final key in wrapperKeys) {
      final value = decoded[key];
      if (value is List) return value;
    }

    // บาง endpoint ตอบเป็น object เดียวโดยไม่ห่อ list
    final nested = decoded.values.whereType<List>();
    if (nested.isNotEmpty) return nested.first;

    return [decoded];
  }

  return [];
}
