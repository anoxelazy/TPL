/// ใบโอนย้าย 1 ใบ พร้อมปุ่มของขั้นตอนที่กดได้ตอนนี้
///
/// **ปุ่มมาจาก `can_*` ที่เซิร์ฟเวอร์ส่งมา ไม่ใช่จากสถานะที่แอปตีความเอง**
/// กติกาว่าใครกดอะไรได้ตอนไหนขึ้นกับทั้งสถานะใบ สิทธิ์ของคนกด และสาขาที่เขา
/// สังกัด — เขียนซ้ำฝั่งแอปมีแต่จะไม่ตรงกัน และเวลา backend แก้กติกาแอปจะค้าง
/// อยู่กับกติกาเก่าโดยไม่มีใครรู้
///
/// คืน `true` ตอนปิดหน้าเมื่อมีอะไรเปลี่ยน หน้ารายการจะได้ดึงใหม่
library;

import 'package:flutter/material.dart';

import 'package:claim/page/asset/asset_models.dart';
import 'package:claim/page/asset/asset_style.dart';
import 'package:claim/page/asset/transfer_api.dart';
import 'package:claim/page/asset/transfer_models.dart';
import 'package:claim/page/asset/transfer_receive_sheet.dart';
import 'package:claim/page/asset/transfer_style.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/mobile_api.dart';
import 'package:claim/widgets/app_card.dart';
import 'package:claim/widgets/state_views.dart';

class TransferDetailPage extends StatefulWidget {
  final String transferNo;

  const TransferDetailPage({super.key, required this.transferNo});

  @override
  State<TransferDetailPage> createState() => _TransferDetailPageState();
}

class _TransferDetailPageState extends State<TransferDetailPage> {
  AssetTransferDoc? _doc;

  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _needLogin = false;

  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _needLogin = false;
    });

    try {
      final doc = await fetchTransfer(widget.transferNo);
      if (!mounted) return;

      setState(() {
        _doc = doc;
        _loading = false;
        _error = doc == null
            ? 'ไม่พบใบโอนย้ายเลขที่ ${widget.transferNo}'
            : null;
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

  /// รันขั้นตอนหนึ่งของใบแล้วดึงใบใหม่
  ///
  /// ดึงใหม่ทุกครั้งแม้จะรู้ผลอยู่แล้ว เพราะ `can_*` กับสถานะเปลี่ยนตามไปด้วย
  /// เดาเองว่าหลังอนุมัติจะกดอะไรได้ต่อคือการเขียนกติกาซ้ำฝั่งแอป
  Future<void> _run(Future<String> Function() work) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final message = await work();
      if (!mounted) return;

      _changed = true;
      _toast(message);
      await _load();
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

  Future<void> _submit() async {
    final sure = await _confirm(
      title: 'ส่งให้ผู้อนุมัติ',
      message:
          'ส่งใบนี้ให้ผู้อนุมัติของแผนกคุณใช่ไหม\n\n'
          'ส่งแล้วจะแก้รายการของในใบไม่ได้อีก',
      action: 'ส่งอนุมัติ',
    );
    if (!sure || !mounted) return;

    await _run(() => submitTransfer(widget.transferNo));
  }

  Future<void> _approve() async {
    final approved = await _confirm(
      title: 'อนุมัติใบโอนย้าย',
      message: 'อนุมัติให้ย้ายของตามใบนี้ใช่ไหม',
      action: 'อนุมัติ',
    );
    if (!approved || !mounted) return;

    await _run(() => approveTransfer(widget.transferNo, approve: true));
  }

  Future<void> _reject() async {
    final reason = await _askReason(
      title: 'ตีกลับใบโอนย้าย',
      hint: 'เช่น ปลายทางยังไม่พร้อมรับ',
      action: 'ตีกลับ',
      danger: true,
    );
    if (reason == null || !mounted) return;

    await _run(
      () => approveTransfer(widget.transferNo, approve: false, reason: reason),
    );
  }

  Future<void> _dispatch() async {
    final result = await showModalBottomSheet<_DispatchInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _DispatchSheet(),
    );
    if (result == null || !mounted) return;

    await _run(
      () => dispatchTransfer(
        widget.transferNo,
        courierName: result.courierName,
        trackingNo: result.trackingNo,
        conditionOut: result.conditionOut,
      ),
    );
  }

  Future<void> _receive() async {
    final doc = _doc;
    if (doc == null) return;

    final changed = await showTransferReceiveSheet(context, doc: doc);
    if (changed != true || !mounted) return;

    _changed = true;
    await _load();
  }

  Future<void> _cancel() async {
    final reason = await _askReason(
      title: 'ยกเลิกใบโอนย้าย',
      hint: 'เช่น ขอผิดใบ สร้างใหม่แล้ว',
      action: 'ยกเลิกใบ',
      danger: true,
      validate: transferCancelReasonError,
    );
    if (reason == null || !mounted) return;

    await _run(() => cancelTransfer(widget.transferNo, reason: reason));
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return answer == true;
  }

  /// ถามเหตุผล คืน null เมื่อกดยกเลิก
  ///
  /// บังคับกรอกเสมอแม้ schema จะไม่บังคับตอนตีกลับ — ตีกลับโดยไม่บอกเหตุผล
  /// ทำให้คนขอไม่รู้ว่าต้องแก้อะไร แล้วก็ส่งใบเดิมกลับมาใหม่
  Future<String?> _askReason({
    required String title,
    required String hint,
    required String action,
    bool danger = false,
    String? Function(String value) validate = transferReasonError,
  }) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: TextFormField(
            controller: controller,
            maxLines: 3,
            maxLength: kTransferReasonMax,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'เหตุผล',
              hintText: hint,
              counterText: '',
            ),
            validator: (value) => validate(value ?? ''),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ปิด'),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.of(context).pop(controller.text.trim());
            },
            style: danger
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            child: Text(action),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: assetAppBar(context, title: widget.transferNo),
        body: _body(doc),
        bottomNavigationBar: doc == null || !doc.hasActions
            ? null
            : _actionBar(doc),
      ),
    );
  }

  Widget _body(AssetTransferDoc? doc) {
    if (_loading) return const LoadingStateView();

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
    if (doc == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: AppSizes.pagePadding,
        children: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          _header(doc),
          const SizedBox(height: AppSizes.gap),
          _routeSection(doc),
          const SizedBox(height: AppSizes.gap),
          _linesSection(doc),
          const SizedBox(height: AppSizes.gap),
          _trackSection(doc),
        ],
      ),
    );
  }

  Widget _header(AssetTransferDoc doc) {
    final scheme = Theme.of(context).colorScheme;
    final item = doc.header;
    final tint = transferStatusColor(item.status, scheme);
    final at = item.transferDate;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.transferNo,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.brandText,
            ),
          ),
          const SizedBox(height: 8),

          // สถานะเป็นแถบเต็มความกว้างแบบหัวหน้ารายละเอียดเคส IT หน้านี้เปิดมา
          // เพื่อดูว่าใบอยู่ขั้นไหน ไม่ต้องประหยัดที่
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSizes.innerRadius),
              border: Border.all(color: tint),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.statusText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: tint,
                    ),
                  ),
                ),
                TransferOverdueTag(item.daysOverdue),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TransferStepper(status: item.status),
          if (item.reason.isNotEmpty) ...[
            const SizedBox(height: 14),
            _reasonBlock(item.reason, scheme),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (at != null)
                TransferMeta(icon: Icons.schedule, text: assetDateLabel(at)),
              if (item.requestByName.isNotEmpty)
                TransferMeta(
                  icon: Icons.person_outline,
                  text: 'ขอโดย ${item.requestByName}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// เหตุผลของใบคือเนื้อเรื่องจริง ๆ ของใบ จึงเด่นกว่าข้อมูลประกอบ
  /// ด้วยแถบสีซ้ายแบบช่องรายละเอียดของเคส IT
  Widget _reasonBlock(String reason, ColorScheme scheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.innerRadius),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: AppColors.brand),
            Expanded(
              child: Container(
                color: AppColors.brand.withValues(alpha: 0.07),
                padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                child: Text(
                  reason,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _routeSection(AssetTransferDoc doc) {
    final item = doc.header;

    return TransferSection(
      title: 'ต้นทาง → ปลายทาง',
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _placeBox(
                  label: 'ต้นทาง',
                  site: transferPlaceText(item.fromSiteName, item.fromSiteId),
                  dept: item.fromDeptName,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Center(
                  child: Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: _placeBox(
                  label: 'ปลายทาง',
                  site: transferPlaceText(item.toSiteName, item.toSiteId),
                  dept: item.toDeptName,
                  highlight: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TransferInfoLine(
          label: 'ผู้รับปลายทาง',
          value: transferPlaceText(item.toCustodianName, item.toCustodian),
        ),
        TransferInfoLine(
          label: 'กำหนดถึง',
          value: item.expectedArrival == null
              ? null
              : assetDateLabel(item.expectedArrival!),
        ),
        TransferInfoLine(label: 'เลขที่ CR', value: doc.crNo),
      ],
    );
  }

  /// กล่องสาขาและแผนกฝั่งหนึ่ง ฝั่งปลายทางพื้นเขียวอ่อนเพราะเป็นที่ที่ของจะไป
  Widget _placeBox({
    required String label,
    required String? site,
    required String dept,
    bool highlight = false,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.brand.withValues(alpha: 0.12)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSizes.innerRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: highlight ? AppColors.brandText : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            site ?? '-',
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (dept.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              dept,
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _linesSection(AssetTransferDoc doc) {
    final pending = doc.header.pendingCount;
    final scheme = Theme.of(context).colorScheme;

    return TransferSection(
      title: 'ทรัพย์สินในใบ (${doc.lines.length})',
      trailing: pending > 0 ? 'ยังรอรับอีก $pending ชิ้น' : null,
      children: [
        for (var i = 0; i < doc.lines.length; i++) ...[
          if (i > 0) Divider(height: 16, color: scheme.outlineVariant),
          _lineRow(doc.lines[i]),
        ],
      ],
    );
  }

  Widget _lineRow(AssetTransferLine line) {
    final scheme = Theme.of(context).colorScheme;
    final tint = line.hasProblem
        ? AppColors.danger
        : (line.isReceived ? AppColors.success : scheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSizes.innerRadius),
            ),
            child: Icon(
              line.isReceived
                  ? (line.hasProblem
                        ? Icons.error_outline
                        : Icons.check_circle_outline)
                  : Icons.inventory_2_outlined,
              size: 18,
              color: tint,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    line.assetId,
                    if (line.serialNo.isNotEmpty) 'S/N ${line.serialNo}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (line.isReceived) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      line.outcomeText,
                      if (line.receiptByName.isNotEmpty)
                        'โดย ${line.receiptByName}',
                      if (line.receivedOnBehalf) 'รับแทน',
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tint,
                    ),
                  ),
                  if (line.note.isNotEmpty)
                    Text(
                      line.note,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ร่องรอยของแต่ละขั้นเป็นไทม์ไลน์ โชว์เฉพาะขั้นที่เกิดขึ้นแล้ว
  Widget _trackSection(AssetTransferDoc doc) {
    String? label(String prefix, String value) =>
        value.isEmpty ? null : '$prefix $value';

    final events = [
      TransferEvent(
        icon: Icons.description_outlined,
        title: 'สร้างใบ',
        detail: _byAt(doc.createBy, '', doc.createAt) ?? '',
      ),
      // ตีกลับแล้วใบกลับเป็นร่าง ไม่มีสถานะของตัวเอง เหลือแค่เหตุผลไว้ให้เห็น
      if (doc.rejectReason.isNotEmpty)
        TransferEvent(
          icon: Icons.undo,
          title: 'ถูกตีกลับ',
          extras: [doc.rejectReason],
          color: AppColors.dangerText,
        ),
      if (doc.approvedAt != null || doc.approvedBy.isNotEmpty)
        TransferEvent(
          icon: Icons.verified_outlined,
          title: 'อนุมัติแล้ว',
          detail:
              _byAt(doc.approvedBy, doc.approvedByName, doc.approvedAt) ?? '',
        ),
      if (doc.dispatchAt != null || doc.dispatchBy.isNotEmpty)
        TransferEvent(
          icon: Icons.local_shipping_outlined,
          title: 'ส่งออกแล้ว',
          detail:
              _byAt(doc.dispatchBy, doc.dispatchByName, doc.dispatchAt) ?? '',
          extras: [
            ?label('ผู้ขนส่ง', doc.courierName),
            ?label('เลขพัสดุ', doc.trackingNo),
          ],
        ),
      if (doc.receiptAt != null)
        TransferEvent(
          icon: Icons.inventory_2_outlined,
          title: 'รับครบแล้ว',
          detail: assetDateTimeLabel(doc.receiptAt!),
          extras: [?label('หมายเหตุส่วนต่าง', doc.discrepancyNote)],
          color: doc.discrepancyNote.isEmpty ? null : AppColors.dangerText,
        ),
      if (doc.cancelReason.isNotEmpty)
        TransferEvent(
          icon: Icons.block,
          title: 'ยกเลิกใบ',
          extras: [doc.cancelReason],
          color: AppColors.dangerText,
        ),
    ];

    return TransferSection(
      title: 'การดำเนินการ',
      children: [TransferTimeline(events: events)],
    );
  }

  String? _byAt(String code, String name, DateTime? at) {
    if (code.isEmpty && at == null) return null;

    final who = name.isEmpty ? code : '$name ($code)';
    if (at == null) return who;
    if (who.isEmpty) return assetDateTimeLabel(at);
    return '$who · ${assetDateTimeLabel(at)}';
  }

  Widget _actionBar(AssetTransferDoc doc) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              if (doc.canCancel)
                TextButton(
                  onPressed: _busy ? null : _cancel,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  child: const Text('ยกเลิกใบ'),
                ),
              if (doc.canApprove) ...[
                TextButton(
                  onPressed: _busy ? null : _reject,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  child: const Text('ตีกลับ'),
                ),
              ],
              const Spacer(),
              _primaryAction(doc),
            ],
          ),
        ),
      ),
    );
  }

  /// ปุ่มหลักของขั้นตอนนี้ มีได้ทีละปุ่มเดียวเพราะใบอยู่ในขั้นเดียว ณ เวลาหนึ่ง
  Widget _primaryAction(AssetTransferDoc doc) {
    final (label, icon, onTap) = switch (doc) {
      _ when doc.canSubmit => ('ส่งอนุมัติ', Icons.send_outlined, _submit),
      _ when doc.canApprove => ('อนุมัติ', Icons.check, _approve),
      _ when doc.canDispatch => (
        'บันทึกส่งออก',
        Icons.local_shipping_outlined,
        _dispatch,
      ),
      _ when doc.canReceive => ('รับของ', Icons.inventory_2_outlined, _receive),
      _ => ('', Icons.check, null),
    };

    if (onTap == null) return const SizedBox.shrink();

    return FilledButton.icon(
      onPressed: _busy ? null : onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

/// ค่าที่กรอกในแผ่นบันทึกการส่งออก
class _DispatchInput {
  final String courierName;
  final String trackingNo;
  final String conditionOut;

  const _DispatchInput(this.courierName, this.trackingNo, this.conditionOut);
}

/// บันทึกการส่งของออกจากต้นทาง — ไม่บังคับสักช่องตาม schema
class _DispatchSheet extends StatefulWidget {
  const _DispatchSheet();

  @override
  State<_DispatchSheet> createState() => _DispatchSheetState();
}

class _DispatchSheetState extends State<_DispatchSheet> {
  final _courier = TextEditingController();
  final _tracking = TextEditingController();
  final _condition = TextEditingController(text: kTransferConditionGood);

  @override
  void dispose() {
    _courier.dispose();
    _tracking.dispose();
    _condition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'บันทึกการส่งออก',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'กรอกเท่าที่มี ไม่กรอกเลยก็บันทึกได้',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _courier,
                maxLength: kTransferCourierMax,
                decoration: const InputDecoration(
                  labelText: 'ผู้ขนส่ง',
                  hintText: 'เช่น ขนส่งภายใน, Kerry',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _tracking,
                maxLength: kTransferTrackingMax,
                decoration: const InputDecoration(
                  labelText: 'เลขพัสดุ',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _condition,
                maxLength: kTransferConditionMax,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'สภาพตอนส่ง',
                  hintText: 'เช่น GOOD',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('ยกเลิก'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(
                      _DispatchInput(
                        _courier.text,
                        _tracking.text,
                        _condition.text,
                      ),
                    ),
                    icon: const Icon(Icons.local_shipping_outlined, size: 18),
                    label: const Text('บันทึกส่งออก'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
