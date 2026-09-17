import 'package:flutter/material.dart';

import 'package:claim/page/repair/repair_appbar.dart';
import 'package:claim/utils/app_colors.dart';

import 'package:claim/page/chat/chat_page.dart';
import 'package:claim/page/repair/asset_page.dart';
import 'package:claim/page/repair/repair_api.dart';
import 'package:claim/page/repair/repair_card.dart';
import 'package:claim/page/repair/repair_detail_page.dart';
import 'package:claim/page/repair/repair_form_page.dart';
import 'package:claim/page/repair/repair_style.dart';
import 'package:claim/page/repair/repair_watch_service.dart';
import 'package:claim/utils/role_service.dart';
import 'package:claim/widgets/state_views.dart';

/// หน้ารายการใบแจ้งซ่อม เปิดได้ทุก role ปุ่มแจ้งซ่อมก็ใช้ได้ทุกคน
class RepairPage extends StatefulWidget {
  const RepairPage({super.key});

  @override
  State<RepairPage> createState() => _RepairPageState();
}

class _RepairPageState extends State<RepairPage> {
  List<RepairTicket> _tickets = [];
  bool _isLoading = true;
  String? _error;
  RepairStatus? _filter;

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
      final tickets = await fetchRepairs();
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _isLoading = false;
        // ตัวกรองเดิมอาจไม่มีอยู่ในชุดข้อมูลใหม่
        if (_filter != null && _countOf(_filter!) == 0) _filter = null;
      });

      // เทียบสถานะกับที่จำไว้แล้วแจ้งเตือนถ้าใบของเราถูกรับงาน/ปิดงาน
      // ส่งรายการที่เพิ่งโหลดไปด้วย จะได้ไม่ยิง API ซ้ำอีกรอบ
      RepairWatchService.I.check(tickets: tickets, force: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  int _countOf(RepairStatus status) =>
      _tickets.where((t) => t.status == status).length;

  List<RepairTicket> get _filtered => _filter == null
      ? _tickets
      : _tickets.where((t) => t.status == _filter).toList();

  Future<void> _openForm() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const RepairFormPage()));
    if (created == true) await _load();
  }

  Future<void> _openDetail(RepairTicket ticket) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RepairDetailPage(ticket: ticket)),
    );
    if (changed == true) await _load();
  }

  void _openAssets() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AssetPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: repairAppBar(
        title: 'แจ้งซ่อม',
        actions: [
          IconButton(
            tooltip: 'ถามบอทเรื่องสถานะซ่อม',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ChatPage())),
            icon: const Icon(Icons.forum_outlined),
          ),
          IconButton(
            tooltip: 'ทะเบียนเครื่อง',
            onPressed: _openAssets,
            icon: const Icon(Icons.devices_other),
          ),
          // ป้ายบอกสิทธิ์ ทีม IT จะได้รู้ว่าตัวเองเห็นปุ่มของ IT อยู่
          if (RoleService.I.isIt)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 14, left: 4),
                child: Text(
                  'IT',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        backgroundColor: AppColors.repairIcon,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('แจ้งซ่อม'),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_isLoading) return const LoadingStateView();

    final error = _error;
    if (error != null) return ErrorStateView(message: error, onRetry: _load);

    if (_tickets.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            EmptyStateView(
              icon: Icons.build_outlined,
              message: 'ยังไม่มีใบแจ้งซ่อม',
            ),
          ],
        ),
      );
    }

    final list = _filtered;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemCount: list.isEmpty ? 2 : list.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) return _filterBar();
          if (list.isEmpty) {
            return const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyStateView(
                icon: Icons.filter_alt_off_outlined,
                message: 'ไม่มีใบแจ้งซ่อมในสถานะนี้',
              ),
            );
          }
          final ticket = list[index - 1];
          return RepairTicketCard(
            ticket: ticket,
            onTap: () => _openDetail(ticket),
          );
        },
      ),
    );
  }

  Widget _filterBar() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: Text('ทั้งหมด ${_tickets.length}'),
          selected: _filter == null,
          onSelected: (_) => setState(() => _filter = null),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        for (final status in RepairStatus.values)
          if (_countOf(status) > 0) _statusChip(status),
      ],
    );
  }

  Widget _statusChip(RepairStatus status) {
    final scheme = Theme.of(context).colorScheme;
    final color = repairStatusColor(status, scheme);
    final selected = _filter == status;

    return ChoiceChip(
      label: Text(
        '${status.label} ${_countOf(status)}',
        style: TextStyle(color: selected ? color : scheme.onSurface),
      ),
      selected: selected,
      onSelected: (_) => setState(() => _filter = status),
      selectedColor: color.withValues(alpha: 0.16),
      side: BorderSide(color: selected ? color : scheme.outlineVariant),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
