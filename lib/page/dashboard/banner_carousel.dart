import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:claim/page/dashboard/banner_api.dart';

/// อัตราส่วนของแบนเนอร์ ทรงยาวแบบแถบ
///
/// รูปต้นฉบับเป็น 3:2 (1024x683) ใช้ 2:1 จึงถูก crop ขอบบนล่างไปบ้าง
/// แลกกับได้แถบที่เตี้ยและยาวกว่า BoxFit.cover จัดให้อยู่กลางรูปเอง
const double _bannerRatio = 2 / 1;

/// หัวข้อ "ประชาสัมพันธ์" กดพับ/กางได้ กับการ์ดเลื่อนข้างใต้
///
/// แบนเนอร์กินพื้นที่บนสุดของหน้าหลัก คนที่เข้ามาเพื่อกดเมนูทุกวันจึงควรพับเก็บได้
/// แต่ต้องไม่ใช่ปิดถาวรจนหาไม่เจอ หัวข้อยังค้างอยู่ให้กดกางกลับมาได้เสมอ
///
/// หัวข้อเป็นแถวเปล่าตรงแนว [sidePadding] ไม่มีการ์ดห่อ เพราะการ์ดเลื่อนข้างใต้
/// ต้องกว้างเต็มจอให้ใบข้างเคียงโผล่ในขอบจอได้ ห่อด้วยการ์ดแล้วจะโผล่ไม่ได้
///
/// สถานะพับ/กางอยู่ที่หน้าที่เรียก เพราะต้องจำลง SharedPreferences ข้ามการเปิด
/// แอป ถ้าเก็บไว้ในนี้ แบนเนอร์จะกางกลับมาเองทุกครั้งที่เปิดแอป
class BannerSection extends StatelessWidget {
  final List<BannerItem> banners;
  final bool expanded;
  final VoidCallback onToggle;
  final double sidePadding;

  const BannerSection({
    super.key,
    required this.banners,
    required this.expanded,
    required this.onToggle,
    this.sidePadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: sidePadding - 4),
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
              child: Row(
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ประชาสัมพันธ์',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      size: 22,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // พับแล้วถอดออกจากต้นไม้ไปเลย ตัวสไลด์มี Timer เลื่อนรูปอัตโนมัติอยู่
        // ข้างใน ซ่อนไว้เฉย ๆ จะเหลือนาฬิกาเดินอยู่หลังของที่มองไม่เห็น
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: BannerCarousel(
                    banners: banners,
                    sidePadding: sidePadding,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// แบนเนอร์ประชาสัมพันธ์แบบการ์ดเลื่อน (แบบแอป Dime!)
///
/// - ใบที่โชว์อยู่กลางจอ เห็นขอบใบก่อนหน้าทางซ้ายและใบถัดไปทางขวาชัด ๆ
///   ข้างละ [_peek] เท่ากัน ให้รู้ว่าเลื่อนได้ทั้งสองทาง ไม่ต้องมีจุดบอกตำแหน่ง
///
///   ประวัติ: เคยให้โผล่ทางขวาข้างเดียว (ขอบขวาเยื้องกับการ์ดข้างล่าง ดูเบี้ยว)
///   แล้วเคยให้กว้างเท่าการ์ดข้างล่างและโผล่ข้างละ 8 จุด (เล็กจนแทบไม่เห็น)
///   ตอนนี้ใบแคบกว่าการ์ดข้างล่างเล็กน้อย แต่อยู่กลางพอดี สองข้างสมดุล
/// - เลื่อนทีละใบ ปล่อยนิ้วแล้วดูดเข้าที่
/// - วนต่อไปทางขวาไม่มีที่สิ้นสุด ใบสุดท้ายต่อด้วยใบแรกเลย (… 3 → 1 → 2 …)
///   ไม่ย้อนกลับไปทางซ้ายทีเดียวทั้งแถว ปัดย้อนไปทางซ้ายก็วนได้เหมือนกัน
/// - เลื่อนเองทุก [_autoPlay] ไปทางขวาเสมอ รูปเดียวเต็มแนวและไม่เลื่อน
/// - ไม่มีตัวนับหรือจุดบอกตำแหน่งบนรูป ใบที่โผล่บอกอยู่แล้วว่ามีอีก
///
/// หัวข้อกับการพับ/กางอยู่ที่ [BannerSection] ตัวนี้เป็นแค่ส่วนรูปเลื่อน
class BannerCarousel extends StatefulWidget {
  final List<BannerItem> banners;

  /// ระยะขอบซ้ายของหน้า ใบแรกจะเริ่มตรงนี้ ให้ตรงแนวกับการ์ดอื่น
  final double sidePadding;

  const BannerCarousel({
    super.key,
    required this.banners,
    this.sidePadding = 16,
  });

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  static const Duration _autoPlay = Duration(seconds: 5);

  /// ช่องว่างระหว่างใบ
  static const double _gap = 10;

  /// ขอบใบก่อนหน้า/ใบถัดไปโผล่เข้ามาในจอข้างละเท่านี้
  static const double _peek = 18;

  /// ระยะจากขอบจอถึงใบที่โชว์ ซ้ายขวาเท่ากัน ใบจึงอยู่กลางจอพอดี
  static const double _inset = _peek + _gap;

  final ScrollController _controller = ScrollController();

  Timer? _timer;

  /// ความกว้างของหนึ่งช่อง (ใบ + ช่องว่าง) คำนวณตอนวาด ใช้ทั้งดูดเข้าที่และเลื่อนเอง
  double _step = 0;

  /// รายการยาวไม่จำกัด ใบที่ i คือรูป i % จำนวนรูป
  ///
  /// เริ่มที่ช่องกลาง ๆ ([_startSlot]) ไม่ใช่ช่อง 0 จะได้ปัดย้อนไปทางซ้ายได้ด้วย
  /// ช่องนั้นหารลงตัวด้วยจำนวนรูป จึงยังเป็นรูปแรกเหมือนช่อง 0 ไม่มีอะไรกระโดด
  int get _startSlot => widget.banners.length * 1000;

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
      _jumpToSlot(_startSlot);
      _restartTimer();
    }
  }

  /// ช่องที่อยู่ตรงแนวซ้ายตอนนี้
  int get _currentSlot => _controller.hasClients && _step > 0
      ? (_controller.offset / _step).round()
      : _startSlot;

  /// กระโดดไปช่อง [slot] หลังวาดเฟรมนี้เสร็จ (ตอนนั้นถึงจะรู้ความกว้างช่อง)
  void _jumpToSlot(int slot) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients || _step <= 0) return;
      _controller.jumpTo(slot * _step);
    });
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
      if (!mounted || !_controller.hasClients || _step <= 0) return;
      // ไปทางขวาเสมอ ใบสุดท้ายต่อด้วยใบแรกเพราะรายการวนไม่สิ้นสุด
      _controller.animateTo(
        (_currentSlot + 1) * _step,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// หยุดเลื่อนแล้วไม่ตรงช่อง ดูดเข้าช่องที่ใกล้สุด
  ///
  /// ปกติการปัดจะดูดเข้าที่เองอยู่แล้ว แต่มีทางที่หลุดได้ เช่น แตะค้างตอนรูป
  /// กำลังเลื่อนเอง แอนิเมชันถูกตัดกลางทาง หรือจอเปลี่ยนขนาดระหว่างเลื่อน
  /// รูปจะค้างเยื้องไม่ตรงแนวกับการ์ดอื่น ตัวนี้เก็บตกทุกกรณีตอนนิ่งแล้ว
  void _settle() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients || _step <= 0) return;
      final position = _controller.position;
      if (position.isScrollingNotifier.value) return;

      final target = _currentSlot * _step;
      if ((position.pixels - target).abs() < 0.5) return;
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
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
    final count = widget.banners.length;
    final pad = widget.sidePadding;

    return LayoutBuilder(
      builder: (context, constraints) {
        final full = constraints.maxWidth;
        // หลายรูปอยู่กลางจอ เว้นที่ให้ขอบใบข้างเคียงโผล่สองข้าง
        // รูปเดียวไม่มีอะไรโผล่ ให้กว้างเท่าการ์ดอื่นบนหน้า
        final inset = _canSlide ? _inset : pad;
        final cardWidth = full - inset * 2;
        final step = cardWidth + _gap;
        if (_canSlide && step != _step) {
          // ครั้งแรกไปช่องเริ่ม ถ้าจอเปลี่ยนขนาด (หมุนจอ) อยู่รูปเดิมต่อ
          _jumpToSlot(_step <= 0 ? _startSlot : _currentSlot);
        }
        _step = step;
        final height = cardWidth / _bannerRatio;

        return SizedBox(
          height: height,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // นิ้วเริ่มลากแล้วนับเวลาใหม่ ไม่ให้เลื่อนเองแทรกตอนกำลังดูอยู่
              if (notification is ScrollStartNotification &&
                  notification.dragDetails != null) {
                _restartTimer();
              }
              if (notification is ScrollEndNotification) _settle();
              return false;
            },
            // หลายรูป: รายการไม่จำกัดความยาว (itemCount เป็น null) วนรูปด้วย %
            child: ListView.builder(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: _canSlide
                  ? _SnapPhysics(step: _step)
                  : const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                left: inset,
                right: _canSlide ? 0 : inset,
              ),
              itemCount: _canSlide ? null : count,
              itemExtent: _canSlide ? _step : cardWidth,
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.only(right: _canSlide ? _gap : 0),
                child: _BannerSlide(
                  item: widget.banners[index % count],
                  onTap: _openLink,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ดูดเข้าที่ทีละใบเหมือน PageView แต่ใช้กับ ListView ที่ใบไม่เต็มจอได้
///
/// PageView ทำให้ใบแรกชิดซ้ายและใบสุดท้ายหยุดตรงแนวเดียวกันพร้อมกันไม่ได้
/// จึงทำ physics เอง ปัดเร็วพอก็ไปใบถัดไป ปัดเบาก็กลับเข้าใบที่ใกล้สุด
class _SnapPhysics extends ScrollPhysics {
  final double step;

  const _SnapPhysics({required this.step, super.parent});

  @override
  _SnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _SnapPhysics(step: step, parent: buildParent(ancestor));

  double _target(ScrollMetrics position, Tolerance tolerance, double velocity) {
    var page = position.pixels / step;
    if (velocity < -tolerance.velocity) {
      page -= 0.5;
    } else if (velocity > tolerance.velocity) {
      page += 0.5;
    }
    return (page.roundToDouble() * step).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    final target = _target(position, tolerance, velocity);
    if (target == position.pixels) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }

  @override
  bool get allowImplicitScrolling => false;
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
          : ColoredBox(color: scheme.surfaceContainerHighest),
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
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: SizedBox.expand(child: image),
      ),
    );

    if (link == null) return card;

    return GestureDetector(onTap: () => onTap(link), child: card);
  }
}
