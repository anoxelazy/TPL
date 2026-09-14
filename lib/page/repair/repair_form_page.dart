import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/page/repair/asset_picker_page.dart';
import 'package:claim/page/repair/asset_tile.dart';
import 'package:claim/page/repair/repair_api.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/permission_service.dart';
import 'package:claim/widgets/app_card.dart';
import 'package:claim/widgets/barcode_scanner.dart';
import 'package:claim/utils/app_icons.dart';

/// หน้าเปิดใบแจ้งซ่อม พนักงานทุกคนใช้ได้ ไม่ต้องมีสิทธิ์ IT
class RepairFormPage extends StatefulWidget {
  const RepairFormPage({super.key});

  @override
  State<RepairFormPage> createState() => _RepairFormPageState();
}

class _RepairFormPageState extends State<RepairFormPage> {
  final _issueField = TextEditingController();
  RepairAsset? _asset;
  bool _looking = false;
  bool _sending = false;

  String _requesterName = '';

  String get _branch => PermissionService.I.getBranchId() ?? '';
  bool get _assetMissingSn => _asset != null && _asset!.sn.trim().isEmpty;

  bool get _canSend =>
      !_sending &&
      _asset != null &&
      !_assetMissingSn &&
      _issueField.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadRequester();
  }

  @override
  void dispose() {
    _issueField.dispose();
    super.dispose();
  }

  Future<void> _loadRequester() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _requesterName =
          prefs.getString('fullname')?.replaceAll(RegExp(r'\s+'), ' ').trim() ??
          '';
    });
  }

  Future<void> _pick() async {
    final asset = await pickAssetFromRegistry(context);
    if (asset == null || !mounted) return;
    setState(() => _asset = asset);
  }

  Future<void> _scan() async {
    final code = await openBarcodeScannerPage(
      context,
      title: 'สแกนเครื่อง',
      hint: 'วาง QR หรือบาร์โค้ดบนเครื่องให้อยู่กลางจอ',
    );
    if (code == null || !mounted) return;

    final sn = snFromScannedCode(code);
    if (sn.isEmpty) return;

    setState(() => _looking = true);

    try {
      final asset = await findAssetBySn(sn);
      if (!mounted) return;
      setState(() {
        _looking = false;
        if (asset != null) _asset = asset;
      });

      if (asset == null) {
        _message(
          'ไม่พบ S/N $sn ในทะเบียนเครื่อง กรุณาแจ้งฝ่าย IT ให้เพิ่มเครื่องก่อน',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _looking = false);
      _message(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _send() async {
    if (!_canSend) return;
    setState(() => _sending = true);

    try {
      await createRepair(
        asset: _asset!,
        issueDescription: _issueField.text.trim(),
        requesterName: _requesterName,
        branch: _branch,
      );
      if (!mounted) return;
      _message('ส่งใบแจ้งซ่อมเรียบร้อย');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _message(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('แจ้งซ่อม')),
      // แตะที่ว่างเพื่อปิดคีย์บอร์ด ฟอร์มนี้มีช่องพิมพ์หลายช่อง
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: AppSizes.pagePadding,
          children: [
            _snCard(scheme),
            const SizedBox(height: AppSizes.gap),
            _issueCard(scheme),
            const SizedBox(height: AppSizes.gap),
            _requesterCard(scheme),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _canSend ? _send : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_sending ? 'กำลังส่ง...' : 'ส่งใบแจ้งซ่อม'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _snCard(ColorScheme scheme) {
    final asset = _asset;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _cardTitle(
                  scheme,
                  Icons.devices_other,
                  'เครื่องที่จะแจ้งซ่อม',
                ),
              ),
              // IconButton(
              //   tooltip: 'สแกนเครื่อง',
              //   onPressed: _looking ? null : _scan,
              //   icon: _looking
              //       ? const SizedBox(
              //           width: 18,
              //           height: 18,
              //           child: CircularProgressIndicator(strokeWidth: 2),
              //         )
              //       : const Icon(AppIcons.scan),
              // ),
            ],
          ),
          const SizedBox(height: 4),

          if (asset == null)
            _pickPrompt(scheme)
          else
            _assetSelected(scheme, asset),

          if (_assetMissingSn) ...[
            const SizedBox(height: 10),
            _hint(
              scheme,
              Icons.error_outline,
              AppColors.danger,
              'เครื่องนี้ยังไม่มี S/N ในทะเบียน แจ้งซ่อมไม่ได้ '
              'กรุณาแจ้งฝ่าย IT ให้กรอก S/N ก่อน',
            ),
          ],
        ],
      ),
    );
  }

  /// ปุ่มเลือกเครื่องตอนยังไม่ได้เลือก
  ///
  /// ทำเป็นกล่องเต็มความกว้างให้ดูเป็นช่องที่ต้องเติม ไม่ใช่ปุ่มเล็ก ๆ
  /// เพราะเป็นข้อมูลบังคับที่ขาดอยู่ ต้องดึงสายตาให้กดก่อนอย่างอื่น
  Widget _pickPrompt(ColorScheme scheme) {
    return InkWell(
      onTap: _pick,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        ),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline, size: 20, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'เลือกเครื่องจากทะเบียน',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'แจ้งซ่อมได้เฉพาะเครื่องที่อยู่ในทะเบียน',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  /// เครื่องที่เลือกไว้ แตะเพื่อเปลี่ยนได้
  Widget _assetSelected(ColorScheme scheme, RepairAsset asset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AssetTile(asset: asset, onTap: _pick),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('เปลี่ยนเครื่อง'),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        ),
      ],
    );
  }

  Widget _issueCard(ColorScheme scheme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(scheme, Icons.report_problem_outlined, 'อาการเสีย'),
          const SizedBox(height: 12),
          TextField(
            controller: _issueField,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'เช่น เปิดไม่ติด จอไม่ขึ้น เสียงดังผิดปกติ',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _requesterCard(ColorScheme scheme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(scheme, Icons.person_outline, 'ผู้แจ้ง'),
          const SizedBox(height: 10),
          _line(scheme, 'ชื่อ', _requesterName.isEmpty ? '-' : _requesterName),
          _line(scheme, 'สาขา', _branch.isEmpty ? '-' : _branch),
        ],
      ),
    );
  }

  Widget _cardTitle(ColorScheme scheme, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _line(ColorScheme scheme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hint(ColorScheme scheme, IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
