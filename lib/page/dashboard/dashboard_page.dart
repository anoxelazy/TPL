import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/page/dashboard/banner_api.dart';
import 'package:claim/page/dashboard/banner_carousel.dart';
import 'package:claim/page/dashboard/dashboard_menu.dart';
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

  List<BannerItem> _banners = [];
  bool _isLoadingBanners = true;
  String? _bannerError;

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

  Future<void> _loadBanners() async {
    try {
      final banners = await fetchBanners();
      if (!mounted) return;
      setState(() {
        _banners = banners;
        _isLoadingBanners = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingBanners = false;
        _bannerError = e.toString().replaceFirst('Exception: ', '');
      });
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

  Widget _buildBanner() {
    if (_isLoadingBanners) return const BannerPlaceholder(loading: true);
    if (_bannerError != null) return BannerPlaceholder(message: _bannerError);
    if (_banners.isEmpty) return const BannerPlaceholder();
    return BannerCarousel(banners: _banners);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _Greeting(name: _userName),
        const SizedBox(height: 16),
        // _SearchButton(onTap: _openSearch),
        // const SizedBox(height: 16),
        _buildBanner(),
        const SizedBox(height: 16),
        // เมนูต้องวาดใหม่เมื่อรู้ผลสิทธิ์ PM ไม่งั้นค้างเป็นล็อกจนกว่าจะสลับหน้า
        ValueListenableBuilder<bool>(
          valueListenable: PmAccessService.I.allowed,
          builder: (context, _, _) =>
              _MenuGrid(items: buildDashboardMenu(context)),
        ),
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
        const ProfileAvatarView(radius: 18),
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

/// การ์ดรวมเมนูแบบไอคอนกลม 4 ช่องต่อแถว
class _MenuGrid extends StatelessWidget {
  final List<DashboardMenuItem> items;

  static const int _columns = 4;
  static const double _gap = 8;

  const _MenuGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      // คำนวณความกว้างช่องเองแล้วใช้ Wrap ความสูงแต่ละช่องจึงยืดตามป้ายชื่อ
      // ที่ยาวไม่เท่ากันได้ ไม่ล้นกรอบเหมือน GridView ที่บังคับ aspect ratio
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth =
              (constraints.maxWidth - _gap * (_columns - 1)) / _columns;

          return Wrap(
            spacing: _gap,
            runSpacing: 20,
            children: [
              for (final item in items)
                SizedBox(
                  width: itemWidth,
                  child: _MenuButton(item: item),
                ),
            ],
          );
        },
      ),
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
