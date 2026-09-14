import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:claim/page/dashboard/banner_api.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/widgets/app_card.dart';

/// อัตราส่วนของแบนเนอร์ ทรงยาวแบบแถบ
///
/// รูปต้นฉบับเป็น 3:2 (1024x683) ใช้ 2:1 จึงถูก crop ขอบบนล่างไปบ้าง
/// แลกกับได้แถบที่เตี้ยและยาวกว่า BoxFit.cover จัดให้อยู่กลางรูปเอง
const double _bannerRatio = 2 / 1;

/// แบนเนอร์สไลด์พร้อมจุดบอกตำแหน่งด้านล่าง
///
/// เลื่อนเองทุก [_autoPlay] และเลื่อนด้วยนิ้วได้ ถ้ามีรูปเดียวจะไม่เลื่อน
/// และไม่โชว์จุด
class BannerCarousel extends StatefulWidget {
  final List<BannerItem> banners;

  const BannerCarousel({super.key, required this.banners});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  static const Duration _autoPlay = Duration(seconds: 5);

  final PageController _controller = PageController();

  Timer? _timer;
  int _index = 0;

  bool get _canSlide => widget.banners.length > 1;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.banners.length != oldWidget.banners.length) {
      _index = 0;
      _restartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!_canSlide) return;

    _timer = Timer.periodic(_autoPlay, (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _openLink(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) return;

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('เปิดลิงก์ไม่ได้')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          child: AspectRatio(
            aspectRatio: _bannerRatio,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.banners.length,
              // นิ้วเลื่อนแล้วเริ่มนับเวลาใหม่ ไม่ให้กระตุกทันทีที่ปล่อยมือ
              onPageChanged: (index) {
                setState(() => _index = index);
                _restartTimer();
              },
              itemBuilder: (context, index) =>
                  _BannerSlide(item: widget.banners[index], onTap: _openLink),
            ),
          ),
        ),
        if (_canSlide) ...[
          const SizedBox(height: 10),
          _Dots(count: widget.banners.length, active: _index),
        ],
      ],
    );
  }
}

class _BannerSlide extends StatelessWidget {
  final BannerItem item;
  final ValueChanged<String> onTap;

  const _BannerSlide({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final link = item.link;

    // cacheWidth ให้ decoder ย่อรูปตอนถอดรหัส ไม่ถือรูป 1024px ไว้เต็มขนาด
    final width = MediaQuery.sizeOf(context).width;
    final pixels = (width * MediaQuery.devicePixelRatioOf(context)).round();

    final image = Image.network(
      item.imageUrl,
      fit: item.fit,
      cacheWidth: pixels,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
      errorBuilder: (context, error, stack) => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 36,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );

    // พื้นรองหลังรูป ตอน contain จะมีแถบว่างข้าง ๆ ต้องไม่โปร่งใส
    // ไม่งั้นจะเห็นพื้นหลังหน้าจอทะลุขึ้นมาแล้วดูเหมือนรูปลอย
    final framed = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SizedBox.expand(child: image),
    );

    if (link == null) return framed;

    return GestureDetector(onTap: () => onTap(link), child: framed);
  }
}

/// จุดกลม ๆ บอกว่าอยู่รูปที่เท่าไร จุดที่เลือกจะยืดเป็นแคปซูล
class _Dots extends StatelessWidget {
  final int count;
  final int active;

  const _Dots({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 20 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == active ? scheme.primary : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

/// กรอบขนาดเท่าแบนเนอร์ ใช้ตอนกำลังโหลด โหลดไม่ได้ หรือยังไม่มีแบนเนอร์
class BannerPlaceholder extends StatelessWidget {
  final bool loading;
  final String? message;

  const BannerPlaceholder({super.key, this.loading = false, this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: EdgeInsets.zero,
      child: AspectRatio(
        aspectRatio: _bannerRatio,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              Icon(
                message == null
                    ? Icons.image_outlined
                    : Icons.image_not_supported_outlined,
                size: 40,
                color: scheme.onSurfaceVariant,
              ),
            const SizedBox(height: 10),
            Text(
              loading
                  ? 'กำลังโหลดแบนเนอร์...'
                  : (message ?? 'ยังไม่มีแบนเนอร์'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
