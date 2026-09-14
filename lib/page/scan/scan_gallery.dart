import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// บันทึกสำเนารูปที่ส่งสำเร็จลงคลังรูปของเครื่อง
///
/// คืน false เมื่อบันทึกไม่ได้ ไม่โยน exception ออกไป เพราะการส่งขึ้นเซิร์ฟเวอร์
/// สำเร็จไปแล้ว ห้ามให้เรื่องนี้กระทบผลการส่ง
///
/// [gal] ตั้งชื่อไฟล์ในคลังรูปตามชื่อไฟล์ต้นทาง จึงเขียนลง temp ด้วยชื่อที่ต้องการ
/// ก่อนแล้วค่อยส่งเข้าคลัง
Future<bool> saveScanImageToGallery({
  required Uint8List bytes,
  required String barcode,
}) async {
  try {
    final name =
        'scan_barcode_${barcode}_${DateTime.now().millisecondsSinceEpoch}';
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, '$name.jpg'));
    await file.writeAsBytes(bytes, flush: true);

    if (!await Gal.hasAccess()) {
      await Gal.requestAccess();
    }
    await Gal.putImage(file.path);
    return true;
  } catch (e) {
    debugPrint('Save to gallery failed: $e');
    return false;
  }
}
