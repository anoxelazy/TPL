import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

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

  try {
    final bytes = await imageFile.readAsBytes();
    final String base64Image = base64Encode(bytes);

    final HttpClient client = HttpClient();
    final HttpClientRequest request = await client.postUrl(Uri.parse(url));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken');
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.add(utf8.encode(jsonEncode({
      "a1No": a1No,
      "IsStempText": false,
      "image1": base64Image,
      "lat": lat,
      "lon": lon,
      "empId": empId,
      "folderName": folderName,
      "imageName": imageName,
    })));
    final HttpClientResponse response = await request.close();
    final String body = await utf8.decoder.bind(response).join();

    debugPrint("API Response (${response.statusCode}): ${normalizeUrl(body)}");

    if (response.statusCode == 200) {
      final String raw = body.trim();
      final String normalized = normalizeUrl(raw);
      return normalized;
    } else {
      debugPrint("Upload failed: ${response.statusCode} $body");
      return null;
    }
  } catch (e) {
    debugPrint("sendClaimToAPI error: $e");
    return null;
  }
}

Future<Map<String, dynamic>> buildSheetPayload(Map<String, dynamic> claim) async {
  final DateTime timestamp = claim['timestamp'] ?? DateTime.now();
  final List<String> imageLinks = List<String>.from(claim['uploadedLinks'] ?? []);
  final String a1 = claim['docNumber'] ?? '';
  final String userId = claim['empID'] ?? '';
  final String dateKey = DateFormat('yyyyMMdd').format(timestamp);
  final String dedupeKey = '${a1}_${userId}_${dateKey}_${imageLinks.length}';

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
  };
}


