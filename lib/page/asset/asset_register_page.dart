import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:claim/page/asset/asset_api.dart';
import 'package:claim/page/asset/asset_models.dart';
import 'package:claim/page/asset/asset_picker.dart';
import 'package:claim/page/asset/asset_style.dart';
import 'package:claim/page/asset/asset_type_dialog.dart';
import 'package:claim/utils/app_icons.dart';
import 'package:claim/utils/mobile_api.dart';
import 'package:claim/widgets/barcode_scanner.dart';
import 'package:claim/widgets/state_views.dart';

/// ฟอร์มเพิ่มทรัพย์สินเข้าทะเบียน และแก้ไขของที่มีอยู่แล้ว
///
/// ส่ง [asset] มา = แก้ของเดิม (PUT) ไม่ส่ง = เพิ่มใหม่ (POST) แบบเดียวกับ
/// หน้าทะเบียนเครื่องของระบบแจ้งซ่อม
///
/// ตอนแก้ไขมีสองช่องที่แก้ไม่ได้ **รหัสทรัพย์สิน** เป็น path ของ endpoint และ
/// **สถานะ** ไม่มีอยู่ใน `requestUpdateAsset` เลย ต้องไปแก้ที่เว็บ
///
/// บันทึกสำเร็จแล้วปิดหน้ากลับไปทะเบียนทันทีทั้งสองโหมด คืน `true` ไปให้
/// หน้าที่เรียกดึงของใหม่ กดย้อนกลับเองโดยไม่บันทึกคืน `false`
///
/// เดิมโหมดเพิ่มค้างหน้าไว้ให้กรอกชิ้นถัดไปต่อ (ตั้งใจให้ลงของทีละล็อตได้เร็ว)
/// แต่ของที่เพิ่งเพิ่มไม่โผล่ให้เห็นสักที คนกดเลยไม่แน่ใจว่าเข้าไปจริงไหม
/// แล้วกดบันทึกซ้ำ — เห็นของตัวเองอยู่ในทะเบียนสำคัญกว่าประหยัดการกดสองที
class AssetRegisterPage extends StatefulWidget {
  final Asset? asset;

  const AssetRegisterPage({super.key, this.asset});

  @override
  State<AssetRegisterPage> createState() => _AssetRegisterPageState();
}

class _AssetRegisterPageState extends State<AssetRegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _assetId = TextEditingController();
  final _assetName = TextEditingController();
  final _typeId = TextEditingController();
  final _serialNo = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _siteId = TextEditingController();
  final _custodian = TextEditingController();
  final _price = TextEditingController();
  final _remark = TextEditingController();
  final _changeNote = TextEditingController();

  List<AssetLookup> _types = const [];
  List<AssetLookup> _statuses = const [];

  AssetLookup? _type;
  AssetLookup? _status;

  DateTime? _acceptDate;
  DateTime? _purchaseDate;
  DateTime? _warrantyExpireDate;

  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  bool _needLogin = false;

  /// โหลดรายการสถานะไม่สำเร็จ บันทึกต่อได้แต่จะไม่มีสถานะติดไปด้วย
  bool _statusUnavailable = false;

  /// กลุ่มที่ไม่มีช่องบังคับสักช่อง เริ่มมาแบบพับไว้
  ///
  /// ฟอร์มนี้มีสิบกว่าช่องแต่บังคับจริง ๆ แค่สามช่องแรก ถ้ากางหมดตั้งแต่เปิดมา
  /// คนที่แค่จะลงทะเบียนของชิ้นหนึ่งต้องเลื่อนผ่านช่องที่ไม่ได้จะกรอกทั้งหน้า
  /// ตอนแก้ไขจะกางเฉพาะกลุ่มที่มีของอยู่แล้ว เพื่อไม่ให้ค่าเดิมหายไปจากสายตา
  bool _deviceOpen = false;
  bool _placeOpen = false;
  bool _purchaseOpen = false;

  /// ชื่อของรหัสในช่องแผนกกับช่องผู้ครอบครอง
  ///
  /// ค่าที่บันทึกจริงยังเป็นรหัสใน [_siteId] / [_custodian] เหมือนเดิม สองตัวนี้
  /// มีไว้โชว์ใต้รหัสให้คนกรอกยืนยันว่าหยิบถูกตัว ไม่ได้ส่งไปกับคำขอ
  ///
  /// ⚠️ [_siteId] เก็บ **รหัสแผนก** ไม่ใช่รหัสสาขา แม้ชื่อช่องฝั่ง API จะเป็น
  /// `current_site_id` — ดูหัวหมวดแผนกใน `asset_api.dart`
  AssetDept? _dept;
  AssetEmployee? _employee;

  bool _resolvingSite = false;
  bool _resolvingCustodian = false;

  /// หาชื่อไม่ได้เพราะยิง API ไม่ผ่าน ไม่ใช่เพราะรหัสไม่มีจริง
  bool _siteLookupFailed = false;
  bool _custodianLookupFailed = false;

  bool get _isEdit => widget.asset != null;

  @override
  void initState() {
    super.initState();

    final asset = widget.asset;
    if (asset != null) {
      _fillFrom(asset);
      _deviceOpen = _deviceFilled > 0;
      _placeOpen = _placeFilled > 0;
      _purchaseOpen = _purchaseFilled > 0;
    } else {
      // ของใหม่ตั้งต้นว่าคนที่ลงทะเบียนเป็นคนถือเอง ซึ่งเป็นกรณีปกติ
      //
      // แผนกไม่เติมตรงนี้เพราะต้องรอ `/me` ตอบก่อนถึงจะรู้ — ปล่อยให้
      // [_fillDeptFromMe] เติมให้ทีหลัง
      _custodian.text = MobileSession.I.empNo ?? '';
      _fillDeptFromMe();
    }

    _resolveSite(_siteId.text);
    _resolveCustodian(_custodian.text);
    _load();
  }

  /// เปลี่ยนแผนก [known] คือแผนกที่รู้มาแล้ว ไม่รู้ก็ส่ง null แล้วจะไปหาชื่อเอง
  void _setSite(String id, AssetDept? known) {
    setState(() {
      _siteId.text = id;
      _dept = known;
      _siteLookupFailed = false;
      _resolvingSite = known == null && id.isNotEmpty;
    });
    if (_resolvingSite) _resolveSite(id);
  }

  void _setCustodian(String id, AssetEmployee? known) {
    setState(() {
      _custodian.text = id;
      _employee = known;
      _custodianLookupFailed = false;
      _resolvingCustodian = known == null && id.isNotEmpty;
    });
    if (_resolvingCustodian) _resolveCustodian(id);
  }

  /// หาชื่อแผนกจากรหัส ทิ้งผลถ้าผู้ใช้เปลี่ยนไปเลือกตัวอื่นระหว่างรอ
  ///
  /// ล้มเหลวไม่ขวางการบันทึก ฟอร์มนี้ทำงานได้ด้วยรหัสล้วน ชื่อเป็นของแถมที่
  /// ช่วยให้คนกรอกมั่นใจว่าหยิบถูกตัว
  Future<void> _resolveSite(String id) async {
    if (id.isEmpty) return;
    setState(() => _resolvingSite = true);

    AssetDept? dept;
    var failed = false;

    try {
      dept = await findAssetDept(id);
    } on MobileApiException {
      // ยิงไม่ผ่านต่างจากหาแล้วไม่มี ดู [AssetPickerField.lookupFailed]
      failed = true;
    }

    if (!mounted || _siteId.text != id) return;

    setState(() {
      _dept = dept;
      _siteLookupFailed = failed;
      _resolvingSite = false;
    });
  }

  Future<void> _resolveCustodian(String id) async {
    if (id.isEmpty) return;
    setState(() => _resolvingCustodian = true);

    AssetEmployee? employee;
    var failed = false;

    try {
      employee = await findAssetEmployee(id);
    } on MobileApiException {
      failed = true;
    }

    if (!mounted || _custodian.text != id) return;

    setState(() {
      _employee = employee;
      _custodianLookupFailed = failed;
      _resolvingCustodian = false;
    });
  }

  /// เติมแผนกตั้งต้นจากแผนกของคนที่ล็อกอิน
  ///
  /// ใช้ `/me` ไม่ใช่ `PermissionService` เพราะตัวหลังให้มาแค่รหัส**สาขา** ซึ่ง
  /// เป็นคนละชุดรหัสกับแผนก เอามาใส่ช่องนี้แล้วจะได้รหัสที่ไม่มีอยู่จริง
  ///
  /// ล้มเหลวก็แค่ไม่มีค่าตั้งต้น คนกรอกเลือกเองได้
  Future<void> _fillDeptFromMe() async {
    AssetProfile? me;
    try {
      me = await fetchAssetProfile();
    } on MobileApiException {
      return;
    }

    // ผู้ใช้อาจเลือกแผนกเองไปแล้วระหว่างรอ อย่าทับของที่เขาตั้งใจเลือก
    if (!mounted || me.deptCode.isEmpty || _siteId.text.isNotEmpty) return;

    _setSite(me.deptCode, AssetDept(code: me.deptCode, name: me.deptName));
  }

  Future<void> _pickSite() async {
    final dept = await pickAssetDept(context, currentId: _siteId.text);
    if (dept == null) return;
    _setSite(dept.code, dept);
  }

  /// เลือกผู้ครอบครอง แล้วเติมแผนกของเขาลงช่องแผนกให้เลย
  ///
  /// แผนกของทรัพย์สินคือแผนกของคนที่ถือมันอยู่ ให้คนกรอกเลือกเองอีกช่องคือ
  /// ถามซ้ำในสิ่งที่ระบบรู้อยู่แล้ว และเปิดช่องให้กรอกไม่ตรงกันได้
  ///
  /// ทับของเดิมเสมอเมื่อเปลี่ยนคนถือ เพราะของย้ายไปอยู่กับคนใหม่แล้ว แผนกเดิม
  /// ไม่เกี่ยวอีกต่อไป คนที่ตั้งใจให้ต่างกันจริง ๆ ยังกดแก้ช่องแผนกทีหลังได้
  Future<void> _pickCustodian() async {
    final employee = await pickAssetEmployee(
      context,
      currentId: _custodian.text,
    );
    if (employee == null) return;

    _setCustodian(employee.id, employee);

    if (employee.deptCode.isNotEmpty) {
      _setSite(
        employee.deptCode,
        AssetDept(code: employee.deptCode, name: employee.deptName),
      );
    }
  }

  void _fillFrom(Asset asset) {
    _assetId.text = asset.id;
    _assetName.text = asset.name;
    _typeId.text = asset.typeId;
    _serialNo.text = asset.serialNo;
    _brand.text = asset.brand;
    _model.text = asset.model;
    _siteId.text = asset.siteId;
    _custodian.text = asset.custodian;
    _remark.text = asset.remark;

    final price = asset.purchasePrice;
    _price.text = price == null ? '' : _priceText(price);

    _acceptDate = asset.acceptDate;
    _purchaseDate = asset.purchaseDate;
    _warrantyExpireDate = asset.warrantyExpireDate;
  }

  /// ราคาที่เอากลับมาโชว์ในช่องกรอก ตัด .0 ของจำนวนเต็มทิ้ง
  ///
  /// ไม่งั้นของที่ราคา 25900 จะกลายเป็น "25900.0" ทุกครั้งที่เปิดมาแก้
  String _priceText(double price) =>
      price == price.roundToDouble() ? price.round().toString() : '$price';

  @override
  void dispose() {
    for (final controller in [
      _assetId,
      _assetName,
      _typeId,
      _serialNo,
      _brand,
      _model,
      _siteId,
      _custodian,
      _price,
      _remark,
      _changeNote,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _needLogin = false;
      _statusUnavailable = false;
    });

    try {
      final types = await fetchAssetTypes();

      // สถานะไม่ใช่ช่องบังคับ โหลดไม่ได้ก็ยังลงทะเบียนต่อได้ จึงไม่ปล่อยให้
      // error ของลิสต์นี้ไปปิดทั้งหน้า ต่างจากประเภทที่ขาดไม่ได้
      List<AssetLookup> statuses = const [];
      var statusFailed = false;
      try {
        statuses = await fetchAssetStatuses();
      } on MobileApiException {
        statusFailed = true;
      }

      if (!mounted) return;
      setState(() {
        _types = types;
        _statuses = statuses;
        _statusUnavailable = statusFailed || statuses.isEmpty;
        // ของที่เปิดมาแก้ต้องเลือกประเภท/สถานะเดิมไว้ให้ ไม่ใช่เริ่มจากว่าง
        // ไม่งั้นคนแก้แค่ยี่ห้อจะเผลอเปลี่ยนประเภทไปด้วยโดยไม่รู้ตัว
        _type = _lookupOf(types, widget.asset?.typeId ?? '');
        _status = _lookupOf(statuses, widget.asset?.statusId ?? '');
        _loading = false;
      });
    } on MobileApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _needLogin = e.needLogin;
        _loading = false;
      });
    } catch (_) {
      // ไม่ดักตรงนี้แล้ววงหมุนจะค้างทั้งหน้า กดอะไรไม่ได้เลย
      if (!mounted) return;
      setState(() {
        _loadError = 'โหลดข้อมูลไม่สำเร็จ กรุณาลองใหม่';
        _loading = false;
      });
    }
  }

  /// หาตัวที่ตรงรหัสในลิสต์ คืน null เมื่อไม่มี
  ///
  /// ต้องคืนตัวที่อยู่ใน [_types]/[_statuses] จริง ๆ ไม่ใช่สร้างตัวใหม่ที่รหัส
  /// ตรงกัน ไม่งั้น DropdownButtonFormField จะ assert ตายเพราะหาค่าที่เลือกไม่เจอ
  AssetLookup? _lookupOf(List<AssetLookup> items, String code) {
    if (code.isEmpty) return null;
    for (final item in items) {
      if (item.code == code) return item;
    }
    return null;
  }

  /// รหัสประเภทที่จะส่งไป มาจากช่องเลือกเมื่อโหลดลิสต์ได้ ไม่ได้ก็มาจากช่องพิมพ์
  String get _typeCode => _type?.code ?? _typeId.text;

  /// สถานะของชิ้นที่กำลังแก้ ใช้ชื่อจากลิสต์ถ้าหาเจอ ไม่เจอก็ใช้ที่ติดมากับของ
  String get _currentStatusLabel {
    final fromList = _status?.label ?? '';
    if (fromList.isNotEmpty) return fromList;

    final fromAsset = widget.asset?.statusLabel ?? '';
    return fromAsset.isEmpty ? 'ยังไม่ระบุ' : fromAsset;
  }

  bool get _hasTypeList => _types.isNotEmpty;

  /// จำนวนช่องที่มีของอยู่ในแต่ละกลุ่มที่พับได้ ใช้ทั้งตอนตัดสินใจว่าจะกางไหม
  /// และตอนเขียนบรรทัดสรุปท้ายหัวข้อ
  int get _deviceFilled =>
      _countFilled([_serialNo.text, _brand.text, _model.text]);

  int get _placeFilled =>
      _countFilled([_siteId.text, _custodian.text]) +
      (_acceptDate == null ? 0 : 1);

  int get _purchaseFilled =>
      _countFilled([_price.text, _remark.text]) +
      (_purchaseDate == null ? 0 : 1) +
      (_warrantyExpireDate == null ? 0 : 1);

  int _countFilled(List<String> values) =>
      values.where((value) => value.trim().isNotEmpty).length;

  /// บรรทัดสรุปของกลุ่มที่พับอยู่ ไม่งั้นกลุ่มที่พับจะดูเหมือนว่างเปล่าเสมอ
  String _filledLabel(int count) =>
      count == 0 ? 'ยังไม่ได้กรอก' : 'กรอกแล้ว $count ช่อง';

  Future<void> _scanInto(TextEditingController controller, String title) async {
    final code = await openBarcodeScannerPage(context, title: title);
    if (code == null || !mounted) return;
    setState(() => controller.text = code.trim());
  }

  Future<void> _pickDate(
    DateTime? current,
    ValueChanged<DateTime?> onPicked,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      // ทรัพย์สินเก่าที่เพิ่งเอาเข้าระบบมีของที่ซื้อมาสิบกว่าปีแล้ว ส่วนวันหมด
      // ประกันเป็นอนาคต ช่วงจึงต้องกว้างทั้งสองทาง
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 30),
    );
    if (picked == null) return;
    onPicked(picked);
  }

  Future<void> _addType() async {
    final created = await showAssetTypeDialog(context);
    if (created == null || !mounted) return;

    setState(() {
      _types = [..._types, created];
      _type = created;
      _typeId.text = created.code;
    });
    _toast('เพิ่มประเภท "${created.label}" แล้ว');
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      // ช่องที่กรอกผิดอาจอยู่ในกลุ่มที่พับไว้ (ราคาซื้อ) ถ้าไม่กางให้ คนกดจะ
      // เห็นแค่ปุ่มที่กดแล้วไม่มีอะไรเกิดขึ้น
      setState(() {
        _deviceOpen = true;
        _placeOpen = true;
        _purchaseOpen = true;
      });
      return;
    }

    setState(() => _saving = true);

    final asset = widget.asset;
    if (asset != null) {
      await _update(asset);
      return;
    }

    try {
      final message = await insertAsset(
        assetId: _assetId.text,
        assetName: _assetName.text,
        assetType: _typeCode,
        serialNo: _serialNo.text,
        brand: _brand.text,
        model: _model.text,
        statusId: _status?.code ?? '',
        siteId: _siteId.text,
        custodian: _custodian.text,
        remark: _remark.text,
        acceptDate: _acceptDate,
        purchaseDate: _purchaseDate,
        warrantyExpireDate: _warrantyExpireDate,
        purchasePrice: assetPriceOf(_price.text),
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

  /// บันทึกการแก้ไขแล้วปิดหน้ากลับไปเลย
  ///
  /// ต่างจากโหมดเพิ่มที่ค้างไว้ให้กรอกชิ้นถัดไป เพราะแก้ของชิ้นเดิมซ้ำ ๆ ไม่มี
  /// ประโยชน์ และหน้ารายละเอียดที่รออยู่ต้องดึงของใหม่มาโชว์
  Future<void> _update(Asset asset) async {
    try {
      final message = await updateAsset(
        assetId: asset.id,
        // ส่งสถานะที่อยากให้เป็นทั้งก้อน ไม่ใช่เฉพาะช่องที่แก้
        // (เหตุผลอยู่ที่ buildAssetUpdatePayload)
        next: asset.copyWith(
          name: _assetName.text.trim(),
          typeId: _typeCode.trim(),
          serialNo: _serialNo.text.trim(),
          brand: _brand.text.trim(),
          model: _model.text.trim(),
          siteId: _siteId.text.trim(),
          custodian: _custodian.text.trim(),
          remark: _remark.text.trim(),
          acceptDate: _acceptDate,
          purchaseDate: _purchaseDate,
          warrantyExpireDate: _warrantyExpireDate,
          purchasePrice: assetPriceOf(_price.text),
        ),
        changeNote: _changeNote.text,
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
    return PopScope(
      // บันทึกสำเร็จจะ pop(true) ไปเองแล้ว ตรงนี้ดักเฉพาะตอนกดย้อนกลับเอง
      // ซึ่งแปลว่ายังไม่ได้บันทึกอะไร หน้าลิสต์ไม่ต้องดึงใหม่
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(false);
      },
      child: Scaffold(
        appBar: assetAppBar(
          context,
          title: _isEdit ? 'แก้ไขทรัพย์สิน' : 'เพิ่มทรัพย์สิน',
          actions: [
            IconButton(
              tooltip: 'เพิ่มประเภททรัพย์สิน',
              onPressed: _loading || _saving ? null : _addType,
              icon: const Icon(Icons.playlist_add),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: _body(),
        ),
        // ปุ่มบันทึกติดขอบล่างเหมือนหน้ารายละเอียดกับหน้าโอนย้าย ฟอร์มนี้ยาว
        // เกินหนึ่งจอ ถ้าปุ่มอยู่ท้ายลิสต์ต้องเลื่อนลงไปหาทุกครั้ง
        bottomNavigationBar: _loading || _loadError != null
            ? null
            : _bottomBar(),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingStateView();

    final error = _loadError;
    if (error != null) {
      // ปุ่มลองใหม่ไม่ช่วยอะไรเมื่อ token หมดอายุ บอกให้ล็อกอินใหม่แทน
      if (_needLogin) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(error, textAlign: TextAlign.center),
          ),
        );
      }
      return ErrorStateView(message: error, onRetry: _load);
    }

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          _notice(),
          _assetCard(),
          _deviceCard(),
          _placeCard(),
          _purchaseCard(),
          if (_isEdit) _changeNoteCard(),
        ],
      ),
    );
  }

  /// เหตุผลของการแก้ไข บังคับกรอกเพราะ `change_note` เป็นช่อง required ของ PUT
  ///
  /// ไม่ใช่พิธีกรรม มันคือบรรทัดที่จะไปโผล่ในประวัติของทรัพย์สินชิ้นนี้
  Widget _changeNoteCard() => _section(
    'เหตุผลที่แก้ไข',
    [
      _field(
        controller: _changeNote,
        label: 'แก้อะไร เพราะอะไร',
        hint: 'เช่น แก้เลข S/N ให้ตรงกับตัวเครื่อง',
        maxLength: kAssetChangeNoteMax,
        maxLines: 3,
        validator: (value) => assetChangeNoteError(value ?? ''),
      ),
    ],
    note: 'เหตุผลจะไปอยู่ในประวัติของทรัพย์สินชิ้นนี้',
    divider: false,
  );

  /// ข้อความเตือนบนสุดของฟอร์ม
  ///
  /// เดิมเป็นกล่องสีอ่อน ตอนนี้เป็นตัวหนังสือสีจางบรรทัดเดียว เรื่องที่บอกเป็น
  /// ข้อควรรู้ ไม่ใช่คำเตือนอันตราย ไม่ต้องมีกล่องสีมาดึงสายตาเป็นอย่างแรกของหน้า
  Widget _notice() {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isEdit
                  ? 'รหัสทรัพย์สินกับสถานะแก้ที่นี่ไม่ได้ ต้องไปแก้ที่เว็บ '
                        'ส่วนการย้ายสาขาหรือเปลี่ยนผู้ครอบครอง ใช้ปุ่มโอนย้าย'
                  : 'ตรวจรหัสกับชื่อให้ตรงก่อนกดบันทึก รหัสทรัพย์สินตั้งแล้ว '
                        'เปลี่ยนทีหลังไม่ได้',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _assetCard() => _section('ข้อมูลทรัพย์สิน', [
    // ตอนแก้ไขล็อกไว้ดูอย่างเดียว รหัสเป็น path ของ endpoint เปลี่ยนไม่ได้
    _field(
      controller: _assetId,
      label: 'รหัสทรัพย์สิน',
      hint: 'เช่น F800-6703-0001',
      maxLength: kAssetIdMax,
      textCapitalization: TextCapitalization.characters,
      readOnly: _isEdit,
      validator: (value) => assetIdError(value ?? ''),
      onScan: _isEdit ? null : () => _scanInto(_assetId, 'สแกนรหัสทรัพย์สิน'),
    ),
    _field(
      controller: _assetName,
      label: 'ชื่อทรัพย์สิน',
      hint: 'เช่น โน้ตบุ๊ก ASUS ฝ่ายบัญชี',
      maxLength: kAssetNameMax,
      validator: (value) => assetRequiredError(
        value ?? '',
        label: 'ชื่อทรัพย์สิน',
        max: kAssetNameMax,
      ),
    ),
    if (_hasTypeList)
      _dropdown(
        label: 'ประเภททรัพย์สิน',
        value: _type,
        items: _types,
        onChanged: (value) => setState(() => _type = value),
        validator: (value) => value == null ? 'เลือกประเภททรัพย์สิน' : null,
      )
    else
      // โหลดลิสต์ได้แต่ยังไม่มีประเภทสักตัวในระบบ ต้องพิมพ์เองหรือกดเพิ่มที่
      // มุมบนขวา ปิดช่องไปเลยจะลงทะเบียนอะไรไม่ได้เลยเพราะเป็นช่องบังคับ
      _field(
        controller: _typeId,
        label: 'รหัสประเภททรัพย์สิน',
        hint: 'ยังไม่มีประเภทในระบบ พิมพ์รหัสเองหรือกดเพิ่มที่มุมบนขวา',
        maxLength: kAssetTypeMax,
        textCapitalization: TextCapitalization.characters,
        validator: (value) => assetTypeIdError(value ?? ''),
      ),
    // สถานะไม่มีอยู่ใน requestUpdateAsset เลย ส่งไปก็ไม่มีผล ตอนแก้ไขจึงโชว์
    // ของเดิมไว้เฉย ๆ ให้รู้ว่าตอนนี้เป็นอะไร ไม่ทำเป็นช่องที่กดเปลี่ยนได้
    if (_isEdit)
      _hint('สถานะปัจจุบัน: $_currentStatusLabel (แก้ที่เว็บเท่านั้น)')
    else if (_statusUnavailable)
      _hint('โหลดรายการสถานะไม่ได้ จะบันทึกโดยไม่ระบุสถานะ')
    else
      _dropdown(
        label: 'สถานะ (ไม่บังคับ)',
        value: _status,
        items: _statuses,
        onChanged: (value) => setState(() => _status = value),
      ),
  ]);

  // สามกลุ่มข้างล่างไม่มีช่องบังคับสักช่อง จึงพับได้ทั้งกลุ่ม
  Widget _deviceCard() => _section(
    'รายละเอียดเครื่อง (ไม่บังคับ)',
    [
      _field(
        controller: _serialNo,
        label: 'Serial Number',
        maxLength: kAssetSerialMax,
        onScan: () => _scanInto(_serialNo, 'สแกน S/N'),
      ),
      _field(controller: _brand, label: 'ยี่ห้อ', maxLength: kAssetBrandMax),
      _field(controller: _model, label: 'รุ่น', maxLength: kAssetModelMax),
    ],
    expanded: _deviceOpen,
    summary: _filledLabel(_deviceFilled),
    onToggle: () => setState(() => _deviceOpen = !_deviceOpen),
  );

  Widget _placeCard() => _section(
    'ที่อยู่ปัจจุบัน (ไม่บังคับ)',
    [
      AssetPickerField(
        label: 'แผนกที่ดูแล',
        hint: 'แตะเพื่อเลือกแผนก',
        code: _siteId.text,
        name: _dept?.name ?? '',
        resolving: _resolvingSite,
        lookupFailed: _siteLookupFailed,
        enabled: !_saving,
        icon: Icons.apartment_outlined,
        onTap: _pickSite,
        onClear: _siteId.text.isEmpty ? null : () => _setSite('', null),
      ),
      AssetPickerField(
        label: 'ผู้ครอบครอง',
        hint: 'แตะเพื่อเลือกพนักงาน',
        code: _custodian.text,
        name: _employee?.fullName ?? '',
        resolving: _resolvingCustodian,
        lookupFailed: _custodianLookupFailed,
        enabled: !_saving,
        icon: Icons.person_outline,
        onTap: _pickCustodian,
        onClear: _custodian.text.isEmpty
            ? null
            : () => _setCustodian('', null),
      ),
      _dateRow(
        label: 'วันที่รับเข้า',
        value: _acceptDate,
        onPick: () =>
            _pickDate(_acceptDate, (d) => setState(() => _acceptDate = d)),
        onClear: () => setState(() => _acceptDate = null),
      ),
    ],
    expanded: _placeOpen,
    summary: _filledLabel(_placeFilled),
    onToggle: () => setState(() => _placeOpen = !_placeOpen),
  );

  Widget _purchaseCard() => _section(
    'การจัดซื้อและประกัน (ไม่บังคับ)',
    [
      _dateRow(
        label: 'วันที่ซื้อ',
        value: _purchaseDate,
        onPick: () =>
            _pickDate(_purchaseDate, (d) => setState(() => _purchaseDate = d)),
        onClear: () => setState(() => _purchaseDate = null),
      ),
      _field(
        controller: _price,
        label: 'ราคาซื้อ',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        validator: (value) => assetPriceError(value ?? ''),
      ),
      _dateRow(
        label: 'วันหมดประกัน',
        value: _warrantyExpireDate,
        onPick: () => _pickDate(
          _warrantyExpireDate,
          (d) => setState(() => _warrantyExpireDate = d),
        ),
        onClear: () => setState(() => _warrantyExpireDate = null),
      ),
      _field(
        controller: _remark,
        label: 'หมายเหตุ',
        maxLength: kAssetRemarkMax,
        maxLines: 2,
      ),
    ],
    expanded: _purchaseOpen,
    summary: _filledLabel(_purchaseFilled),
    onToggle: () => setState(() => _purchaseOpen = !_purchaseOpen),
  );

  /// กลุ่มช่องกรอกหนึ่งชุด
  ///
  /// ใช้ป้ายกำกับกับเส้นคั่นแทนการ์ด ฟอร์มนี้มีห้ากลุ่ม ถ้าทุกกลุ่มเป็นกล่องมี
  /// ขอบ หน้าจะกลายเป็นกล่องซ้อนกล่องตั้งแต่บนยันล่าง
  Widget _section(
    String title,
    List<Widget> children, {
    String? note,
    bool divider = true,
    bool? expanded,
    String? summary,
    VoidCallback? onToggle,
  }) => AssetSection(
    title: title,
    note: note,
    divider: divider,
    expanded: expanded,
    summary: summary,
    onToggle: onToggle,
    children: children,
  );

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    int? maxLength,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    VoidCallback? onScan,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_saving,
      readOnly: readOnly,
      maxLength: maxLength,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: _decoration(
        label: label,
        hint: hint,
        suffixIcon: onScan == null || !canScanBarcode
            ? null
            : IconButton(
                tooltip: 'สแกนบาร์โค้ด',
                onPressed: _saving ? null : onScan,
                icon: const Icon(AppIcons.scan, size: 20),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
      ),
    );
  }

  /// กรอบช่องกรอกของฟอร์มนี้ เตี้ยกว่าค่าตั้งต้นของธีม
  ///
  /// ธีมรวมตั้งช่องไว้สูงพอดีกับหน้าที่มีสามสี่ช่อง แต่ฟอร์มนี้มีสิบกว่าช่อง
  /// ความสูงระดับนั้นคูณสิบกลายเป็นหน้าที่ต้องเลื่อนสามจอกว่าจะถึงปุ่มบันทึก
  InputDecoration _decoration({
    required String label,
    String? hint,
    Widget? suffixIcon,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    isDense: true,
    contentPadding: const EdgeInsets.fromLTRB(14, 16, 12, 12),
    labelStyle: const TextStyle(fontSize: 14),
    hintStyle: const TextStyle(fontSize: 13),
    // ซ่อนตัวนับตัวอักษร ช่องส่วนใหญ่ยาวเหลือเฟือ โชว์ไว้รกเปล่า ๆ
    counterText: '',
    // ปุ่มท้ายช่องมีพื้นที่กดขั้นต่ำ 48 จุดของมันเอง ถ้าไม่บีบตรงนี้ ช่องที่มี
    // ปุ่มจะสูงกว่าช่องอื่นทั้งที่เพิ่งลดความสูงของช่องลงมา
    suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    suffixIcon: suffixIcon,
  );

  Widget _dropdown({
    required String label,
    required AssetLookup? value,
    required List<AssetLookup> items,
    required ValueChanged<AssetLookup?> onChanged,
    String? Function(AssetLookup?)? validator,
  }) {
    return DropdownButtonFormField<AssetLookup>(
      initialValue: value,
      isExpanded: true,
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration: _decoration(label: label),
      validator: validator,
      onChanged: _saving ? null : onChanged,
      items: [
        for (final item in items)
          DropdownMenuItem(
            value: item,
            child: Text(item.detailLabel, overflow: TextOverflow.ellipsis),
          ),
      ],
    );
  }

  Widget _dateRow({
    required String label,
    required DateTime? value,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: _saving ? null : onPick,
      child: InputDecorator(
        decoration: _decoration(
          label: label,
          suffixIcon: value == null
              ? const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.calendar_today_outlined, size: 18),
                )
              : IconButton(
                  tooltip: 'ล้างวันที่',
                  onPressed: _saving ? null : onClear,
                  icon: const Icon(Icons.close, size: 18),
                ),
        ),
        child: Text(
          value == null ? 'ยังไม่ระบุ' : assetDateLabel(value),
          style: TextStyle(
            fontSize: 14,
            color: value == null ? scheme.onSurfaceVariant : scheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _hint(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );

  /// แถบปุ่มบันทึกติดขอบล่าง มีเส้นคั่นบนแทนเงา ให้เข้าชุดกับหน้าอื่นในโมดูล
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
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _saving
                  ? 'กำลังบันทึก...'
                  : (_isEdit ? 'บันทึกการแก้ไข' : 'บันทึกทรัพย์สิน'),
            ),
          ),
        ),
      ),
    );
  }
}
