import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:package_info_plus/package_info_plus.dart';

String _encodeBase64(Uint8List bytes) {
  return base64Encode(bytes);
}

Future<Uint8List> _compressImage(Uint8List bytes, {int maxWidth = 1920, int maxHeight = 1080, int quality = 85}) async {
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

  // Decode image
  final image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception('Failed to decode image');
  }

  // Calculate new dimensions while maintaining aspect ratio
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

  // Resize if needed
  img.Image resizedImage;
  if (newWidth != image.width || newHeight != image.height) {
    resizedImage = img.copyResize(image, width: newWidth, height: newHeight);
  } else {
    resizedImage = image;
  }

  // Encode with compression
  return img.encodeJpg(resizedImage, quality: quality);
}

String normalizeUrl(String url) {
  final parts = url.split('://');
  if (parts.length != 2) return url;
  final protocol = parts[0];
  final rest = parts[1].replaceAll(RegExp(r'/+'), '/');
  return '$protocol://$rest';
}

class SimpleHttpResponse {
  final int statusCode;
  final String body;
  SimpleHttpResponse(this.statusCode, this.body);
}

Future<SimpleHttpResponse> postJsonPreserveRedirect(
  Uri uri,
  String jsonBody,
) async {
  final HttpClient client = HttpClient();
  try {
    final HttpClientRequest request = await client.postUrl(uri);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.add(utf8.encode(jsonBody));
    final HttpClientResponse response = await request.close();

    if ({301, 302, 303, 307, 308}.contains(response.statusCode)) {
      final String? location = response.headers.value(
        HttpHeaders.locationHeader,
      );
      if (location != null) {
        final Uri redirectUri = Uri.parse(location);
        if (response.statusCode == 303) {
          final HttpClientRequest getReq = await client.getUrl(redirectUri);
          final HttpClientResponse getResp = await getReq.close();
          final String getBody = await utf8.decoder.bind(getResp).join();
          return SimpleHttpResponse(getResp.statusCode, getBody);
        } else {
          final HttpClientRequest postReq = await client.postUrl(redirectUri);
          postReq.headers.set(
            HttpHeaders.contentTypeHeader,
            'application/json',
          );
          postReq.add(utf8.encode(jsonBody));
          final HttpClientResponse postResp = await postReq.close();
          final String postBody = await utf8.decoder.bind(postResp).join();
          return SimpleHttpResponse(postResp.statusCode, postBody);
        }
      }
    }
    final String body = await utf8.decoder.bind(response).join();
    return SimpleHttpResponse(response.statusCode, body);
  } finally {
    client.close(force: true);
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
  const String baseUrl = "http://147.50.36.66:1152";
  final String url = "$baseUrl/api/GETImageLink_Folder";

  HttpClient? client;

  try {
    final fileSize = await imageFile.length();
    if (fileSize > 50 * 1024 * 1024) {
      throw Exception(
        'Image file too large for upload: ${fileSize ~/ (1024 * 1024)}MB (max 50MB)',
      );
    }

    final bytes = await imageFile.readAsBytes();

    // Compress image before encoding
    final compressedBytes = await _compressImage(bytes);

    if (compressedBytes.length > 30 * 1024 * 1024) {
      throw Exception('Compressed image too large (max 30MB)');
    }

    final String base64Image = await compute(_encodeBase64, compressedBytes);

    client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 7);
    client.idleTimeout = const Duration(seconds: 7);

    final HttpClientRequest request = await client
        .postUrl(Uri.parse(url))
        .timeout(const Duration(seconds: 30));

    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken');
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set('X-Image-Width', '720');
    request.headers.set('X-Image-Height', '720');
    request.headers.set('X-Preserve-Size', 'true');
    request.headers.set('X-No-Resize', 'true');
    request.headers.set('Accept', 'application/json');

    final minimalData = {
      "a1No": a1No,
      "image1": base64Image,
      "empId": empId,
      "folderName": folderName,
      "imageName": imageName,
    };

    final jsonString = jsonEncode(minimalData);
    request.headers.set(
      HttpHeaders.contentLengthHeader,
      utf8.encode(jsonString).length,
    );
    request.add(utf8.encode(jsonString));

    final HttpClientResponse response = await request.close().timeout(
      const Duration(seconds: 120),
    );

    final String body = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 7));

    debugPrint("API Response (${response.statusCode}): ${normalizeUrl(body)}");

    if (response.statusCode == 200) {
      final String raw = body.trim();
      final String normalized = normalizeUrl(raw);
      return normalized;
    } else {
      debugPrint("Upload failed: ${response.statusCode} $body");
      throw Exception('อัปโหลดรูปภาพไม่สำเร็จ');

    }
  } 
  on TimeoutException catch (e) {
    throw Exception('อัปโหลดรูปภาพไม่สำเร็จ');

  } on SocketException catch (e) {
    throw Exception('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาลองส่งใหม่');
  } on TimeoutException catch (e) {
    throw Exception('การอัปโหลดใช้เวลานานเกินไป กรุณาส่งใหม่');
  } finally {
    client?.close(force: true);
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
  const String baseUrl = "http://147.50.36.66:1152";
  final String url = "$baseUrl/api/GETImageLink_Folder";

  HttpClient? client;

  try {
    final fileSize = await imageFile.length();
    if (fileSize > 50 * 1024 * 1024) {
      throw Exception(
        'Image file too large for upload: ${fileSize ~/ (1024 * 1024)}MB (max 50MB)',
      );
    }

    final bytes = await imageFile.readAsBytes();

    client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 7);
    client.idleTimeout = const Duration(seconds: 7);

    final HttpClientRequest request = await client
        .postUrl(Uri.parse(url))
        .timeout(const Duration(seconds: 30));

    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken');
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'multipart/form-data; boundary=boundary123',
    );

    final boundary = 'boundary123';
    final List<int> requestBody = [];

    final fields = {
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
    };

    for (final entry in fields.entries) {
      requestBody.addAll(utf8.encode('--$boundary\r\n'));
      requestBody.addAll(
        utf8.encode(
          'Content-Disposition: form-data; name="${entry.key}"\r\n\r\n',
        ),
      );
      requestBody.addAll(utf8.encode('${entry.value}\r\n'));
    }

    requestBody.addAll(utf8.encode('--$boundary\r\n'));
    requestBody.addAll(
      utf8.encode(
        'Content-Disposition: form-data; name="image1"; filename="$imageName.jpg"\r\n',
      ),
    );
    requestBody.addAll(utf8.encode('Content-Type: image/jpeg\r\n\r\n'));
    requestBody.addAll(bytes);
    requestBody.addAll(utf8.encode('\r\n--$boundary--\r\n'));

    request.add(requestBody);

    final HttpClientResponse response = await request.close().timeout(
      const Duration(seconds: 120),
    );

    final String body = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final String raw = body.trim();
      final String normalized = normalizeUrl(raw);
      return normalized;
    } else {
      // throw Exception('อัปโหลดรูปภาพไม่สำเร็จ');
      return null;

    }
  } on TimeoutException catch (e) {
    throw Exception('อัปโหลดรูปภาพไม่สำเร็จ');

  } on SocketException catch (e) {
    debugPrint('Network error: $e');
    throw Exception('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาลองส่งใหม่');
  } on TimeoutException catch (e) {
    debugPrint('Timeout: $e');
    throw Exception('การอัปโหลดใช้เวลานานเกินไป กรุณาส่งใหม่');
  } finally {
    client?.close(force: true);
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

  // Get app version
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
  const String url = "http://147.50.36.66:1152";
  HttpClient? client;

  try {
    final originalBytes = await imageFile.readAsBytes();

    // Compress image before upload
    final bytes = await _compressImage(originalBytes);

    client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 7);
    client.idleTimeout = const Duration(seconds: 7);

    final request = await client
        .postUrl(Uri.parse(url))
        .timeout(const Duration(seconds: 30));

    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/octet-stream',
    );
    request.headers.set(HttpHeaders.contentLengthHeader, bytes.length);
    request.add(bytes);

    final response = await request.close().timeout(
      const Duration(seconds: 120),
    );

    if (response.statusCode == 200) {
      final responseBytes = await response.toList();
      final flatBytes = responseBytes.expand((x) => x).toList();

      // Check if we received image data (basic check)
      if (flatBytes.isNotEmpty && flatBytes.length > 100) {
        // Assume image is at least 100 bytes
        return Uint8List.fromList(flatBytes);
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
  } on TimeoutException catch (e) {
    debugPrint("Image processing timeout: $e");
    _showErrorNotification('การแปลงรูปภาพหมดเวลา');
    throw Exception('อัปโหลดรูปภาพไม่สำเร็จ');

  } on SocketException catch (e) {
    debugPrint('Network error: $e');
    throw Exception('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาลองส่งใหม่');
  } on TimeoutException catch (e) {
    debugPrint('Timeout: $e');
    throw Exception('การอัปโหลดใช้เวลานานเกินไป กรุณาส่งใหม่');
  } finally {
    client?.close(force: true);
  }
}

void _showErrorNotification(String message) {
  // Since this is called from API, we need context
  // For now, just debug print, but ideally pass context or use global key
  debugPrint('Error notification: $message');
  // TODO: Show actual notification using ScaffoldMessenger or similar
}
