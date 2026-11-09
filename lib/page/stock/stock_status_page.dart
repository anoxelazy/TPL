import 'package:flutter/material.dart';
import 'package:claim/page/stock/shipment_progress.dart';
import 'package:claim/page/stock/stock_api.dart';
import 'package:claim/page/stock/stock_detail_page.dart';
import 'package:claim/page/stock/stock_status_style.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/permission_service.dart';
import 'package:claim/widgets/app_card.dart';
import 'package:claim/widgets/donut_chart.dart';
import 'package:claim/widgets/info_row.dart';
import 'package:claim/widgets/state_views.dart';

/// บิลของแต่ละสถานะที่มีอยู่จริง 1 กลุ่ม
class _StatusGroup {
  final String key;
  final int count;

  const _StatusGroup(this.key, this.count);

  String get label => stockStatusLabel(key);
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
  /// jobstatusid ที่กรองอยู่ ('' = บิลที่ไม่มี jobstatusid) null = ทั้งหมด
  String? _statusFilter;
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
      // ยิงตารางสถานะขนานไปกับข้อมูล ตัวมันไม่ throw
      final statusesReady = loadJobStatuses();
      final items = await fetchBillStock(branchId: branchId);
      await statusesReady;
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
        // ตัวกรองเดิมอาจไม่มีอยู่ในชุดข้อมูลใหม่
        if (_statusFilter != null && _countOf(_statusFilter!) == 0) {
          _statusFilter = null;
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

  static String _keyOf(BillStockItem item) => item.jobStatusId?.trim() ?? '';

  int _countOf(String key) =>
      _items.where((item) => _keyOf(item) == key).length;

  /// สถานะที่มีบิลอยู่จริง เรียงตามลำดับในรายการจาก API ที่ไม่รู้จักไว้ท้ายสุด
  List<_StatusGroup> get _groups {
    final counts = <String, int>{};
    for (final item in _items) {
      counts.update(_keyOf(item), (n) => n + 1, ifAbsent: () => 1);
    }

    final keys = counts.keys.toList()
      ..sort((a, b) {
        final byOrder = jobStatusOrder(a).compareTo(jobStatusOrder(b));
        return byOrder != 0 ? byOrder : a.compareTo(b);
      });
    // ไม่มี jobstatusid ไว้ท้ายสุดเสมอ
    if (keys.remove('')) keys.add('');

    return [for (final key in keys) _StatusGroup(key, counts[key]!)];
  }

  List<BillStockItem> get _filtered {
    final keyword = _query.trim().toLowerCase();

    return _items.where((item) {
      if (_statusFilter != null && _keyOf(item) != _statusFilter) return false;
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

  /// สีเน้นของเนื้อหาตามสถานะที่กรองอยู่ ไม่ได้กรองใช้เขียวแบรนด์
  ///
  /// เดิมทั้งแถบหัวเรื่องเปลี่ยนสีตามตัวกรองด้วย ตอนนี้แถบเป็นสีปกติของธีม
  /// สีของสถานะเหลือแค่ในเนื้อหา ไม่ใช่ทาทั้งหัวจอ
  Color _accentColor() {
    final theme = Theme.of(context);
    final key = _statusFilter;
    if (key == null) return theme.colorScheme.primary;
    return stockStatusColor(key, theme.colorScheme);
  }

  @override
  Widget build(BuildContext context) {
    final branchId = _branchId;
    final hasBranch = branchId != null && branchId.isNotEmpty;
    final accent = _accentColor();

    return Scaffold(
      appBar: AppBar(
        title: Text('สถานะคลังสินค้า ${hasBranch ? branchId : '-'}'),
      ),
      body: _buildBody(accent),
    );
  }

  Widget _buildBody(Color accent) {
    if (_isLoading) {
      return const ListLoadingView();
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
              groups: _groups,
              selected: _statusFilter,
              onSelected: (key) => setState(() => _statusFilter = key),
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

/// กราฟภาพรวมของบิลทั้งสาขา พร้อม chip กรองตามสถานะงานที่มีบิลอยู่จริง
class _SummaryCard extends StatelessWidget {
  final int total;
  final List<_StatusGroup> groups;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _SummaryCard({
    required this.total,
    required this.groups,
    required this.selected,
    required this.onSelected,
  });

  /// chip ของแต่ละสถานะ ตอนเลือกอยู่จะย้อมสีเดียวกับเนื้อหา
  Widget _statusChip(BuildContext context, _StatusGroup group) {
    final scheme = Theme.of(context).colorScheme;

    return StatusFilterChip(
      label: group.label,
      count: group.count,
      color: stockStatusColor(group.key, scheme),
      selected: selected == group.key,
      onSelected: () => onSelected(group.key),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedLabel = selected == null ? null : stockStatusLabel(selected!);

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
                    fontSize: 14,
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
            selectedLabel: selectedLabel,
            slices: [
              for (final group in groups)
                DonutSlice(
                  label: group.label,
                  value: group.count,
                  color: stockStatusColor(group.key, scheme),
                ),
            ],
          ),
          if (groups.length > 1) ...[
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
                for (final group in groups) _statusChip(context, group),
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
          StockBillHeader(
            item: item,
            trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
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
          borderRadius: BorderRadius.circular(AppSizes.innerRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.innerRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.innerRadius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }
}
