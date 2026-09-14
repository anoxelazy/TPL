import 'package:flutter/material.dart';
import 'package:claim/page/stock/shipment_progress.dart';
import 'package:claim/page/stock/stock_api.dart';
import 'package:claim/page/stock/stock_detail_page.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/permission_service.dart';
import 'package:claim/widgets/app_card.dart';
import 'package:claim/widgets/donut_chart.dart';
import 'package:claim/widgets/info_row.dart';
import 'package:claim/widgets/state_views.dart';

/// สีของแต่ละระยะ ใช้ทั้งบนกราฟและ chip สถานะให้ตรงกัน
Color _stageColor(ShipmentStage? stage, ColorScheme scheme) {
  switch (stage) {
    case ShipmentStage.origin:
      return AppColors.stageOrigin;
    case ShipmentStage.warehouse:
      return AppColors.stageWarehouse;
    case ShipmentStage.parked:
      return AppColors.pending;
    case ShipmentStage.delivering:
      return AppColors.stageDelivering;
    case ShipmentStage.delivered:
      return AppColors.success;
    case ShipmentStage.returned:
      return AppColors.danger;
    case null:
      return scheme.onSurfaceVariant;
  }
}

/// หน้าเช็คสถานะคลังสินค้าของสาขาที่ผู้ใช้ login เข้ามา
class StockStatusPage extends StatefulWidget {
  const StockStatusPage({super.key});

  @override
  State<StockStatusPage> createState() => _StockStatusPageState();
}

class _StockStatusPageState extends State<StockStatusPage> {
  final TextEditingController _searchController = TextEditingController();

  List<BillStockItem> _items = [];
  bool _isLoading = true;
  String? _error;
  ShipmentStage? _stageFilter;
  String _query = '';

  String? get _branchId => PermissionService.I.getBranchId();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final branchId = _branchId;

    if (branchId == null || branchId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'ไม่พบรหัสสาขาของผู้ใช้ กรุณาเข้าสู่ระบบใหม่';
        _items = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // ยิงตารางแปลรหัสสถานะขนานไปกับข้อมูล ตัวมันไม่ throw
      final stagesReady = loadJobStatusStages();
      final items = await fetchBillStock(branchId: branchId);
      await stagesReady;
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
        // ตัวกรองเดิมอาจไม่มีอยู่ในชุดข้อมูลใหม่
        if (_stageFilter != null && _countOf(_stageFilter!) == 0) {
          _stageFilter = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  int _countOf(ShipmentStage stage) =>
      _items.where((item) => item.stage == stage).length;

  List<BillStockItem> get _filtered {
    final keyword = _query.trim().toLowerCase();

    return _items.where((item) {
      if (_stageFilter != null && item.stage != _stageFilter) return false;
      if (keyword.isEmpty) return true;
      return item.searchIndex.contains(keyword);
    }).toList();
  }

  Future<void> _openDetail(BillStockItem item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => StockDetailPage(item: item)),
    );
    // กลับมาพร้อมสถานะที่เปลี่ยนแล้ว ต้องดึงข้อมูลใหม่ให้ตรง
    if (changed == true) await _load();
  }

  /// สีธีมของหน้าตามระยะที่กรองอยู่ ไม่ได้กรองจะใช้สีแถบหัวเรื่องปกติ
  Color _accentColor() {
    final theme = Theme.of(context);
    final stage = _stageFilter;
    if (stage == null) {
      return theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    }
    return _stageColor(stage, theme.colorScheme);
  }

  @override
  Widget build(BuildContext context) {
    final branchId = _branchId;
    final hasBranch = branchId != null && branchId.isNotEmpty;
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
            // สีเหลืองต้องใช้ตัวหนังสือสีเข้มถึงจะอ่านออก ต่างจากเขียว/แดง
            final foreground =
                ThemeData.estimateBrightnessForColor(background) ==
                    Brightness.dark
                ? Colors.white
                : Colors.black87;

            return AppBar(
              title: Text('สถานะคลังสินค้า ${hasBranch ? branchId : '-'}'),
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
      body: _buildBody(accent),
    );
  }

  Widget _buildBody(Color accent) {
    if (_isLoading) {
      return const LoadingStateView();
    }

    if (_error != null) {
      return ErrorStateView(message: _error!, onRetry: _load);
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: accent,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            EmptyStateView(message: 'ไม่มีข้อมูลคลังสินค้าของสาขานี้'),
          ],
        ),
      );
    }

    final filtered = _filtered;
    // กรองแล้วไม่เหลืออะไร ต้องบอก ไม่ใช่ปล่อยให้จอว่างใต้กราฟ
    final noMatch = filtered.isEmpty;

    return RefreshIndicator(
      onRefresh: _load,
      color: accent,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        // สองแถวแรกเป็นช่องค้นหากับกราฟภาพรวม ที่เหลือคือการ์ดของแต่ละบิล
        itemCount: noMatch ? 3 : filtered.length + 2,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _QuietSearchField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
              ),
            );
          }
          if (index == 1) {
            return _SummaryCard(
              total: _items.length,
              selected: _stageFilter,
              countOf: _countOf,
              onSelected: (stage) => setState(() => _stageFilter = stage),
            );
          }
          if (noMatch) {
            return const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyStateView(
                message: 'ไม่พบรายการที่ค้นหา',
                icon: Icons.search_off,
              ),
            );
          }

          final item = filtered[index - 2];
          return _StockCard(item: item, onTap: () => _openDetail(item));
        },
      ),
    );
  }
}

/// กราฟภาพรวมของบิลทั้งสาขา พร้อม chip กรองตามระยะ
class _SummaryCard extends StatelessWidget {
  final int total;
  final ShipmentStage? selected;
  final int Function(ShipmentStage) countOf;
  final ValueChanged<ShipmentStage?> onSelected;

  const _SummaryCard({
    required this.total,
    required this.selected,
    required this.countOf,
    required this.onSelected,
  });

  /// chip ของแต่ละระยะ ตอนเลือกอยู่จะย้อมสีเดียวกับแถบหัวเรื่อง
  Widget _stageChip(BuildContext context, ShipmentStage stage) {
    final scheme = Theme.of(context).colorScheme;

    return StatusFilterChip(
      label: stage.label,
      count: countOf(stage),
      color: _stageColor(stage, scheme),
      selected: selected == stage,
      onSelected: () => onSelected(stage),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stages = ShipmentStage.values
        .where((stage) => countOf(stage) > 0)
        .toList();

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.donut_large, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ภาพรวมทั้งหมด',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DonutChart(
            centerTop: '$total',
            centerBottom: 'รายการ',
            diameter: 116,
            hideEmpty: true,
            selectedLabel: selected?.label,
            slices: [
              for (final stage in ShipmentStage.values)
                DonutSlice(
                  label: stage.label,
                  value: countOf(stage),
                  color: _stageColor(stage, scheme),
                ),
            ],
          ),
          if (stages.length > 1) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text('ทั้งหมด $total'),
                  selected: selected == null,
                  onSelected: (_) => onSelected(null),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                for (final stage in stages) _stageChip(context, stage),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  final BillStockItem item;
  final VoidCallback onTap;

  const _StockCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.billCode,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'สถานะสินค้า: ',
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          TextSpan(
                            text: item.jobStatusId ?? '-',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: item.displayStatus,
                color: _stageColor(item.stage, scheme),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 10),
          ShipmentProgress(stage: item.stage),
        ],
      ),
    );
  }
}

/// ช่องค้นหาแบบไม่เด่น: ไม่มีขอบ พื้นจาง ตัวหนังสือเล็ก
///
/// วางเป็นแถวแรกของลิสต์ จึงเลื่อนหายไปพร้อมเนื้อหา ไม่ค้างกินพื้นที่บนจอ
class _QuietSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _QuietSearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      // ธีมตั้ง bodyLarge ไว้ 18px ต้องกำหนดเอง ไม่งั้นช่องสูงและเด่นเกิน
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: 'ค้นหาเลขบิล / ลูกค้า',
        hintStyle: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        prefixIcon: Icon(
          Icons.search,
          size: 17,
          color: scheme.onSurfaceVariant,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 36),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'ล้างคำค้น',
                icon: const Icon(Icons.close, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }
}
