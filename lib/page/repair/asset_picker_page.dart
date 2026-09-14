import 'package:flutter/material.dart';

import 'package:claim/page/repair/asset_tile.dart';
import 'package:claim/page/repair/repair_api.dart';
import 'package:claim/utils/app_icons.dart';
import 'package:claim/widgets/barcode_scanner.dart';
import 'package:claim/widgets/state_views.dart';

/// เลือกเครื่องจากทะเบียน คืนเครื่องที่เลือก หรือ null เมื่อกดย้อนกลับ
///
/// แจ้งซ่อมได้เฉพาะเครื่องที่อยู่ในทะเบียน จึงไม่มีทางกรอกชื่อเครื่องเอง
/// ต้องผ่านหน้านี้เท่านั้น เครื่องที่ยังไม่มีในทะเบียนต้องให้ IT เพิ่มก่อน
Future<RepairAsset?> pickAssetFromRegistry(BuildContext context) {
  return Navigator.of(context).push<RepairAsset>(
    MaterialPageRoute(builder: (_) => const AssetPickerPage()),
  );
}

class AssetPickerPage extends StatefulWidget {
  const AssetPickerPage({super.key});

  @override
  State<AssetPickerPage> createState() => _AssetPickerPageState();
}

class _AssetPickerPageState extends State<AssetPickerPage> {
  final _searchController = TextEditingController();

  List<RepairAsset> _assets = [];
  bool _isLoading = true;
  String? _error;
  String _query = '';

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

  /// สแกนแล้วเอา S/N ไปใส่ช่องค้นหา ไม่เลือกให้ทันที
  ///
  /// ให้ผู้ใช้เห็นก่อนว่าเครื่องที่สแกนได้คือเครื่องไหนในทะเบียน แล้วค่อยกดเลือก
  /// เผื่อกรณีสแกนผิดใบหรือ QR ติดผิดเครื่อง
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
      appBar: AppBar(title: const Text('เลือกเครื่องที่จะแจ้งซ่อม')),
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
              message:
                  'ยังไม่มีเครื่องในทะเบียน\nกรุณาแจ้งฝ่าย IT ให้เพิ่มเครื่องก่อน',
            ),
          ],
        ),
      );
    }

    final list = _filtered;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: list.isEmpty ? 2 : list.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) return _searchField();
          if (list.isEmpty) {
            return const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyStateView(
                icon: Icons.search_off,
                message:
                    'ไม่พบเครื่องที่ค้นหา\nถ้าเครื่องนี้ยังไม่มีในทะเบียน '
                    'กรุณาแจ้งฝ่าย IT ให้เพิ่มก่อน',
              ),
            );
          }

          final asset = list[index - 1];
          return AssetTile(
            asset: asset,
            onTap: () => Navigator.of(context).pop(asset),
          );
        },
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
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
