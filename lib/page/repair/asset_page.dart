import 'package:flutter/material.dart';

import 'package:claim/page/repair/asset_form_page.dart';
import 'package:claim/page/repair/asset_tile.dart';
import 'package:claim/page/repair/repair_api.dart';
import 'package:claim/utils/app_icons.dart';
import 'package:claim/utils/role_service.dart';
import 'package:claim/widgets/barcode_scanner.dart';
import 'package:claim/widgets/state_views.dart';

/// ทะเบียนเครื่องคอมพิวเตอร์ ดูได้ทุกคน เพิ่ม/แก้/ลบเฉพาะ IT
class AssetPage extends StatefulWidget {
  const AssetPage({super.key});

  @override
  State<AssetPage> createState() => _AssetPageState();
}

class _AssetPageState extends State<AssetPage> {
  final _searchController = TextEditingController();

  List<RepairAsset> _assets = [];
  bool _isLoading = true;
  String? _error;
  String _query = '';

  bool get _isIt => RoleService.I.isIt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final assets = await fetchAssets();
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<RepairAsset> get _filtered {
    final keyword = _query.trim().toLowerCase();
    if (keyword.isEmpty) return _assets;
    return _assets.where((a) => a.searchIndex.contains(keyword)).toList();
  }

  Future<void> _openForm({RepairAsset? asset}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AssetFormPage(asset: asset)),
    );
    if (changed == true) await _load();
  }

  Future<void> _scanToSearch() async {
    final code = await openBarcodeScannerPage(
      context,
      title: 'สแกนเครื่อง',
      hint: 'วาง QR หรือบาร์โค้ดบนเครื่องให้อยู่กลางจอ',
    );
    if (code == null || !mounted) return;

    final sn = snFromScannedCode(code);
    _searchController.text = sn;
    setState(() => _query = sn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ทะเบียนเครื่อง')),
      floatingActionButton: _isIt
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มเครื่อง'),
            )
          : null,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: _body(),
      ),
    );
  }

  Widget _body() {
    if (_isLoading) return const LoadingStateView();

    final error = _error;
    if (error != null) return ErrorStateView(message: error, onRetry: _load);

    if (_assets.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            EmptyStateView(
              icon: Icons.devices_other,
              message: 'ยังไม่มีเครื่องในทะเบียน',
            ),
          ],
        ),
      );
    }

    final list = _filtered;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemCount: list.isEmpty ? 2 : list.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) return _searchField();
          if (list.isEmpty) {
            return const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyStateView(
                icon: Icons.search_off,
                message: 'ไม่พบเครื่องที่ค้นหา',
              ),
            );
          }
          final asset = list[index - 1];
          return AssetTile(
            asset: asset,
            onTap: () => _openForm(asset: asset),
          );
        },
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value),
      decoration: InputDecoration(
        hintText: 'ค้นหา S/N รหัสทรัพย์สิน ยี่ห้อ แผนก',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_query.isNotEmpty)
              IconButton(
                tooltip: 'ล้าง',
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                icon: const Icon(Icons.close),
              ),
            if (canScanBarcode)
              IconButton(
                tooltip: 'สแกน',
                onPressed: _scanToSearch,
                icon: const Icon(AppIcons.scan),
              ),
          ],
        ),
      ),
    );
  }
}
