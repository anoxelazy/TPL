/// รายการใบโอนย้ายทรัพย์สิน
///
/// สามมุมมองในหน้าเดียว เพราะมาจากคนละ endpoint แต่เป็นคำถามเดียวกันว่า
/// "ตอนนี้มีใบอะไรที่ฉันต้องสนใจ"
///
/// - **รอฉันทำ** `/transfers/pending` เซิร์ฟเวอร์คัดตามสิทธิ์ของคนเรียกให้แล้ว
/// - **ทั้งหมด** `/transfers` ค้นและกรองเองได้ แบ่งหน้า
/// - **ของค้างทาง** `/transfers/aging` ส่งไปแล้วเกินกำหนดแต่ไม่มีใครรับ
///
/// มุมมองแรกเป็นค่าตั้งต้น เพราะคนเปิดหน้านี้ส่วนใหญ่มาเพราะมีอะไรรอให้กด
library;

import 'package:flutter/material.dart';

import 'package:claim/page/asset/asset_list_page.dart';
import 'package:claim/page/asset/asset_models.dart';
import 'package:claim/page/asset/asset_style.dart';
import 'package:claim/page/asset/transfer_api.dart';
import 'package:claim/page/asset/transfer_create_page.dart';
import 'package:claim/page/asset/transfer_detail_page.dart';
import 'package:claim/page/asset/transfer_models.dart';
import 'package:claim/page/asset/transfer_style.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/mobile_api.dart';
import 'package:claim/widgets/state_views.dart';

enum _View { pending, all, aging }

class TransferListPage extends StatefulWidget {
  const TransferListPage({super.key});

  @override
  State<TransferListPage> createState() => _TransferListPageState();
}

class _TransferListPageState extends State<TransferListPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  _View _view = _View.pending;

  AssetTransferQuery _query = const AssetTransferQuery();

  List<AssetTransferItem> _items = const [];
  List<AssetTransitAging> _aging = const [];
  int _total = 0;
  bool _hasMore = false;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  bool _needLogin = false;

  /// มีสิทธิ์ `TRANSFER_CREATE` ไหม ตั้งต้นเป็น true จนกว่า `/me` จะบอกว่าไม่มี
  bool _canCreate = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
    _loadPermission();
  }

  Future<void> _loadPermission() async {
    final allowed = await canCreateTransfer();
    if (!mounted || allowed == _canCreate) return;
    setState(() => _canCreate = allowed);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_view != _View.all || !_hasMore || _loadingMore || _loading) return;
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) _loadMore();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _needLogin = false;
    });

    try {
      switch (_view) {
        case _View.pending:
          final rows = await fetchPendingTransfers();
          if (!mounted) return;
          setState(() {
            _items = rows;
            _total = rows.length;
            _hasMore = false;
          });
        case _View.all:
          final result = await fetchTransfers(_query.copyWith(page: 1));
          if (!mounted) return;
          setState(() {
            _items = result.items;
            _total = result.total;
            _hasMore = result.hasMore;
            _query = _query.copyWith(page: 1);
          });
        case _View.aging:
          final rows = await fetchTransitAging();
          if (!mounted) return;
          setState(() {
            _aging = rows;
            _total = rows.length;
            _hasMore = false;
          });
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } on MobileApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _needLogin = e.needLogin;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);

    try {
      final next = _query.copyWith(page: _query.page + 1);
      final result = await fetchTransfers(next);
      if (!mounted) return;

      setState(() {
        _items = [..._items, ...result.items];
        _hasMore = result.hasMore;
        _query = next;
        _loadingMore = false;
      });
    } on MobileApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      _toast(e.message);
    }
  }

  void _switchTo(_View view) {
    if (_view == view) return;
    setState(() {
      _view = view;
      _items = const [];
      _aging = const [];
      _total = 0;
      _hasMore = false;
    });
    _load();
  }

  void _applyFilter(AssetTransferQuery query) {
    setState(() => _query = query);
    _load();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openDoc(String transferNo) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TransferDetailPage(transferNo: transferNo),
      ),
    );
    if (changed == true) await _load();
  }

  /// กลับมาแล้วดึงใหม่ เขาอาจเพิ่งเพิ่มของที่กำลังจะเอามาใส่ใบ
  Future<void> _openRegistry() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AssetListPage()));
    if (!mounted) return;
    await _load();
  }

  Future<void> _create() async {
    final transferNo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const TransferCreatePage()),
    );
    if (transferNo == null || !mounted) return;

    // พาไปเปิดใบที่เพิ่งสร้างเลย คนสร้างเสร็จมักต้องกดส่งอนุมัติต่อทันที
    await _openDoc(transferNo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: assetAppBar(
        context,
        title: 'ใบโอนย้าย',
        actions: [
          if (_canCreate)
            IconButton(
              tooltip: 'สร้างใบโอนย้าย',
              onPressed: _create,
              icon: const Icon(Icons.add),
            ),
          // ทางลัดข้ามไปทะเบียน เพราะปุ่ม + ของหน้านี้สร้าง "ใบ" ไม่ใช่ "ของ"
          // คนที่ตั้งใจมาเพิ่มทรัพย์สินชิ้นใหม่แล้วมาโผล่ที่นี่จะได้ไม่ต้อง
          // ย้อนกลับไปหน้าแรกเพื่อหาเมนูที่ถูก
          PopupMenuButton<String>(
            tooltip: 'เมนูเพิ่มเติม',
            onSelected: (value) {
              if (value == 'registry') _openRegistry();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'registry',
                child: Text('ทะเบียนทรัพย์สิน (เพิ่ม/ค้นของ)'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _viewPicker(),
          if (_view == _View.all) _searchBar(),
          if (_view == _View.all) _filterBar(),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _viewPicker() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: SegmentedButton<_View>(
        segments: const [
          ButtonSegment(value: _View.pending, label: Text('รอฉันทำ')),
          ButtonSegment(value: _View.all, label: Text('ทั้งหมด')),
          ButtonSegment(value: _View.aging, label: Text('ค้างทาง')),
        ],
        selected: {_view},
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 13)),
        ),
        onSelectionChanged: (values) => _switchTo(values.first),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (value) =>
            _applyFilter(_query.copyWith(keyword: value.trim())),
        decoration: InputDecoration(
          hintText: 'เลขที่ใบ รหัสทรัพย์สิน หรือชื่อคนขอ',
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          suffixIcon: _query.keyword.isEmpty && _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'ล้าง',
                  onPressed: () {
                    _searchController.clear();
                    _applyFilter(_query.copyWith(keyword: ''));
                  },
                  icon: const Icon(Icons.clear),
                ),
        ),
      ),
    );
  }

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('ยังไม่ปิด'),
            selected: _query.openOnly,
            onSelected: (on) => _applyFilter(_query.copyWith(openOnly: on)),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('เลยกำหนด'),
            selected: _query.overdueOnly,
            onSelected: (on) => _applyFilter(_query.copyWith(overdueOnly: on)),
          ),
          const Spacer(),
          if (!_loading)
            Text(
              '$_total ใบ',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const ListLoadingView();

    final error = _error;
    if (error != null) {
      return _needLogin
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(error, textAlign: TextAlign.center),
              ),
            )
          : ErrorStateView(message: error, onRetry: _load);
    }

    if (_view == _View.aging) return _agingList();

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 64),
            EmptyStateView(
              message: switch (_view) {
                _View.pending => 'ไม่มีใบที่รอคุณดำเนินการ',
                _View.all => _query.hasFilter
                    ? 'ไม่พบใบที่ตรงกับที่ค้น'
                    : 'ยังไม่มีใบโอนย้ายในระบบ',
                _View.aging => '',
              },
              icon: Icons.inbox_outlined,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scrollController,
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _row(_items[index]);
        },
      ),
    );
  }

  Widget _row(AssetTransferItem item) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => _openDoc(item.transferNo),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.transferNo,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TransferStatusChip(item),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18, color: scheme.outline),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.routeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
            if (item.reason.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                item.reason,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _metaOf(item),
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                TransferOverdueTag(item.daysOverdue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _metaOf(AssetTransferItem item) {
    final at = item.transferDate;

    return [
      if (at != null) assetDateLabel(at),
      if (item.lineCount > 0)
        item.pendingCount > 0
            ? 'ของ ${item.lineCount} ชิ้น · รอรับ ${item.pendingCount}'
            : 'ของ ${item.lineCount} ชิ้น',
      if (item.requestByName.isNotEmpty) 'ขอโดย ${item.requestByName}',
    ].join(' · ');
  }

  Widget _agingList() {
    if (_aging.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 64),
            EmptyStateView(
              message: 'ไม่มีของค้างทาง ทุกใบที่ส่งออกถูกรับตามกำหนดหมดแล้ว',
              icon: Icons.local_shipping_outlined,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _aging.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) => _agingRow(_aging[index]),
      ),
    );
  }

  Widget _agingRow(AssetTransitAging row) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: () => _openDoc(row.transferNo),
      title: Text(
        row.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            [
              row.transferNo,
              if (row.toSiteName.isNotEmpty)
                'ปลายทาง ${row.toSiteName}'
              else if (row.toSiteId.isNotEmpty)
                'ปลายทาง ${row.toSiteId}',
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              TransferOverdueTag(row.daysOverdue),
              if (row.actionRequired.isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    row.actionRequired,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: Icon(Icons.chevron_right, size: 18, color: scheme.outline),
    );
  }
}
