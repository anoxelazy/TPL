import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/page/dashboard/banner_api.dart';
import 'package:claim/page/dashboard/banner_carousel.dart';
import 'package:claim/page/dashboard/dashboard_menu.dart';
import 'package:claim/page/dashboard/it_case_banner.dart';
import 'package:claim/page/dashboard/it_case_open_cards.dart';
import 'package:claim/page/dashboard/line_support.dart';
import 'package:claim/page/dashboard/support_links.dart';
import 'package:claim/utils/pm_access_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadBanners();
    // ช่องทางแจ้งปัญหาอ่านจาก issue.json อ่าน cache ก่อนแล้วดึงของใหม่เบื้องหลัง
    SupportLinksService.I.load();
    // สิทธิ์เมนู PM มาจาก pm.json อ่าน cache ก่อนแล้วดึงของใหม่เบื้องหลัง
    PmAccessService.I.init();
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _Greeting(name: _userName),
        const SizedBox(height: 16),

        // ไม่มีรูปใน banner.json ก็ไม่ต้องกินที่เลย ไม่ใช่ขึ้นกล่องเทาเปล่า ๆ
        // ที่คนใช้ทำอะไรกับมันไม่ได้ ระหว่างโหลดก็ยังไม่โชว์ ขึ้นมาตอนได้รูปจริง
        if (_banners.isNotEmpty) ...[
          BannerCarousel(banners: _banners),
          const SizedBox(height: 16),
        ],

        const ItCaseBanner(),
        const SizedBox(height: 16),
        ValueListenableBuilder<bool>(
          valueListenable: PmAccessService.I.allowed,
          builder: (context, _, _) =>
              _MenuGrid(items: buildDashboardMenu(context)),
        ),
        const ItCaseOpenCases(),
      ],
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
        const LineSupportButton(),
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
  final List<DashboardMenuItem> items;

  const _MenuGrid({required this.items});

  @override
  State<_MenuGrid> createState() => _MenuGridState();
}

class _MenuGridState extends State<_MenuGrid> {
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

    for (final item in widget.items) {
      final painter = TextPainter(
        text: TextSpan(
          text: item.label,
          style: const TextStyle(fontSize: _labelSize, height: _labelHeight),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 3,
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
            ],
          );
        },
      ),
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
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: item.iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, size: 26, color: item.iconColor),
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
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.3,
              color: blocked ? scheme.onSurfaceVariant : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
