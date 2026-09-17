import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

const int maxUploadFileBytes = 50 * 1024 * 1024;

Future<Uint8List> compressImageBytes(
  Uint8List bytes, {
  int maxEdge = 1600,
  int quality = 85,
}) async {
  try {
    return await compute(
      _compressIsolate,
      _CompressRequest(bytes, maxEdge, quality),
    );
  } catch (e) {
    debugPrint('Image compress failed: $e');
    return bytes;
  }
}

/// แปลงเป็น base64 (ไม่มี prefix data:image) ใน isolate
Future<String> encodeBase64InBackground(Uint8List bytes) {
  return compute(base64Encode, bytes);
}

class _CompressRequest {
  final Uint8List bytes;
  final int maxEdge;
  final int quality;

  const _CompressRequest(this.bytes, this.maxEdge, this.quality);
}

Uint8List _compressIsolate(_CompressRequest request) {
  final decoded = img.decodeImage(request.bytes);
  if (decoded == null) return request.bytes;

  final longest = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;

  // ไม่ขยายรูปที่เล็กกว่าเป้าอยู่แล้ว
  final resized = longest <= request.maxEdge
      ? decoded
      : img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? request.maxEdge : null,
          height: decoded.height > decoded.width ? request.maxEdge : null,
          interpolation: img.Interpolation.linear,
        );

  return img.encodeJpg(resized, quality: request.quality);
}
