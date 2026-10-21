import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:claim/page/claim/image_utils.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('resize_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  File jpeg(String name, int width, int height) {
    final file = File(p.join(dir.path, name));
    file.writeAsBytesSync(
      img.encodeJpg(img.Image(width: width, height: height)),
    );
    return file;
  }

  img.Image read(File f) => img.decodeImage(f.readAsBytesSync())!;

  test('รูปแนวนอนใหญ่ ย่อด้านยาวเหลือ 720 สัดส่วนเดิม', () async {
    final out = await resizeImage(
      jpeg('wide.jpg', 1600, 1200),
      useCache: false,
    );
    final image = read(out);

    expect(image.width, 720);
    expect(image.height, 540);
  });

  test('รูปแนวตั้งจากกล้อง ไม่ถูกบีบเป็นสี่เหลี่ยมจัตุรัส', () async {
    final out = await resizeImage(jpeg('tall.jpg', 960, 1280), useCache: false);
    final image = read(out);

    expect(image.height, 720);
    expect(image.width, 540);
  });

  test('รูปเล็กพออยู่แล้ว ใช้ไฟล์เดิมไม่บีบซ้ำ', () async {
    final source = jpeg('small.jpg', 720, 480);
    final before = source.readAsBytesSync();

    final out = await resizeImage(source, useCache: false);

    expect(out.path, source.path);
    expect(out.readAsBytesSync(), before, reason: 'ต้องไม่ถูกเข้ารหัสใหม่');
  });
}
