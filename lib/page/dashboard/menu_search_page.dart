import 'package:flutter/material.dart';

import 'package:claim/page/dashboard/dashboard_menu.dart';

/// หน้าค้นหาเมนู
///
/// แยกเป็นหน้าของตัวเองเพื่อให้คีย์บอร์ดมีที่ปิด: กดย้อนกลับหรือแตะที่ว่าง
/// ก็ปิดได้ ต่างจากตอนวางช่องค้นหาไว้บนหน้าหลักที่คีย์บอร์ดค้างอยู่
///
/// ตอนยังไม่พิมพ์จะไม่ลิสต์เมนูออกมา เพราะเมนูทั้งหมดอยู่บนหน้าหลักแล้ว
class MenuSearchPage extends StatefulWidget {
  /// เมนูทั้งหมด สร้างมาจากหน้าหลักเพื่อให้ปุ่มยังกดไปต่อได้หลังปิดหน้านี้
  final List<DashboardMenuItem> items;

  /// เรียกหลังปิดหน้านี้แล้ว ให้หน้าหลักเป็นคนพาไปต่อ
  final ValueChanged<DashboardMenuItem> onSelected;

  const MenuSearchPage({
    super.key,
    required this.items,
    required this.onSelected,
  });

  /// เปิดหน้านี้แบบเฟดเข้า + ขยายเล็กน้อย ไม่ใช่สไลด์จากขวาแบบ default
  ///
  /// ให้ความรู้สึกว่าช่องค้นหาบนหน้าหลักคลี่ออกเป็นหน้าค้นหา
  /// ไม่ใช่การเปลี่ยนไปหน้าอื่น
  static Route<void> route({
    required List<DashboardMenuItem> items,
    required ValueChanged<DashboardMenuItem> onSelected,
  }) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) =>
          MenuSearchPage(items: items, onSelected: onSelected),
      transitionsBuilder: (context, animation, secondary, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeIn,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<MenuSearchPage> createState() => _MenuSearchPageState();
}

class _MenuSearchPageState extends State<MenuSearchPage> {
  final TextEditingController _controller = TextEditingController();

  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(DashboardMenuItem item) {
    Navigator.of(context).pop();
    widget.onSelected(item);
  }

  /// key บอก AnimatedSwitcher ว่าเปลี่ยนสภาพแล้ว ต้องเฟดสลับ
  /// ผลค้นหาใช้ key เดียวกันทุกคำค้น จะได้ไม่เฟดใหม่ทุกตัวอักษรที่พิมพ์
  Widget _buildBody(
    ColorScheme scheme,
    bool typing,
    List<DashboardMenuItem> results,
  ) {
    if (!typing) {
      return _Hint(
        key: const ValueKey('idle'),
        text: 'พิมพ์ชื่อเมนูที่ต้องการ',
        scheme: scheme,
      );
    }

    if (results.isEmpty) {
      return _Hint(
        key: const ValueKey('empty'),
        text: 'ไม่พบเมนูที่ค้นหา',
        scheme: scheme,
      );
    }

    return ListView.builder(
      key: const ValueKey('results'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        return ListTile(
          onTap: () => _select(item),
          leading: Icon(item.icon, color: item.iconColor),
          title: Text(
            item.label,
            style: TextStyle(
              fontSize: 15,
              color: item.isBlocked
                  ? scheme.onSurfaceVariant
                  : scheme.onSurface,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onAppBar = Theme.of(context).appBarTheme.foregroundColor;
    final typing = _query.trim().isNotEmpty;
    final results = typing
        ? filterDashboardMenu(widget.items, _query)
        : const <DashboardMenuItem>[];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: TextStyle(fontSize: 16, color: onAppBar),
          cursorColor: onAppBar,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: 'ค้นหาเมนู',
            hintStyle: TextStyle(
              fontSize: 16,
              color: onAppBar?.withValues(alpha: 0.7),
            ),
            // ธีมตั้ง filled + ขอบไว้ ต้องปิดเอง ไม่งั้นเป็นกล่องขาวบนแถบเขียว
            filled: false,
            border: InputBorder.none,
            isDense: true,
          ),
        ),
        actions: [
          if (typing)
            IconButton(
              tooltip: 'ล้างคำค้น',
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      // แตะที่ว่างเพื่อปิดคีย์บอร์ด
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          // default จะจัดลูกไว้กลางจอตามขนาดตัวเอง ลิสต์ต้องยืดเต็มพื้นที่
          layoutBuilder: (current, previous) =>
              Stack(fit: StackFit.expand, children: [...previous, ?current]),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: _buildBody(scheme, typing, results),
        ),
      ),
    );
  }
}

/// ข้อความกลางจอ ใช้ทั้งตอนยังไม่พิมพ์และตอนค้นไม่เจอ
class _Hint extends StatelessWidget {
  final String text;
  final ColorScheme scheme;

  const _Hint({super.key, required this.text, required this.scheme});

  @override
  Widget build(BuildContext context) {
    // ต้องเต็มจอ ไม่งั้น GestureDetector ที่ครอบจะไม่รับการแตะที่ว่าง
    return SizedBox.expand(
      child: Align(
        alignment: const Alignment(0, -0.4),
        child: Text(
          text,
          style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
