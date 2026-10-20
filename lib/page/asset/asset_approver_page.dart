/// ตั้งผู้อนุมัติของแต่ละแผนก
///
/// เป็นงานตั้งค่าไม่ใช่งานประจำวันของพนักงานสาขา คนที่เข้ามาคือคนที่ต้องไล่
/// เก็บให้ครบทุกแผนกก่อนเปิดใช้ flow อนุมัติการโอนย้าย หน้าจอจึงเรียงแผนกที่
/// ยังขาดขึ้นก่อนเสมอ แทนที่จะเรียงตามชื่อแล้วปล่อยให้เลื่อนหาเอง
///
/// ⚠️ ยังเข้าไม่ถึงทุกแผนก — `/deptlist` กับ `/approvers/summary` ตัดผลที่ 100
/// แถวก่อนกรอง หน้านี้เลยเอา `/approvers` มาเติมให้ได้มากที่สุด แต่แผนกที่
/// **ยังไม่มีผู้อนุมัติและไม่ติดมาในร้อยแถวแรก** จะมองไม่เห็นเลย รอ backend
/// แก้ (ดูหัวหมวดใน [asset_api.dart])
library;

import 'package:flutter/material.dart';

import 'package:claim/page/asset/asset_api.dart';
import 'package:claim/page/asset/asset_models.dart';
import 'package:claim/page/asset/asset_picker.dart';
import 'package:claim/page/asset/asset_style.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/mobile_api.dart';
import 'package:claim/widgets/state_views.dart';

class AssetApproverPage extends StatefulWidget {
  const AssetApproverPage({super.key});

  @override
  State<AssetApproverPage> createState() => _AssetApproverPageState();
}

class _AssetApproverPageState extends State<AssetApproverPage> {
  final _search = TextEditingController();

  List<AssetDeptApprovers> _board = const [];
  String _query = '';

  /// โชว์เฉพาะแผนกที่ยังไม่พร้อม
  ///
  /// กรองในเครื่องด้วย `is_ready` ไม่ใช้ `notReadyOnly` ของ API เพราะตัวนั้น
  /// กรองด้วย `has_backup` ไม่ตรงกับชื่อ
  bool _gapsOnly = false;

  bool _loading = true;
  String? _error;
  bool _needLogin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _needLogin = false;
    });

    try {
      final board = await loadApproverBoard();
      if (!mounted) return;
      setState(() {
        _board = board;
        _loading = false;
      });
    } on MobileApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _needLogin = e.needLogin;
        _loading = false;
      });
    }
  }

  List<AssetDeptApprovers> get _shown {
    final query = _query.trim().toLowerCase();
    final words = query.split(RegExp(r'\s+')).where((e) => e.isNotEmpty);

    return _board.where((dept) {
      if (_gapsOnly && dept.isReady) return false;
      return words.every(dept.searchIndex.contains);
    }).toList();
  }

  int get _notReadyCount => _board.where((e) => !e.isReady).length;

  Future<void> _openDept(AssetDeptApprovers dept) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _DeptSheet(dept: dept),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: assetAppBar(context, title: 'ผู้อนุมัติแต่ละแผนก'),
      body: _body(),
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

    final shown = _shown;

    return Column(
      children: [
        _header(),
        Expanded(
          child: shown.isEmpty
              ? const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: EmptyStateView(
                    message: 'ไม่พบแผนกที่ตรงกับที่ค้น',
                    icon: Icons.apartment_outlined,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => _deptRow(shown[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _header() {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'พิมพ์ชื่อแผนก รหัสแผนก หรือชื่อผู้อนุมัติ',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'ล้าง',
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _notReadyCount == 0
                      ? '${_board.length} แผนก ตั้งผู้อนุมัติครบแล้วทุกแผนก'
                      : '$_notReadyCount จาก ${_board.length} แผนก ยังอนุมัติไม่ได้',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _notReadyCount == 0
                        ? scheme.onSurfaceVariant
                        : AppColors.danger,
                  ),
                ),
              ),
              FilterChip(
                label: const Text('เฉพาะที่ยังขาด'),
                selected: _gapsOnly,
                onSelected: (on) => setState(() => _gapsOnly = on),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _deptRow(AssetDeptApprovers dept) {
    final scheme = Theme.of(context).colorScheme;
    final gap = dept.gapLabel;

    // ชื่อผู้อนุมัติที่ใช้ได้จริง เอาไว้ให้กวาดตาดูได้โดยไม่ต้องกดเข้าไป
    final working = dept.approvers
        .where((e) => e.isActive && e.isEffective)
        .map((e) => e.name.isEmpty ? e.id : e.name)
        .join(', ');

    return ListTile(
      onTap: () => _openDept(dept),
      title: Text(
        dept.deptName.isEmpty ? dept.deptCode : dept.deptName,
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
              dept.deptCode,
              if (dept.staffCount > 0) 'พนักงาน ${dept.staffCount} คน',
              if (working.isNotEmpty) working,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          if (gap.isNotEmpty) ...[
            const SizedBox(height: 4),
            AssetTag(gap, color: dept.isReady ? null : AppColors.danger),
          ],
        ],
      ),
      trailing: Icon(Icons.chevron_right, size: 18, color: scheme.outline),
    );
  }
}

/// จัดการผู้อนุมัติของแผนกเดียว คืน `true` เมื่อมีอะไรเปลี่ยนไป
class _DeptSheet extends StatefulWidget {
  final AssetDeptApprovers dept;

  const _DeptSheet({required this.dept});

  @override
  State<_DeptSheet> createState() => _DeptSheetState();
}

class _DeptSheetState extends State<_DeptSheet> {
  late List<AssetApprover> _rows = widget.dept.approvers;

  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();

    // `/summary` ส่งมาเฉพาะคนที่ใช้ได้ ดึงซ้ำด้วย includeInactive เพื่อให้เห็น
    // คนที่ถูกปิดไว้ด้วย ไม่งั้นปิดใครไปแล้วเขาจะหายจากลิสต์ แล้วไม่มีทาง
    // กดเปิดกลับได้อีกเลย
    _reload();
  }

  /// ดึงรายชื่อของแผนกนี้ใหม่หลังแก้ไข
  ///
  /// ดึงเฉพาะแผนกนี้ ไม่ดึงทั้งกระดาน เพราะแผ่นนี้เปิดค้างอยู่และคนกดกำลังรอดู
  /// ผลของสิ่งที่เพิ่งกด กระดานค่อยดึงใหม่ตอนปิดแผ่น
  Future<void> _reload() async {
    try {
      final rows = await fetchApproverRows(
        deptCode: widget.dept.deptCode,
        includeInactive: true,
      );
      if (!mounted) return;
      setState(() {
        _rows = rows..sort((a, b) => a.order.compareTo(b.order));
      });
    } on MobileApiException {
      // ดึงใหม่ไม่สำเร็จไม่ได้แปลว่าสิ่งที่เพิ่งบันทึกไปล้มเหลว ปล่อยรายการเดิม
      // ค้างไว้ แล้วให้กระดานข้างนอกดึงใหม่ตอนปิดแผ่น
    }
  }

  /// รันงานที่เขียนข้อมูล แล้วโชว์ข้อความที่เซิร์ฟเวอร์ตอบมา
  Future<void> _run(Future<String> Function() work) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final message = await work();
      if (!mounted) return;
      _changed = true;
      _toast(message);
      await _reload();
    } on MobileApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _add() async {
    final employee = await pickAssetEmployee(context);
    if (employee == null || !mounted) return;

    // ลำดับถัดจากที่มีอยู่ คนเพิ่มคนที่สองมักตั้งใจให้เป็นตัวสำรอง ไม่ใช่มาแทน
    // ตัวจริง เดาให้แล้วเขาเปลี่ยนทีหลังได้
    final used = _rows.map((e) => e.order).toSet();
    var next = kApproverOrderMin;
    while (used.contains(next) && next < kApproverOrderMax) {
      next++;
    }

    final order = await _askOrder(initial: next);
    if (order == null || !mounted) return;

    await _run(
      () => insertApprover(
        deptCode: widget.dept.deptCode,
        approverId: employee.id,
        order: order,
      ),
    );
  }

  /// เลือกลำดับการอนุมัติ 1–5 ตามที่ schema ยอมรับ คืน null เมื่อกดปิด
  ///
  /// ไม่กันลำดับที่ซ้ำกับคนอื่นในแผนก เพราะไม่รู้ว่าเซิร์ฟเวอร์ยอมหรือไม่ยอม
  /// กันไว้ฝั่งแอปแล้วเซิร์ฟเวอร์ยอมจริง จะกลายเป็นแอปห้ามในสิ่งที่ทำได้
  Future<int?> _askOrder({required int initial}) {
    return showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('ลำดับการอนุมัติ'),
        children: [
          for (
            var order = kApproverOrderMin;
            order <= kApproverOrderMax;
            order++
          )
            ListTile(
              onTap: () => Navigator.of(context).pop(order),
              selected: order == initial,
              title: Text(
                order == kApproverOrderMin
                    ? 'ลำดับ $order (ตัวจริง)'
                    : 'ลำดับ $order (สำรอง)',
              ),
              trailing: order == initial
                  ? const Icon(Icons.check, size: 20)
                  : null,
            ),
        ],
      ),
    );
  }

  Future<void> _changeOrder(AssetApprover approver) async {
    final order = await _askOrder(initial: approver.order);
    if (order == null || order == approver.order || !mounted) return;

    await _run(
      () => updateApprover(
        deptCode: widget.dept.deptCode,
        approverId: approver.id,
        order: order,
      ),
    );
  }

  Future<void> _toggleActive(AssetApprover approver) async {
    if (approver.isActive && !await _confirmDisable(approver)) return;
    if (!mounted) return;

    await _run(
      () => updateApprover(
        deptCode: widget.dept.deptCode,
        approverId: approver.id,
        isActive: !approver.isActive,
      ),
    );
  }

  /// ยืนยันก่อนปิดใช้งาน เปิดกลับไม่ต้องถาม
  ///
  /// ปิดผู้อนุมัติคนสุดท้ายที่ใช้ได้ = แผนกนั้นอนุมัติการโอนย้ายไม่ได้เลย
  /// คนกดควรรู้ก่อน ไม่ใช่มารู้ตอนมีคนโอนย้ายไม่ผ่าน
  Future<bool> _confirmDisable(AssetApprover approver) async {
    final working = _rows.where((e) => e.isActive && e.isEffective).length;
    if (working > 1) return true;

    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ปิดผู้อนุมัติคนสุดท้าย'),
        content: Text(
          '${approver.label} เป็นผู้อนุมัติคนเดียวที่ใช้ได้ของ '
          '${widget.dept.label}\n\n'
          'ปิดแล้วแผนกนี้จะอนุมัติการโอนย้ายไม่ได้จนกว่าจะตั้งคนใหม่',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('ปิดใช้งาน'),
          ),
        ],
      ),
    );
    return sure == true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: SizedBox(
        height: media.size.height * 0.8,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.dept.deptName.isEmpty
                              ? widget.dept.deptCode
                              : widget.dept.deptName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.dept.deptCode,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'ปิด',
                    onPressed: () => Navigator.of(context).pop(_changed),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _rows.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: EmptyStateView(
                        message:
                            'แผนกนี้ยังไม่มีผู้อนุมัติ\nการโอนย้ายของแผนกนี้จะยังอนุมัติไม่ได้',
                        icon: Icons.person_off_outlined,
                      ),
                    )
                  : ListView.separated(
                      itemCount: _rows.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) => _row(_rows[index]),
                    ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: FilledButton.icon(
                  onPressed: _busy ? null : _add,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('เพิ่มผู้อนุมัติ'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(AssetApprover approver) {
    final scheme = Theme.of(context).colorScheme;
    final problem = approver.problemLabel;

    return ListTile(
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: problem.isEmpty
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        child: Text(
          '${approver.order}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: problem.isEmpty
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      title: Text(
        approver.name.isEmpty ? approver.id : approver.name,
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
              approver.id,
              if (approver.position.isNotEmpty) approver.position,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          if (problem.isNotEmpty) ...[
            const SizedBox(height: 4),
            AssetTag(problem, color: AppColors.danger),
          ],
        ],
      ),
      trailing: PopupMenuButton<String>(
        enabled: !_busy,
        onSelected: (action) {
          switch (action) {
            case 'order':
              _changeOrder(approver);
            case 'active':
              _toggleActive(approver);
          }
        },
        // ไม่มีปุ่ม "ถอนออกจากแผนก" ทั้งที่มี `DELETE /approver/{dept}/{id}`
        // เพราะยิงของจริงดูแล้วเมื่อ 24 ก.ย. 2026 มันคือ soft delete — ตั้ง
        // `is_active = false` แถวยังอยู่ ผลลัพธ์เหมือน "ปิดใช้งาน" ทุกอย่าง
        // มีปุ่มสองปุ่มที่ทำเรื่องเดียวกันแต่ชื่อต่างกันคือหลอกคนกด
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'order', child: Text('เปลี่ยนลำดับ')),
          PopupMenuItem(
            value: 'active',
            child: Text(approver.isActive ? 'ปิดใช้งาน' : 'เปิดใช้งาน'),
          ),
        ],
      ),
    );
  }
}
