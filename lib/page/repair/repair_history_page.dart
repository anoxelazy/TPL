import 'package:flutter/material.dart';

import 'package:claim/page/repair/repair_appbar.dart';

import 'package:claim/page/repair/repair_api.dart';
import 'package:claim/page/repair/repair_card.dart';
import 'package:claim/page/repair/repair_detail_page.dart';
import 'package:claim/widgets/state_views.dart';

/// ประวัติการซ่อมของเครื่องเดียว กรองด้วย S/N ที่ฝั่งเซิร์ฟเวอร์
class RepairHistoryPage extends StatefulWidget {
  final String sn;
  final String deviceName;

  const RepairHistoryPage({
    super.key,
    required this.sn,
    required this.deviceName,
  });

  @override
  State<RepairHistoryPage> createState() => _RepairHistoryPageState();
}

class _RepairHistoryPageState extends State<RepairHistoryPage> {
  List<RepairTicket> _tickets = [];
  bool _isLoading = true;
  String? _error;

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
      final tickets = await fetchRepairs(sn: widget.sn);
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
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

  Future<void> _open(RepairTicket ticket) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RepairDetailPage(ticket: ticket)),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: repairAppBar(
        title: 'ประวัติการซ่อม',
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                widget.deviceName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color:
                      Theme.of(
                        context,
                      ).appBarTheme.foregroundColor?.withValues(alpha: 0.92) ??
                      Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
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
              icon: Icons.history,
              message: 'เครื่องนี้ยังไม่เคยแจ้งซ่อม',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _tickets.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => RepairTicketCard(
          ticket: _tickets[index],
          onTap: () => _open(_tickets[index]),
        ),
      ),
    );
  }
}
