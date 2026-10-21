import 'package:flutter/material.dart';

import 'package:claim/page/asset/asset_api.dart';
import 'package:claim/page/asset/asset_approver_page.dart';
import 'package:claim/page/asset/asset_detail_page.dart';
import 'package:claim/page/asset/asset_models.dart';
import 'package:claim/page/asset/asset_register_page.dart';
import 'package:claim/page/asset/asset_style.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/app_icons.dart';
import 'package:claim/utils/mobile_api.dart';
import 'package:claim/widgets/barcode_scanner.dart';
import 'package:claim/widgets/state_views.dart';

/// หน้าหลักของระบบทรัพย์สิน: ค้นหาของที่จะโอนย้ายหรือแก้ไข
///
/// กรองและแบ่งหน้าที่ฝั่งเซิร์ฟเวอร์ทั้งหมด (`/assets` รับตัวกรองมาครบ) ไม่ได้
/// โหลดทั้งทะเบียนมากรองในเครื่องแบบระบบ PM เพราะทะเบียนโตขึ้นเรื่อย ๆ
///
/// เป็นรายการยาวที่คนกวาดตาหาของทีละสิบ ๆ ชิ้น จึงทำเป็นแถวคั่นด้วยเส้นบาง
/// ไม่ใช่การ์ดเรียงกัน — การ์ดกินความสูงต่อชิ้นเกือบเท่าตัวโดยไม่ได้บอกอะไรเพิ่ม
class AssetListPage extends StatefulWidget {
  const AssetListPage({super.key});

  @override
  State<AssetListPage> createState() => _AssetListPageState();
}

class _AssetListPageState extends State<AssetListPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  AssetQuery _query = const AssetQuery();

  List<Asset> _items = const [];
  int? _total;
  bool _hasMore = false;

  List<AssetLookup> _types = const [];
  List<AssetLookup> _statuses = const [];

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  bool _needLogin = false;

  /// รหัสแผนกที่คนกดสังกัด ใช้เป็นตัวกรอง "แผนกของฉัน" ไม่มีก็ซ่อนชิปนั้น
  ///
  /// มาจาก `/me` เท่านั้น — `PermissionService` ให้มาแค่รหัส**สาขา** ซึ่งเป็น
  /// คนละชุดรหัสกับแผนก เอามากรอง `current_site_id` จะไม่เจออะไรเลย
  String _myDeptCode = '';

  /// รหัสพนักงานของคนที่ใช้อยู่ ใช้เป็นตัวกรอง "ที่ฉันถืออยู่"
  final String _myEmpNo = MobileSession.I.empNo ?? '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
    _loadLookups();
    _loadDeptNames();
  }

  /// โหลดลิสต์แผนกไว้แปลรหัสบนการ์ดเป็นชื่อ พร้อมหาแผนกของคนกด
  ///
  /// แยกจาก [_load] เพราะรายการต้องขึ้นทันที ไม่ควรรอไดเรกทอรีโหลดเสร็จก่อน
  /// ล้มเหลวก็แค่เห็นรหัสแบบเดิม ไม่ใช่หน้า error
  Future<void> _loadDeptNames() async {
    try {
      await loadAssetDepts();

      final me = await fetchAssetProfile();
      if (!mounted) return;
      setState(() => _myDeptCode = me.deptCode);
    } on MobileApiException {
      return;
    }
    if (!mounted) return;
    setState(() {});
  }

  /// ป้ายบนชิปตัวกรองแผนก
  ///
  /// ชิปกินความกว้างจำกัด ชื่อแผนกเต็ม ๆ อย่าง "ขายกลุ่มลูกค้าธุรกิจเฉพาะ
  /// ฝ่ายขายและการตลาดกลุ่มลูกค้ารายย่อย" ยาวกว่าครึ่งจอ จึงไม่พ่วงรหัสต่อท้าย
  String _siteChipLabel(String siteId) {
    if (siteId.isNotEmpty && siteId == _myDeptCode) return 'แผนกของฉัน';

    final name = assetDeptNameOf(siteId);
    return 'แผนก ${name.isEmpty ? siteId : name}';
  }

  /// ป้ายบนชิปตัวกรองผู้ถือ
  ///
  /// ชื่อขึ้นเฉพาะเมื่อเคยหามาแล้วในรอบนี้ (เช่นเพิ่งเปิดหน้ารายละเอียดของคนนั้น)
  /// ไม่ยิงหาเพิ่มเพื่อชิปตัวเดียว
  String _custodianChipLabel(String custodian) {
    if (custodian == _myEmpNo) return 'ที่ฉันถืออยู่';

    final name = assetEmployeeNameOf(custodian);
    return 'ผู้ถือ ${name.isEmpty ? custodian : name}';
  }

  /// ที่อยู่บนการ์ด แทนรหัสสาขาด้วยชื่อเมื่อรู้จัก
  ///
  /// ไม่แปลรหัสผู้ครอบครองด้วย เพราะ `/employee` ไม่มีตัวดึงเป็นชุด หน้าหนึ่งมี
  /// 50 แถว แปลครบคือยิง 50 ครั้งบน 4G ของสาขา ชื่อคนไปดูในหน้ารายละเอียดได้
  String _placeLabelOf(Asset asset) {
    final name = assetDeptNameOf(asset.siteId);
    if (name.isEmpty) return asset.placeLabel;

    return [name, if (asset.custodian.isNotEmpty) asset.custodian].join(' · ');
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// ใกล้ถึงท้ายลิสต์แล้วค่อยขอหน้าถัดไป ไม่ต้องรอให้ผู้ใช้เลื่อนจนสุด
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 400) return;
    _loadMore();
  }

  /// ตัวเลือกของชิปกรอง โหลดไม่ได้ก็แค่ไม่มีชิปให้กด ไม่ปิดทั้งหน้า
  Future<void> _loadLookups() async {
    try {
      final types = await fetchAssetTypes();
      if (!mounted) return;
      setState(() => _types = types);
    } on MobileApiException {
      // เงียบไว้ ตัวลิสต์หลักมี error ของตัวเองอยู่แล้ว ขึ้นซ้อนกันสองที่จะงง
    }

    try {
      final statuses = await fetchAssetStatuses();
      if (!mounted) return;
      setState(() => _statuses = statuses);
    } on MobileApiException {
      // เช่นเดียวกัน
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _needLogin = false;
    });

    try {
      final result = await fetchAssets(_query.copyWith(page: 1));
      if (!mounted) return;
      setState(() {
        _query = _query.copyWith(page: 1);
        _items = result.items;
        _total = result.total;
        _hasMore = result.hasMore;
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

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_hasMore) return;
    setState(() => _loadingMore = true);

    final next = _query.copyWith(page: _query.page + 1);

    try {
      final result = await fetchAssets(next);
      if (!mounted) return;
      setState(() {
        _query = next;
        _items = [..._items, ...result.items];
        _total = result.total ?? _total;
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } on MobileApiException catch (e) {
      if (!mounted) return;
      // หน้าถัดไปพังไม่ควรล้างของที่โหลดมาแล้ว แค่บอกแล้วหยุดโหลดต่อ
      setState(() {
        _loadingMore = false;
        _hasMore = false;
      });
      _toast(e.message);
    }
  }

  /// เปลี่ยนตัวกรองแล้วเริ่มนับหน้าใหม่เสมอ ไม่งั้นจะได้หน้า 3 ของผลชุดใหม่
  void _applyFilter(AssetQuery query) {
    setState(() => _query = query.copyWith(page: 1));
    _load();
  }

  Future<void> _scanToSearch() async {
    final code = await openBarcodeScannerPage(
      context,
      title: 'สแกนรหัสทรัพย์สิน',
      hint: 'วางบาร์โค้ดบนตัวเครื่องให้อยู่กลางจอ',
    );
    if (code == null || !mounted) return;

    _searchController.text = code;
    _applyFilter(_query.copyWith(keyword: code));
  }

  Future<void> _openDetail(Asset asset) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AssetDetailPage(assetId: asset.id)),
    );
    // กลับมาพร้อมของที่เปลี่ยนแล้ว ต้องดึงใหม่ ไม่งั้นแถวยังโชว์สาขาเดิม
    if (changed == true) await _load();
  }

  Future<void> _openRegister() async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AssetRegisterPage()));
    if (saved == true) await _load();
  }

  /// ไม่ต้องดึงทะเบียนใหม่หลังกลับมา การตั้งผู้อนุมัติไม่แตะข้อมูลทรัพย์สิน
  Future<void> _openApprovers() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const AssetApproverPage()));

  Future<void> _pickLookup({
    required String title,
    required List<AssetLookup> items,
    required String selected,
    required ValueChanged<String> onPicked,
  }) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: AssetSectionTitle(title),
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text('ทั้งหมด'),
              trailing: selected.isEmpty ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, ''),
            ),
            for (final item in items)
              ListTile(
                title: Text(item.detailLabel),
                trailing: selected == item.code
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(ctx, item.code),
              ),
          ],
        ),
      ),
    );

    if (picked == null) return;
    onPicked(picked);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: assetAppBar(
        context,
        title: 'ทะเบียนทรัพย์สิน',
        actions: [
          IconButton(
            tooltip: 'เพิ่มทรัพย์สิน',
            onPressed: _openRegister,
            icon: const Icon(Icons.add),
          ),
          // ตั้งผู้อนุมัติเป็นงานตั้งค่าที่ทำปีละไม่กี่ครั้ง ซ่อนในเมนูสามจุดได้
          // ต่างจากใบโอนย้ายซึ่งเป็นงานประจำวัน — อันนั้นย้ายขึ้นไปเป็นแถบบน
          // หน้าหลักแล้ว ไม่ต้องกดเข้ามาที่นี่ก่อนสามที
          //
          // ⚠️ ยังไม่ได้กั้นสิทธิ์ — `/me` ไม่มี permission ของงาน admin มาให้
          // (มีแค่ ASSET_* กับ TRANSFER_*) ต้องรอ backend เพิ่มมาก่อน
          PopupMenuButton<String>(
            tooltip: 'เมนูเพิ่มเติม',
            onSelected: (value) {
              if (value == 'approver') _openApprovers();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'approver',
                child: Text('ผู้อนุมัติแต่ละแผนก'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _searchBar(),
          _activeFilterBar(),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _searchBar() {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(child: _searchField(scheme)),
          const SizedBox(width: 8),
          _filterButton(),
        ],
      ),
    );
  }

  Widget _searchField(ColorScheme scheme) {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: (value) =>
          _applyFilter(_query.copyWith(keyword: value.trim())),
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'ค้นรหัส ชื่อ S/N หรือผู้ครอบครอง',
        hintStyle: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
        prefixIcon: Icon(Icons.search, color: scheme.onSurfaceVariant),
        isDense: true,
        // ช่องค้นหาไม่ต้องเน้นด้วยสี แค่ให้รู้ว่าพิมพ์ตรงนี้ได้
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.innerRadius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.innerRadius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_query.keyword.isNotEmpty || _searchController.text.isNotEmpty)
              IconButton(
                tooltip: 'ล้างคำค้น',
                onPressed: () {
                  _searchController.clear();
                  _applyFilter(_query.copyWith(keyword: ''));
                },
                icon: const Icon(Icons.close, size: 18),
                color: scheme.onSurfaceVariant,
              ),
            if (canScanBarcode)
              IconButton(
                tooltip: 'สแกนบาร์โค้ด',
                onPressed: _scanToSearch,
                icon: const Icon(AppIcons.scan, size: 20),
                color: scheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  /// ปุ่มเปิดแผ่นตัวกรอง มีตัวเลขบอกว่าตอนนี้เปิดอยู่กี่ตัว
  ///
  /// ยุบชิปหกตัวที่เคยเรียงอยู่ใต้ช่องค้นหามาไว้ในปุ่มเดียว รายการได้ความสูง
  /// คืนไปเกือบหนึ่งแถว และไม่ต้องเลื่อนแถบชิปไปทางขวาเพื่อหาตัวที่ต้องการ
  Widget _filterButton() {
    final scheme = Theme.of(context).colorScheme;
    final count = _query.filterCount;

    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      child: OutlinedButton.icon(
        onPressed: _openFilterSheet,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.innerRadius),
          ),
          side: BorderSide(
            color: count > 0 ? scheme.primary : scheme.outlineVariant,
            width: count > 0 ? 1.5 : 1,
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        icon: const Icon(Icons.tune, size: 18),
        label: const Text('กรอง'),
      ),
    );
  }

  /// แถบชิปของตัวกรองที่เปิดอยู่ กดกากบาทเอาออกทีละตัวได้
  ///
  /// จำเป็นเมื่อตัวกรองไปซ่อนอยู่ในแผ่น ถ้าไม่โชว์ตรงนี้ คนที่เปิดหน้ามาเจอ
  /// รายการน้อยผิดปกติจะไม่รู้ว่ามีตัวกรองค้างอยู่จากครั้งก่อน
  Widget _activeFilterBar() {
    final query = _query;
    if (query.filterCount == 0) return const SizedBox.shrink();

    final chips = <Widget>[
      if (query.typeId.isNotEmpty)
        _activeChip(
          _labelOf(_types, query.typeId, query.typeId),
          () => _applyFilter(query.copyWith(typeId: '')),
        ),
      if (query.statusId.isNotEmpty)
        _activeChip(
          _labelOf(_statuses, query.statusId, query.statusId),
          () => _applyFilter(query.copyWith(statusId: '')),
        ),
      if (query.siteId.isNotEmpty)
        _activeChip(
          _siteChipLabel(query.siteId),
          () => _applyFilter(query.copyWith(siteId: '')),
        ),
      if (query.custodian.isNotEmpty)
        _activeChip(
          _custodianChipLabel(query.custodian),
          () => _applyFilter(query.copyWith(custodian: '')),
        ),
      if (query.warrantyExpiring)
        _activeChip(
          'ใกล้หมดประกัน',
          () => _applyFilter(query.copyWith(warrantyExpiring: false)),
        ),
      if (query.incompleteOnly)
        _activeChip(
          'ข้อมูลไม่ครบ',
          () => _applyFilter(query.copyWith(incompleteOnly: false)),
        ),
      if (query.includeInactive)
        _activeChip(
          'รวมของที่ปิดใช้งาน',
          () => _applyFilter(query.copyWith(includeInactive: false)),
        ),
    ];

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) => chips[index],
      ),
    );
  }

  Widget _activeChip(String label, VoidCallback onRemove) {
    final scheme = Theme.of(context).colorScheme;

    return InputChip(
      label: Text(label),
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close, size: 16),
      backgroundColor: scheme.primary.withValues(alpha: 0.08),
      side: BorderSide(color: scheme.primary.withValues(alpha: 0.5)),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  /// แผ่นตัวกรองทั้งหมด
  ///
  /// แก้ลงสำเนา ([draft]) แล้วค่อยยิงตอนกด "ใช้ตัวกรอง" ครั้งเดียว ไม่ยิงทุกครั้ง
  /// ที่แตะสวิตช์ ไม่งั้นคนที่เปิดสามตัวกรองจะเสียเวลารอผลโหลดสามรอบ
  Future<void> _openFilterSheet() async {
    var draft = _query;

    final applied = await showModalBottomSheet<AssetQuery>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          void update(AssetQuery next) => setSheet(() => draft = next);

          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: AssetSectionTitle('ตัวกรอง'),
                ),
                _sheetPickRow(
                  label: 'ประเภท',
                  value: _labelOf(_types, draft.typeId, 'ทั้งหมด'),
                  items: _types,
                  onTap: () => _pickLookup(
                    title: 'ประเภททรัพย์สิน',
                    items: _types,
                    selected: draft.typeId,
                    onPicked: (code) => update(draft.copyWith(typeId: code)),
                  ),
                ),
                _sheetPickRow(
                  label: 'สถานะ',
                  value: _labelOf(_statuses, draft.statusId, 'ทั้งหมด'),
                  items: _statuses,
                  onTap: () => _pickLookup(
                    title: 'สถานะทรัพย์สิน',
                    items: _statuses,
                    selected: draft.statusId,
                    onPicked: (code) => update(draft.copyWith(statusId: code)),
                  ),
                ),
                const Divider(height: 1),
                if (_myDeptCode.isNotEmpty)
                  _sheetSwitch(
                    label: 'เฉพาะแผนกของฉัน ($_myDeptCode)',
                    value: draft.siteId.isNotEmpty,
                    onChanged: (on) =>
                        update(draft.copyWith(siteId: on ? _myDeptCode : '')),
                  ),
                if (_myEmpNo.isNotEmpty)
                  _sheetSwitch(
                    label: 'เฉพาะที่ฉันถืออยู่',
                    value: draft.custodian.isNotEmpty,
                    onChanged: (on) =>
                        update(draft.copyWith(custodian: on ? _myEmpNo : '')),
                  ),
                _sheetSwitch(
                  label: 'ใกล้หมดประกัน',
                  value: draft.warrantyExpiring,
                  onChanged: (on) =>
                      update(draft.copyWith(warrantyExpiring: on)),
                ),
                _sheetSwitch(
                  label: 'ข้อมูลไม่ครบ',
                  note: 'ของที่ยังกรอกไม่ครบทุกช่อง ไว้ตามเก็บตก',
                  value: draft.incompleteOnly,
                  onChanged: (on) => update(draft.copyWith(incompleteOnly: on)),
                ),
                _sheetSwitch(
                  label: 'รวมของที่ปิดใช้งานแล้ว',
                  value: draft.includeInactive,
                  onChanged: (on) =>
                      update(draft.copyWith(includeInactive: on)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: draft.filterCount == 0
                            ? null
                            : () =>
                                  Navigator.pop(sheetContext, draft.cleared()),
                        child: const Text('ล้างทั้งหมด'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, draft),
                        child: const Text('ใช้ตัวกรอง'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (applied == null) return;
    _applyFilter(applied);
  }

  /// แถวเลือกค่าจากลิสต์ในแผ่นตัวกรอง
  ///
  /// [items] ว่างแปลว่าโหลดลิสต์นั้นไม่สำเร็จ กดไม่ได้และบอกเหตุผลไว้ ไม่ใช่
  /// ซ่อนแถวไปเฉย ๆ จะได้รู้ว่ามีตัวกรองนี้อยู่แต่ตอนนี้ใช้ไม่ได้
  Widget _sheetPickRow({
    required String label,
    required String value,
    required List<AssetLookup> items,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = items.isNotEmpty;

    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 15)),
      subtitle: enabled
          ? null
          : Text(
              'โหลดรายการไม่ได้',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            enabled ? value : '-',
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 18, color: scheme.outline),
        ],
      ),
      onTap: enabled ? onTap : null,
    );
  }

  Widget _sheetSwitch({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? note,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 15)),
      subtitle: note == null
          ? null
          : Text(
              note,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
      value: value,
      onChanged: onChanged,
      dense: true,
    );
  }

  /// ชื่อที่โชว์ของรหัสที่เลือกไว้ ไม่ได้เลือกก็ใช้ข้อความสำรอง
  String _labelOf(List<AssetLookup> items, String code, String fallback) {
    if (code.isEmpty) return fallback;
    for (final item in items) {
      if (item.code == code) return item.label;
    }
    return code;
  }

  Widget _body() {
    if (_loading) return const ListLoadingView();

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

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(top: 60),
          children: [
            EmptyStateView(
              message: _query.hasFilter
                  ? 'ไม่พบทรัพย์สินตามที่ค้น ลองล้างตัวกรองดู'
                  : 'ยังไม่มีทรัพย์สินในทะเบียน กดปุ่ม + เพื่อเพิ่ม',
              icon: Icons.inventory_2_outlined,
            ),
          ],
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        itemCount: _items.length + 1,
        separatorBuilder: (_, index) => index >= _items.length - 1
            ? const SizedBox.shrink()
            : Divider(height: 1, indent: 16, color: scheme.outlineVariant),
        itemBuilder: (context, index) {
          if (index == _items.length) return _footer();
          return _assetRow(_items[index]);
        },
      ),
    );
  }

  /// ท้ายลิสต์: บอกว่ากำลังโหลดต่อ หรือบอกยอดรวมเมื่อหมดแล้ว
  Widget _footer() {
    final scheme = Theme.of(context).colorScheme;

    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final total = _total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      child: Text(
        total == null
            ? 'แสดง ${_items.length} รายการ'
            : 'แสดง ${_items.length} จาก $total รายการ',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
    );
  }

  /// หนึ่งแถวในทะเบียน
  ///
  /// สามบรรทัดคงที่: ชื่อ / รหัส + ประเภท / ที่อยู่ เรียงตามลำดับที่คนใช้ตามหา
  /// จริง ๆ (รู้ชื่อ → ยืนยันด้วยรหัส → เช็คว่าอยู่ไหน) บรรทัดเตือนเรื่องประกัน
  /// โผล่เฉพาะตอนหมดแล้ว และเป็นที่เดียวในแถวที่มีสี
  Widget _assetRow(Asset asset) {
    final scheme = Theme.of(context).colorScheme;
    final expired = asset.warrantyExpired == true;

    final subtitle = [
      asset.id,
      if (asset.typeLabel.isNotEmpty) asset.typeLabel,
    ].join(' · ');

    return InkWell(
      onTap: () => _openDetail(asset),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.name.isEmpty ? asset.id : asset.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _placeLabelOf(asset),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                  if (expired)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'ประกันหมดแล้ว ${assetDateLabel(asset.warrantyExpireDate!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AssetTag(asset.statusLabel),
                const SizedBox(height: 6),
                Icon(Icons.chevron_right, size: 18, color: scheme.outline),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
