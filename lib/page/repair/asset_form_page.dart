import 'package:flutter/material.dart';

import 'package:claim/page/repair/repair_appbar.dart';
import 'package:image_picker/image_picker.dart';

import 'package:claim/page/repair/repair_api.dart';
import 'package:claim/page/repair/repair_history_page.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/widgets/local_image_view.dart';
import 'package:claim/utils/app_icons.dart';
import 'package:claim/utils/role_service.dart';
import 'package:claim/widgets/app_card.dart';
import 'package:claim/widgets/barcode_scanner.dart';

/// เพิ่ม/แก้ไขเครื่องในทะเบียน
///
/// ส่ง [asset] มา = แก้ของเดิม ไม่ส่ง = เพิ่มใหม่
/// คนที่ไม่ใช่ IT เปิดได้แต่แก้ไม่ได้ ช่องทั้งหมดจะถูกล็อกและไม่มีปุ่มบันทึก
class AssetFormPage extends StatefulWidget {
  final RepairAsset? asset;

  const AssetFormPage({super.key, this.asset});

  @override
  State<AssetFormPage> createState() => _AssetFormPageState();
}

class _AssetFormPageState extends State<AssetFormPage> {
  late final Map<String, TextEditingController> _fields = {
    for (final key in _labels.keys) key: TextEditingController(),
  };

  /// ชื่อฟิลด์ -> ป้ายที่โชว์ เรียงตามลำดับที่อยากให้เห็นในฟอร์ม
  static const Map<String, String> _labels = {
    'asset_code': 'รหัสทรัพย์สิน',
    'sn': 'S/N',
    'computer_name': 'ชื่อเครื่องใน network',
    'device_type': 'ประเภทเครื่อง',
    'brand': 'ยี่ห้อ',
    'model': 'รุ่น',
    'department': 'แผนก',
    'employee_name': 'ผู้ครอบครองเครื่อง',
    'windows_version': 'เวอร์ชัน Windows',
    'office_installed': 'Office ที่ติดตั้ง',
    'computer_age': 'อายุเครื่อง',
  };

  final Map<String, bool> _software = {
    for (final key in kAssetSoftware.keys) key: false,
  };

  String _warrantyStart = '';
  String _warrantyEnd = '';
  String _imageUrl = '';
  XFile? _newPhoto;
  bool _saving = false;

  bool get _isEdit => widget.asset != null;

  bool get _readOnly => !RoleService.I.isIt;

  bool get _canSave =>
      !_saving && !_readOnly && _fields['sn']!.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();

    final asset = widget.asset;
    if (asset == null) return;

    _fields['asset_code']!.text = asset.assetCode;
    _fields['sn']!.text = asset.sn;
    _fields['computer_name']!.text = asset.computerName;
    _fields['device_type']!.text = asset.deviceType;
    _fields['brand']!.text = asset.brand;
    _fields['model']!.text = asset.model;
    _fields['department']!.text = asset.department;
    _fields['employee_name']!.text = asset.employeeName;
    _fields['windows_version']!.text = asset.windowsVersion;
    _fields['office_installed']!.text = asset.officeInstalled;
    _fields['computer_age']!.text = asset.computerAge;

    _warrantyStart = asset.warrantyStart;
    _warrantyEnd = asset.warrantyEnd;
    _imageUrl = asset.imageUrl;
    for (final key in kAssetSoftware.keys) {
      _software[key] = asset.software[key] ?? false;
    }
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _text(String key) => _fields[key]!.text.trim();

  RepairAsset _build() => RepairAsset(
    id: widget.asset?.id,
    assetCode: _text('asset_code'),
    sn: _text('sn'),
    computerName: _text('computer_name'),
    deviceType: _text('device_type'),
    brand: _text('brand'),
    model: _text('model'),
    department: _text('department'),
    employeeName: _text('employee_name'),
    windowsVersion: _text('windows_version'),
    officeInstalled: _text('office_installed'),
    warrantyStart: _warrantyStart,
    warrantyEnd: _warrantyEnd,
    computerAge: _text('computer_age'),
    imageUrl: _imageUrl,
    software: _software,
  );

  Future<void> _scanSn() async {
    final code = await openBarcodeScannerPage(
      context,
      title: 'สแกน S/N',
      hint: 'วางบาร์โค้ด S/N ให้อยู่กลางจอ',
    );
    if (code == null || !mounted) return;

    setState(() {
      _fields['sn']!.text = code.contains('?')
          ? (Uri.tryParse(code)?.queryParameters['sn']?.trim() ?? code.trim())
          : code.trim();
    });
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('ถ่ายรูป'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('เลือกจากคลังรูป'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null || !mounted) return;

    setState(() => _newPhoto = picked);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = DateTime.tryParse(isStart ? _warrantyStart : _warrantyEnd);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    // ส่งเป็น yyyy-MM-dd ตามชนิด date ของคอลัมน์
    final value =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';

    setState(() {
      if (isStart) {
        _warrantyStart = value;
      } else {
        _warrantyEnd = value;
      }
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);

    final previousPhoto = _imageUrl;

    try {
      final photo = _newPhoto;
      if (photo != null) {
        _imageUrl = await uploadAssetPhoto(file: photo, sn: _text('sn'));
      }

      final asset = _build();
      if (_isEdit) {
        await updateAsset(asset);
      } else {
        await createAsset(asset);
      }

      // ลบรูปเก่าหลังบันทึกสำเร็จเท่านั้น ลบก่อนแล้วบันทึกพลาดจะเสียรูปฟรี
      if (photo != null && previousPhoto.isNotEmpty) {
        await deleteAssetPhoto(previousPhoto);
      }

      if (!mounted) return;
      _message(_isEdit ? 'บันทึกการแก้ไขแล้ว' : 'เพิ่มเครื่องแล้ว');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _imageUrl = previousPhoto;
      });
      _message(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _delete() async {
    final asset = widget.asset;
    if (asset == null || _saving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันลบเครื่อง'),
        content: Text(
          '${asset.displayName}\nS/N ${asset.sn}\n\n'
          'ลบแล้วกู้คืนไม่ได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);

    try {
      await deleteAsset(id: asset.id, sn: asset.sn);
      if (asset.imageUrl.isNotEmpty) await deleteAssetPhoto(asset.imageUrl);
      if (!mounted) return;
      _message('ลบเครื่องแล้ว');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RepairHistoryPage(
          sn: _text('sn'),
          deviceName: widget.asset?.displayName ?? _text('sn'),
        ),
      ),
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: repairAppBar(
        title: _isEdit ? 'ข้อมูลเครื่อง' : 'เพิ่มเครื่อง',
        actions: [
          if (_isEdit && !_readOnly)
            IconButton(
              tooltip: 'ลบเครื่อง',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _photoCard(scheme),
            const SizedBox(height: AppSizes.gap),
            _detailCard(scheme),
            const SizedBox(height: AppSizes.gap),
            _warrantyCard(scheme),
            const SizedBox(height: AppSizes.gap),
            _softwareCard(scheme),
            if (_isEdit) ...[
              const SizedBox(height: AppSizes.gap),
              OutlinedButton.icon(
                onPressed: _openHistory,
                icon: const Icon(Icons.history),
                label: const Text('ประวัติการซ่อมของเครื่องนี้'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
            ],
            if (!_readOnly) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _canSave ? _save : null,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.repairIcon,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _photoCard(ColorScheme scheme) {
    final photo = _newPhoto;

    return AppCard(
      child: Column(
        children: [
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: photo != null
                ? LocalImageView(file: photo)
                : _imageUrl.isEmpty
                ? Icon(
                    Icons.photo_camera_outlined,
                    size: 40,
                    color: scheme.onSurfaceVariant,
                  )
                : Image.network(
                    _imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Icon(
                      Icons.broken_image_outlined,
                      size: 40,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
          ),
          if (!_readOnly) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickPhoto,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(
                _imageUrl.isEmpty && photo == null
                    ? 'เพิ่มรูปเครื่อง'
                    : 'เปลี่ยนรูป',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailCard(ColorScheme scheme) {
    return AppCard(
      child: Column(
        children: [
          for (final entry in _labels.entries) ...[
            TextField(
              controller: _fields[entry.key],
              readOnly: _readOnly,
              onChanged: entry.key == 'sn' ? (_) => setState(() {}) : null,
              decoration: InputDecoration(
                labelText: entry.value,
                suffixIcon: entry.key == 'sn' && !_readOnly && canScanBarcode
                    ? IconButton(
                        tooltip: 'สแกน',
                        onPressed: _scanSn,
                        icon: const Icon(AppIcons.scan),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _warrantyCard(ColorScheme scheme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ประกัน',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          _dateRow(scheme, 'เริ่มประกัน', _warrantyStart, true),
          _dateRow(scheme, 'สิ้นสุดประกัน', _warrantyEnd, false),
        ],
      ),
    );
  }

  Widget _dateRow(
    ColorScheme scheme,
    String label,
    String value,
    bool isStart,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        label,
        style: TextStyle(fontSize: 14, color: scheme.onSurface),
      ),
      trailing: Text(
        value.isEmpty ? 'ไม่ระบุ' : value,
        style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
      ),
      onTap: _readOnly ? null : () => _pickDate(isStart: isStart),
    );
  }

  Widget _softwareCard(ColorScheme scheme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ซอฟต์แวร์ที่ติดตั้ง',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          for (final entry in kAssetSoftware.entries)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: _software[entry.key] ?? false,
              title: Text(entry.value, style: const TextStyle(fontSize: 14)),
              onChanged: _readOnly
                  ? null
                  : (value) =>
                        setState(() => _software[entry.key] = value ?? false),
            ),
        ],
      ),
    );
  }
}
