import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

// Function to run base64 encoding in separate isolate
String _encodeBase64(Uint8List bytes) {
  return base64Encode(bytes);
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
      final String? location = response.headers.value(HttpHeaders.locationHeader);
      if (location != null) {
        final Uri redirectUri = Uri.parse(location);
        if (response.statusCode == 303) {
          final HttpClientRequest getReq = await client.getUrl(redirectUri);
          final HttpClientResponse getResp = await getReq.close();
          final String getBody = await utf8.decoder.bind(getResp).join();
          return SimpleHttpResponse(getResp.statusCode, getBody);
        } else {
          final HttpClientRequest postReq = await client.postUrl(redirectUri);
          postReq.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
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

// Upload image to server - tries multipart first for better size preservation
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
  const String baseUrl = "http://61.91.54.130:1159";
  final String url = "$baseUrl/api/GETImageLink_Folder";

  HttpClient? client;

  try {
    final fileSize = await imageFile.length();
    if (fileSize > 50 * 1024 * 1024) { 
      throw Exception('Image file too large for upload: ${fileSize ~/ (1024 * 1024)}MB (max 50MB)');
    }

    final bytes = await imageFile.readAsBytes();

    if (bytes.length > 30 * 1024 * 1024) { 
      throw Exception('Image too large after encoding (max 30MB raw file)');
    }

    final String base64Image = await compute(_encodeBase64, bytes);

    client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30); 
    client.idleTimeout = const Duration(seconds: 30); 

    final HttpClientRequest request = await client.postUrl(Uri.parse(url))
        .timeout(const Duration(seconds: 60)); 

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
    request.headers.set(HttpHeaders.contentLengthHeader, utf8.encode(jsonString).length);
    request.add(utf8.encode(jsonString));

    final HttpClientResponse response = await request.close()
        .timeout(const Duration(seconds: 120)); // Response timeout

    final String body = await utf8.decoder.bind(response)
        .join()
        .timeout(const Duration(seconds: 30)); // Body read timeout

    debugPrint("API Response (${response.statusCode}): ${normalizeUrl(body)}");

    if (response.statusCode == 200) {
      final String raw = body.trim();
      final String normalized = normalizeUrl(raw);
      return normalized;
    } else {
      debugPrint("Upload failed: ${response.statusCode} $body");
      return null;
    }
  } on TimeoutException catch (e) {
    debugPrint("Upload timeout: $e");
    return null;
  } catch (e) {
    debugPrint("sendClaimToAPI error: $e");
    return null;
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
  const String baseUrl = "http://61.91.54.130:1159";
  final String url = "$baseUrl/api/GETImageLink_Folder";

  HttpClient? client;

  try {
    final fileSize = await imageFile.length();
    if (fileSize > 50 * 1024 * 1024) { 
      throw Exception('Image file too large for upload: ${fileSize ~/ (1024 * 1024)}MB (max 50MB)');
    }

    final bytes = await imageFile.readAsBytes();

    client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);
    client.idleTimeout = const Duration(seconds: 30);

    final HttpClientRequest request = await client.postUrl(Uri.parse(url))
        .timeout(const Duration(seconds: 60));

    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken');
    request.headers.set(HttpHeaders.contentTypeHeader, 'multipart/form-data; boundary=boundary123');

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
      requestBody.addAll(utf8.encode('Content-Disposition: form-data; name="${entry.key}"\r\n\r\n'));
      requestBody.addAll(utf8.encode('${entry.value}\r\n'));
    }

    requestBody.addAll(utf8.encode('--$boundary\r\n'));
    requestBody.addAll(utf8.encode('Content-Disposition: form-data; name="image1"; filename="$imageName.jpg"\r\n'));
    requestBody.addAll(utf8.encode('Content-Type: image/jpeg\r\n\r\n'));
    requestBody.addAll(bytes);
    requestBody.addAll(utf8.encode('\r\n--$boundary--\r\n'));

    request.add(requestBody);

    final HttpClientResponse response = await request.close()
        .timeout(const Duration(seconds: 120));

    final String body = await utf8.decoder.bind(response)
        .join()
        .timeout(const Duration(seconds: 30));


    if (response.statusCode == 200) {
      final String raw = body.trim();
      final String normalized = normalizeUrl(raw);
      return normalized;
    } else {
      return null;
    }
  } on TimeoutException catch (e) {
    return null;
  } catch (e) {
    return null;
  } finally {
    client?.close(force: true);
  }
}

Future<Map<String, dynamic>> buildSheetPayload(Map<String, dynamic> claim) async {
  final DateTime timestamp = claim['timestamp'] ?? DateTime.now();
  final List<String> imageLinks = List<String>.from(claim['uploadedLinks'] ?? []);
  final String a1 = claim['docNumber'] ?? '';
  final String userId = claim['empID'] ?? '';
  final String dateKey = DateFormat('yyyyMMdd').format(timestamp);
  final String dedupeKey = '${a1}_${userId}_${dateKey}_${imageLinks.length}';
  final String remarkType = claim['remarkType'] ?? '';

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
  };
}


