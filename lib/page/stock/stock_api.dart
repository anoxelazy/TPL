import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:claim/utils/dio_service.dart';

/// ชื่อ module ใน Permissions.Modules ที่ต้องเปิดให้ก่อนใช้ฟีเจอร์นี้
const String stockModule = 'stock';

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

const String kStatusJsonUrl =
    'https://raw.githubusercontent.com/anoxelazy/API_json/main/status.json';
const String _kStatusCacheKey = 'job_status_stages_json';

Map<String, ShipmentStage> _jobStatusStages = const {};

Map<String, ShipmentStage> get kJobStatusStages => _jobStatusStages;

ShipmentStage? shipmentStageFromJobStatus(String? jobStatusId) {
  if (jobStatusId == null) return null;
  return _jobStatusStages[jobStatusId.trim()];
}

/// ใส่ mapping ให้เทสต์โดยไม่ต้องยิง status.json จริง
///
/// ตัวจริงโหลดจากเน็ต ในเทสต์จึงว่างเสมอ ทำให้ [BillStockItem.stage]
/// เป็น null และทดสอบพฤติกรรมที่ขึ้นกับสถานะไม่ได้
@visibleForTesting
void setJobStatusStagesForTest(Map<String, ShipmentStage> stages) {
  _jobStatusStages = Map.unmodifiable(stages);
}

Future<void> loadJobStatusStages() async {
  SharedPreferences? prefs;

  try {
    prefs = await SharedPreferences.getInstance();

    final response = await dio.get(
      kStatusJsonUrl,
      options: Options(
        headers: {'Accept': 'application/json'},
        receiveTimeout: const Duration(seconds: 20),
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final body = response.data is String
        ? response.data as String
        : jsonEncode(response.data);

    final parsed = _parseJobStatusStages(body);
    if (parsed == null) throw Exception('รูปแบบไฟล์ไม่ถูกต้อง');

    _jobStatusStages = parsed;
    await prefs.setString(_kStatusCacheKey, body);
  } catch (e) {
    debugPrint('status.json error: $e');

    final cached = prefs?.getString(_kStatusCacheKey);
    final parsed = cached == null ? null : _parseJobStatusStages(cached);
    if (parsed != null) _jobStatusStages = parsed;
  }
}

Map<String, ShipmentStage>? _parseJobStatusStages(String body) {
  try {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;

    dynamic decoded = jsonDecode(trimmed);
    if (decoded is Map && decoded['job_status_stages'] is Map) {
      decoded = decoded['job_status_stages'];
    }
    if (decoded is! Map) return null;

    final result = <String, ShipmentStage>{};
    for (final entry in decoded.entries) {
      final id = entry.key.toString().trim();
      final stage = _stageByName[entry.value?.toString().trim()];
      if (id.isEmpty || stage == null) continue;
      result[id] = stage;
    }

    return result.isEmpty ? null : result;
  } catch (e) {
    debugPrint('status.json parse error: $e');
    return null;
  }
}

final Map<String, ShipmentStage> _stageByName = {
  for (final stage in ShipmentStage.values) stage.name: stage,
};

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

  /// ระยะที่บิลไปถึงแล้ว null = jobstatusid ที่ยังไม่รู้จัก
  ShipmentStage? get stage => shipmentStageFromJobStatus(jobStatusId);

  /// บิลนี้พักสถานะอยู่แล้วหรือไม่ ใช้กันไม่ให้พักซ้ำ
  ///
  /// ดู [stage] ก่อนเพราะแม่นที่สุด แต่ mapping ของมันโหลดมาจาก status.json
  /// ระยะไกล ถ้าโหลดไม่ได้และไม่มี cache [stage] จะเป็น null ทั้งที่บิลพักอยู่จริง
  /// แล้วจะพักซ้ำได้ จึงมีทางสำรองอ่านจากชื่อสถานะที่ API ส่งมาเอง
  bool get isParked {
    if (stage != null) return stage == ShipmentStage.parked;

    final text = status;
    return text != '-' && text.contains('พัก');
  }

  String get status =>
      _pick(['statusName', 'status', 'statusText', 'stockStatus', 'state']) ??
      '-';

  /// สถานะที่เอาไปโชว์: ใช้ของ API ก่อน ถ้าไม่มีค่อยแปลจาก jobstatusid
  String get displayStatus {
    final apiStatus = status;
    if (apiStatus != '-') return apiStatus;
    return stage?.label ?? '-';
  }

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
