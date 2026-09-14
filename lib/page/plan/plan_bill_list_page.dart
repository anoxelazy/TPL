import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:claim/page/plan/plan_api.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/widgets/app_card.dart';
import 'package:claim/widgets/info_row.dart';
import 'package:claim/widgets/state_views.dart';

final NumberFormat _money = NumberFormat('#,##0.00');

/// บิลทั้งหมดในรอบส่งที่เลือก
class PlanBillListPage extends StatefulWidget {
  final PlanJobItem plan;

  const PlanBillListPage({super.key, required this.plan});

  @override
  State<PlanBillListPage> createState() => _PlanBillListPageState();
}

class _PlanBillListPageState extends State<PlanBillListPage> {
  List<BillItem> _items = [];
  bool _isLoading = true;
  String? _error;
  BillStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await fetchBillList(truckSendId: widget.plan.truckSendId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<BillItem> get _filtered {
    if (_statusFilter == null) return _items;
    return _items.where((item) => item.status == _statusFilter).toList();
  }

  int _countOf(BillStatus status) =>
      _items.where((item) => item.status == status).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รายการบิลในแผน')),
      body: Column(
        children: [
          if (!_isLoading && _error == null && _items.isNotEmpty)
            _StatusFilterBar(
              selected: _statusFilter,
              total: _items.length,
              countOf: _countOf,
              onSelected: (status) => setState(() => _statusFilter = status),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingStateView();
    }

    if (_error != null) {
      return ErrorStateView(message: _error!, onRetry: _load);
    }

    final filtered = _filtered;

    if (filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 80),
            EmptyStateView(
              icon: Icons.receipt_long,
              message: _items.isEmpty
                  ? 'ไม่มีบิลในรอบส่งนี้'
                  : 'ไม่มีบิลในสถานะที่เลือก',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _BillCard(item: filtered[index]),
      ),
    );
  }
}

Color _colorOf(BillStatus status) {
  switch (status) {
    case BillStatus.success:
      return AppColors.success;
    case BillStatus.failed:
      return AppColors.danger;
    case BillStatus.remaining:
      return AppColors.pending;
  }
}

IconData _iconOf(BillStatus status) {
  switch (status) {
    case BillStatus.success:
      return Icons.check_circle;
    case BillStatus.failed:
      return Icons.error;
    case BillStatus.remaining:
      return Icons.pending_actions;
  }
}

class _StatusFilterBar extends StatelessWidget {
  final BillStatus? selected;
  final int total;
  final int Function(BillStatus) countOf;
  final ValueChanged<BillStatus?> onSelected;

  const _StatusFilterBar({
    required this.selected,
    required this.total,
    required this.countOf,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: StatusFilterChip(
              label: 'ทั้งหมด',
              count: total,
              selected: selected == null,
              onSelected: () => onSelected(null),
            ),
          ),
          // ย้อมสีเดียวกับที่การ์ดและหน้าสถานะคลังใช้ จะได้อ่านสถานะออกทันที
          for (final status in BillStatus.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: StatusFilterChip(
                label: status.label,
                count: countOf(status),
                color: _colorOf(status),
                selected: selected == status,
                onSelected: () => onSelected(status),
              ),
            ),
        ],
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  final BillItem item;

  const _BillCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _colorOf(item.status);
    final bool hasMoney = item.cod > 0 || item.deliveryPrice > 0;

    // clipContent ให้แถบสีซ้ายไม่ล้นมุมโค้งของการ์ด
    //
    // ใช้ Stack ไม่ใช่ Row+IntrinsicHeight เพราะ IntrinsicHeight ต้อง
    // วัด layout เพิ่มอีกรอบทุกการ์ด ทำให้เลื่อน list หนัก
    // Stack วัดจากลูกที่ไม่ได้ positioned (เนื้อหา) แล้วแถบซ้ายที่
    // positioned top/bottom จะยืดตามความสูงนั้นเองในรอบเดียว
    return AppCard(
      clipContent: true,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: 5,
            child: ColoredBox(color: accent),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(19, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.a1,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    StatusChip(
                      label: item.status.label,
                      color: accent,
                      icon: _iconOf(item.status),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                InfoRow(icon: Icons.person_outline, value: item.recieptName),
                InfoRow(icon: Icons.location_on_outlined, value: item.address),
                InfoRow(icon: Icons.phone_outlined, value: item.tel),
                InfoRow(
                  icon: Icons.inventory_2_outlined,
                  value: item.qty > 0 ? '${item.qty} ชิ้น' : '',
                ),
                InfoRow(icon: Icons.payments_outlined, value: item.typePay),
                if (hasMoney)
                  InfoRow(
                    icon: Icons.savings_outlined,
                    value:
                        'COD ${_money.format(item.cod)} · '
                        'ขนส่ง ${_money.format(item.deliveryPrice)} บาท',
                  ),
                InfoRow(icon: Icons.notes_outlined, value: item.memo),
                if (item.hasPod)
                  InfoRow(
                    icon: Icons.assignment_turned_in_outlined,
                    value: 'มีใบ POD',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
