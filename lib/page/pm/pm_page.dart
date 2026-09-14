import 'package:flutter/material.dart';

import 'package:claim/page/pm/pm_api.dart';
import 'package:claim/page/pm/pm_form_page.dart';
import 'package:claim/page/pm/pm_location.dart';
import 'package:claim/page/pm/pm_models.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/app_icons.dart';
import 'package:claim/utils/mobile_api.dart';
import 'package:claim/widgets/app_card.dart';
import 'package:claim/widgets/barcode_scanner.dart';
import 'package:claim/widgets/donut_chart.dart';
import 'package:claim/widgets/info_row.dart';
import 'package:claim/widgets/state_views.dart';

/// ตัวกรองสถานะของปีที่เลือก
///
/// เรียงตามลำดับงาน (ยังไม่ทำ → ทำค้าง → เสร็จ) ทั้งบน chip และบนกราฟ
/// ให้สายตาไล่ไปทางเดียวกัน
enum _PmFilter {
  all('ทั้งหมด'),
  todo('ยังไม่ทำ'),
  partial('ทำค้างไว้'),
  done('เสร็จแล้ว');

  final String label;
  const _PmFilter(this.label);

  /// ส่วนที่เอาไปวาดกราฟ ไม่รวม "ทั้งหมด" เพราะมันคือผลรวมของอีกสามตัว
  static List<_PmFilter> get statuses => const [todo, partial, done];
}

/// สีประจำสถานะ ใช้ทั้ง chip กราฟ และป้ายบนการ์ดให้ตรงกัน
///
/// "ทั้งหมด" คืน null เพราะไม่ได้ผูกกับสถานะไหน [StatusFilterChip] รับ null
/// แล้วใช้สีปกติของธีมให้เอง
Color? _filterColor(_PmFilter filter, ColorScheme scheme) {
  switch (filter) {
    case _PmFilter.all:
      return null;
    case _PmFilter.todo:
      return scheme.onSurfaceVariant;
    case _PmFilter.partial:
      return AppColors.pending;
    case _PmFilter.done:
      return AppColors.success;
  }
}

/// หน้ารวมงาน PM ประจำปี
///
/// API ไม่มีตัวกรองหรือแบ่งหน้า ต้องโหลดทั้งก้อน (ของจริง ~600 KB / 134 เครื่อง)
/// แล้วค้นในเครื่อง จึงโหลดครั้งเดียวตอนเปิดหน้า ไม่ยิงซ้ำตอนพิมพ์ค้นหา
class PmPage extends StatefulWidget {
  const PmPage({super.key});

  @override
  State<PmPage> createState() => _PmPageState();
}

class _PmPageState extends State<PmPage> {
  final _searchController = TextEditingController();

  List<PmHead> _heads = [];
  bool _isLoading = true;
  String? _error;
  bool _needLogin = false;
  String _query = '';
  _PmFilter _filter = _PmFilter.all;

  /// ปีที่กำลังดู ตั้งต้นที่ปีปัจจุบันเพราะงานที่ต้องทำคือของปีนี้
  late int _year = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _load();
    // ตารางแปลงรหัสสถานที่ อ่าน cache ก่อนแล้วดึงของใหม่เบื้องหลัง
    // ไม่ต้องรอ เพราะมีค่าสำรองติดมากับแอปอยู่แล้ว
    PmLocations.I.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _needLogin = false;
    });

    try {
      final heads = await fetchPmList();
      if (!mounted) return;
      setState(() {
        _heads = heads;
        _isLoading = false;
      });
    } on MobileApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.message;
        _needLogin = e.needLogin;
      });
    }
  }

  /// ปีที่เลือกได้ = ปีที่มีข้อมูล บวกปีปัจจุบันเสมอ
  ///
  /// ต้องใส่ปีปัจจุบันเองด้วย เพราะต้นปีจะยังไม่มีเครื่องไหนทำ PM เลย
  /// ถ้าเอาแต่ปีที่มีข้อมูล ช่างจะเลือกปีนี้ไม่ได้ทั้งที่เป็นปีที่ต้องทำ
  List<int> get _years {
    final set = <int>{DateTime.now().year};
    for (final head in _heads) {
      set.addAll(head.years);
    }
    final list = set.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  List<PmHead> get _filtered {
    final keyword = _query.trim().toLowerCase();

    return _heads.where((head) {
      if (keyword.isNotEmpty && !head.searchIndex.contains(keyword)) {
        return false;
      }

      switch (_filter) {
        case _PmFilter.all:
          return true;
        case _PmFilter.todo:
          return head.completedCount(_year) == 0;
        case _PmFilter.partial:
          return head.isPartial(_year);
        case _PmFilter.done:
          return head.isDone(_year);
      }
    }).toList();
  }

  int get _doneCount => _heads.where((h) => h.isDone(_year)).length;

  Future<void> _scanToSearch() async {
    final code = await openBarcodeScannerPage(
      context,
      title: 'สแกนเครื่อง',
      hint: 'วางบาร์โค้ดบนเครื่องให้อยู่กลางจอ',
    );
    if (code == null || !mounted) return;

    _searchController.text = code;
    setState(() => _query = code);
  }

  Future<void> _openForm(PmHead head) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PmFormPage(head: head, year: _year),
      ),
    );
    if (saved == true) await _load();
  }

  /// สีธีมของหน้าตามตัวกรองที่เลือกอยู่ ไม่ได้กรองจะใช้สีแถบหัวเรื่องปกติ
  ///
  /// ทำแบบเดียวกับหน้าสถานะคลังสินค้า ให้ทั้งแอปรู้สึกเป็นระบบเดียวกัน
  Color _accentColor() {
    final theme = Theme.of(context);
    return _filterColor(_filter, theme.colorScheme) ??
        theme.appBarTheme.backgroundColor ??
        theme.colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        // ไล่สีตอนสลับตัวกรอง ไม่ให้แถบกระโดดเปลี่ยนสีทันที
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: accent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          builder: (context, color, _) {
            final background = color ?? accent;
            // สีส้มต้องใช้ตัวหนังสือสีเข้มถึงจะอ่านออก ต่างจากเขียว/เทา
            final foreground =
                ThemeData.estimateBrightnessForColor(background) ==
                    Brightness.dark
                ? Colors.white
                : Colors.black87;

            return AppBar(
              title: const Text('PM ประจำปี'),
              backgroundColor: background,
              foregroundColor: foreground,
              titleTextStyle: Theme.of(
                context,
              ).appBarTheme.titleTextStyle?.copyWith(color: foreground),
              iconTheme: IconThemeData(color: foreground),
            );
          },
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: _body(accent),
      ),
    );
  }

  /// ปุ่มเลือกปี วางไว้ในการ์ดความคืบหน้า ไม่ใช่บน AppBar
  ///
  /// ปีเป็นตัวกำหนดว่าตัวเลขทั้งการ์ดหมายถึงอะไร อยู่ติดกับตัวเลขจึงอ่านเป็น
  /// เรื่องเดียวกัน ตอนอยู่บน AppBar มันลอยจนดูเหมือนไม่เกี่ยวกับอะไรเลย
  Widget _yearPicker() {
    final scheme = Theme.of(context).colorScheme;

    return PopupMenuButton<int>(
      tooltip: 'เลือกปี',
      initialValue: _year,
      position: PopupMenuPosition.under,
      onSelected: (value) => setState(() => _year = value),
      itemBuilder: (context) => _years
          .map((y) => PopupMenuItem(value: y, child: Text('ปี $y')))
          .toList(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ปี $_year',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(Color accent) {
    if (_isLoading) return const LoadingStateView();

    final error = _error;
    if (error != null) {
      // token ใช้ไม่ได้แล้ว กดลองใหม่กี่ทีก็ไม่ผ่าน ต้องบอกให้ไปเข้าสู่ระบบใหม่
      if (_needLogin) {
        return Center(
          child: EmptyStateView(icon: Icons.lock_outline, message: error),
        );
      }
      return ErrorStateView(message: error, onRetry: _load);
    }

    if (_heads.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            EmptyStateView(
              icon: Icons.desktop_windows_outlined,
              message: 'ยังไม่มีเครื่องในระบบ PM',
            ),
          ],
        ),
      );
    }

    final list = _filtered;

    return RefreshIndicator(
      onRefresh: _load,
      color: accent,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: list.isEmpty ? 2 : list.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) return _header();
          if (list.isEmpty) {
            return const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyStateView(
                icon: Icons.search_off,
                message: 'ไม่พบเครื่องที่ค้นหา',
              ),
            );
          }
          return _PmTile(
            head: list[index - 1],
            year: _year,
            onTap: () => _openForm(list[index - 1]),
          );
        },
      ),
    );
  }

  Widget _header() {
    final scheme = Theme.of(context).colorScheme;
    final total = _heads.length;
    final done = _doneCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'ความคืบหน้า',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _yearPicker(),
                ],
              ),
              const SizedBox(height: 12),
              DonutChart(
                centerTop: '$done',
                centerBottom: 'จาก $total',
                diameter: 124,
                hideEmpty: true,
                // ส่วนที่กรองอยู่จะเด่นขึ้นบนกราฟด้วย กด chip แล้วเห็นทันที
                // ว่าตัวเองกำลังดูก้อนไหนของทั้งหมด
                selectedLabel: _filter == _PmFilter.all ? null : _filter.label,
                slices: [
                  for (final status in _PmFilter.statuses)
                    DonutSlice(
                      label: status.label,
                      value: _countOf(status),
                      color:
                          _filterColor(status, scheme) ??
                          scheme.onSurfaceVariant,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _searchField(),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in _PmFilter.values) ...[
                StatusFilterChip(
                  label: filter.label,
                  count: _countOf(filter),
                  color: _filterColor(filter, scheme),
                  selected: _filter == filter,
                  onSelected: () => setState(() => _filter = filter),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  int _countOf(_PmFilter filter) {
    switch (filter) {
      case _PmFilter.all:
        return _heads.length;
      case _PmFilter.todo:
        return _heads.where((h) => h.completedCount(_year) == 0).length;
      case _PmFilter.partial:
        return _heads.where((h) => h.isPartial(_year)).length;
      case _PmFilter.done:
        return _doneCount;
    }
  }

  Widget _searchField() {
    final scheme = Theme.of(context).colorScheme;

    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value),
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'ค้นหาชื่อเครื่อง รหัสทรัพย์สิน ผู้ใช้',
        hintStyle: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
        prefixIcon: const Icon(Icons.search, size: 18),
        prefixIconConstraints: const BoxConstraints(minWidth: 38),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_query.isNotEmpty)
              IconButton(
                tooltip: 'ล้าง',
                icon: const Icon(Icons.close, size: 16),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
            IconButton(
              tooltip: 'สแกน',
              icon: const Icon(AppIcons.scan, size: 20),
              onPressed: _scanToSearch,
            ),
          ],
        ),
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// เครื่อง 1 เครื่องในรายการ
class _PmTile extends StatelessWidget {
  final PmHead head;
  final int year;
  final VoidCallback onTap;

  const _PmTile({required this.head, required this.year, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = head.completedCount(year);

    final (Color color, String label) = done == 0
        ? (scheme.onSurfaceVariant, 'ยังไม่ทำ')
        : done >= pmTaskCount
        ? (AppColors.success, 'เสร็จแล้ว')
        : (AppColors.pending, 'ทำค้างไว้ $done/$pmTaskCount');

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.desktop_windows_outlined, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  head.comName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (head.fixAsset != null) head.fixAsset!,
                    // โชว์ชื่อสถานที่ ไม่ใช่รหัส คนอ่านไม่รู้ว่าเลข 2 คืออะไร
                    if (head.location != null)
                      PmLocations.I.labelOf(head.location),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                // หมายเหตุแยกบรรทัด ไม่เอาไปต่อท้ายรหัสทรัพย์สิน
                // เพราะเป็นข้อความอิสระที่ยาวได้ ต่อกันแล้วจะโดนตัดหายทั้งคู่
                if (head.remark != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.sticky_note_2_outlined,
                        size: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          head.remark!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
