import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:claim/utils/image_encode_io.dart';
import 'package:claim/utils/supabase_config.dart';

const String _function = '/functions/v1/get-asset';
const String _bucket = 'asset-photos';
const String _roleIt = 'IT';

enum RepairStatus {
  pending('PENDING', 'รอ IT รับเรื่อง'),
  inProgress('IN_PROGRESS', 'กำลังซ่อม'),
  completed('COMPLETED', 'ปิดงานแล้ว');

  final String code;
  final String label;

  const RepairStatus(this.code, this.label);

  static RepairStatus fromCode(String? code) {
    final normalized = code?.trim().toUpperCase();
    for (final status in RepairStatus.values) {
      if (status.code == normalized) return status;
    }
    return RepairStatus.pending;
  }
}

const Map<String, String> kAssetSoftware = {
  'adobe': 'Adobe',
  'tps': 'TPS',
  'tms': 'TMS',
  'hr_system': 'ระบบ HR',
  'sap': 'SAP',
  'yale_system': 'ระบบ Yale',
  'web_internal': 'เว็บภายใน',
  'mobile_app': 'Mobile App',
};

/// ดึง S/N ออกจากค่าที่สแกนได้จาก QR/บาร์โค้ดบนตัวเครื่อง
///
/// QR ที่ติดบนเครื่อง encode เป็น URL ของหน้าเว็บ (มี `?sn=...`) ไม่ใช่ S/N
/// เปล่า ๆ แต่บาร์โค้ดที่ติดมือเองอาจเป็น S/N ตรง ๆ จึงรองรับทั้งสองแบบ
String snFromScannedCode(String value) {
  final trimmed = value.trim();
  if (!trimmed.contains('?')) return trimmed;
  return Uri.tryParse(trimmed)?.queryParameters['sn']?.trim() ?? trimmed;
}

/// เครื่องคอมพิวเตอร์ 1 เครื่องในทะเบียน (ตาราง maintanance)
class RepairAsset {
  final int? id;
  final String assetCode;
  final String sn;
  final String computerName;
  final String deviceType;
  final String brand;
  final String model;
  final String department;
  final String employeeName;
  final String windowsVersion;
  final String officeInstalled;
  final String warrantyStart;
  final String warrantyEnd;
  final String computerAge;
  final String imageUrl;
  final Map<String, bool> software;

  const RepairAsset({
    this.id,
    this.assetCode = '',
    this.sn = '',
    this.computerName = '',
    this.deviceType = '',
    this.brand = '',
    this.model = '',
    this.department = '',
    this.employeeName = '',
    this.windowsVersion = '',
    this.officeInstalled = '',
    this.warrantyStart = '',
    this.warrantyEnd = '',
    this.computerAge = '',
    this.imageUrl = '',
    this.software = const {},
  });

  /// คอลัมน์ซีเรียลในตารางนี้ชื่อ "S/N" ตรงตัว มี slash และเป็นตัวพิมพ์ใหญ่
  factory RepairAsset.fromJson(Map<String, dynamic> json) => RepairAsset(
    id: _int(json['id']),
    assetCode: _str(json['asset_code']),
    sn: _str(json['S/N']),
    computerName: _str(json['computer_name']),
    deviceType: _str(json['device_type']),
    brand: _str(json['brand']),
    model: _str(json['model']),
    department: _str(json['department']),
    employeeName: _str(json['employee_name']),
    windowsVersion: _str(json['windows_version']),
    officeInstalled: _str(json['office_installed']),
    warrantyStart: _str(json['warranty_start']),
    warrantyEnd: _str(json['warranty_end']),
    computerAge: _str(json['computer_age']),
    imageUrl: _str(json['image_url']),
    software: {for (final key in kAssetSoftware.keys) key: _bool(json[key])},
  );

  /// ส่งครบทุกคอลัมน์เสมอ เพราะ PUT เขียนทับทั้งแถว ไม่ใช่ partial update
  /// ฟิลด์ที่ไม่ส่งจะกลายเป็น null หรือ false
  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'asset_code': assetCode,
    'S/N': sn,
    'computer_name': computerName,
    'device_type': deviceType,
    'brand': brand,
    'model': model,
    'department': department,
    'employee_name': employeeName,
    'windows_version': windowsVersion,
    'office_installed': officeInstalled,
    'warranty_start': _dateOrNull(warrantyStart),
    'warranty_end': _dateOrNull(warrantyEnd),
    'computer_age': computerAge,
    'image_url': imageUrl,
    for (final key in kAssetSoftware.keys) key: software[key] ?? false,
  };

  RepairAsset copyWith({String? imageUrl}) => RepairAsset(
    id: id,
    assetCode: assetCode,
    sn: sn,
    computerName: computerName,
    deviceType: deviceType,
    brand: brand,
    model: model,
    department: department,
    employeeName: employeeName,
    windowsVersion: windowsVersion,
    officeInstalled: officeInstalled,
    warrantyStart: warrantyStart,
    warrantyEnd: warrantyEnd,
    computerAge: computerAge,
    imageUrl: imageUrl ?? this.imageUrl,
    software: software,
  );

  /// ชื่อเครื่องที่เอาไปโชว์และบันทึกลงใบแจ้งซ่อม
  String get displayName {
    final parts = [brand, model].where((e) => e.isNotEmpty);
    if (parts.isNotEmpty) return parts.join(' ');
    if (deviceType.isNotEmpty) return deviceType;
    return assetCode.isNotEmpty ? assetCode : sn;
  }

  String get searchIndex => [
    assetCode,
    sn,
    brand,
    model,
    computerName,
    department,
    employeeName,
  ].join(' ').toLowerCase();
}

/// ใบแจ้งซ่อม 1 ใบ (ตาราง repair_tickets)
class RepairTicket {
  final int? id;
  final int? assetId;
  final String assetCode;

  /// ในตารางนี้ชื่อคอลัมน์เป็น sn ตัวพิมพ์เล็ก ต่างจากตารางทะเบียนเครื่อง
  final String sn;
  final String branch;
  final String deviceName;
  final String issueDescription;
  final String requesterName;
  final String approverName;
  final String technicianName;
  final String note;
  final RepairStatus status;
  final DateTime? createdAt;
  final DateTime? completedAt;

  const RepairTicket({
    required this.id,
    required this.assetId,
    required this.assetCode,
    required this.sn,
    required this.branch,
    required this.deviceName,
    required this.issueDescription,
    required this.requesterName,
    required this.approverName,
    required this.technicianName,
    required this.note,
    required this.status,
    required this.createdAt,
    required this.completedAt,
  });

  factory RepairTicket.fromJson(Map<String, dynamic> json) => RepairTicket(
    id: _int(json['id']),
    assetId: _int(json['asset_id']),
    assetCode: _str(json['asset_code']),
    sn: _str(json['sn']),
    branch: _str(json['branch']),
    deviceName: _str(json['device_name']),
    issueDescription: _str(json['issue_description']),
    requesterName: _str(json['requester_name']),
    approverName: _str(json['approver_name']),
    technicianName: _str(json['technician_name']),
    note: _str(json['note']),
    status: RepairStatus.fromCode(_str(json['status'])),
    createdAt: _localTime(json['created_at']),
    completedAt: _localTime(json['completed_at']),
  );
}

// -------------------------------------------------------------- ใบแจ้งซ่อม

/// ใบแจ้งซ่อมทั้งหมด ใหม่ไปเก่า ส่ง [sn] มาเพื่อดูเฉพาะเครื่องนั้น
Future<List<RepairTicket>> fetchRepairs({String? sn}) async {
  final data = await _get({
    'action': 'get_repairs',
    if (sn != null && sn.isNotEmpty) 'sn': sn,
  });

  if (data is! List) return const [];
  return data
      .whereType<Map>()
      .map((e) => RepairTicket.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

/// เปิดใบแจ้งซ่อมใหม่ พนักงานทุกคนทำได้ ไม่ต้องมีสิทธิ์ IT
///
/// รับ [asset] เป็นก้อน ไม่ได้แยกรับ sn กับชื่อเครื่องเป็นสตริง เพื่อบังคับว่า
/// **แจ้งซ่อมได้เฉพาะเครื่องที่อยู่ในทะเบียน** เรียกฟังก์ชันนี้โดยไม่มีเครื่อง
/// จากทะเบียนจึงทำไม่ได้ตั้งแต่ตอนคอมไพล์ ไม่ต้องไปหวังว่าทุกหน้าจอจะเช็คเอง
///
/// ชื่อเครื่องเอาจาก [RepairAsset.displayName] ใบของเครื่องเดียวกันจะได้เขียน
/// ชื่อตรงกันทุกใบ ไม่มี "Dell" กับ "เดล" ปนกันเหมือนตอนให้พิมพ์เอง
Future<void> createRepair({
  required RepairAsset asset,
  required String issueDescription,
  required String requesterName,
  required String branch,
  List<String> imageUrls = const [],
}) async {
  final sn = asset.sn.trim();
  if (sn.isEmpty) {
    // sn เป็นตัวเชื่อมใบแจ้งซ่อมกับเครื่อง (หน้าประวัติกรองด้วยค่านี้)
    // ปล่อยให้ว่างแล้วใบจะลอย ค้นจากเครื่องไม่เจอ
    throw Exception('เครื่องนี้ยังไม่มี S/N ในทะเบียน กรุณาแจ้งฝ่าย IT');
  }

  await _post(
    query: {'action': 'create_repair'},
    body: {
      if (asset.id != null) 'asset_id': asset.id,
      if (asset.assetCode.isNotEmpty) 'asset_code': asset.assetCode,
      'sn': sn,
      'branch': branch,
      'device_name': asset.displayName,
      'issue_description': issueDescription,
      'requester_name': requesterName,
      // คอลัมน์ image_urls เป็น array ส่งเป็นลิสต์ตรง ๆ ไม่ใช่สตริงคั่นคอมมา
      // ไม่มีรูปก็ไม่ส่งช่องนี้เลย ปล่อยให้เป็นค่าตั้งต้นของคอลัมน์
      if (imageUrls.isNotEmpty) 'image_urls': imageUrls,
    },
  );
}

/// รับเคส / เปลี่ยนช่าง / ปิดงาน เฉพาะ IT
///
/// เป็น partial update ส่งเฉพาะฟิลด์ที่แก้ ต่างจากทะเบียนเครื่อง
/// completed_at เซิร์ฟเวอร์เซ็ตเองตอนสถานะเป็น COMPLETED client กำหนดไม่ได้
Future<void> updateRepair({
  required int id,
  RepairStatus? status,
  String? technicianName,
  String? approverName,
  String? note,
  String? issueDescription,
}) async {
  await _put(
    query: {'action': 'update_repair'},
    body: {
      'id': id,
      if (status != null) 'status': status.code,
      if (technicianName != null) 'technician_name': technicianName,
      if (approverName != null) 'approver_name': approverName,
      if (note != null) 'note': note,
      if (issueDescription != null) 'issue_description': issueDescription,
      'requester_role': _roleIt,
    },
  );
}

// ------------------------------------------------------------ ทะเบียนเครื่อง

Future<List<RepairAsset>> fetchAssets() async {
  final data = await _get(const {});
  if (data is! List) return const [];
  return data
      .whereType<Map>()
      .map((e) => RepairAsset.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

/// หาเครื่องจาก S/N คืน null เมื่อไม่มีในทะเบียน (เซิร์ฟเวอร์ตอบ 404)
Future<RepairAsset?> findAssetBySn(String sn) async {
  final data = await _get({'sn': sn}, notFoundIsNull: true);
  if (data is! Map) return null;
  return RepairAsset.fromJson(Map<String, dynamic>.from(data));
}

Future<void> createAsset(RepairAsset asset) async {
  await _post(
    query: const {},
    body: {...asset.toJson(), 'requester_role': _roleIt},
  );
}

Future<void> updateAsset(RepairAsset asset) async {
  await _put(
    query: const {},
    body: {...asset.toJson(), 'requester_role': _roleIt},
  );
}

/// DELETE ตัวนี้มี body ไม่ใช่ query
Future<void> deleteAsset({required int? id, required String sn}) async {
  await _requireKey();

  try {
    final response = await supabaseDio.delete(
      _function,
      data: {if (id != null) 'id': id, 'sn': sn, 'requester_role': _roleIt},
      options: Options(validateStatus: (_) => true),
    );
    _unwrap(response);
  } on DioException catch (e) {
    throw Exception(_networkMessage(e));
  }
}

// -------------------------------------------------------------------- รูปแนบ

/// อัปโหลดรูปเครื่องในทะเบียนแล้วคืน public URL
Future<String> uploadAssetPhoto({
  required File file,
  required String sn,
}) => _uploadPhoto(file: file, path: _safeSn(sn));

/// อัปโหลดรูปปัญหาที่แนบมากับใบแจ้งซ่อม แล้วคืน public URL
///
/// อยู่ bucket เดียวกับรูปเครื่องแต่แยกโฟลเดอร์ `repairs/` ไว้ รูปทะเบียนเครื่อง
/// เป็นของถาวรของเครื่องนั้น ส่วนรูปนี้เป็นของใบ ๆ เดียว ปนกันแล้วตอนล้าง
/// ของเก่าจะแยกไม่ออกว่าอันไหนลบได้
Future<String> uploadRepairPhoto({
  required File file,
  required String sn,
}) => _uploadPhoto(file: file, path: 'repairs/${_safeSn(sn)}');

/// อัปโหลดรูปหนึ่งใบเข้า [path] (โฟลเดอร์) แล้วคืน public URL
///
/// ย่อก่อนเสมอตามสเปกเดียวกับเว็บ (ด้านยาวสุด 1280 คุณภาพ 80)
/// ไม่งั้นรูปจากกล้อง 3-5 MB จะกินพื้นที่ bucket และทำให้หน้ารายการโหลดช้า
Future<String> _uploadPhoto({
  required File file,
  required String path,
}) async {
  await _requireKey();

  final bytes = await compressImageForUpload(file, maxEdge: 1280, quality: 80);
  final fullPath = '$path/${DateTime.now().millisecondsSinceEpoch}.jpg';

  try {
    final response = await supabaseDio.post(
      '/storage/v1/object/$_bucket/$fullPath',
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          'Content-Type': 'image/jpeg',
          'Content-Length': bytes.length,
          'x-upsert': 'true',
        },
        validateStatus: (_) => true,
      ),
    );

    if ((response.statusCode ?? 0) >= 300) {
      throw Exception('อัปโหลดรูปไม่สำเร็จ (HTTP ${response.statusCode})');
    }

    return '${SupabaseConfig.baseUrl}/storage/v1/object/public/$_bucket/$fullPath';
  } on DioException catch (e) {
    throw Exception(_networkMessage(e));
  }
}

/// ลบแบบ best-effort ลบไม่ได้ไม่ควรทำให้การบันทึกข้อมูลหลักล้มตาม
Future<void> deleteAssetPhoto(String publicUrl) async {
  const marker = '/object/public/$_bucket/';
  final at = publicUrl.indexOf(marker);
  if (at < 0) return;

  try {
    await supabaseDio.delete(
      '/storage/v1/object/$_bucket/${publicUrl.substring(at + marker.length)}',
      options: Options(validateStatus: (_) => true),
    );
  } catch (e) {
    debugPrint('delete photo failed: $e');
  }
}

/// ตัดอักขระที่ใช้เป็นชื่อโฟลเดอร์ไม่ได้ออก ให้ตรงกับที่เว็บทำ
String _safeSn(String sn) {
  final cleaned = sn.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
  return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
}

// ------------------------------------------------------------------ transport

/// ทุก response ห่อด้วย { success, data } หรือ { error } ตอนล้มเหลว
///
/// เช็คทั้ง HTTP status และ success เพราะบาง endpoint ตอบ 200 มาพร้อม
/// success: false จะดูแค่ status code อย่างเดียวไม่พอ
Future<dynamic> _get(
  Map<String, dynamic> query, {
  bool notFoundIsNull = false,
}) async {
  await _requireKey();

  try {
    final response = await supabaseDio.get(
      _function,
      queryParameters: query,
      options: Options(validateStatus: (_) => true),
    );

    if (notFoundIsNull && response.statusCode == 404) return null;
    return _unwrap(response);
  } on DioException catch (e) {
    throw Exception(_networkMessage(e));
  }
}

Future<dynamic> _post({
  required Map<String, dynamic> query,
  required Map<String, dynamic> body,
}) async {
  await _requireKey();

  try {
    final response = await supabaseDio.post(
      _function,
      queryParameters: query,
      data: body,
      options: Options(validateStatus: (_) => true),
    );
    return _unwrap(response);
  } on DioException catch (e) {
    throw Exception(_networkMessage(e));
  }
}

Future<dynamic> _put({
  required Map<String, dynamic> query,
  required Map<String, dynamic> body,
}) async {
  await _requireKey();

  try {
    final response = await supabaseDio.put(
      _function,
      queryParameters: query,
      data: body,
      options: Options(validateStatus: (_) => true),
    );
    return _unwrap(response);
  } on DioException catch (e) {
    throw Exception(_networkMessage(e));
  }
}

dynamic _unwrap(Response<dynamic> response) {
  final body = response.data;
  final ok = response.statusCode != null && response.statusCode! < 300;

  if (body is Map) {
    // ข้อความ error เป็นภาษาไทยที่เขียนให้ผู้ใช้อ่านอยู่แล้ว แสดงต่อได้เลย
    final error = body['error'];
    if (error != null) throw Exception(error.toString());
    if (ok && body['success'] == true) return body['data'];
  }

  if (ok) return body;
  throw Exception('ทำรายการไม่สำเร็จ (HTTP ${response.statusCode})');
}

/// รอคีย์มาก่อนค่อยยิง เปิดหน้าแจ้งซ่อมทันทีที่เปิดแอปจะได้ไม่ชนกับตอนโหลดคีย์
Future<void> _requireKey() async {
  if (await SupabaseConfig.ensureKey()) return;
  throw Exception('โหลดคีย์ระบบแจ้งซ่อมไม่ได้ กรุณาตรวจสอบอินเทอร์เน็ต');
}

String _networkMessage(DioException e) {
  debugPrint('repair api error: ${e.type} ${e.message}');
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout) {
    return 'เชื่อมต่อระบบแจ้งซ่อมหมดเวลา กรุณาลองใหม่';
  }
  return 'เชื่อมต่อระบบแจ้งซ่อมไม่ได้ กรุณาตรวจสอบอินเทอร์เน็ต';
}

String _str(dynamic value) {
  if (value == null) return '';
  final text = value.toString().trim();
  return text == 'null' ? '' : text;
}

/// created_at กับ completed_at เป็น timestamptz ฐานข้อมูลส่งมาเป็นเวลา UTC
///
/// DateTime.tryParse จะได้ DateTime แบบ UTC และ DateFormat จะพิมพ์ตามนั้นตรง ๆ
/// ไม่แปลงให้ ต้อง toLocal() เอง ไม่งั้นไทยเห็นเวลาย้อนหลังไป 7 ชั่วโมง
DateTime? _localTime(dynamic value) =>
    DateTime.tryParse(_str(value))?.toLocal();

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(_str(value));
}

/// ฐานข้อมูลคืน boolean มาเป็นสตริง "true"/"false" ไม่ใช่ bool จริง
bool _bool(dynamic value) {
  if (value is bool) return value;
  final text = _str(value).toLowerCase();
  return text == 'true' || text == '1';
}

/// วันที่ว่างต้องส่ง null ไม่ใช่สตริงว่าง ไม่งั้น postgres ฟ้อง invalid date
String? _dateOrNull(String value) => value.isEmpty ? null : value;
