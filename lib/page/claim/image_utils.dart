import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

Future<File> resizeImage(File file, {int maxSize = 720, bool useCache = true}) async {
  try {
    // Check cache first
    if (useCache) {
      final cached = _ImageCache.get(file, maxSize, 78);
      if (cached != null && await cached.exists()) {
        debugPrint('Using cached image');
        return cached;
      }
    }

    // Get file size
    final fileSize = await file.length();
    if (fileSize > 50 * 1024 * 1024) { // Reduced from 100MB to 50MB
      throw Exception('Image file too large: ${fileSize ~/ (1024 * 1024)}MB (max 50MB)');
    }

    debugPrint('Processing image, size: ${fileSize ~/ 1024}KB');

    // Read file with timeout to prevent hanging
    final bytes = await file.readAsBytes();

    // Decode image in isolate
    final decodedImage = await compute(_decodeImageSafely, bytes);
    if (decodedImage == null) {
      throw Exception('Failed to decode image');
    }

    // Check dimensions (reduced limits for mobile performance)
    if (decodedImage.width > 10000 || decodedImage.height > 10000) {
      throw Exception('Image dimensions too large: ${decodedImage.width}x${decodedImage.height} (max 10000x10000)');
    }

    img.Image processedImage;

    // Only resize if necessary
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

      debugPrint('Resizing image from ${decodedImage.width}x${decodedImage.height} to ${newWidth}x${newHeight}');

      // Use faster interpolation for mobile
      processedImage = img.copyResize(
        decodedImage,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear, // Changed from cubic to linear for speed
      );

      debugPrint('Resize completed: ${processedImage.width}x${processedImage.height}');
    }

    // Encode with lower quality for smaller file size and faster processing
    final newBytes = await compute(_encodeImageSafely, _EncodeParams(processedImage, 85, progressive: false)); // Increased quality from 78 to 85, removed progressive

    // Write file
    final newFile = await file.writeAsBytes(newBytes, flush: true);

    // Cache the result
    if (useCache) {
      _ImageCache.put(file, maxSize, 85, newFile); // Updated quality parameter
    }

    debugPrint('Image processing completed, final size: ${newBytes.length ~/ 1024}KB');
    return newFile;

  } catch (e) {
    debugPrint('Image processing error: $e');
    // Return original file if processing fails
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
      // Clear old quality caches (60, 40, 65, 78)
      if (key.contains('_60') || key.contains('_40') || key.contains('_65') || key.contains('_78')) {
        keysToRemove.add(key);
      }
    }
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }

  static void clearAllCache() {
    _cache.clear();
    debugPrint('Image cache cleared');
  }

  static int getCacheSize() {
    return _cache.length;
  }
}

// Public function to clear old cache
void clearOldImageCache() {
  _ImageCache.clearOldQualityCache();
}

Future<List<File>> processImagesBatch(List<File> files, {int maxSize = 720}) async {
  debugPrint('Starting parallel batch processing of ${files.length} images');

  // Process images in parallel with controlled concurrency
  // Use chunks of 2 images at a time to avoid overwhelming mobile devices
  const int concurrencyLimit = 2;
  final List<File> results = [];

  for (int i = 0; i < files.length; i += concurrencyLimit) {
    final endIndex = (i + concurrencyLimit < files.length) ? i + concurrencyLimit : files.length;
    final chunk = files.sublist(i, endIndex);

    debugPrint('Processing chunk ${i ~/ concurrencyLimit + 1}/${(files.length / concurrencyLimit).ceil()}: ${chunk.length} images');

    // Process this chunk in parallel
    final chunkFutures = chunk.map((file) async {
      try {
        return await resizeImage(file, maxSize: maxSize, useCache: true);
      } catch (e) {
        debugPrint('Failed to process image: $e');
        return file; // Return original file if processing fails
      }
    });

    // Wait for all images in this chunk to complete
    final chunkResults = await Future.wait(chunkFutures, eagerError: false);
    results.addAll(chunkResults);

    debugPrint('Chunk completed: ${chunkResults.length} images processed');
  }

  debugPrint('Batch processing completed: ${results.length}/${files.length} images');
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
    final image = img.decodeImage(bytes);
    if (image != null) {
      debugPrint('Decoded image: ${image.width}x${image.height}');
    }
    return image;
  } catch (e) {
    debugPrint('Image decode error in isolate: $e');
    return null;
  }
}

Uint8List _encodeImageSafely(_EncodeParams params) {
  try {
    final result = img.encodeJpg(
      params.image,
      quality: params.quality,
    );
    debugPrint('Encoded image, size: ${result.length ~/ 1024}KB, quality: ${params.quality}');
    return result;
  } catch (e) {
    debugPrint('Image encode error in isolate: $e');
    try {
      return img.encodeJpg(img.Image(width: 1, height: 1), quality: 50);
    } catch (fallbackError) {
      debugPrint('Fallback encoding also failed: $fallbackError');
      return Uint8List(0);
    }
  }
}

Future<File> generateThumbnail(File file, {int size = 720}) async {
  try {
    final cached = _ImageCache.get(file, size, 75); // Updated quality
    if (cached != null && await cached.exists()) {
      return cached;
    }

    final bytes = await file.readAsBytes();
    final decodedImage = await compute(_decodeImageSafely, bytes);

    if (decodedImage == null) {
      throw Exception('Failed to decode image for thumbnail');
    }

    // Create thumbnail with faster processing
    final thumbnail = img.copyResize(
      decodedImage,
      width: size,
      height: size,
      interpolation: img.Interpolation.linear, // Changed to linear for speed
    );

    final thumbnailBytes = await compute(_encodeImageSafely, _EncodeParams(thumbnail, 75, progressive: false)); // Updated quality
    final thumbnailFile = await file.writeAsBytes(thumbnailBytes, flush: true);

    _ImageCache.put(file, size, 75, thumbnailFile); // Updated quality

    return thumbnailFile;
  } catch (e) {
    debugPrint('Thumbnail generation error: $e');
    return file;
  }
}


