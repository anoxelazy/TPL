import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:claim/utils/image_encode.dart';

export 'package:claim/utils/image_encode.dart';

Future<Uint8List> compressImageForUpload(
  File file, {
  int maxEdge = 1600,
  int quality = 85,
}) async {
  final bytes = await file.readAsBytes();
  return compressImageBytes(bytes, maxEdge: maxEdge, quality: quality);
}
