import 'dart:io';
import 'package:image/image.dart' as img;

Future<File> resizeImage(File file, {int maxSize = 1080}) async {
  final bytes = await file.readAsBytes();
  final decodedImage = img.decodeImage(bytes);
  if (decodedImage == null) return file;

  if (decodedImage.width <= maxSize && decodedImage.height <= maxSize) {
    return file;
  }

  final resized = img.copyResize(
    decodedImage,
    width: decodedImage.width > decodedImage.height ? maxSize : null,
    height: decodedImage.height >= decodedImage.width ? maxSize : null,
    interpolation: img.Interpolation.cubic,
  );

  final newBytes = img.encodeJpg(resized, quality: 90);
  final newFile = await file.writeAsBytes(newBytes, flush: true);
  return newFile;
}


