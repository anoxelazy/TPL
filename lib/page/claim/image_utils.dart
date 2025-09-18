import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

Future<File> resizeImage(File file, {int maxSize = 720, bool useCache = true}) async {
  try {
    if (useCache) {
      final cached = _ImageCache.get(file, maxSize, 78);
      if (cached != null && await cached.exists()) {
        return cached;
      }
    }

    final fileSize = await file.length();
    if (fileSize > 100 * 1024 * 1024) {
      throw Exception('Image file too large: ${fileSize ~/ (1024 * 1024)}MB (max 100MB)');
    }

    final bytes = await file.readAsBytes();

    final decodedImage = await compute(_decodeImageSafely, bytes);
    if (decodedImage == null) {
      throw Exception('Failed to decode image');
    }

    if (decodedImage.width > 20000 || decodedImage.height > 20000) {
      throw Exception('Image dimensions too large: ${decodedImage.width}x${decodedImage.height} (max 20000x20000)');
    }

    img.Image processedImage;

    if (decodedImage.width <= maxSize && decodedImage.height <= maxSize) {
      processedImage = decodedImage;
      debugPrint('Image already within size limits: ${decodedImage.width}x${decodedImage.height}');
    } else {
      final aspectRatio = decodedImage.width / decodedImage.height;
      int newWidth, newHeight;

      if (aspectRatio > 1) {
        newWidth = maxSize;
        newHeight = (maxSize / aspectRatio).round();
      } else {
        newHeight = maxSize;
        newWidth = (maxSize * aspectRatio).round();
      }

      debugPrint('Resizing image from ${decodedImage.width}x${decodedImage.height} to ${newWidth}x${newHeight} (maxSize: $maxSize)');

      processedImage = img.copyResize(
        decodedImage,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.cubic,
      );

      debugPrint('Resize completed: ${processedImage.width}x${processedImage.height}');
    }

    final newBytes = await compute(_encodeImageSafely, _EncodeParams(processedImage, 78, progressive: true));

    final newFile = await file.writeAsBytes(newBytes, flush: true);

    if (useCache) {
      _ImageCache.put(file, maxSize, 78, newFile);
    }

    return newFile;

  } catch (e) {
    debugPrint('Image processing error: $e');
    return file;
  }
}

class _EncodeParams {
  final img.Image image;
  final int quality;
  final bool progressive;
  _EncodeParams(this.image, this.quality, {this.progressive = false});
}

class _ImageCache {
  static final Map<String, File> _cache = {};
  static const int _maxCacheSize = 10;

  static void _initialize() {
    clearOldQualityCache();
  }

  static String _getCacheKey(File file, int maxSize, int quality) {
    return '${file.path}_${maxSize}_${quality}';
  }

  static File? get(File file, int maxSize, int quality) {
    final key = _getCacheKey(file, maxSize, quality);
    return _cache[key];
  }

  static void put(File file, int maxSize, int quality, File processedFile) {
    final key = _getCacheKey(file, maxSize, quality);
    if (_cache.length >= _maxCacheSize) {
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
    }
    _cache[key] = processedFile;
  }

  static void clear() {
    _cache.clear();
  }

  static void clearOldQualityCache() {
    final keysToRemove = <String>[];
    for (final key in _cache.keys) {
      if (key.contains('_60') || key.contains('_40')) {
        keysToRemove.add(key);
      }
    }
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }
}

Future<List<File>> processImagesBatch(List<File> files, {int maxSize = 720}) async {
  final List<Future<File>> futures = [];

  for (final file in files) {
    futures.add(resizeImage(file, maxSize: maxSize, useCache: true));
  }

  final results = await Future.wait(futures, eagerError: false);
  return results;
}

String _getOptimalFormat(String filePath) {
  final extension = filePath.toLowerCase().split('.').last;
  switch (extension) {
    case 'jpg':
    case 'jpeg':
      return 'jpg';
    case 'png':
      return 'png';
    case 'webp':
      return 'webp';
    default:
      return 'jpg';
  }
}

class ImagePreloader {
  static final Map<String, Future<File>> _preloadCache = {};

  static Future<File> preloadImage(File file, {int maxSize = 720}) {
    final key = '${file.path}_${maxSize}';
    if (_preloadCache.containsKey(key)) {
      return _preloadCache[key]!;
    }

    final future = resizeImage(file, maxSize: maxSize, useCache: true);
    _preloadCache[key] = future;

    future.then((_) {
      Future.delayed(const Duration(minutes: 5), () {
        _preloadCache.remove(key);
      });
    });

    return future;
  }

  static void clearPreloadCache() {
    _preloadCache.clear();
  }
}

img.Image? _decodeImageSafely(Uint8List bytes) {
  try {
    return img.decodeImage(bytes);
  } catch (e) {
    debugPrint('Image decode error in isolate: $e');
    return null;
  }
}

Uint8List _encodeImageSafely(_EncodeParams params) {
  try {
    return img.encodeJpg(
      params.image,
      quality: params.quality,
    );
  } catch (e) {
    debugPrint('Image encode error in isolate: $e');
    return img.encodeJpg(img.Image(width: 1, height: 1), quality: 50);
  }
}

Future<File> generateThumbnail(File file, {int size = 720}) async {
  try {
    final cached = _ImageCache.get(file, size, 65);
    if (cached != null && await cached.exists()) {
      return cached;
    }

    final bytes = await file.readAsBytes();
    final decodedImage = await compute(_decodeImageSafely, bytes);

    if (decodedImage == null) {
      throw Exception('Failed to decode image for thumbnail');
    }

    final thumbnail = img.copyResize(
      decodedImage,
      width: size,
      height: size,
      interpolation: img.Interpolation.cubic, 
    );

    final thumbnailBytes = await compute(_encodeImageSafely, _EncodeParams(thumbnail, 65, progressive: false)); 
    final thumbnailFile = await file.writeAsBytes(thumbnailBytes, flush: true);

    _ImageCache.put(file, size, 65, thumbnailFile);

    return thumbnailFile;
  } catch (e) {
    debugPrint('Thumbnail generation error: $e');
    return file;
  }
}


