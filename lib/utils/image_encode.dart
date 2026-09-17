import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// ขนาดไฟล์รูปที่ยอมรับ ใหญ่กว่านี้ decode ไม่ผ่านหรือกินแรมจนแอปตาย
const int maxUploadFileBytes = 50 * 1024 * 1024;

/// ย่อรูปสำหรับอัปโหลดโดยคงสัดส่วนเดิม
///
/// คงสัดส่วนเพราะรูปหลักฐาน (หน้าปัดไมล์ / บาร์โค้ด) ต้องอ่านตัวเลขออก
/// การบีบเป็นสี่เหลี่ยมจัตุรัสทำให้อ่านไม่ได้
///
/// ทำใน isolate เพราะทั้ง decode และ encode หนักพอที่จะทำให้เฟรมกระตุก
/// ย่อไม่สำเร็จจะคืนไบต์เดิม ดีกว่าบล็อกไม่ให้ส่งเลย
///
/// รับเป็นไบต์ไม่ใช่ File เพราะไฟล์นี้ต้องคอมไพล์บนเว็บได้ด้วย ซึ่งไม่มี
/// `dart:io` ฝั่งที่ถือไฟล์จริงอยู่ให้ใช้ compressImageForUpload ใน
/// image_encode_io.dart ที่ห่อตัวนี้ไว้อีกชั้น
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
