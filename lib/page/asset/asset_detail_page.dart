import 'package:flutter/material.dart';

import 'package:claim/page/asset/asset_api.dart';
import 'package:claim/page/asset/asset_log_view.dart';
import 'package:claim/page/asset/asset_models.dart';
import 'package:claim/page/asset/asset_register_page.dart';
import 'package:claim/page/asset/asset_style.dart';
import 'package:claim/page/asset/asset_transfer_page.dart';
import 'package:claim/page/asset/transfer_api.dart' show canCreateTransfer;
import 'package:claim/page/asset/transfer_create_page.dart';
import 'package:claim/page/asset/transfer_detail_page.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/mobile_api.dart';
import 'package:claim/widgets/state_views.dart';

/// รายละเอียดทรัพย์สิน 1 ชิ้น พร้อมประวัติการเปลี่ยนแปลง
///
/// เป็นทางเข้าของทั้งการโอนย้ายและการแก้ไข ตั้งใจให้เห็นที่อยู่ปัจจุบันกับ
/// ประวัติก่อนเสมอ จะได้รู้ว่าของชิ้นนี้เพิ่งถูกย้ายไปหรือยัง ก่อนย้ายซ้ำ
///
/// คืน `true` ตอนปิดหน้าเมื่อมีการเปลี่ยนแปลง หน้าลิสต์จะได้ดึงใหม่
class AssetDetailPage extends StatefulWidget {
  final String assetId;

  const AssetDetailPage({super.key, required this.assetId});

  @override
  State<AssetDetailPage> createState() => _AssetDetailPageState();
}

class _AssetDetailPageState extends State<AssetDetailPage> {
  Asset? _asset;
  List<AssetLogEvent> _log = const [];

  /// ตารางแปลรหัสสถานะในประวัติเป็นชื่อ เช่น `IN_USE` → "กำลังใช้งาน"
  ///
  /// ประวัติเก็บค่าดิบที่เคยอยู่ในฐานข้อมูล ไม่ได้เก็บชื่อตอนนั้นไว้ด้วย
  Map<String, String> _statusNames = const {};

  bool _loading = true;
  String? _error;
  bool _needLogin = false;

  /// มีการแก้ไขเกิดขึ้นในหน้านี้หรือยัง ใช้บอกหน้าลิสต์ตอนกดย้อนกลับ
  bool _changed = false;

  /// มีสิทธิ์ `TRANSFER_CREATE` ไหม ตั้งต้นเป็น true จนกว่า `/me` จะบอกว่าไม่มี
  bool _canTransfer = true;

  @override
  void initState() {
    super.initState();
    _load();
    _loadPermission();
  }

  Future<void> _loadPermission() async {
    final allowed = await canCreateTransfer();
    if (!mounted || allowed == _canTransfer) return;
    setState(() => _canTransfer = allowed);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _needLogin = false;
    });

    try {
      final asset = await fetchAsset(widget.assetId);

      // ประวัติพังไม่ควรทำให้ดูรายละเอียดไม่ได้ มันเป็นข้อมูลเสริม
      List<AssetLogEntry> log = const [];
      try {
        log = await fetchAssetLog(widget.assetId);
      } on MobileApiException {
        log = const [];
      }

      if (!mounted) return;
      setState(() {
        _asset = asset;
        _log = groupAssetLog(log);
        _loading = false;
        _error = asset == null ? 'ไม่พบทรัพย์สินรหัส ${widget.assetId}' : null;
      });

      if (asset != null) {
        _loadPlaceNames(asset);
        _loadLogNames();
      }
    } on MobileApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _needLogin = e.needLogin;
        _loading = false;
      });
    }
  }

  /// แปลงรหัสสาขากับรหัสผู้ครอบครองเป็นชื่อคน
  ///
  /// ยิงหลังจากวาดหน้าไปแล้ว ไม่รวมใน [_load] เพราะรายละเอียดทรัพย์สินต้องขึ้น
  /// ทันทีที่ได้ข้อมูล ไม่ควรรอไดเรกทอรี 66 KB โหลดเสร็จก่อน ล้มเหลวก็แค่เห็น
  /// รหัสเปล่า ๆ แบบเดิม ไม่ใช่หน้า error
  Future<void> _loadPlaceNames(Asset asset) async {
    try {
      await Future.wait([
        findAssetDept(asset.siteId),
        findAssetEmployee(asset.custodian),
      ]);
    } on MobileApiException {
      return;
    }
    if (!mounted) return;
    setState(() {});
  }

  /// หาชื่อของรหัสทุกตัวที่โผล่ในประวัติ
  ///
  /// ประวัติเก็บค่าดิบไว้ ไม่มีชื่อติดมาด้วย ต้องแปลเอง — สถานะกับประเภทดึงจาก
  /// ตาราง lookup ส่วนรหัสสาขา/พนักงานที่เคยเป็นเจ้าของของชิ้นนี้ค่อยหาทีละตัว
  /// เฉพาะรหัสที่โผล่จริง (ปกติสองสามตัว) ไม่ได้โหลดทั้งบริษัท
  Future<void> _loadLogNames() async {
    final people = <String>{};
    final sites = <String>{};

    for (final event in _log) {
      if (event.by.isNotEmpty) people.add(event.by);

      for (final change in event.changes) {
        final field = change.field.toLowerCase().replaceAll('_', '');
        final values = [change.oldValue, change.newValue].where(
          (e) => e.isNotEmpty,
        );

        if (field == 'currentcustodian') people.addAll(values);
        if (field == 'currentsiteid') sites.addAll(values);
      }
    }

    try {
      final statuses = await fetchAssetStatuses();

      // ทำทีละคนไม่ยิงพร้อมกัน เพราะ findAssetEmployee เก็บผลลง cache ร่วมกัน
      // การค้นรหัสหนึ่งมักได้คนอื่นติดมาด้วย ยิงเรียงกันจึงประหยัดรอบกว่า
      for (final id in people) {
        await findAssetEmployee(id);
      }
      for (final id in sites) {
        await findAssetDept(id);
      }

      if (!mounted) return;
      setState(() {
        _statusNames = {for (final e in statuses) e.code: e.label};
      });
    } on MobileApiException {
      // แปลไม่ได้ก็โชว์รหัสดิบไปก่อน ดีกว่าขึ้น error ทั้งหน้าเพราะประวัติ
      return;
    }
  }

  /// ชื่อพร้อมรหัสถ้าหาชื่อได้ หาไม่ได้ก็รหัสเปล่า ๆ
  ///
  /// รหัสต้องติดมาด้วยเสมอ เพราะเป็นค่าที่อยู่ในฐานข้อมูลจริงและเป็นสิ่งที่
  /// คนถือเอกสารในมือเอาไปเทียบ ชื่อมีไว้ให้อ่านออกเฉย ๆ
  String _named(String code, String name, String empty) {
    if (code.isEmpty) return empty;
    return name.isEmpty ? code : '$name ($code)';
  }

  /// สร้างใบโอนย้ายจริงโดยเลือกของชิ้นนี้ไว้ให้แล้ว
  ///
  /// การย้ายของต้องเป็นใบที่มีคนอนุมัติ ตาม Spec v3.0 — การ `PUT` เปลี่ยนสาขา
  /// ตรง ๆ เป็นแค่ "การแก้ข้อมูลให้ถูกต้อง" ซึ่งอยู่ในปุ่มแก้ไขข้อมูลแทน
  Future<void> _openTransferDoc(Asset asset) async {
    final transferNo = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => TransferCreatePage(initialAssets: [asset]),
      ),
    );
    if (transferNo == null || !mounted) return;

    _changed = true;

    // พาไปเปิดใบที่เพิ่งสร้างต่อ คนสร้างเสร็จมักต้องกดส่งอนุมัติทันที
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransferDetailPage(transferNo: transferNo),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  /// แก้ที่อยู่ให้ถูกต้องโดยไม่สร้างใบ
  ///
  /// ใช้ตอนข้อมูลในระบบผิดมาแต่แรก ไม่ใช่ตอนของย้ายจริง เช่นลงทะเบียนผิดสาขา
  /// ไว้ตั้งแต่ต้น การสร้างใบโอนย้ายให้ของที่ไม่เคยขยับจริงทำให้ประวัติเพี้ยน
  Future<void> _openCorrection(Asset asset) async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AssetTransferPage(asset: asset)),
    );
    if (done != true) return;

    _changed = true;
    await _load();
  }

  Future<void> _openEdit(Asset asset) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AssetRegisterPage(asset: asset)),
    );
    if (saved != true) return;

    _changed = true;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final asset = _asset;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: assetAppBar(context, title: asset?.id ?? widget.assetId),
        body: _body(),
        bottomNavigationBar: asset == null ? null : _actions(asset),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingStateView();

    final error = _error;
    if (error != null) {
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

    final asset = _asset!;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _header(asset),
          _placeSection(asset),
          _detailSection(asset),
          _logSection(),
        ],
      ),
    );
  }

  /// หัวหน้า: ชื่อของ รหัส และสถานะ ไม่ใส่กรอบ ให้ชื่อเป็นของที่ใหญ่สุดในหน้า
  Widget _header(Asset asset) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            asset.name.isEmpty ? asset.id : asset.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              asset.id,
              if (asset.typeLabel.isNotEmpty) asset.typeLabel,
            ].join(' · '),
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          if (asset.statusLabel.isNotEmpty) ...[
            const SizedBox(height: 10),
            AssetTag(asset.statusLabel),
          ],
        ],
      ),
    );
  }

  Widget _placeSection(Asset asset) => AssetSection(
    title: 'อยู่ที่ไหนตอนนี้',
    children: [
      AssetInfoLine(
        label: 'แผนกที่ดูแล',
        value: _named(
          asset.siteId,
          assetDeptNameOf(asset.siteId),
          'ยังไม่ระบุ',
        ),
      ),
      AssetInfoLine(
        label: 'ผู้ครอบครอง',
        value: _named(
          asset.custodian,
          assetEmployeeNameOf(asset.custodian),
          'ยังไม่ระบุ',
        ),
      ),
      AssetInfoLine(
        label: 'วันที่รับเข้า',
        value: asset.acceptDate == null
            ? null
            : assetDateLabel(asset.acceptDate!),
      ),
    ],
  );

  Widget _detailSection(Asset asset) {
    final expired = asset.warrantyExpired;
    final price = asset.purchasePrice;
    final brandModel = [
      asset.brand,
      asset.model,
    ].where((e) => e.isNotEmpty).join(' ');

    return AssetSection(
      title: 'รายละเอียด',
      children: [
        AssetInfoLine(
          label: 'S/N',
          value: asset.serialNo.isEmpty ? null : asset.serialNo,
        ),
        AssetInfoLine(label: 'ยี่ห้อ/รุ่น', value: brandModel),
        AssetInfoLine(
          label: 'วันที่ซื้อ',
          value: asset.purchaseDate == null
              ? null
              : assetDateLabel(asset.purchaseDate!),
        ),
        AssetInfoLine(
          label: 'ราคาซื้อ',
          value: price == null ? null : '$price บาท',
        ),
        AssetInfoLine(
          label: expired == true ? 'ประกันหมดแล้ว' : 'ประกันถึง',
          value: asset.warrantyExpireDate == null
              ? null
              : assetDateLabel(asset.warrantyExpireDate!),
          // สีเดียวในกลุ่มนี้ ใช้เมื่อประกันหมดจริง ๆ เท่านั้น
          valueColor: expired == true ? AppColors.danger : null,
        ),
        AssetInfoLine(
          label: 'หมายเหตุ',
          value: asset.remark.isEmpty ? null : asset.remark,
        ),
      ],
    );
  }

  Widget _logSection() => AssetSection(
    title: 'ประวัติการเปลี่ยนแปลง',
    divider: false,
    children: [
      AssetLogTimeline(events: _log, statusNames: _statusNames),
    ],
  );

  /// ปุ่มโอนย้ายเป็นตัวเด่น เพราะเป็นงานหลักของเมนูนี้ ส่วนแก้ไขข้อมูลเป็นงาน
  /// รองที่ทำนาน ๆ ครั้ง จึงเป็นปุ่มตัวหนังสือเปล่า ไม่ใช่ปุ่มมีกรอบคู่กัน
  Widget _actions(Asset asset) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              TextButton(
                onPressed: () => _openEdit(asset),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                  minimumSize: const Size(0, 48),
                ),
                child: const Text('แก้ไขข้อมูล'),
              ),
              // แก้ที่อยู่โดยไม่สร้างใบ เป็นงานนาน ๆ ครั้งของคนที่รู้ว่าข้อมูล
              // ผิดมาแต่แรก ซ่อนในเมนูไม่ให้แข่งพื้นที่กับปุ่มโอนย้ายจริง
              PopupMenuButton<String>(
                tooltip: 'เมนูเพิ่มเติม',
                onSelected: (value) {
                  if (value == 'fix') _openCorrection(asset);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'fix',
                    child: Text('แก้ที่อยู่ให้ถูกต้อง (ไม่สร้างใบ)'),
                  ),
                ],
              ),
              const Spacer(),
              if (_canTransfer)
                FilledButton.icon(
                  onPressed: () => _openTransferDoc(asset),
                  icon: const Icon(Icons.swap_horiz, size: 20),
                  label: const Text('โอนย้าย'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
