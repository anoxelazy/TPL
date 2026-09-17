import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/utils/api_host.dart';
import 'package:claim/utils/app_logger.dart';
import 'package:claim/utils/dio_service.dart';
import 'package:claim/utils/image_encode_io.dart';
import 'package:claim/page/scan/scan_image_parser.dart';

const String scanModule = 'ScanBar&TakePhoto';
const String scanTagName = 'Bar';
const Duration _apiTimeout = Duration(seconds: 60);

enum ScanCheckStatus { found, notFound, error }

class ScanCheckResult {
  final ScanCheckStatus status;

  final List<String> images;

  final String? message;

  const ScanCheckResult({
    required this.status,
    this.images = const <String>[],
    this.message,
  });

  bool get hasImages => images.isNotEmpty;
}

class ScanApiException implements Exception {
  final String message;

  final String? debugDetail;

  const ScanApiException(this.message, {this.debugDetail});

  @override
  String toString() => message;
}

Future<String> loadScanToken() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token') ?? '';
  if (token.isEmpty) {
    throw const ScanApiException('ไม่พบ token กรุณาเข้าสู่ระบบใหม่');
  }
  return token;
}

Future<String> loadScanEmpId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('driverID') ?? '';
}

Future<ScanCheckResult> checkIsTakeBar({
  required String barcode,
  required String token,
}) async {
  try {
    final response = await dio.post(
      '/api/CheckIsTakeBar',
      queryParameters: {'barcode': barcode, 'module': scanTagName},
      data: const <String, dynamic>{},
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        receiveTimeout: _apiTimeout,
        validateStatus: (_) => true,
      ),
    );

    final code = response.statusCode;
    final parsed = parseImageResponse(response.data, baseUrl: ApiHost.I.active);

    await AppLogger.I.log(
      'scan_check',
      data: {
        'barcode': barcode,
        'status': code,
        'images': parsed.images.length,
      },
    );

    return _interpretCheck(code, parsed);
  } on DioException catch (e) {
    await AppLogger.I.log(
      'scan_check_error',
      data: {'barcode': barcode, 'type': e.type.name},
    );

    return ScanCheckResult(
      status: ScanCheckStatus.error,
      message: _networkMessage(e),
    );
  }
}

ScanCheckResult _interpretCheck(int? code, ParsedImageResponse parsed) {
  if (code == null) {
    return const ScanCheckResult(
      status: ScanCheckStatus.error,
      message: 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาลองใหม่',
    );
  }

  if (code >= 200 && code < 300) {
    return ScanCheckResult(
      status: ScanCheckStatus.found,
      images: parsed.images,
      message: parsed.message,
    );
  }

  if (code == 404) {
    return ScanCheckResult(
      status: ScanCheckStatus.notFound,
      message: parsed.message ?? 'ไม่พบข้อมูลรูปของบาร์โค้ดนี้',
    );
  }

  if (code >= 500) {
    return const ScanCheckResult(
      status: ScanCheckStatus.error,
      message: 'เซิร์ฟเวอร์มีปัญหา กรุณาติดต่อเจ้าหน้าที่',
    );
  }

  return ScanCheckResult(
    status: ScanCheckStatus.error,
    message: parsed.message ?? 'ตรวจสอบบาร์โค้ดไม่สำเร็จ (code $code)',
  );
}

String _networkMessage(DioException e) {
  if (e.response?.statusCode == 401) {
    return 'token หมดอายุ กรุณาเข้าสู่ระบบใหม่';
  }
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout) {
    return 'เชื่อมต่อเซิร์ฟเวอร์หมดเวลา กรุณาลองใหม่';
  }
  return 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาลองใหม่';
}

Future<Uint8List> uploadTrackingImage({
  required String barcode,
  required File file,
  required String empId,
  required String token,
}) async {
  if (await file.length() > maxUploadFileBytes) {
    throw const ScanApiException('ไฟล์รูปใหญ่เกินไป กรุณาถ่ายใหม่');
  }

  final bytes = await compressImageForUpload(file);
  final base64Image = await encodeBase64InBackground(bytes);
  const imageCount = 1;

  await AppLogger.I.log(
    'scan_upload_start',
    data: {
      'barcode': barcode,
      'imageCount': imageCount,
      'sizeKB': (base64Image.length / 1024).round(),
    },
  );

  try {
    final response = await dio.post(
      '/api/TrackingImg',
      data: {
        'Tracking': barcode,
        'TagName': scanTagName,
        'EmpID': empId,
        'ImgLst': [base64Image],
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        receiveTimeout: _apiTimeout,
        sendTimeout: _apiTimeout,
        validateStatus: (_) => true,
      ),
    );

    final ok = isUploadSuccessful(
      statusCode: response.statusCode,
      body: response.data,
      sentCount: imageCount,
    );

    await AppLogger.I.log(
      'scan_upload_result',
      data: {'barcode': barcode, 'status': response.statusCode, 'success': ok},
    );

    if (!ok) {
      throw ScanApiException(
        'กรุณาถ่ายใหม่ $barcode ส่งไม่สำเร็จ',
        debugDetail:
            'status=${response.statusCode} body=${_shortBody(response.data)}',
      );
    }

    return bytes;
  } on DioException catch (e) {
    await AppLogger.I.log(
      'scan_upload_error',
      data: {'barcode': barcode, 'type': e.type.name},
    );

    throw ScanApiException(
      'กรุณาถ่ายใหม่ $barcode ส่งไม่สำเร็จ',
      debugDetail: 'dio=${e.type.name} status=${e.response?.statusCode}',
    );
  }
}

bool isUploadSuccessful({
  required int? statusCode,
  required dynamic body,
  required int sentCount,
}) {
  if (statusCode == null || statusCode < 200 || statusCode >= 300) return false;

  final map = _asJsonMap(body);
  if (map == null) return false;

  if (map['success'] != true && map['success']?.toString() != 'true') {
    return false;
  }

  final saved = _asInt(map['saved']);
  if (saved == null || saved < sentCount) return false;

  return true;
}

Map<String, dynamic>? _asJsonMap(dynamic body) {
  dynamic decoded = body;

  if (decoded is String) {
    final trimmed = decoded.trim();
    if (trimmed.isEmpty) return null;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
  }

  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  return null;
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

String _shortBody(dynamic body) {
  final text = body?.toString() ?? '';
  return text.length <= 200 ? text : '${text.substring(0, 200)}...';
}
