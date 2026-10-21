import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/utils/app_icons.dart';
import 'package:claim/page/dashboard/asset_transfer_banner.dart';
import 'package:claim/page/dashboard/banner_api.dart';
import 'package:claim/page/dashboard/banner_carousel.dart';
import 'package:claim/page/dashboard/dashboard_banner.dart';
import 'package:claim/page/dashboard/dashboard_menu.dart';
import 'package:claim/page/dashboard/it_case_banner.dart';
import 'package:claim/page/dashboard/it_case_open_cards.dart';
import 'package:claim/page/dashboard/line_invite_banner.dart';
import 'package:claim/page/dashboard/weather_chip.dart';
import 'package:claim/utils/pm_access_service.dart';
import 'package:claim/utils/rank_service.dart';
// พักการค้นหาบนหน้าหลักไว้ก่อน ย้ายไปอยู่หน้าสถานะคลังสินค้าแทน
// import 'package:claim/page/dashboard/menu_search_page.dart';
import 'package:claim/widgets/app_card.dart';
import 'package:claim/widgets/profile_avatar_view.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _userName = '';

  /// แบนเนอร์ที่มีรูปจริงใน banner.json ว่างแปลว่าไม่ต้องโชว์อะไรเลย
  ///
  /// [fetchBanners] คัดแถวที่ไม่มี image_url ออกให้แล้ว ที่เหลือจึงโชว์ได้หมด
  List<BannerItem> _banners = [];

  /// แบนเนอร์กางอยู่ไหม จำไว้ข้ามการเปิดแอป
  ///
  /// เริ่มที่พับไว้ ประชาสัมพันธ์เป็นของที่ดูเมื่ออยากดู ไม่ใช่ของที่ต้องทำ
  /// ให้เมนูกับของค้างได้ที่ครึ่งบนของจอก่อน คนที่อยากดูกดกางเองแล้วระบบจำไว้ให้
  ///
  /// อ่านค่าตั้งแต่ initState พร้อมชื่อผู้ใช้ ซึ่งเสร็จก่อนแบนเนอร์จะโหลดมาจาก
  /// เน็ตเสมอ คนที่กางไว้จึงไม่เห็นมันหุบแวบหนึ่งแล้วกางเอง
  bool _bannerOpen = false;

  static const String _bannerOpenKey = 'dashboard_banner_open';

  /// ระยะขอบซ้ายขวาของเนื้อหาบนหน้า แบนเนอร์ใช้ค่าเดียวกันให้ใบแรกตรงแนว
  static const double _pagePadding = 16;

  /// ระยะห่างระหว่างกลุ่มบนหน้าหลัก ใช้ค่าเดียวทุกช่วง
  static const double _sectionGap = 20;

  /// กุญแจของการ์ดเคสค้าง ใช้สั่งให้มันดึงข้อมูลใหม่ตอนดึงหน้าจอลง
  ///
  /// การ์ดนั้นโหลดเองอยู่แล้วทั้งตอนเปิดแอปและเป็นรอบ แต่ผู้ใช้ที่ดึงหน้าจอลง
  /// คาดหวังว่าทุกอย่างบนหน้าจะสดพร้อมกัน ไม่ใช่สดเฉพาะบางกล่อง
  final GlobalKey<ItCaseOpenCasesState> _openCases = GlobalKey();

  /// เลื่อนหน้าลงมาแล้วหรือยัง ใช้ตัดสินว่าจะขีดเส้นใต้แถบทักทายไหม
  ///
  /// แถบค้างอยู่กับที่ ถ้าไม่มีเส้นคั่น เนื้อหาที่ไหลลอดอยู่ข้างใต้จะดูเหมือน
  /// ทับกันมั่วเพราะพื้นหลังสีเดียวกัน ตอนอยู่บนสุดไม่มีอะไรลอด ไม่ต้องมีเส้น
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadBannerOpen();
    _loadBanners();
    // สิทธิ์เมนู PM มาจาก pm.json อ่าน cache ก่อนแล้วดึงของใหม่เบื้องหลัง
    PmAccessService.I.init();
  }

  /// ดึงหน้าจอลงแล้วโหลดใหม่ทุกอย่างที่หน้านี้โชว์อยู่
  ///
  /// ยิงพร้อมกันทุกตัว ไม่ใช่ไล่ทีละอัน วงหมุนจะได้หยุดตอนตัวที่ช้าสุดเสร็จ
  /// ไม่ใช่รอบวกเวลาของทุกเส้นเข้าด้วยกัน
  ///
  /// ตัวไหนพังก็เงียบของมันเอง (แต่ละตัวดักไว้ข้างในแล้ว) หน้าหลักไม่ควรขึ้น
  /// error ทั้งหน้าเพราะไฟล์ประกอบไฟล์เดียวโหลดไม่ได้ ในเมื่อเมนูยังกดได้ครบ
  Future<void> _refresh() async {
    await Future.wait([
      _quiet(_loadUserName()),
      _quiet(_loadBanners()),
      _quiet(PmAccessService.I.init()),
      // ป้ายอันดับบนรูปโปรไฟล์ฟัง service กลางอยู่ อัปเดตให้เอง
      _quiet(RankService.I.init()),
      // การ์ดเคสค้างถือ state ของตัวเอง ต้องสั่งผ่าน key
      _quiet(_openCases.currentState?.refresh() ?? Future<void>.value()),
    ]);
  }

  /// ยิงงานหนึ่งอย่างโดยไม่ให้ error หลุดไปล้ม Future.wait ทั้งชุด
  ///
  /// ตัวหนึ่งพังไม่ควรลากตัวที่สำเร็จแล้วให้ดูเหมือนพังตาม และ onRefresh
  /// ที่โยน exception ออกมาจะทิ้งวงหมุนค้างไว้บนจอ
  Future<void> _quiet(Future<void> task) async {
    try {
      await task;
    } catch (e) {
      debugPrint('dashboard refresh: $e');
    }
  }

  /// ชื่อที่ทักทายใช้ fullname เป็นหลัก ถ้าไม่มีค่อยถอยไป username
  /// แล้ว driverID ตามลำดับ
  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();

    String pick(String key) {
      final value = prefs.getString(key)?.trim() ?? '';
      // fullname ที่ API ส่งมามีช่องว่างซ้อนกันหลายตัว (เช่น "ลาดกระบัง  ลาดกระบัง")
      return value.replaceAll(RegExp(r'\s+'), ' ');
    }

    final name = [
      pick('fullname'),
      pick('username'),
      pick('driverID'),
    ].firstWhere((value) => value.isNotEmpty, orElse: () => '');

    if (!mounted) return;
    setState(() => _userName = name);
  }

  /// อ่านว่าครั้งก่อนกางแบนเนอร์ไว้หรือเปล่า ไม่เคยตั้ง = พับไว้
  Future<void> _loadBannerOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final open = prefs.getBool(_bannerOpenKey) ?? false;

    if (!mounted || open == _bannerOpen) return;
    setState(() => _bannerOpen = open);
  }

  /// พับ/กางแบนเนอร์ แล้วจำไว้ใช้ครั้งหน้า
  ///
  /// เขียนลง prefs เบื้องหลัง ไม่ต้องรอ ไม่งั้นการกดพับจะหน่วงตามดิสก์
  Future<void> _toggleBannerOpen() async {
    final open = !_bannerOpen;
    setState(() => _bannerOpen = open);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bannerOpenKey, open);
  }

  /// โหลดแบนเนอร์เงียบ ๆ พังก็แค่ไม่มีแบนเนอร์
  ///
  /// เดิมขึ้นกล่องเทาบอกว่าโหลดไม่สำเร็จคาไว้กลางหน้าหลัก ซึ่งคนใช้ทำอะไรกับมัน
  /// ไม่ได้อยู่ดี ได้แต่มองว่าแอปเสีย ทั้งที่เมนูข้างล่างใช้ได้ปกติทุกอัน
  Future<void> _loadBanners() async {
    try {
      final banners = await fetchBanners();
      if (!mounted) return;
      setState(() => _banners = banners);
    } catch (e) {
      debugPrint('banner: $e');
    }
  }

  // /// เปิดหน้าค้นหาแยก ไม่ให้คีย์บอร์ดขึ้นค้างบนหน้าหลัก
  // ///
  // /// ส่ง context ของหน้าหลักไปด้วย ผลค้นหาจึงพาไปหน้าถัดไปได้
  // /// หลังหน้าค้นหาถูกปิดแล้ว
  // void _openSearch() {
  //   final items = buildDashboardMenu(context);
  //
  //   Navigator.of(context).push(
  //     MenuSearchPage.route(
  //       items: items,
  //       onSelected: (item) => openDashboardMenu(context, item),
  //     ),
  //   );
  // }

  /// จำไว้ว่าตอนนี้เลื่อนพ้นบนสุดแล้วหรือยัง
  ///
  /// setState เฉพาะตอนค่าพลิก ไม่ใช่ทุกพิกเซลที่นิ้วลาก ไม่งั้นหน้าทั้งหน้า
  /// (เมนู แบนเนอร์ การ์ดเคส) จะ rebuild ตลอดการเลื่อนหนึ่งครั้ง
  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;

    final scrolled = notification.metrics.extentBefore > 0;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _refresh,
      // วงหมุนต้องโผล่จากใต้แถบทักทาย ไม่ใช่จากขอบบนสุดแล้วทับแถบที่ค้างอยู่
      edgeOffset: kToolbarHeight + 1,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: CustomScrollView(
          // เนื้อหาสั้นกว่าจอ (เช่นยังไม่มีแบนเนอร์กับเคสค้าง) ก็ต้องยังดึงลงได้
          // ไม่งั้นบางคนจะเจอว่าดึงไม่ติดโดยไม่รู้ว่าเพราะอะไร
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // แถบทักทายค้างอยู่บนสุดตลอด รูปโปรไฟล์กับปุ่มติดต่อจึงกดได้ทุกจังหวะ
            // ไม่ต้องเลื่อนกลับขึ้นไปหา
            //
            // เคยลองหัวเขียวไล่สีกับลวดลายแล้ว ฉูดฉาดเกินไปสำหรับหน้าที่เปิดทุกวัน
            // หัวจึงกลืนกับพื้นเหมือนหน้าอื่นตามธีมรวม
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              // ธีมรวมตั้ง centerTitle ไว้ ซึ่งใช้กับหัวเรื่องที่เป็นข้อความ
              // แถบนี้เป็นแถวเต็มความกว้าง ต้องชิดซ้ายเหมือนเดิม
              centerTitle: false,
              titleSpacing: 16,
              // สีแถบมาจากธีมรวม ซึ่งเป็นสีเดียวกับพื้นหน้าอยู่แล้ว
              title: _Greeting(name: _userName),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  height: 1,
                  color: _scrolled ? scheme.outlineVariant : Colors.transparent,
                ),
              ),
            ),
            // แบนเนอร์อยู่นอกกรอบที่มีขอบซ้ายขวา ใบถัดไปจะได้โผล่ถึงขอบจอจริง
            // ใบแรกยังเริ่มตรงแนว [_pagePadding] เดียวกับการ์ดข้างล่าง
            //
            // ไม่มีรูปใน banner.json ก็ไม่ต้องกินที่เลย ไม่ใช่ขึ้นกล่องเทาเปล่า ๆ
            // ที่คนใช้ทำอะไรกับมันไม่ได้ ระหว่างโหลดก็ยังไม่โชว์ ขึ้นมาตอนได้รูปจริง
            if (_banners.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.only(top: 12),
                sliver: SliverToBoxAdapter(
                  child: BannerSection(
                    banners: _banners,
                    expanded: _bannerOpen,
                    onToggle: _toggleBannerOpen,
                    sidePadding: _pagePadding,
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                _pagePadding,
                _banners.isNotEmpty ? _sectionGap : 12,
                _pagePadding,
                24,
              ),
              sliver: SliverList.list(
                children: [
                  // ทุกกลุ่มเว้นห่างกันเท่ากัน ([_sectionGap]) หน้าจะอ่านเป็น
                  // จังหวะเดียวกันทั้งหน้า กลุ่มแถบงานกับตารางเมนูไม่มีหัวข้อ
                  // (เคยมี "ส่งเรื่อง" / "เมนู") หน้าตาของแต่ละกลุ่มบอกอยู่แล้ว
                  // ว่าคืออะไร หัวข้อเลยเป็นแค่ตัวหนังสือที่กินที่
                  //
                  // ชวนแอด LINE เฉพาะคนที่ยังไม่ได้ผูกบัญชีกับบอท ผูกแล้วหรือ
                  // กดปิดแล้วจะไม่กินที่เลย ตัวมันเว้นระยะใต้ตัวเองมาให้แล้ว
                  const LineInviteBanner(),

                  // งานที่ส่งถึงคนปลายทาง (ทีม IT / คนอนุมัติ-รับของ) ต่างจาก
                  // เมนูในตารางที่เป็นหน้าไว้เปิดดูข้อมูล ทะเบียนทรัพย์สินจึงอยู่
                  // ในตาราง ไม่ใช่ตรงนี้ สองแถบอยู่การ์ดใบเดียวกันคั่นด้วยเส้น
                  //
                  // แถบใบโอนย้ายนับใบที่รอคนคนนี้อยู่เองตอนเปิดหน้า แล้วโชว์เป็นตัวเลข
                  const DashboardBannerGroup(
                    children: [
                      ItCaseBanner(framed: false),
                      AssetTransferBanner(framed: false),
                    ],
                  ),
                  const SizedBox(height: _sectionGap),
                  ValueListenableBuilder<bool>(
                    valueListenable: PmAccessService.I.allowed,
                    builder: (context, _, _) {
                      // แยกสองกองที่เดียวตรงนี้ ตารางโชว์เฉพาะเมนูที่กดได้
                      // ที่เหลือไปอยู่ในแถวพับเก็บใต้ตาราง
                      final items = buildDashboardMenu(context);
                      return _MenuGrid(
                        items: unlockedMenu(items),
                        locked: lockedMenu(items),
                      );
                    },
                  ),
                  ItCaseOpenCases(key: _openCases),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// รูปผู้ใช้กับคำทักทายมุมบนซ้ายของหน้าหลัก
class _Greeting extends StatelessWidget {
  final String name;

  const _Greeting({required this.name});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        const ProfileAvatarView(radius: 18, tapOpensRank: true),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'สวัสดีคุณ',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 1),
              Text(
                name.isEmpty ? '-' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // ปุ่มแจ้งปัญหาที่เคยอยู่ตรงนี้ย้ายไปอยู่หน้าโปรไฟล์แล้ว
        const WeatherChip(),
      ],
    );
  }
}

// /// ช่องค้นหาบนหน้าหลักเป็นแค่ปุ่ม ไม่ใช่ TextField
// ///
// /// กดแล้วเด้งไปหน้าค้นหา คีย์บอร์ดจึงไม่ขึ้นบนหน้าที่ไม่มีที่ปิด
// class _SearchButton extends StatelessWidget {
//   final VoidCallback onTap;
//
//   const _SearchButton({required this.onTap});
//
//   @override
//   Widget build(BuildContext context) {
//     final scheme = Theme.of(context).colorScheme;
//     final radius = BorderRadius.circular(28);
//
//     return Material(
//       color: scheme.surface,
//       borderRadius: radius,
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: radius,
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//           decoration: BoxDecoration(
//             borderRadius: radius,
//             border: Border.all(color: scheme.outlineVariant),
//           ),
//           child: Row(
//             children: [
//               Icon(Icons.search, size: 19, color: scheme.onSurfaceVariant),
//               const SizedBox(width: 10),
//               Text(
//                 'ค้นหาเมนู',
//                 style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

/// จำนวนเมนูสูงสุดต่อหนึ่งหน้า เกินนี้เลื่อนไปหน้าถัดไป
///
/// 8 = 4 ช่องสองแถว พอดีกับที่ตามองเห็นทีเดียวโดยไม่ต้องกวาดหา
/// ยัดทุกเมนูไว้หน้าเดียวแล้วการ์ดจะยาวจนดันของข้างล่างตกจอ
const int kMenuPerPage = 8;

/// การ์ดรวมเมนูแบบไอคอนกลม 4 ช่องต่อแถว แบ่งหน้าเมื่อเกิน [kMenuPerPage]
class _MenuGrid extends StatefulWidget {
  /// เมนูที่กดได้ อยู่ในตารางหลัก
  final List<DashboardMenuItem> items;

  /// เมนูที่กดไม่ได้ อยู่ในแถวพับเก็บใต้ตาราง
  final List<DashboardMenuItem> locked;

  const _MenuGrid({required this.items, this.locked = const []});

  @override
  State<_MenuGrid> createState() => _MenuGridState();
}

class _MenuGridState extends State<_MenuGrid> {
  /// กางเมนูที่ยังไม่มีสิทธิ์อยู่หรือเปล่า เริ่มที่พับไว้เสมอ
  ///
  /// ไม่ได้จำค่าไว้ข้ามการเปิดแอป เพราะคนที่ไม่มีสิทธิ์ไม่ได้อยากเห็นของที่กด
  /// ไม่ได้ทุกวัน เขาเปิดดูตอนสงสัยว่าระบบมีอะไรบ้างแค่ครั้งสองครั้ง
  bool _showLocked = false;
  static const int _columns = 4;
  static const double _gap = 8;
  static const double _rowGap = 20;
  static const double _iconSize = 54;
  static const double _iconLabelGap = 8;
  static const double _labelSize = 11.5;
  static const double _labelHeight = 1.3;

  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _pageCount => (widget.items.length / kMenuPerPage).ceil();

  /// เมนูของหน้าที่ [page] หน้าสุดท้ายมีไม่ครบก็ไม่เป็นไร
  List<DashboardMenuItem> _itemsOf(int page) {
    final from = page * kMenuPerPage;
    final to = (from + kMenuPerPage).clamp(0, widget.items.length);
    return widget.items.sublist(from, to);
  }

  /// ความสูงของป้ายชื่อที่ยาวที่สุด ที่ความกว้างช่องเท่านี้
  ///
  /// PageView ต้องรู้ความสูงล่วงหน้า จะปล่อยให้ยืดตามเนื้อหาเหมือน Wrap ไม่ได้
  /// วัดจากป้ายจริงทุกอัน แทนที่จะตั้งความสูงตายตัวเผื่อสามบรรทัดไว้ก่อน
  /// ซึ่งจะเหลือที่ว่างใต้ไอคอนเป็นแถบใหญ่เมื่อป้ายสั้นกันหมด
  ///
  /// เอาความสูงที่วัดได้ตรง ๆ ไม่ใช่ จำนวนบรรทัด x ขนาดฟอนต์ x height
  /// เพราะฟอนต์ปัดเศษไม่ตรงกับสูตร คำนวณเองแล้วเตี้ยกว่าของจริงอยู่เศษพิกเซล
  /// พอไปอยู่ใน SizedBox ความสูงตายตัวก็ overflow
  double _maxLabelHeight(double width) {
    var height = 0.0;

    // วัดจากเมนูที่ล็อกด้วย เพราะพอกางออกมาก็ใช้ความสูงช่องเดียวกัน
    for (final item in [...widget.items, ...widget.locked]) {
      final painter = TextPainter(
        text: TextSpan(
          text: item.label,
          style: const TextStyle(fontSize: _labelSize, height: _labelHeight),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        // ป้ายบรรทัดเดียวเสมอ (ดู _MenuButton) วัดแค่บรรทัดเดียวพอ
        maxLines: 1,
      )..layout(maxWidth: width);

      if (painter.height > height) height = painter.height;
    }

    return height;
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pageCount;

    return AppCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth =
              (constraints.maxWidth - _gap * (_columns - 1)) / _columns;

          final tileHeight =
              _iconSize + _iconLabelGap + _maxLabelHeight(itemWidth);

          // หน้าที่เต็มมีกี่แถว ทุกหน้าสูงเท่ากันหมด หน้าสุดท้ายที่มีแถวเดียว
          // จะเหลือที่ว่างข้างล่าง ดีกว่าการ์ดกระโดดสูงต่ำตอนเลื่อนหน้า
          final rows = (widget.items.length.clamp(0, kMenuPerPage) / _columns)
              .ceil()
              .clamp(1, 2);
          final pageHeight = rows * tileHeight + (rows - 1) * _rowGap;

          return Column(
            children: [
              SizedBox(
                height: pageHeight,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages,
                  onPageChanged: (page) => setState(() => _page = page),
                  itemBuilder: (context, page) => Wrap(
                    spacing: _gap,
                    runSpacing: _rowGap,
                    children: [
                      for (final item in _itemsOf(page))
                        SizedBox(
                          width: itemWidth,
                          height: tileHeight,
                          child: _MenuButton(item: item),
                        ),
                    ],
                  ),
                ),
              ),
              if (pages > 1) ...[
                const SizedBox(height: 14),
                _PageDots(count: pages, current: _page.clamp(0, pages - 1)),
              ],
              if (widget.locked.isNotEmpty)
                _lockedSection(itemWidth, tileHeight),
            ],
          );
        },
      ),
    );
  }

  /// แถวพับเก็บของเมนูที่ยังกดไม่ได้
  ///
  /// คนที่มีสิทธิ์ครบจะไม่เห็นแถวนี้เลย (ไม่มีของให้พับ) ส่วนคนที่สิทธิ์น้อย
  /// เห็นแถวเดียวแทนช่องจาง ๆ ห้าหกช่องที่กดไม่ได้
  Widget _lockedSection(double itemWidth, double tileHeight) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        const SizedBox(height: 12),
        Divider(height: 1, color: scheme.outlineVariant),
        InkWell(
          onTap: () => setState(() => _showLocked = !_showLocked),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                // ไม่บอกว่า "ยังไม่มีสิทธิ์" ตรงนี้ ไม่ต้องทวงกับผู้ใช้ทุกครั้ง
                // ที่เปิดแอปว่าเขาใช้อะไรไม่ได้บ้าง กดเข้าไปแล้วค่อยบอกก็ทัน
                Expanded(
                  child: Text(
                    'เมนูอื่น ๆ',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  _showLocked ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_showLocked)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Wrap(
              spacing: _gap,
              runSpacing: _rowGap,
              children: [
                for (final item in widget.locked)
                  SizedBox(
                    width: itemWidth,
                    height: tileHeight,
                    child: _MenuButton(item: item),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// จุดบอกหน้าใต้ตารางเมนู
///
/// หน้าที่อยู่เป็นขีดยาว ไม่ใช่จุดกลมสีเข้ม ต่างกันด้วยรูปร่างไม่ใช่แค่สี
class _PageDots extends StatelessWidget {
  final int count;
  final int current;

  const _PageDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == current ? scheme.primary : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  final DashboardMenuItem item;

  const _MenuButton({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blocked = item.isBlocked;

    return InkWell(
      onTap: () => openDashboardMenu(context, item),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: blocked ? 0.4 : 1,
                // ไอคอนเส้นล้วน ไม่มีวงกลมรอบ (ลองวงกลมทึบกับวงกลมเส้นขอบ
                // มาแล้ว) ช่องยังกว้าง 54 เท่าเดิม ตารางจะได้ไม่ขยับ ขยาย
                // ไอคอนขึ้นแทนที่วงกลมที่หายไป ไม่ให้ช่องดูโหรงเหรง
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: AppIcons.duotone(
                    item.icon,
                    size: 34,
                    color: item.iconColor,
                  ),
                ),
              ),
              if (blocked)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.locked ? Icons.lock_outline : Icons.schedule,
                      size: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // ชื่อเมนูบรรทัดเดียว ชื่อในเมนูจึงย่อให้สั้น (ชื่อเต็มอยู่บนหัว
          // ของแต่ละหน้า) ถ้าจอแคบจนไม่พอจริง ๆ ตัวหนังสือหดลงเองนิดหนึ่ง
          // ดีกว่าตัดเป็น "..." จนอ่านไม่ออกว่าเมนูอะไร
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.3,
                color: blocked ? scheme.onSurfaceVariant : scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
