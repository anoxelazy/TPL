/// ช่องเลือกสาขาและเลือกพนักงานของระบบทรัพย์สิน
///
/// ก่อนหน้านี้สองช่องนี้เป็นช่องพิมพ์รหัสเปล่า ๆ พิมพ์ `BKK01` แทน `BKK10`
/// ก็บันทึกผ่าน เพราะ schema ฝั่งส่งเช็คแค่ความยาว ของก็ไปอยู่สาขาที่ไม่มีจริง
/// โดยไม่มีอะไรฟ้อง endpoint `/branch` กับ `/employee` ที่เพิ่งมาทำให้เลือก
/// จากรายการจริงได้
///
/// เป็น bottom sheet ไม่ใช่หน้าของตัวเอง ด้วยเหตุผลเดียวกับ [showAssetTypeDialog]
/// คนที่เปิดมากำลังกรอกฟอร์มค้างอยู่ พาออกไปทั้งหน้าแล้วกลับมาที่กรอกไว้จะหาย
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:claim/page/asset/asset_api.dart';
import 'package:claim/page/asset/asset_models.dart';
import 'package:claim/utils/mobile_api.dart';
import 'package:claim/widgets/state_views.dart';

/// เลือกสาขา คืน null เมื่อปิดไปเฉย ๆ
Future<AssetBranch?> pickAssetBranch(
  BuildContext context, {
  String currentId = '',
}) {
  return _showPickerSheet<AssetBranch>(
    context,
    title: 'เลือกสาขา/สถานที่',
    hint: 'พิมพ์ชื่อสาขา จังหวัด หรือรหัส',
    body: (query) => _BranchList(query: query, currentId: currentId),
  );
}

/// เลือกแผนก คืน null เมื่อปิดไปเฉย ๆ
///
/// ใช้กับช่อง `current_site_id` ของทรัพย์สิน ซึ่งเก็บรหัส**แผนก**ไม่ใช่สาขา
/// แม้ชื่อช่องจะอ่านว่า site — อย่าสลับกับ [pickAssetBranch] ที่ใช้กับ
/// `to_site_id` ของใบโอนย้าย อันนั้นเป็นสาขาจริง ๆ
Future<AssetDept?> pickAssetDept(
  BuildContext context, {
  String currentId = '',
}) {
  return _showPickerSheet<AssetDept>(
    context,
    title: 'เลือกแผนก',
    hint: 'พิมพ์ชื่อแผนกหรือรหัสแผนก',
    body: (query) => _DeptList(query: query, currentId: currentId),
  );
}

/// เลือกพนักงาน คืน null เมื่อปิดไปเฉย ๆ
///
/// [branchId] จำกัดให้เห็นเฉพาะคนในสาขานั้น ส่งมาตอนเลือกผู้ครอบครองหลังจาก
/// เลือกสาขาปลายทางไปแล้ว — ของที่ย้ายไปสาขาหนึ่งมักถูกคนในสาขานั้นรับไว้
Future<AssetEmployee?> pickAssetEmployee(
  BuildContext context, {
  String currentId = '',
  String branchId = '',
  String permCode = '',
  String title = 'เลือกผู้ครอบครอง',
}) {
  return _showPickerSheet<AssetEmployee>(
    context,
    title: title,
    hint: 'พิมพ์ชื่อหรือรหัสพนักงาน',
    body: (query) => _EmployeeList(
      query: query,
      currentId: currentId,
      branchId: branchId,
      permCode: permCode,
    ),
  );
}

/// โครงร่วมของช่องเลือกทั้งสองแบบ: หัวเรื่อง ช่องค้น แล้วก็รายการ
///
/// สูง 85% ของจอตายตัว ไม่ให้ยืดหดตามจำนวนรายการ เพราะรายการเปลี่ยนทุกครั้งที่
/// พิมพ์ ปล่อยให้ยืดหดแล้วแผ่นจะกระตุกขึ้นลงใต้นิ้วที่กำลังพิมพ์อยู่
Future<T?> _showPickerSheet<T>(
  BuildContext context, {
  required String title,
  required String hint,
  required Widget Function(String query) body,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PickerSheet(title: title, hint: hint, body: body),
  );
}

class _PickerSheet extends StatefulWidget {
  final String title;
  final String hint;
  final Widget Function(String query) body;

  const _PickerSheet({
    required this.title,
    required this.hint,
    required this.body,
  });

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.85,
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'ปิด',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _search,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  prefixIcon: const Icon(Icons.search),
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
                  isDense: true,
                ),
              ),
            ),
            Expanded(child: widget.body(_query)),
          ],
        ),
      ),
    );
  }
}

/// รายการสาขา — โหลดทั้งก้อนครั้งเดียวแล้วกรองในเครื่อง
///
/// 260 สาขากรองในเครื่องได้สบายและตอบสนองทันทีทุกตัวอักษร ไม่ต้องหน่วงรอพิมพ์จบ
class _BranchList extends StatefulWidget {
  final String query;
  final String currentId;

  const _BranchList({required this.query, required this.currentId});

  @override
  State<_BranchList> createState() => _BranchListState();
}

class _BranchListState extends State<_BranchList> {
  List<AssetBranch> _all = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final branches = await loadAssetBranches(refresh: refresh);
      if (!mounted) return;
      setState(() {
        _all = branches;
        _loading = false;
      });
    } on MobileApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  List<AssetBranch> get _shown {
    final query = widget.query.trim().toLowerCase();
    if (query.isEmpty) return _all;

    // แยกเป็นคำ ๆ แล้วต้องเจอครบทุกคำ คนพิมพ์ "hub ขอนแก่น" คาดว่าจะเจอแถวเดียว
    // ไม่ใช่ทุกสาขาที่มีคำว่า hub บวกทุกสาขาในขอนแก่น
    final words = query.split(RegExp(r'\s+')).where((e) => e.isNotEmpty);

    return _all
        .where((branch) => words.every(branch.searchIndex.contains))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const ListLoadingView();

    final error = _error;
    if (error != null) {
      return ErrorStateView(message: error, onRetry: () => _load(refresh: true));
    }

    final shown = _shown;
    if (shown.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 48),
        child: EmptyStateView(
          message: 'ไม่พบสาขาที่ตรงกับที่ค้น',
          icon: Icons.store_outlined,
        ),
      );
    }

    return ListView.builder(
      itemCount: shown.length,
      itemBuilder: (context, index) {
        final branch = shown[index];

        return _PickerRow(
          title: branch.name.isEmpty ? branch.id : branch.name,
          code: branch.id,
          subtitle: branch.placeLabel,
          // สาขาที่ไม่มีคนประจำเลือกได้ แต่บอกไว้ก่อน ส่วนใหญ่ที่เลือกโดนคือ
          // สาขาปิดที่ชื่อคล้ายกับสาขาที่เปิดอยู่
          note: branch.staffCount == 0 ? 'ไม่มีพนักงานประจำ' : '',
          selected: branch.id == widget.currentId,
          onTap: () => Navigator.of(context).pop(branch),
        );
      },
    );
  }
}

/// รายการแผนก — โหลดทั้งก้อนครั้งเดียวแล้วกรองในเครื่อง
///
/// กรองในเครื่องเพราะ `keyword` ของ `/deptlist` ค้นได้แค่ในชุด 100 แถวที่ถูก
/// ตัดมาแล้ว ส่งไปก็ไม่เจอของที่ถูกตัดอยู่ดี
class _DeptList extends StatefulWidget {
  final String query;
  final String currentId;

  const _DeptList({required this.query, required this.currentId});

  @override
  State<_DeptList> createState() => _DeptListState();
}

class _DeptListState extends State<_DeptList> {
  List<AssetDept> _all = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final depts = await loadAssetDepts(refresh: refresh);
      if (!mounted) return;
      setState(() {
        _all = depts;
        _loading = false;
      });
    } on MobileApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  List<AssetDept> get _shown {
    final query = widget.query.trim().toLowerCase();
    if (query.isEmpty) return _all;

    final words = query.split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    return _all.where((dept) => words.every(dept.searchIndex.contains)).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const ListLoadingView();

    final error = _error;
    if (error != null) {
      return ErrorStateView(message: error, onRetry: () => _load(refresh: true));
    }

    final shown = _shown;
    if (shown.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 48),
        child: EmptyStateView(
          message: 'ไม่พบแผนกที่ตรงกับที่ค้น',
          icon: Icons.apartment_outlined,
        ),
      );
    }

    return ListView.builder(
      itemCount: shown.length,
      itemBuilder: (context, index) {
        final dept = shown[index];

        return _PickerRow(
          title: dept.name.isEmpty ? dept.code : dept.name,
          code: dept.code,
          subtitle: dept.staffCount > 0 ? 'พนักงาน ${dept.staffCount} คน' : '',
          selected: dept.code == widget.currentId,
          onTap: () => Navigator.of(context).pop(dept),
        );
      },
    );
  }
}

/// รายการพนักงาน — ให้เซิร์ฟเวอร์ค้น หน่วงรอให้พิมพ์หยุดก่อนถึงยิง
class _EmployeeList extends StatefulWidget {
  final String query;
  final String currentId;
  final String branchId;

  /// เหลือแค่คนที่มีสิทธิ์นี้ เช่น `TRANSFER_RECEIVE` ว่าง = ไม่กรอง
  final String permCode;

  const _EmployeeList({
    required this.query,
    required this.currentId,
    required this.branchId,
    this.permCode = '',
  });

  @override
  State<_EmployeeList> createState() => _EmployeeListState();
}

class _EmployeeListState extends State<_EmployeeList> {
  /// รอให้พิมพ์หยุดเท่านี้ก่อนค่อยยิง ยิงทุกตัวอักษรบน 4G ของสาขาแปลว่า
  /// ผลของคำที่พิมพ์ไปแล้วจะทยอยกลับมาทับกันเอง
  static const _debounce = Duration(milliseconds: 350);

  Timer? _timer;

  /// รอบการค้นล่าสุด ใช้ทิ้งผลของรอบเก่าที่กลับมาช้ากว่ารอบใหม่
  int _round = 0;

  /// สาขาที่กำลังจำกัดอยู่ ว่าง = ค้นทุกสาขา
  ///
  /// แยกจาก `widget.branchId` เพราะกดขยายเป็นทุกสาขาได้จากในลิสต์ การจำกัด
  /// ตามสาขาปลายทางเดาถูกเกือบทุกครั้ง แต่ครั้งที่เดาผิดต้องมีทางออก ไม่ใช่
  /// ต้องปิดแผ่นไปล้างช่องสาขาก่อนแล้วค่อยกลับเข้ามาใหม่
  late String _branchId = widget.branchId;

  List<AssetEmployee> _rows = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search(immediate: true);
  }

  @override
  void didUpdateWidget(_EmployeeList old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _search();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// เลิกจำกัดตามสาขาแล้วค้นใหม่ทันที คนที่กดปุ่มนี้รอผลอยู่ ไม่ต้องหน่วง
  void _widenToAllBranches() {
    setState(() => _branchId = '');
    _search(immediate: true);
  }

  void _search({bool immediate = false}) {
    _timer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
    });

    if (immediate) {
      _run();
      return;
    }
    _timer = Timer(_debounce, _run);
  }

  Future<void> _run() async {
    final round = ++_round;

    try {
      final rows = await searchAssetEmployees(
        keyword: widget.query,
        branchId: _branchId,
        permCode: widget.permCode,
      );
      if (!mounted || round != _round) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } on MobileApiException catch (e) {
      if (!mounted || round != _round) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const ListLoadingView();

    final error = _error;
    if (error != null) {
      return ErrorStateView(message: error, onRetry: () async => _run());
    }

    if (_rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Column(
          children: [
            EmptyStateView(
              message: _branchId.isEmpty
                  ? 'ไม่พบพนักงานที่ตรงกับที่ค้น'
                  : 'ไม่พบพนักงานที่ตรงกับที่ค้นในสาขา $_branchId',
              icon: Icons.person_search_outlined,
            ),
            if (_branchId.isNotEmpty) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _widenToAllBranches,
                icon: const Icon(Icons.travel_explore, size: 18),
                label: const Text('ค้นทุกสาขา'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _rows.length + (_branchId.isEmpty ? 0 : 1),
      itemBuilder: (context, index) {
        // แถวท้ายสุดบอกว่ากำลังเห็นแค่สาขาเดียวอยู่ ไม่ได้ขึ้นข้างบนเพราะคน
        // ส่วนใหญ่เจอคนที่หาในแถวแรก ๆ แล้วไม่ต้องอ่านอะไรเพิ่ม
        if (index == _rows.length) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: TextButton.icon(
              onPressed: _widenToAllBranches,
              icon: const Icon(Icons.travel_explore, size: 18),
              label: Text('เห็นเฉพาะสาขา $_branchId · ค้นทุกสาขา'),
            ),
          );
        }

        final employee = _rows[index];

        return _PickerRow(
          title: employee.fullName.isEmpty ? employee.id : employee.fullName,
          code: employee.id,
          subtitle: employee.roleLabel,
          selected: employee.id == widget.currentId,
          onTap: () => Navigator.of(context).pop(employee),
        );
      },
    );
  }
}

/// หนึ่งบรรทัดในช่องเลือก หน้าตาเดียวกันทั้งสาขาและพนักงาน
class _PickerRow extends StatelessWidget {
  final String title;
  final String code;
  final String subtitle;
  final String note;
  final bool selected;
  final VoidCallback onTap;

  const _PickerRow({
    required this.title,
    required this.code,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.note = '',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      dense: true,
      selected: selected,
      onTap: onTap,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [code, if (subtitle.isNotEmpty) subtitle].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
      trailing: selected
          ? Icon(Icons.check, size: 20, color: scheme.primary)
          : note.isEmpty
          ? null
          : Text(
              note,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
    );
  }
}

/// ช่องที่หน้าตาเหมือนช่องกรอกแต่กดแล้วเปิดลิสต์ให้เลือกแทนที่จะขึ้นคีย์บอร์ด
///
/// ใช้ [InputDecorator] ไม่ใช่ `TextFormField` ที่ `readOnly` เพราะช่องนี้ต้อง
/// โชว์สองบรรทัด (ชื่อกับรหัส) ซึ่งช่องกรอกจริงทำไม่ได้ และไม่มีอะไรให้พิมพ์
/// อยู่แล้ว การมี controller ค้างไว้มีแต่จะทำให้คนอ่านโค้ดเข้าใจผิด
class AssetPickerField extends StatelessWidget {
  final String label;

  /// ข้อความตอนยังไม่ได้เลือก
  final String hint;

  /// รหัสที่เลือกอยู่ ว่าง = ยังไม่ได้เลือก
  final String code;

  /// ชื่อที่หามาได้จากรหัส ว่างได้ (ยังโหลดไม่เสร็จ หรือรหัสไม่มีในระบบแล้ว)
  final String name;

  /// กำลังหาชื่อจากรหัสอยู่ โชว์วงกลมหมุนเล็ก ๆ แทนที่จะโชว์รหัสเปล่า ๆ วาบหนึ่ง
  final bool resolving;

  /// หาชื่อไม่ได้เพราะยิง API ไม่ผ่าน คนละเรื่องกับหาแล้วไม่เจอ
  ///
  /// อย่างหลังแปลว่ารหัสผิดจริง ต้องเตือน อย่างแรกแปลว่าไม่มีเน็ตหรือยังไม่ได้
  /// ล็อกอิน รหัสอาจถูกอยู่ก็ได้ เตือนไปจะทำให้คนแก้ของที่ไม่ได้พัง
  final bool lookupFailed;

  final bool enabled;
  final IconData icon;
  final VoidCallback onTap;

  /// ล้างค่า ไม่ส่งมา = ล้างไม่ได้
  final VoidCallback? onClear;

  const AssetPickerField({
    super.key,
    required this.label,
    required this.code,
    required this.onTap,
    this.hint = 'แตะเพื่อเลือก',
    this.name = '',
    this.resolving = false,
    this.lookupFailed = false,
    this.enabled = true,
    this.icon = Icons.expand_more,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = code.trim().isEmpty;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          suffixIcon: empty || onClear == null
              ? Icon(icon, size: 20, color: scheme.onSurfaceVariant)
              : IconButton(
                  tooltip: 'ล้าง',
                  onPressed: enabled ? onClear : null,
                  icon: const Icon(Icons.clear, size: 18),
                  color: scheme.onSurfaceVariant,
                ),
        ),
        child: _value(scheme, empty),
      ),
    );
  }

  Widget _value(ColorScheme scheme, bool empty) {
    if (empty) {
      return Text(
        hint,
        style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
      );
    }

    // รหัสมาก่อนชื่อเสมอ เพราะรหัสคือค่าที่ถูกบันทึกจริง คนที่กำลังตรวจทานกับ
    // เอกสารในมือมองหารหัส ส่วนชื่อมีไว้ยืนยันว่าหยิบถูกตัว
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          code,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        if (resolving)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else if (name.isNotEmpty)
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          )
        else if (!lookupFailed)
          // รหัสที่หาชื่อไม่เจอคือรหัสที่พิมพ์ผิดไว้ก่อนหน้านี้ หรือสาขา/คนที่ถูก
          // ลบออกจากระบบไปแล้ว ทั้งสองอย่างคนกรอกควรรู้ ไม่ใช่ปล่อยเงียบ
          Text(
            'ไม่พบรหัสนี้ในระบบ',
            style: TextStyle(fontSize: 12, color: scheme.error),
          ),
      ],
    );
  }
}
