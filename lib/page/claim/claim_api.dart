import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:claim/utils/dio_service.dart';
import 'package:claim/utils/url_utils.dart';

// ฟีเจอร์อื่นเรียก normalizeUrl ผ่านไฟล์นี้อยู่ จึงส่งต่อจากตัวกลางให้
export 'package:claim/utils/url_utils.dart' show normalizeUrl, resolveImageUrl;

String _encodeBase64(Uint8List bytes) {
  return base64Encode(bytes);
}

Future<Uint8List> _compressImage(
  Uint8List bytes, {
  int maxWidth = 1920,
  int maxHeight = 1080,
  int quality = 85,
}) async {
  return await compute(_compressImageIsolate, {
    'bytes': bytes,
    'maxWidth': maxWidth,
    'maxHeight': maxHeight,
    'quality': quality,
  });
}

Uint8List _compressImageIsolate(Map<String, dynamic> params) {
  final bytes = params['bytes'] as Uint8List;
  final maxWidth = params['maxWidth'] as int;
  final maxHeight = params['maxHeight'] as int;
  final quality = params['quality'] as int;

  final image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception('Failed to decode image');
  }

  var newWidth = image.width;
  var newHeight = image.height;

  if (newWidth > maxWidth) {
    newHeight = (newHeight * maxWidth / newWidth).round();
    newWidth = maxWidth;
  }

  if (newHeight > maxHeight) {
    newWidth = (newWidth * maxHeight / newHeight).round();
    newHeight = maxHeight;
  }

  img.Image resizedImage;
  if (newWidth != image.width || newHeight != image.height) {
    resizedImage = img.copyResize(image, width: newWidth, height: newHeight);
  } else {
    resizedImage = image;
  }

  return img.encodeJpg(resizedImage, quality: quality);
}

class SimpleHttpResponse {
  final int statusCode;
  final String body;
  final bool noResponse;

  SimpleHttpResponse(this.statusCode, this.body, {this.noResponse = false});
}

Future<SimpleHttpResponse> postJsonPreserveRedirect(
  Uri uri,
  String jsonBody,
) async {
  try {
    final response = await dio.postUri(
      uri,
      data: jsonBody,
      options: Options(
        headers: {'Content-Type': 'application/json'},
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
        followRedirects: true,
        maxRedirects: 5,
        validateStatus: (_) => true,
      ),
    );

    return SimpleHttpResponse(
      response.statusCode ?? 0,
      response.data.toString(),
    );
  } on DioException catch (e) {
    final response = e.response;
    if (response != null) {
      return SimpleHttpResponse(
        response.statusCode ?? 0,
        response.data?.toString() ?? '',
      );
    }
    debugPrint('Sheet POST no response: ${e.type} ${e.message}');
    return SimpleHttpResponse(0, e.message ?? e.type.name, noResponse: true);
  }
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
  try {
    final fileSize = await imageFile.length();
    if (fileSize > 50 * 1024 * 1024) {
      throw Exception(
        'Image file too large for upload: ${fileSize ~/ (1024 * 1024)}MB (max 50MB)',
      );
    }

    final bytes = await imageFile.readAsBytes();
    final compressedBytes = await _compressImage(bytes);

    if (compressedBytes.length > 30 * 1024 * 1024) {
      throw Exception('Compressed image too large (max 30MB)');
    }

    final String base64Image = await compute(_encodeBase64, compressedBytes);

    final response = await dio.post(
      '/api/GETImageLink_Folder',
      data: {
        "a1No": a1No,
        "image1": base64Image,
        "empId": empId,
        "folderName": folderName,
        "imageName": imageName,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
          'X-Image-Width': '720',
          'X-Image-Height': '720',
          'X-Preserve-Size': 'true',
          'X-No-Resize': 'true',
          'Accept': 'application/json',
        },
        // เซิร์ฟเวอร์ต้องอัปโหลดรูปต่อไปยัง Drive ก่อนตอบลิงก์กลับมา
        // มักเกิน receiveTimeout 7 วินาทีของ dio
        receiveTimeout: const Duration(seconds: 60),
      ),
    );

    if (response.statusCode == 200) {
      final String raw = response.data.toString().trim();
      final String normalized = normalizeUrl(raw);
      return normalized;
    } else {
      throw Exception('อัปโหลดรูปภาพไม่สำเร็จ');
    }
  } on DioException catch (e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw Exception('อัปโหลดรูปภาพไม่สำเร็จ');
    }
    throw Exception('อัปโหลดรูปภาพไม่สำเร็จ');
  }
}

Future<String?> sendClaimToAPIMultipart({
  required String a1No,
  required String empId,
  required String folderName,
  required String imageName,
  required File imageFile,
  required double lat,
  required double lon,
  required String bearerToken,
}) async {
  try {
    final fileSize = await imageFile.length();
    if (fileSize > 50 * 1024 * 1024) {
      throw Exception(
        'Image file too large for upload: ${fileSize ~/ (1024 * 1024)}MB (max 50MB)',
      );
    }

    final bytes = await imageFile.readAsBytes();

    final formData = FormData.fromMap({
      'a1No': a1No,
      'IsStempText': 'false',
      'lat': lat.toString(),
      'lon': lon.toString(),
      'empId': empId,
      'folderName': folderName,
      'imageName': imageName,
      'width': '720',
      'height': '720',
      'keepOriginalSize': 'true',
      'image1': MultipartFile.fromBytes(
        bytes,
        filename: '$imageName.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    });

    final response = await dio.post(
      '/api/GETImageLink_Folder',
      data: formData,
      options: Options(
        headers: {'Authorization': 'Bearer $bearerToken'},
        // เหมือน sendClaimToAPI: รอเซิร์ฟเวอร์อัปโหลดรูปขึ้น Drive
        receiveTimeout: const Duration(seconds: 60),
      ),
    );

    if (response.statusCode == 200) {
      final String raw = response.data.toString().trim();
      final String normalized = normalizeUrl(raw);
      return normalized;
    } else {
      return null;
    }
  } on DioException catch (e) {
    debugPrint('Multipart upload error: ${e.type} ${e.message}');
    return null;
  }
}

Future<Map<String, dynamic>> buildSheetPayload(
  Map<String, dynamic> claim,
) async {
  final DateTime timestamp = claim['timestamp'] ?? DateTime.now();
  final List<String> imageLinks = List<String>.from(
    claim['uploadedLinks'] ?? [],
  );
  final String a1 = claim['docNumber'] ?? '';
  final String userId = claim['empID'] ?? '';
  final String dateKey = DateFormat('yyyyMMdd').format(timestamp);
  final String dedupeKey = '${a1}_${userId}_${dateKey}_${imageLinks.length}';
  final String remarkType = claim['remarkType'] ?? '';
  final packageInfo = await PackageInfo.fromPlatform();
  final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

  return {
    'date': DateFormat('yyyy-MM-dd').format(timestamp),
    'a1_no': a1,
    'claim_type': claim['type'] ?? '',
    'truck_no': claim['carCode'] ?? '',
    'user_id': userId,
    'images': imageLinks,
    'image_count': imageLinks.length,
    'created_at': timestamp.toIso8601String(),
    'dedupe_key': dedupeKey,
    'remarks_type': claim['remarks'] ?? '',
    'remark_type': remarkType,
    'special_case': claim['fromFrontStore'] == true ? 'มาจากคลังหน้าบ้าน' : '',
    'version': appVersion,
  };
}

Future<Uint8List?> sendImageForProcessing(File imageFile) async {
  try {
    final originalBytes = await imageFile.readAsBytes();
    final bytes = await _compressImage(originalBytes);

    final response = await dio.post(
      '/',
      data: bytes,
      options: Options(
        headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Length': bytes.length,
        },
      ),
    );

    if (response.statusCode == 200) {
      final responseBytes = response.data;

      if (responseBytes is List &&
          responseBytes.isNotEmpty &&
          responseBytes.length > 100) {
        return Uint8List.fromList(List<int>.from(responseBytes));
      } else {
        _showErrorNotification('ไม่ได้รับข้อมูลรูปภาพกลับมา');
        throw Exception('อัปโหลดรูปภาพไม่สำเร็จ');
      }
    } else {
      _showErrorNotification(
        'การส่งรูปภาพล้มเหลว: HTTP ${response.statusCode}',
      );
      throw Exception('อัปโหลดรูปภาพไม่สำเร็จ');
    }
  } on DioException catch (e) {
    debugPrint("Image processing error: ${e.message}");
    if (e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionTimeout) {
      _showErrorNotification('การแปลงรูปภาพหมดเวลา');
      throw Exception('อัปโหลดรูปภาพไม่สำเร็จ');
    }
    throw Exception('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาลองส่งใหม่');
  }
}

void _showErrorNotification(String message) {
  debugPrint('Error notification: $message');
}
