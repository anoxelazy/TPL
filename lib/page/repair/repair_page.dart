import 'package:flutter/material.dart';

import 'package:claim/page/repair/repair_appbar.dart';
import 'package:claim/utils/app_colors.dart';

import 'package:claim/page/chat/chat_page.dart';
import 'package:claim/page/chat/line_invite_bar.dart';
import 'package:claim/page/repair/asset_page.dart';
import 'package:claim/page/repair/repair_api.dart';
import 'package:claim/page/repair/repair_card.dart';
import 'package:claim/page/repair/repair_list_header.dart';
import 'package:claim/page/repair/repair_detail_page.dart';
import 'package:claim/page/repair/repair_form_page.dart';
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

  /// ถามบอทเป็นแผ่นเลื่อนขึ้นมา ไม่ใช่หน้าใหม่ รายการใบยังอยู่ข้างหลัง
  void _openChat() => showChatSheet(context);

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
          // ป้ายบอกสิทธิ์ ทีม IT จะได้รู้ว่าตัวเองเห็นปุ่มของ IT อยู่
          //
          // เดิมเป็นตัวหนังสือลอยต่อท้ายไอคอน อ่านแล้วเหมือนปุ่มที่กดไม่ติด
          // ใส่กรอบให้มันดูเป็นป้ายบอกสถานะ ไม่ใช่ของที่กดได้
          if (RoleService.I.isIt) const _RoleBadge(label: 'IT'),
        ],
      ),
      // ปุ่มลอยสองชั้น ถามบอทอยู่เหนือแจ้งซ่อม
      //
      // แจ้งซ่อมเป็นงานหลักของหน้า จึงเป็นปุ่มทึบสีแบรนด์และอยู่ล่างสุดที่นิ้ว
      // โป้งถึงก่อน ส่วนถามบอทเป็นของรอง ใช้พื้นขาวขอบบางให้เบากว่ากันชัด ๆ
      // ไม่ใช่ปุ่มทึบสองอันแย่งกันเด่น
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _chatButton(),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'repair-new',
            onPressed: _openForm,
            icon: const Icon(Icons.add),
            label: const Text('แจ้งซ่อม'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ชวนแอด LINE เฉพาะคนที่ยังไม่ได้ผูกบัญชี ผูกแล้วไม่กินที่เลย
          const LineInviteBar(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  /// ปุ่มถามบอท เตี้ยกว่าปุ่มลอยมาตรฐาน
  ///
  /// ไม่ได้ใช้ FloatingActionButton เพราะมันบังคับความสูงขั้นต่ำ 48 จุด
  /// เท่ากับปุ่มแจ้งซ่อมพอดี สองปุ่มขนาดเท่ากันวางซ้อนกันแล้วดูเป็นของคู่กัน
  /// ทั้งที่อันหนึ่งเป็นงานหลักอีกอันเป็นของรอง
  Widget _chatButton() {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppSizes.pillRadius);

    return Material(
      color: scheme.surface,
      borderRadius: radius,
      elevation: 2,
      child: InkWell(
        onTap: _openChat,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.forum_outlined,
                size: 16,
                color: AppColors.brandText,
              ),
              const SizedBox(width: 6),
              const Text(
                'ถามบอท',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pick(RepairStatus? status) => setState(() => _filter = status);

  Widget _body() {
    if (_isLoading) return const ListLoadingView();

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
      child: CustomScrollView(
        // ใบน้อยกว่าหนึ่งจอก็ต้องยังดึงลงโหลดใหม่ได้
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RepairStatGrid(
                    tickets: _tickets,
                    filter: _filter,
                    onPick: _pick,
                  ),
                  const SizedBox(height: AppSizes.gap),
                  RepairShortcuts(onAssets: _openAssets),
                  const SizedBox(height: 22),
                  // ตัวกรองมีที่เดียวคือการ์ดสรุปข้างบน เคยมีแถบแท็บซ้ำอีกชุด
                  // ตรงนี้ด้วย ซึ่งเป็นของชิ้นเดียวกันสองหน้าตาในจอเดียว
                  const RepairListHeading(),
                ],
              ),
            ),
          ),
          if (list.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 48),
                child: EmptyStateView(
                  icon: Icons.filter_alt_off_outlined,
                  message: 'ไม่มีใบแจ้งซ่อมในสถานะนี้',
                ),
              ),
            )
          else
            SliverPadding(
              // ล่างสุดต้องพ้นปุ่มลอยสองชั้น ไม่งั้นใบสุดท้ายโดนทับ
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 150),
              sliver: SliverList.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => RepairTicketCard(
                  ticket: list[index],
                  onTap: () => _openDetail(list[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ป้ายบอกสิทธิ์บนแถบหัวเรื่อง
///
/// แถบหัวเรื่องเป็นสีพื้นหน้า จึงเป็นกรอบเขียวโปร่ง ไม่ใส่พื้นทึบ
/// ถ้าทึบมันจะเด่นกว่าปุ่มจริง ๆ ข้าง ๆ ทั้งที่กดไม่ได้
///
/// โหมดมืดใช้ primary ของธีมแทน เพราะเขียวเข้มของ [AppColors.brandText]
/// จมไปกับพื้นมืดจนอ่านไม่ออก
class _RoleBadge extends StatelessWidget {
  final String label;

  const _RoleBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.brightness == Brightness.dark
        ? theme.colorScheme.primary
        : AppColors.brandText;

    return Center(
      child: Container(
        margin: const EdgeInsets.only(left: 2, right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.pillRadius),
          border: Border.all(color: color.withValues(alpha: 0.7)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
