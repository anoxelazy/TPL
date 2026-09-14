import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/page/plan/plan_api.dart';
import 'package:claim/page/plan/plan_detail_page.dart';
import 'package:claim/widgets/donut_chart.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/widgets/app_card.dart';
import 'package:claim/widgets/state_views.dart';

class PlanPage extends StatefulWidget {
  const PlanPage({super.key});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  List<PlanJobItem> _items = [];
  bool _isLoading = true;
  String? _error;
  String? _username;

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
      final prefs = await SharedPreferences.getInstance();
      final items = await fetchMyPlans();
      if (!mounted) return;
      setState(() {
        _username = prefs.getString('username');
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

  @override
  Widget build(BuildContext context) {
    final hasUsername = _username != null && _username!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('แผนของคุณ ${hasUsername ? _username : ''}'.trimRight()),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingStateView();
    }

    if (_error != null) {
      return ErrorStateView(message: _error!, onRetry: _load);
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            EmptyStateView(
              message: 'ยังไม่มีแผนงานของคุณ',
              icon: Icons.assignment_outlined,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        // แถวแรกเป็นกราฟภาพรวม ที่เหลือคือการ์ดของแต่ละรอบส่ง
        itemCount: _items.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => index == 0
            ? _SummaryCard(items: _items)
            : _PlanCard(item: _items[index - 1]),
      ),
    );
  }
}

/// กราฟภาพรวมของทุกรอบส่งรวมกัน อยู่บนสุดของหน้า
class _SummaryCard extends StatelessWidget {
  final List<PlanJobItem> items;

  const _SummaryCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    int sumOf(int Function(PlanJobItem) pick) =>
        items.fold(0, (total, item) => total + pick(item));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.donut_large, size: 22, color: scheme.primary),
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
              Text(
                '${items.length} รอบส่ง',
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'สินค้ารวม ${sumOf((e) => e.billTotal)} รายการ',
            style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _breakdownChart(
            sumOf((e) => e.billSuccess),
            sumOf((e) => e.billRemain),
            sumOf((e) => e.billFail),
          ),
        ],
      ),
    );
  }

  /// กราฟสัดส่วน สำเร็จ / คงเหลือ / ไม่สำเร็จ กลางวงบอก % ที่ส่งสำเร็จแล้ว
  Widget _breakdownChart(int success, int remaining, int failed) {
    final total = success + remaining + failed;

    return DonutChart(
      centerTop: total == 0 ? '-' : '${(success * 100 / total).round()}%',
      centerBottom: BillStatus.success.label,
      slices: [
        DonutSlice(
          label: BillStatus.success.label,
          value: success,
          color: AppColors.success,
        ),
        DonutSlice(
          label: BillStatus.remaining.label,
          value: remaining,
          color: AppColors.pending,
        ),
        DonutSlice(
          label: BillStatus.failed.label,
          value: failed,
          color: AppColors.danger,
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanJobItem item;

  const _PlanCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => PlanDetailPage(plan: item))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.local_shipping, size: 26, color: scheme.onSurface),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.truckSendId,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'สินค้ารวม ${item.billTotal} รายการ',
            style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _Metric(
                  label: BillStatus.success.label,
                  accent: AppColors.success,
                  icon: Icons.check_circle,
                  value: item.billSuccess,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: BillStatus.remaining.label,
                  accent: AppColors.pending,
                  icon: Icons.pending_actions,
                  value: item.billRemain,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: BillStatus.failed.label,
                  accent: AppColors.danger,
                  icon: Icons.error,
                  value: item.billFail,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ตัวเลขสรุป 1 ช่อง: ป้ายชื่อด้านบน ไอคอนกับตัวเลขด้านล่าง
class _Metric extends StatelessWidget {
  final String label;
  final Color accent;
  final IconData icon;
  final int? value;

  const _Metric({
    required this.label,
    required this.accent,
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    // จัดกลางทั้งป้ายชื่อและตัวเลข สามช่องจึงถ่วงน้ำหนักเท่ากันทั้งการ์ด
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: accent,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: accent),
            const SizedBox(width: 6),
            Text(
              value?.toString() ?? '-',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
