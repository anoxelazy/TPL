import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:claim/utils/image_encode.dart';

export 'package:claim/utils/image_encode.dart';

/// ย่อรูปจากไฟล์บนเครื่อง สำหรับฝั่งที่มี `dart:io` (มือถือ/เดสก์ท็อป)
///
/// แยกออกมาจาก image_encode.dart เพราะไฟล์นั้นต้องคอมไพล์บนเว็บได้ด้วย
/// และเว็บไม่มี `dart:io` เลย import ตัวที่มี File ปนเข้าไปไม่ได้
///
/// re-export ตัวหลักไว้ด้วย ฝั่งมือถือจึง import ไฟล์เดียวจบเหมือนเดิม
/// ยังเรียก [encodeBase64InBackground] ต่อได้โดยไม่ต้อง import เพิ่ม
Future<Uint8List> compressImageForUpload(
  File file, {
  int maxEdge = 1600,
  int quality = 85,
}) async {
  final bytes = await file.readAsBytes();
  return compressImageBytes(bytes, maxEdge: maxEdge, quality: quality);
}
