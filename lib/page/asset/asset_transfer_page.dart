import 'package:flutter/material.dart';

import 'package:claim/page/asset/asset_api.dart';
import 'package:claim/page/asset/asset_models.dart';
import 'package:claim/page/asset/asset_picker.dart';
import 'package:claim/page/asset/asset_style.dart';
import 'package:claim/utils/mobile_api.dart';

/// แก้แผนกหรือผู้ครอบครองของทรัพย์สินให้ถูกต้อง **โดยไม่สร้างใบโอนย้าย**
///
/// ⚠️ นี่ไม่ใช่หน้าโอนย้าย — การย้ายของจริงต้องเป็นใบที่มีคนอนุมัติ อยู่ที่
/// [TransferCreatePage] หน้านี้คือการ `PUT` เปลี่ยน `current_site_id` /
/// `current_custodian` ตรง ๆ ซึ่ง Spec v3.0 กำกับไว้ว่าเป็น "การแก้ข้อมูลให้
/// ถูกต้อง" เท่านั้น
///
/// ใช้ตอนข้อมูลผิดมาแต่แรก เช่นลงทะเบียนผิดแผนกไว้ตั้งแต่ต้น — ของที่ไม่เคย
/// ขยับจริงไม่ควรมีใบโอนย้าย เพราะใบจะไปโผล่ในรายงานว่ามีการเคลื่อนย้าย
///
/// เดิมหน้านี้ชื่อ "โอนย้ายทรัพย์สิน" และเป็นทางเดียวที่ย้ายของได้ เพราะตอนนั้น
/// backend ยังไม่มี API ใบโอนย้าย พอมีแล้วชื่อเดิมกลายเป็นคำโกหก
///
/// `change_note` ยังบังคับกรอกเหมือนเดิม เหตุผลจะไปโผล่ใน `/log`
///
/// ทั้งสองช่องเลือกจากรายการจริง ([pickAssetDept] / [pickAssetEmployee]) ไม่ใช่
/// พิมพ์รหัสเอง เพราะฝั่งเซิร์ฟเวอร์เช็คแค่ความยาว ไม่ได้เช็คว่ารหัสมีจริง
/// พิมพ์ผิดหนึ่งตัวคือของไปอยู่แผนกที่ไม่มีอยู่โดยไม่มีอะไรฟ้อง
///
/// คืน `true` เมื่อโอนย้ายสำเร็จ
class AssetTransferPage extends StatefulWidget {
  final Asset asset;

  const AssetTransferPage({super.key, required this.asset});

  @override
  State<AssetTransferPage> createState() => _AssetTransferPageState();
}

class _AssetTransferPageState extends State<AssetTransferPage> {
  final _formKey = GlobalKey<FormState>();

  final _refNo = TextEditingController();
  final _changeNote = TextEditingController();

  /// ปลายทางที่เลือกไว้ เริ่มจากที่อยู่เดิมของทรัพย์สิน
  late String _siteId = widget.asset.siteId;
  late String _custodian = widget.asset.custodian;

  /// ชื่อของรหัสสองตัวข้างบน มีไว้ยืนยันว่าหยิบถูกตัว ไม่ได้ส่งไปกับคำขอ
  AssetDept? _dept;
  AssetEmployee? _employee;

  late bool _resolvingSite = widget.asset.siteId.isNotEmpty;
  late bool _resolvingCustodian = widget.asset.custodian.isNotEmpty;

  /// หาชื่อไม่ได้เพราะยิง API ไม่ผ่าน ไม่ใช่เพราะรหัสไม่มีจริง
  bool _siteLookupFailed = false;
  bool _custodianLookupFailed = false;

  /// ชื่อของที่อยู่เดิม เก็บแยกเพราะ [_branch] / [_employee] เปลี่ยนตามปลายทาง
  /// ที่ผู้ใช้เลือกใหม่ แต่หัวข้อ "ย้ายจาก" ต้องคงที่
  String _fromSiteName = '';
  String _fromCustodianName = '';

  /// ตัวตนของคนกดจาก `/me` ใช้ทำปุ่มลัด
  AssetProfile? _me;

  bool _saving = false;

  /// แผนกที่คนกดสังกัด ใช้เป็นปุ่มลัด "แผนกฉัน"
  ///
  /// มีแต่จาก `/me` เท่านั้น — `PermissionService` ให้มาแค่รหัส**สาขา** ซึ่งเป็น
  /// คนละชุดรหัสกับแผนก เอามาใส่ช่องนี้จะได้รหัสที่ไม่มีอยู่จริง
  String get _myDeptCode => _me?.deptCode ?? '';

  /// รหัสพนักงานของคนกด ใช้เป็นปุ่มลัด "รับมาถือเอง"
  String get _myEmpNo {
    final profile = _me;
    if (profile != null && profile.empId.isNotEmpty) return profile.empId;
    return MobileSession.I.empNo ?? '';
  }

  @override
  void initState() {
    super.initState();
    _resolveSite(widget.asset.siteId);
    _resolveCustodian(widget.asset.custodian);
    _loadProfile();
  }

  @override
  void dispose() {
    _refNo.dispose();
    _changeNote.dispose();
    super.dispose();
  }

  /// ผลของงานที่ล้มเหลวแล้วไม่เป็นไร คืน null แทนการโยนต่อ
  ///
  /// การหาชื่อกับการดึงตัวตนคนกดเป็นของแถมทั้งคู่ หน้านี้ทำงานได้ด้วยรหัสล้วน
  /// ล้มแล้วไปขวางไม่ให้โอนย้ายคือแลกของจำเป็นกับของประดับ
  static Future<T?> _quiet<T>(Future<T> work) =>
      work.then<T?>((value) => value).catchError((Object _) => null);

  Future<void> _loadProfile() async {
    final profile = await _quiet(fetchAssetProfile());
    if (!mounted || profile == null) return;
    setState(() => _me = profile);
  }

  /// เปลี่ยนแผนกที่ดูแล
  ///
  /// [known] คือข้อมูลแผนกที่รู้มาแล้ว (ผู้ใช้เพิ่งเลือกจากลิสต์) ส่ง null มา
  /// เมื่อมีแต่รหัส แล้วจะไปหาชื่อให้เอง
  void _setSite(String id, AssetDept? known) {
    setState(() {
      _siteId = id;
      _dept = known;
      _siteLookupFailed = false;
      _resolvingSite = known == null && id.isNotEmpty;
    });
    if (_resolvingSite) _resolveSite(id);
  }

  void _setCustodian(String id, AssetEmployee? known) {
    setState(() {
      _custodian = id;
      _employee = known;
      _custodianLookupFailed = false;
      _resolvingCustodian = known == null && id.isNotEmpty;
    });
    if (_resolvingCustodian) _resolveCustodian(id);
  }

  /// หาชื่อแผนกจากรหัส ทิ้งผลถ้าผู้ใช้เปลี่ยนไปเลือกตัวอื่นระหว่างรอ
  Future<void> _resolveSite(String id) async {
    if (id.isEmpty) return;

    AssetDept? dept;
    var failed = false;

    try {
      dept = await findAssetDept(id);
    } on MobileApiException {
      // ยิงไม่ผ่านต่างจากหาแล้วไม่มี ดู [AssetPickerField.lookupFailed]
      failed = true;
    }

    if (!mounted || _siteId != id) return;

    setState(() {
      _dept = dept;
      _siteLookupFailed = failed;
      _resolvingSite = false;
      if (id == widget.asset.siteId) _fromSiteName = dept?.name ?? '';
    });
  }

  Future<void> _resolveCustodian(String id) async {
    if (id.isEmpty) return;

    AssetEmployee? employee;
    var failed = false;

    try {
      employee = await findAssetEmployee(id);
    } on MobileApiException {
      failed = true;
    }

    if (!mounted || _custodian != id) return;

    setState(() {
      _employee = employee;
      _custodianLookupFailed = failed;
      _resolvingCustodian = false;
      if (id == widget.asset.custodian) {
        _fromCustodianName = employee?.fullName ?? '';
      }
    });
  }

  Future<void> _pickSite() async {
    final dept = await pickAssetDept(context, currentId: _siteId);
    if (dept == null) return;
    _setSite(dept.code, dept);
  }

  Future<void> _pickCustodian() async {
    // ไม่จำกัดตามแผนก เพราะ pickAssetEmployee กรองด้วย branchId ไม่ใช่ deptCode
    // และคนถือของใหม่อาจอยู่คนละแผนกกับที่ตั้งไว้ก็ได้
    final employee = await pickAssetEmployee(
      context,
      currentId: _custodian,
      branchId: _siteId,
    );
    if (employee == null) return;
    _setCustodian(employee.id, employee);
  }

  /// ปลายทางต่างจากที่อยู่ปัจจุบันจริงไหม
  ///
  /// กันการกดบันทึกโดยไม่ได้เปลี่ยนอะไร ซึ่งจะได้ประวัติปลอมเพิ่มมาหนึ่งบรรทัด
  /// แล้วคนอ่านประวัติทีหลังจะงงว่าตกลงย้ายไปไหน
  bool get _hasChange =>
      _siteId != widget.asset.siteId || _custodian != widget.asset.custodian;

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_hasChange) {
      _toast('ยังไม่ได้เปลี่ยนแผนกหรือผู้ครอบครอง');
      return;
    }

    setState(() => _saving = true);

    try {
      final message = await updateAsset(
        assetId: widget.asset.id,
        // ส่งของเดิมทั้งก้อนโดยเปลี่ยนแค่ปลายทาง เหตุผลอยู่ที่
        // buildAssetUpdatePayload — ส่งเฉพาะช่องที่แก้อาจทำให้ช่องอื่นถูกล้าง
        next: widget.asset.copyWith(siteId: _siteId, custodian: _custodian),
        changeNote: _changeNote.text,
        refNo: _refNo.text,
      );
      if (!mounted) return;

      _toast(message);
      Navigator.of(context).pop(true);
    } on MobileApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.message);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: assetAppBar(context, title: 'แก้ที่อยู่ทรัพย์สิน'),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              _header(),
              _fromSection(),
              _toSection(),
              _reasonSection(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _header() {
    final asset = widget.asset;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            asset.name.isEmpty ? asset.id : asset.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            asset.id,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// ที่อยู่เดิม โชว์ไว้ให้เทียบกับปลายทางที่กำลังเลือก
  Widget _fromSection() {
    final asset = widget.asset;

    return AssetSection(
      title: 'ตอนนี้อยู่ที่',
      children: [
        AssetInfoLine(
          label: 'แผนกที่ดูแล',
          value: _placeLabel(asset.siteId, _fromSiteName, 'ยังไม่ระบุแผนก'),
        ),
        AssetInfoLine(
          label: 'ผู้ครอบครอง',
          value: _placeLabel(asset.custodian, _fromCustodianName, 'ยังไม่ระบุ'),
        ),
      ],
    );
  }

  /// รหัสพร้อมชื่อถ้าหาเจอ หาไม่เจอก็รหัสเปล่า ๆ แบบเดิม
  String _placeLabel(String code, String name, String empty) {
    if (code.isEmpty) return empty;
    return name.isEmpty ? code : '$name ($code)';
  }

  Widget _toSection() {
    final scheme = Theme.of(context).colorScheme;

    return AssetSection(
      title: 'แก้เป็น',
      children: [
        AssetPickerField(
          label: 'แผนกที่ดูแล',
          hint: 'แตะเพื่อเลือกแผนก',
          code: _siteId,
          name: _dept?.name ?? '',
          resolving: _resolvingSite,
          lookupFailed: _siteLookupFailed,
          enabled: !_saving,
          icon: Icons.apartment_outlined,
          onTap: _pickSite,
          onClear: _siteId.isEmpty ? null : () => _setSite('', null),
        ),
        AssetPickerField(
          label: 'ผู้ครอบครองคนใหม่',
          hint: 'แตะเพื่อเลือกพนักงาน',
          code: _custodian,
          name: _employee?.fullName ?? '',
          resolving: _resolvingCustodian,
          lookupFailed: _custodianLookupFailed,
          enabled: !_saving,
          icon: Icons.person_outline,
          onTap: _pickCustodian,
          onClear: _custodian.isEmpty ? null : () => _setCustodian('', null),
        ),
        // ปุ่มลัดสองตัวนี้ครอบคลุมเคสที่เจอบ่อยสุด: ของมาอยู่ที่แผนกเรา
        // แล้วเราเป็นคนถือไว้เอง เปิดลิสต์หาตัวเองทุกครั้งเสียเวลาเปล่า
        if (_myDeptCode.isNotEmpty || _myEmpNo.isNotEmpty)
          Wrap(
            spacing: 8,
            children: [
              if (_myDeptCode.isNotEmpty)
                _shortcut('แผนกฉัน ($_myDeptCode)', _useMyDept),
              if (_myEmpNo.isNotEmpty) _shortcut('ฉันถือไว้เอง', _useMyself),
            ],
          ),
        if (!_hasChange)
          Text(
            'ยังเหมือนเดิมทั้งสองช่อง เปลี่ยนอย่างน้อยหนึ่งช่องถึงจะบันทึกได้',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  /// ย้ายมาอยู่แผนกของคนกด
  ///
  /// `/me` ส่งชื่อแผนกมาด้วยอยู่แล้ว ใช้ได้เลยไม่ต้องไปหาซ้ำ
  void _useMyDept() {
    final profile = _me;
    if (profile == null || profile.deptCode.isEmpty) return;

    _setSite(
      profile.deptCode,
      AssetDept(code: profile.deptCode, name: profile.deptName),
    );
  }

  void _useMyself() {
    final profile = _me;
    final id = _myEmpNo;

    _setCustodian(
      id,
      profile != null && profile.empId == id
          ? AssetEmployee(
              id: id,
              fullName: profile.fullName,
              deptCode: profile.deptCode,
              deptName: profile.deptName,
              branchId: profile.branchId,
              positionName: profile.positionName,
              positionLevel: profile.positionLevel,
            )
          : null,
    );
  }

  Widget _shortcut(String label, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;

    return ActionChip(
      label: Text(label),
      onPressed: _saving ? null : onTap,
      backgroundColor: scheme.surface,
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: scheme.onSurface,
      ),
    );
  }

  Widget _reasonSection() => AssetSection(
    title: 'เหตุผลและเอกสารอ้างอิง',
    note: 'เหตุผลจะไปอยู่ในประวัติของทรัพย์สินชิ้นนี้',
    divider: false,
    children: [
      TextFormField(
        controller: _changeNote,
        enabled: !_saving,
        maxLength: kAssetChangeNoteMax,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'เหตุผลที่ย้าย',
          hintText: 'เช่น ย้ายตามพนักงานที่เปลี่ยนสาขา',
          counterText: '',
        ),
        // API บังคับ change_note ไม่ได้บังคับเล่น ๆ มันคือบรรทัดที่จะไปอยู่
        // ในประวัติ ปล่อยว่างแล้วอีกหกเดือนไม่มีใครรู้ว่าย้ายทำไม
        validator: (value) => assetChangeNoteError(value ?? ''),
      ),
      TextFormField(
        controller: _refNo,
        enabled: !_saving,
        maxLength: kAssetRefNoMax,
        decoration: const InputDecoration(
          labelText: 'เลขที่เอกสารอ้างอิง (ไม่บังคับ)',
          hintText: 'เช่น เลขใบโอนย้าย',
          counterText: '',
        ),
      ),
    ],
  );

  Widget _bottomBar() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: FilledButton.icon(
            onPressed: _saving || !_hasChange ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.edit_location_alt_outlined),
            label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึกการแก้ไข'),
          ),
        ),
      ),
    );
  }
}
