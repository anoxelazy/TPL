import 'package:flutter/material.dart';

import 'package:claim/page/asset/asset_api.dart';
import 'package:claim/page/asset/asset_models.dart';
import 'package:claim/utils/mobile_api.dart';

/// เพิ่มประเภททรัพย์สินใหม่ คืนประเภทที่เพิ่งเพิ่มเมื่อบันทึกสำเร็จ
///
/// อยู่ในป๊อปอัปไม่ใช่หน้าของตัวเอง เพราะคนที่เปิดมาคือคนที่กำลังกรอกทรัพย์สิน
/// อยู่แล้วเจอว่าไม่มีประเภทที่ต้องการในลิสต์ พาออกไปทั้งหน้าแล้วกลับมาที่กรอก
/// ค้างไว้จะหาย
Future<AssetLookup?> showAssetTypeDialog(BuildContext context) {
  return showDialog<AssetLookup>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _AssetTypeDialog(),
  );
}

class _AssetTypeDialog extends StatefulWidget {
  const _AssetTypeDialog();

  @override
  State<_AssetTypeDialog> createState() => _AssetTypeDialogState();
}

class _AssetTypeDialogState extends State<_AssetTypeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _typeId = TextEditingController();
  final _descTh = TextEditingController();
  final _descEn = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _typeId.dispose();
    _descTh.dispose();
    _descEn.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      await insertAssetType(
        typeId: _typeId.text,
        descTh: _descTh.text,
        descEn: _descEn.text,
      );
      if (!mounted) return;

      // ส่งของที่เพิ่งเพิ่มกลับไปให้ฟอร์มเลือกต่อได้ทันที ไม่ต้องรอโหลดลิสต์ใหม่
      Navigator.of(context).pop(
        AssetLookup(
          code: _typeId.text.trim(),
          nameTh: _descTh.text.trim(),
          nameEn: _descEn.text.trim(),
        ),
      );
    } on MobileApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เพิ่มประเภททรัพย์สิน'),
      content: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _typeId,
              enabled: !_saving,
              textCapitalization: TextCapitalization.characters,
              maxLength: kAssetTypeMax,
              decoration: const InputDecoration(
                labelText: 'รหัสประเภท',
                hintText: 'เช่น NOTEBOOK หรือ IT-PRINTER',
                counterText: '',
              ),
              validator: (value) => assetTypeIdError(value ?? ''),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descTh,
              enabled: !_saving,
              maxLength: kAssetTypeDescMax,
              decoration: const InputDecoration(
                labelText: 'ชื่อภาษาไทย',
                counterText: '',
              ),
              validator: (value) => assetRequiredError(
                value ?? '',
                label: 'ชื่อภาษาไทย',
                max: kAssetTypeDescMax,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descEn,
              enabled: !_saving,
              maxLength: kAssetTypeDescMax,
              decoration: const InputDecoration(
                labelText: 'ชื่อภาษาอังกฤษ',
                counterText: '',
              ),
              // API บังคับทั้งไทยและอังกฤษ ปล่อยว่างช่องใดช่องหนึ่งจะโดนตีกลับ
              validator: (value) => assetRequiredError(
                value ?? '',
                label: 'ชื่อภาษาอังกฤษ',
                max: kAssetTypeDescMax,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก'),
        ),
      ],
    );
  }
}
