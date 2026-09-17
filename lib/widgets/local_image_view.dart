import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';

/// รูปที่ผู้ใช้เพิ่งเลือกไว้ ยังไม่ได้อัปโหลด
///
/// อ่านเป็นไบต์แล้ววาดด้วย [Image.memory] แทน `Image.file` เพราะเว็บไม่มี
/// `dart:io` ให้สร้าง File และ path ของ [XFile] ฝั่งเว็บเป็น blob ที่เปิดแบบ
/// ไฟล์ไม่ได้ ทางนี้ใช้ได้เหมือนกันทั้งมือถือและเว็บ
///
/// ใช้กับรูปที่เพิ่งเลือกเท่านั้น รูปที่อัปโหลดไปแล้วเป็น URL ให้ใช้
/// [Image.network] ตามปกติ
class LocalImageView extends StatelessWidget {
  final XFile file;

  final double? width;
  final double? height;
  final BoxFit fit;

  const LocalImageView({
    super.key,
    required this.file,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      // อ่านใหม่เมื่อเปลี่ยนรูป ไม่ใช่ค้างรูปเดิมเพราะ future ตัวเก่ายังอยู่
      key: ValueKey(file.path),
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return SizedBox(
            width: width,
            height: height ?? 120,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        return Image.memory(bytes, width: width, height: height, fit: fit);
      },
    );
  }
}
