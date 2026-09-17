import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:claim/utils/mobile_api.dart';
import 'package:claim/utils/app_colors.dart';

/// รูปของเคส รับค่าดิบจาก API มาเลย ไม่ต้องรู้ว่ามาแบบไหน
///
/// ยังไม่ยืนยันว่า API ส่งรูปมาเป็นอะไร ตอนส่งเคสเราส่ง base64 ขึ้นไป ส่วนเว็บ
/// โชว์เป็น `<img>` ซึ่งเป็นลิงก์ก็ได้ data URI ก็ได้ จึงเดาจากหน้าตาของค่า
/// แทนการผูกกับแบบเดียว
///
/// พาธที่ไม่มีโดเมน (เช่น `/upload/it/IT2026106446.jpg`) ต่อกับ
/// [MobileApi.baseUrl] ให้ เพราะรูปอยู่เครื่องเดียวกับ API
class ItCaseImage extends StatefulWidget {
  final String source;

  const ItCaseImage({super.key, required this.source});

  @override
  State<ItCaseImage> createState() => _ItCaseImageState();
}

class _ItCaseImageState extends State<ItCaseImage> {
  Uint8List? _bytes;
  String? _url;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(ItCaseImage old) {
    super.didUpdateWidget(old);
    if (old.source != widget.source) _read();
  }

  /// แปลงค่าดิบเป็นรูปที่โหลดได้ ครั้งเดียวตอนเปิดหน้า
  ///
  /// base64 ของรูปจากมือถือยาวเป็นล้านตัวอักษร ถอดใหม่ทุกครั้งที่ build
  /// จะหน่วงเห็นได้ชัดเวลาเลื่อนหน้าจอ
  void _read() {
    final text = widget.source.trim();
    _bytes = null;
    _url = null;

    if (text.isEmpty) return;

    if (text.startsWith('http://') || text.startsWith('https://')) {
      _url = text;
      return;
    }

    if (text.startsWith('data:')) {
      final comma = text.indexOf(',');
      if (comma != -1) _bytes = _decode(text.substring(comma + 1));
      return;
    }

    // ขึ้นต้นด้วย / หรือมีนามสกุลไฟล์ แปลว่าเป็นพาธบนเซิร์ฟเวอร์ ไม่ใช่ base64
    if (text.startsWith('/') || _looksLikePath(text)) {
      _url = text.startsWith('/')
          ? '${MobileApi.baseUrl}$text'
          : '${MobileApi.baseUrl}/$text';
      return;
    }

    _bytes = _decode(text);
  }

  static bool _looksLikePath(String text) =>
      text.length < 300 &&
      RegExp(
        r'\.(jpe?g|png|gif|webp|bmp)$',
        caseSensitive: false,
      ).hasMatch(text);

  static Uint8List? _decode(String text) {
    try {
      return base64Decode(text.replaceAll(RegExp(r'\s'), ''));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image(BoxFit.cover);
    if (image == null) return _broken(context);

    return GestureDetector(
      // แตะเพื่อดูเต็มจอ รูปในการ์ดถูกครอบไว้ บางทีตัวปัญหาอยู่นอกกรอบพอดี
      onTap: () => _openFull(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 260,
            minWidth: double.infinity,
          ),
          child: image,
        ),
      ),
    );
  }

  /// รูปที่พร้อมวาด ไม่มีทั้งลิงก์และ bytes ก็คืน null
  Widget? _image(BoxFit fit) {
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: fit,
        errorBuilder: (context, _, _) => _broken(context),
      );
    }

    final url = _url;
    if (url == null) return null;

    return Image.network(
      url,
      fit: fit,
      errorBuilder: (context, _, _) => _broken(context),
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
    );
  }

  /// กล่องแทนรูปที่โหลดไม่ได้ ไม่ปล่อยว่างเฉย ๆ ไม่งั้นคนอ่านจะนึกว่าไม่มีรูป
  Widget _broken(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 90,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            'แสดงรูปไม่ได้',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _openFull(BuildContext context) {
    final image = _image(BoxFit.contain);
    if (image == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Center(child: InteractiveViewer(maxScale: 5, child: image)),
        ),
      ),
    );
  }
}
