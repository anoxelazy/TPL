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
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          _header(doc),
          _routeSection(doc),
          _linesSection(doc),
          _trackSection(doc),
        ],
      ),
    );
  }

  Widget _header(AssetTransferDoc doc) {
    final scheme = Theme.of(context).colorScheme;
    final item = doc.header;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TransferStatusChip(item),
              const SizedBox(width: 8),
              TransferOverdueTag(item.daysOverdue),
            ],
          ),
          const SizedBox(height: 10),
          if (item.reason.isNotEmpty)
            Text(
              item.reason,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
          const SizedBox(height: 4),
          Text(
            [
              if (item.transferDate != null) assetDateLabel(item.transferDate!),
              if (item.requestByName.isNotEmpty) 'ขอโดย ${item.requestByName}',
            ].join(' · '),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _routeSection(AssetTransferDoc doc) {
    final item = doc.header;

    return AssetSection(
      title: 'ต้นทาง → ปลายทาง',
      children: [
        TransferInfoLine(
          label: 'จากสาขา',
          value: _place(item.fromSiteName, item.fromSiteId),
        ),
        TransferInfoLine(label: 'จากแผนก', value: item.fromDeptName),
        TransferInfoLine(
          label: 'ไปสาขา',
          value: _place(item.toSiteName, item.toSiteId),
        ),
        TransferInfoLine(label: 'ไปแผนก', value: item.toDeptName),
        TransferInfoLine(
          label: 'ผู้รับปลายทาง',
          value: _place(item.toCustodianName, item.toCustodian),
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

  String? _place(String name, String code) {
    if (code.isEmpty && name.isEmpty) return null;
    if (name.isEmpty) return code;
    if (code.isEmpty) return name;
    return '$name ($code)';
  }

  Widget _linesSection(AssetTransferDoc doc) {
    final pending = doc.header.pendingCount;

    return AssetSection(
      title: 'ทรัพย์สินในใบ (${doc.lines.length})',
      note: pending > 0 ? 'ยังรอรับอีก $pending ชิ้น' : null,
      children: [for (final line in doc.lines) _lineRow(line)],
    );
  }

  Widget _lineRow(AssetTransferLine line) {
    final scheme = Theme.of(context).colorScheme;
    final tint = line.hasProblem
        ? AppColors.danger
        : (line.isReceived ? AppColors.success : scheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              line.isReceived
                  ? (line.hasProblem
                        ? Icons.error_outline
                        : Icons.check_circle_outline)
                  : Icons.radio_button_unchecked,
              size: 18,
              color: tint,
            ),
          ),
          const SizedBox(width: 10),
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

  /// ร่องรอยของแต่ละขั้น โชว์เฉพาะขั้นที่เกิดขึ้นแล้ว
  Widget _trackSection(AssetTransferDoc doc) {
    return AssetSection(
      title: 'การดำเนินการ',
      divider: false,
      children: [
        TransferInfoLine(
          label: 'สร้างใบ',
          value: _byAt(doc.createBy, '', doc.createAt),
        ),
        TransferInfoLine(
          label: 'อนุมัติ',
          value: _byAt(doc.approvedBy, doc.approvedByName, doc.approvedAt),
        ),
        TransferInfoLine(label: 'เหตุผลที่ตีกลับ', value: doc.rejectReason),
        TransferInfoLine(
          label: 'ส่งออก',
          value: _byAt(doc.dispatchBy, doc.dispatchByName, doc.dispatchAt),
        ),
        TransferInfoLine(label: 'ผู้ขนส่ง', value: doc.courierName),
        TransferInfoLine(label: 'เลขพัสดุ', value: doc.trackingNo),
        TransferInfoLine(
          label: 'รับครบ',
          value: doc.receiptAt == null
              ? null
              : assetDateTimeLabel(doc.receiptAt!),
        ),
        TransferInfoLine(label: 'หมายเหตุส่วนต่าง', value: doc.discrepancyNote),
        TransferInfoLine(label: 'เหตุผลที่ยกเลิก', value: doc.cancelReason),
      ],
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
