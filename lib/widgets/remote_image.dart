import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// รูปที่รับได้ทั้ง URL และ base64 ในตัวเดียวกัน
///
/// เซิร์ฟเวอร์ตอบรูปกลับมาได้ทั้งสองแบบ หน้าจอจึงต้องไม่ต้องรู้ว่าได้แบบไหนมา
/// - ขึ้นต้น http:// หรือ https:// → โหลดจาก network
/// - นอกนั้น → ถอด base64 (ตัด header `data:image/...;base64,` และ whitespace ออกก่อน)
///
/// ถอดไม่สำเร็จหรือโหลดไม่ได้จะโชว์ไอคอนรูปแตกแทน ไม่ throw ออกไปทำให้จอพัง
class RemoteImage extends StatelessWidget {
  /// URL เต็ม หรือ base64 (มี/ไม่มี prefix data:image ก็ได้)
  final String source;
  final BoxFit fit;
  final double? width;
  final double? height;

  const RemoteImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  bool get _isNetwork =>
      source.startsWith('http://') || source.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    if (_isNetwork) {
      return Image.network(
        source,
        fit: fit,
        width: width,
        height: height,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, _, __) => const _BrokenImage(),
      );
    }

    final bytes = decodeBase64Image(source);
    if (bytes == null) return const _BrokenImage();

    return Image.memory(
      bytes,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, _, __) => const _BrokenImage(),
    );
  }
}

/// ถอด base64 เป็นไบต์ คืน null เมื่อถอดไม่ได้ (ไม่ throw)
Uint8List? decodeBase64Image(String raw) {
  try {
    var data = raw.trim();

    // ตัด header ของ data URI ออก เหลือเฉพาะส่วน base64
    final marker = data.indexOf('base64,');
    if (marker != -1) data = data.substring(marker + 'base64,'.length);

    // เซิร์ฟเวอร์บางตัวใส่ newline คั่นทุก 76 ตัวอักษรตามมาตรฐาน MIME
    data = data.replaceAll(RegExp(r'\s'), '');
    if (data.isEmpty) return null;

    return base64Decode(data);
  } catch (_) {
    return null;
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.broken_image_outlined,
        size: 28,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// เปิดรูปเต็มจอแบบเลื่อนดูได้หลายรูป ปัดซ้ายขวาเปลี่ยนรูป ซูม/ลากได้
///
/// [initialIndex] คือรูปที่ผู้ใช้แตะ จะเปิดที่รูปนั้นก่อน ไม่ใช่รูปแรกเสมอ
Future<void> showFullScreenGallery(
  BuildContext context, {
  required List<String> sources,
  int initialIndex = 0,
  String? title,
}) {
  if (sources.isEmpty) return Future.value();

  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => _GalleryPage(
        sources: sources,
        initialIndex: initialIndex.clamp(0, sources.length - 1),
        title: title,
      ),
    ),
  );
}

class _GalleryPage extends StatefulWidget {
  final List<String> sources;
  final int initialIndex;
  final String? title;

  const _GalleryPage({
    required this.sources,
    required this.initialIndex,
    this.title,
  });

  @override
  State<_GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<_GalleryPage> {
  late final PageController _pageController;

  /// คุมการซูมของรูปที่กำลังดูอยู่ ต้องรู้ว่าซูมอยู่หรือไม่เพื่อสลับ
  /// ความหมายของการลากนิ้ว (ดูด้านล่าง)
  final TransformationController _zoom = TransformationController();

  late int _index;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
    _zoom.addListener(_onZoomChanged);
  }

  @override
  void dispose() {
    _zoom.removeListener(_onZoomChanged);
    _zoom.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onZoomChanged() {
    // เทียบกับ 1.01 ไม่ใช่ 1 เพราะ matrix มีเศษทศนิยมติดมาหลังซูมกลับ
    final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _onPageChanged(int index) {
    // รีเซ็ตการซูมเมื่อเปลี่ยนรูป ไม่งั้นรูปใหม่จะเปิดมาแบบซูมค้างอยู่
    _zoom.value = Matrix4.identity();
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.sources.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                // ตอนซูมอยู่ ลากนิ้วคือการเลื่อนดูส่วนที่ขยาย ไม่ใช่เปลี่ยนรูป
                // ถ้าไม่ปิดไว้ ทั้งสองท่าจะแย่งกันจนเลื่อนดูรูปที่ซูมไม่ได้
                physics: _zoomed
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                itemCount: total,
                itemBuilder: (context, i) => InteractiveViewer(
                  // ผูก controller กับรูปที่กำลังดูเท่านั้น รูปข้างเคียง
                  // ใช้ตัวภายในของมันเอง จะได้ไม่ถูกซูมตามไปด้วย
                  transformationController: i == _index ? _zoom : null,
                  maxScale: 5,
                  child: RemoteImage(
                    source: widget.sources[i],
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            if (widget.title != null)
              Positioned(
                left: 16,
                top: 12,
                right: 56,
                child: Text(
                  widget.title!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            Positioned(
              right: 8,
              top: 4,
              child: IconButton(
                tooltip: 'ปิด',
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // บอกว่ากำลังดูรูปที่เท่าไรจากทั้งหมด ไม่งั้นผู้ใช้ไม่รู้ว่าปัดต่อได้
            if (total > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 20,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_index + 1} / $total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// เปิดรูปเต็มจอบนพื้นหลังดำ ซูม/ลากได้ มีปุ่มปิดมุมขวาบน
Future<void> showFullScreenImage(
  BuildContext context, {
  required String source,
  String? title,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  maxScale: 5,
                  child: RemoteImage(source: source, fit: BoxFit.contain),
                ),
              ),
              if (title != null)
                Positioned(
                  left: 16,
                  top: 12,
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              Positioned(
                right: 8,
                top: 4,
                child: IconButton(
                  tooltip: 'ปิด',
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
