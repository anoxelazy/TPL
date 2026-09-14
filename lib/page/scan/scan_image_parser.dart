import 'dart:convert';

/// ผลของการอ่าน response ที่ปนรูปกับข้อความไว้ในคีย์เดียวกัน
class ParsedImageResponse {
  /// รูปที่พร้อมส่งให้ UI แสดง (URL เต็ม หรือ base64)
  final List<String> images;

  /// ข้อความที่ตั้งใจให้ผู้ใช้อ่าน null เมื่อไม่มี
  final String? message;

  const ParsedImageResponse({required this.images, required this.message});

  static const ParsedImageResponse empty = ParsedImageResponse(
    images: <String>[],
    message: null,
  );
}

/// คีย์ที่เซิร์ฟเวอร์ใช้ใส่ข้อความสำหรับผู้ใช้
const Set<String> _messageKeys = {
  'message',
  'msg',
  'error',
  'errormessage',
  'detail',
  'description',
  'remark',
  'statusmessage',
};

/// อ่าน response ของ CheckIsTakeBar แยกว่าอันไหนรูปอันไหนข้อความ
///
/// เซิร์ฟเวอร์ใช้คีย์ `Message` ใส่มาทั้ง "ลิงก์รูป" และ "ข้อความแจ้งผู้ใช้"
/// จึง **ตัดสินจากค่าก่อนชื่อคีย์** ถ้าดูจากชื่อคีย์ ลิงก์รูปจะถูกนับเป็นข้อความ
/// แล้วไม่มีรูปขึ้นให้ดูเลย
///
/// เดินทั้ง JSON tree เพราะเซิร์ฟเวอร์อาจห่อ map/list ซ้อนกันกี่ชั้นก็ได้
/// และไม่ throw ในทุกกรณี body ที่ไม่ใช่ JSON object จะได้ผลว่างกลับไป
ParsedImageResponse parseImageResponse(
  dynamic body, {
  required String baseUrl,
}) {
  final images = <String>[];
  String? message;

  void walk(dynamic node, String? key) {
    if (node == null) return;

    if (node is String) {
      if (_isImageValue(node)) {
        images.add(_toDisplayableSource(node, baseUrl));
      } else if (key != null && _messageKeys.contains(key.toLowerCase())) {
        final text = node.trim();
        // เก็บข้อความแรกที่เจอ ไม่ให้คีย์ชั้นลึกทับข้อความหลัก
        if (text.isNotEmpty) message ??= text;
      }
      return;
    }

    if (node is Map) {
      for (final entry in node.entries) {
        walk(entry.value, entry.key?.toString());
      }
      return;
    }

    if (node is List) {
      // list สืบคีย์ของ parent ต่อ เช่น {"Message": ["url1", "url2"]}
      for (final item in node) {
        walk(item, key);
      }
      return;
    }

    // num / bool ไม่ใช่ทั้งรูปและข้อความ
  }

  try {
    walk(_decodeIfJson(body), null);
  } catch (_) {
    return ParsedImageResponse.empty;
  }

  return ParsedImageResponse(images: images, message: message);
}

/// dio คืน body เป็น String เมื่อ server ไม่ได้ตั้ง content-type เป็น json
dynamic _decodeIfJson(dynamic body) {
  if (body is! String) return body;

  final trimmed = body.trim();
  if (trimmed.isEmpty) return null;

  try {
    return jsonDecode(trimmed);
  } catch (_) {
    // ไม่ใช่ JSON ก็ยังอ่านเป็นค่าเดี่ยวได้ เช่นเซิร์ฟเวอร์ตอบ URL เปล่า ๆ
    return trimmed;
  }
}

/// ค่านี้เป็นรูปหรือไม่ ตัดสินจากตัวค่าเองเท่านั้น
bool _isImageValue(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return false;

  if (value.startsWith('http://') || value.startsWith('https://')) return true;
  if (value.startsWith('data:image')) return true;
  // path แบบ relative ที่เซิร์ฟเวอร์ตอบมา เช่น /Tps/Bar/2026/09/x.png
  if (value.startsWith('/') || value.startsWith('~/')) return true;

  // base64 ก้อนยาว ๆ ข้อความภาษาไทยไม่เข้าเกณฑ์นี้เพราะมีอักขระนอกชุด base64
  if (value.length > 100) {
    final compact = value.replaceAll(RegExp(r'\s'), '');
    if (compact.isNotEmpty && RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(compact)) {
      return true;
    }
  }

  return false;
}

/// ทำให้ค่าที่เป็นรูปใช้แสดงได้จริง
///
/// relative path ต้องต่อ baseUrl ให้เป็น URL เต็มก่อน ไม่งั้น Image.network
/// โหลดไม่ได้ ส่วนลิงก์เต็มและ base64 ปล่อยผ่าน
String _toDisplayableSource(String raw, String baseUrl) {
  final value = raw.trim();

  if (value.startsWith('http://') ||
      value.startsWith('https://') ||
      value.startsWith('data:image')) {
    return value;
  }

  if (value.startsWith('/') || value.startsWith('~/')) {
    final path = value.startsWith('~/') ? value.substring(1) : value;
    // ตัด slash ท้าย baseUrl และ slash หน้า path ออก แล้วต่อด้วยตัวเดียว
    final host = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final tail = path.replaceAll(RegExp(r'^/+'), '');
    return '$host/$tail';
  }

  // base64 ล้วน ส่งต่อให้ RemoteImage ถอดเอง
  return value;
}
