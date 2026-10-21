/// สร้างใบโอนย้ายทรัพย์สิน
///
/// ใบหนึ่งใบย้ายของได้หลายชิ้น ต่างจากหน้าโอนย้ายเดิมของแอปที่ทำทีละชิ้นผ่าน
/// `PUT /asset/{id}` — การย้ายของสิบชิ้นไปสาขาเดียวกันควรเป็นใบเดียวที่อนุมัติ
/// ครั้งเดียว ไม่ใช่สิบใบ
///
/// คืนเลขที่ใบที่สร้างสำเร็จตอนปิดหน้า หน้าที่เรียกจะได้พาไปเปิดใบนั้นต่อ
library;

import 'package:flutter/material.dart';

import 'package:claim/page/asset/asset_api.dart' show findAssetBranch;
import 'package:claim/page/asset/asset_models.dart';
import 'package:claim/page/asset/asset_picker.dart';
import 'package:claim/page/asset/asset_style.dart';
import 'package:claim/page/asset/transfer_api.dart';
import 'package:claim/page/asset/transfer_asset_picker.dart';
import 'package:claim/page/asset/transfer_models.dart';
import 'package:claim/page/asset/transfer_style.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/mobile_api.dart';

class TransferCreatePage extends StatefulWidget {
  /// ทรัพย์สินที่เลือกมาแล้วจากหน้าอื่น เช่นกดโอนย้ายจากหน้ารายละเอียดของชิ้นหนึ่ง
  final List<Asset> initialAssets;

  const TransferCreatePage({super.key, this.initialAssets = const []});

  @override
  State<TransferCreatePage> createState() => _TransferCreatePageState();
}

class _TransferCreatePageState extends State<TransferCreatePage> {
  final _formKey = GlobalKey<FormState>();

  final _reason = TextEditingController();
  final _crNo = TextEditingController();

  late List<Asset> _assets = [...widget.initialAssets];

  /// สาขาปลายทาง ตั้งอัตโนมัติจาก `branch_id` ของผู้รับที่เลือก ไม่มีช่องให้
  /// เลือกเอง — ของไปอยู่ที่ไหนก็ที่นั่นแหละที่ผู้รับนั่งทำงาน
  String _toSiteId = '';

  /// ชื่อสาขาไว้โชว์อย่างเดียว ไปหามาทีหลังจากลิสต์สาขา หาไม่เจอก็โชว์รหัส
  AssetBranch? _toBranch;

  String _toCustodian = '';
  AssetEmployee? _toEmployee;
  bool _resolvingCustodian = false;

  /// ส่งเข้าแผนกโดยไม่ระบุผู้รับ เช่นส่งเข้าคลัง
  ///
  /// cheat sheet ยอมให้ `to_custodian` ว่างได้ แล้วหัวหน้าแผนกปลายทางเป็นคนรับ
  /// โหมดนี้ไม่มีคนให้ดึงสาขากับแผนก จึงต้องเลือกสองอย่างนั้นเอง
  bool _noCustodian = false;

  /// แผนกปลายทาง ตั้งอัตโนมัติจากแผนกของผู้รับที่เลือก
  ///
  /// API บังคับ `to_dept_code` แต่คนกรอกคิดเป็น "ส่งไปให้ใครที่สาขาไหน" ไม่ได้
  /// คิดเป็นรหัสแผนก เลยเดาจากคนที่เขาเลือกแทนที่จะให้เลือกแผนกเองอีกช่อง
  ///
  /// ไม่ได้กำหนดว่าใครอนุมัติ — ผู้อนุมัติคือของแผนกผู้ขอ (ตาม cheat sheet)
  String _toDeptCode = '';
  String _toDeptName = '';

  DateTime? _expectedArrival;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // ค่าตั้งต้นที่ใช้ได้เกือบทุกครั้ง — ของภายในบริษัทมักถึงภายในสัปดาห์
    _expectedArrival = DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _reason.dispose();
    _crNo.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickCustodian() async {
    // ไม่กรองด้วยสิทธิ์ TRANSFER_RECEIVE — ตาม Workflow v2.0 ผู้รับโอนไม่ต้องมี
    // สิทธิ์นั้น ถูกระบุชื่อบนใบคืออำนาจในตัวเอง เคยกรองไว้แล้วพนักงานส่วนใหญ่
    // เลยเลือกเป็นผู้รับไม่ได้
    final employee = await pickAssetEmployee(
      context,
      currentId: _toCustodian,
      title: 'เลือกผู้รับปลายทาง',
    );
    if (employee == null) return;

    setState(() {
      _toCustodian = employee.id;
      _toEmployee = employee;
      _resolvingCustodian = false;

      // แผนกกับสาขาปลายทางมาจากคนรับ (`dept_code` / `branch_id` ของเส้น
      // `/employee`) ถ้าเขาไม่มีติดมาก็ปล่อยว่างให้ [_blocker] ฟ้อง
      _toDeptCode = employee.deptCode;
      _toDeptName = employee.deptName;
      _toSiteId = employee.branchId;
      _toBranch = null;
    });

    final branch = await findAssetBranch(employee.branchId);
    // เลือกคนใหม่ไปแล้วระหว่างรอ ชื่อสาขาที่ได้มาเป็นของคนเก่า ทิ้งไป
    if (!mounted || _toSiteId != employee.branchId) return;
    setState(() => _toBranch = branch);
  }

  void _clearCustodian() {
    setState(() {
      _toCustodian = '';
      _toEmployee = null;
      _toDeptCode = '';
      _toDeptName = '';
      _toSiteId = '';
      _toBranch = null;
    });
  }

  /// สลับโหมดแล้วล้างปลายทางทั้งหมด สาขา/แผนกที่ดึงมาจากคนเก่าไม่ควรค้างไป
  /// เป็นค่าของโหมดเลือกเอง โดยที่คนกรอกไม่ทันสังเกต
  void _setNoCustodian(bool value) {
    if (value == _noCustodian) return;
    _clearCustodian();
    setState(() => _noCustodian = value);
  }

  Future<void> _pickBranch() async {
    final branch = await pickAssetBranch(context, currentId: _toSiteId);
    if (branch == null) return;
    setState(() {
      _toSiteId = branch.id;
      _toBranch = branch;
    });
  }

  Future<void> _pickDept() async {
    final dept = await pickAssetDept(context, currentId: _toDeptCode);
    if (dept == null) return;
    setState(() {
      _toDeptCode = dept.code;
      _toDeptName = dept.name;
    });
  }

  Future<void> _pickAssets() async {
    final picked = await pickTransferAssets(context, selected: _assets);
    if (picked == null) return;
    setState(() => _assets = picked);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedArrival ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      helpText: 'วันที่คาดว่าของจะถึง',
    );
    if (picked == null) return;
    setState(() => _expectedArrival = picked);
  }

  /// ข้อความบอกว่าอะไรยังไม่ครบ คืน null เมื่อพร้อมบันทึก
  ///
  /// รวมไว้ที่เดียวเพราะสามในสี่ช่องบังคับไม่ใช่ `TextFormField` ตัว Form
  /// เลยตรวจให้ไม่ได้ทั้งหมด
  String? get _blocker {
    if (_assets.isEmpty) return 'เลือกทรัพย์สินที่จะย้ายอย่างน้อยหนึ่งชิ้น';
    if (_noCustodian) {
      if (_toSiteId.isEmpty) return 'เลือกสาขาปลายทาง';
      if (_toDeptCode.isEmpty) return 'เลือกแผนกปลายทาง';
      return transferArrivalError(_expectedArrival);
    }
    if (_toCustodian.isEmpty) {
      return 'เลือกผู้รับปลายทาง เพื่อให้ระบบรู้ว่าของไปสาขาและแผนกไหน';
    }
    if (_toDeptCode.isEmpty) return 'ผู้รับคนนี้ไม่มีแผนกในระบบ เลือกคนอื่น';
    if (_toSiteId.isEmpty) return 'ผู้รับคนนี้ไม่มีสาขาในระบบ เลือกคนอื่น';
    return transferArrivalError(_expectedArrival);
  }

  Future<void> _save() async {
    if (_saving) return;

    final blocker = _blocker;
    if (blocker != null) {
      _toast(blocker);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      final transferNo = await createTransfer(
        toDeptCode: _toDeptCode,
        toSiteId: _toSiteId,
        expectedArrival: _expectedArrival!,
        reason: _reason.text,
        assetIds: [for (final asset in _assets) asset.id],
        toCustodian: _toCustodian,
        crNo: _crNo.text,
      );
      if (!mounted) return;

      Navigator.of(context).pop(transferNo);
    } on MobileApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: assetAppBar(context, title: 'สร้างใบโอนย้าย'),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: AppSizes.pagePadding,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              _assetSection(),
              const SizedBox(height: AppSizes.gap),
              _toSection(),
              const SizedBox(height: AppSizes.gap),
              _reasonSection(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _assetSection() {
    final scheme = Theme.of(context).colorScheme;

    return TransferSection(
      title: 'ทรัพย์สินที่จะย้าย',
      trailing: _assets.isEmpty ? null : 'เลือกไว้ ${_assets.length} ชิ้น',
      children: [
        if (_assets.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppSizes.innerRadius),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 28,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 6),
                Text(
                  'ยังไม่ได้เลือกทรัพย์สิน',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          for (final asset in _assets) _assetRow(asset),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
          ),
          onPressed: _saving ? null : _pickAssets,
          icon: const Icon(Icons.add, size: 18),
          label: Text(_assets.isEmpty ? 'เลือกทรัพย์สิน' : 'แก้ไขรายการ'),
        ),
      ],
    );
  }

  Widget _assetRow(Asset asset) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSizes.innerRadius),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 18,
              color: AppColors.brandText,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.name.isEmpty ? asset.id : asset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  [
                    asset.id,
                    if (asset.statusLabel.isNotEmpty) asset.statusLabel,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'เอาออก',
            onPressed: _saving
                ? null
                : () => setState(() => _assets.remove(asset)),
            icon: const Icon(Icons.close, size: 18),
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  /// "ชื่อ (รหัส)" ถ้ายังไม่รู้ชื่อก็รหัสอย่างเดียว ว่างทั้งคู่ขึ้น "ไม่ระบุ"
  String _placeLabel(String name, String code) {
    if (code.isEmpty) return 'ไม่ระบุ';
    return name.isEmpty ? code : '$name ($code)';
  }

  Widget _toSection() {
    final scheme = Theme.of(context).colorScheme;

    return TransferSection(
      title: 'ปลายทาง',
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('ระบุผู้รับ'),
              icon: Icon(Icons.person_outline),
            ),
            ButtonSegment(
              value: true,
              label: Text('ไม่ระบุผู้รับ'),
              icon: Icon(Icons.warehouse_outlined),
            ),
          ],
          selected: {_noCustodian},
          showSelectedIcon: false,
          onSelectionChanged: _saving
              ? null
              : (selection) => _setNoCustodian(selection.first),
        ),
        const SizedBox(height: 14),
        if (_noCustodian)
          ..._noCustodianFields(scheme)
        else
          ..._custodianFields(scheme),
        const SizedBox(height: 14),
        _dateRow(),
      ],
    );
  }

  /// โหมดส่งเข้าแผนก เลือกสาขากับแผนกเอง หัวหน้าแผนกปลายทางเป็นคนรับ
  List<Widget> _noCustodianFields(ColorScheme scheme) => [
    AssetPickerField(
      label: 'สาขาปลายทาง',
      hint: 'แตะเพื่อเลือกสาขา',
      code: _toSiteId,
      name: _toBranch?.name ?? '',
      enabled: !_saving,
      icon: Icons.store_outlined,
      onTap: _pickBranch,
      onClear: _toSiteId.isEmpty
          ? null
          : () => setState(() {
              _toSiteId = '';
              _toBranch = null;
            }),
    ),
    const SizedBox(height: 12),
    AssetPickerField(
      label: 'แผนกปลายทาง',
      hint: 'แตะเพื่อเลือกแผนก',
      code: _toDeptCode,
      name: _toDeptName,
      enabled: !_saving,
      icon: Icons.groups_outlined,
      onTap: _pickDept,
      onClear: _toDeptCode.isEmpty
          ? null
          : () => setState(() {
              _toDeptCode = '';
              _toDeptName = '';
            }),
    ),
    Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        'หัวหน้าแผนกปลายทางจะเป็นคนรับของ',
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
    ),
  ];

  /// โหมดระบุผู้รับ สาขากับแผนกดึงจากคนที่เลือก
  List<Widget> _custodianFields(ColorScheme scheme) => [
    AssetPickerField(
      label: 'ผู้รับปลายทาง',
      hint: 'แตะเพื่อเลือกพนักงาน',
      code: _toCustodian,
      name: _toEmployee?.fullName ?? '',
      resolving: _resolvingCustodian,
      enabled: !_saving,
      icon: Icons.person_outline,
      onTap: _pickCustodian,
      onClear: _toCustodian.isEmpty ? null : _clearCustodian,
    ),
    // ไม่บอกว่าใครอนุมัติ — ผู้อนุมัติคือของแผนกผู้ขอ ไม่ใช่แผนกปลายทาง
    // เคยเขียนผิดว่าเป็นแผนกปลายทางจนคนเข้าใจผิด
    if (_toCustodian.isNotEmpty)
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: AppColors.brand.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSizes.innerRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TransferMeta(
              icon: Icons.store_outlined,
              text:
                  'สาขาปลายทาง ${_placeLabel(_toBranch?.name ?? '', _toSiteId)}',
            ),
            const SizedBox(height: 4),
            TransferMeta(
              icon: Icons.groups_outlined,
              text: 'แผนกปลายทาง ${_placeLabel(_toDeptName, _toDeptCode)}',
            ),
          ],
        ),
      ),
  ];

  Widget _dateRow() {
    final scheme = Theme.of(context).colorScheme;
    final date = _expectedArrival;

    return InkWell(
      onTap: _saving ? null : _pickDate,
      // ให้เงาตอนแตะโค้งเท่ากรอบช่องกรอกของธีม
      borderRadius: BorderRadius.circular(AppSizes.innerRadius),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'วันที่คาดว่าของจะถึง',
          suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          date == null ? 'แตะเพื่อเลือกวันที่' : assetDateLabel(date),
          style: TextStyle(
            fontSize: 14,
            color: date == null ? scheme.onSurfaceVariant : scheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _reasonSection() => TransferSection(
    title: 'เหตุผลและเอกสารอ้างอิง',
    note: 'เหตุผลจะไปอยู่ในใบให้ผู้อนุมัติอ่าน',
    children: [
      TextFormField(
        controller: _reason,
        enabled: !_saving,
        maxLength: kTransferReasonMax,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'เหตุผลที่ย้าย',
          hintText: 'เช่น ย้ายตามพนักงานที่เปลี่ยนสาขา',
          counterText: '',
        ),
        validator: (value) => transferReasonError(value ?? ''),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _crNo,
        enabled: !_saving,
        maxLength: kTransferCrNoMax,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'เลขที่ CR (ไม่บังคับ)',
          hintText: 'เช่น CR-2026-045',
          counterText: '',
        ),
      ),
    ],
  );

  Widget _bottomBar() {
    final scheme = Theme.of(context).colorScheme;
    final blocker = _blocker;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (blocker != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    blocker,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: _saving || blocker != null ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.description_outlined),
                label: Text(_saving ? 'กำลังสร้างใบ...' : 'สร้างใบโอนย้าย'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
