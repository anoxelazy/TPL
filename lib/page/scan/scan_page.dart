import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/permission_service.dart';
import 'package:claim/widgets/barcode_scanner.dart';
import 'package:claim/page/scan/scan_api.dart';
import 'package:claim/page/scan/scan_controller.dart';
import 'package:claim/page/scan/scan_gallery.dart';
import 'package:claim/page/scan/scan_widgets.dart';
import 'package:claim/utils/app_icons.dart';

/// หน้าสแกนบาร์โค้ดแล้วถ่ายรูปหลักฐาน
///
/// ออกแบบให้ยิงต่อเนื่องได้เร็วที่สุด: โฟกัสช่องให้เองตอนเข้าหน้า
/// ไม่มีปุ่มยืนยัน ไม่มี alert ตอนสำเร็จ ส่งเสร็จเคลียร์ช่องแล้วโฟกัสกลับ
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final ScanController _c = ScanController();
  final TextEditingController _field = TextEditingController();
  final FocusNode _fieldFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChanged);
    _c.loadSession();
    // โฟกัสให้เลยเพื่อให้ปืนสแกนยิงได้ทันที ไม่ต้องแตะจอก่อน
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusField());
  }

  @override
  void dispose() {
    _c.removeListener(_onChanged);
    _c.dispose();
    _field.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  void _onChanged() {
    // controller เคลียร์ค่าเองหลังส่งสำเร็จ ช่องต้องตามให้ตรง
    if (_c.barcode.isEmpty && _field.text.isNotEmpty) {
      _field.clear();
    }
    if (mounted) setState(() {});
  }

  void _focusField() {
    if (mounted) _fieldFocus.requestFocus();
  }

  // ------------------------------------------------------------------- actions

  Future<void> _scanWithCamera() async {
    final code = await openBarcodeScannerPage(
      context,
      title: 'สแกนบาร์โค้ด',
      hint: 'วางบาร์โค้ดให้อยู่กลางจอ ระบบจะกรอกให้อัตโนมัติ',
    );
    if (code == null || !mounted) return;

    _field.text = code;
    _c.onBarcodeChanged(code);
    _focusField();
  }

  Future<void> _takePhotoAndSend() async {
    // กันส่งซ้อน: กำลังอัปโหลดอยู่หรือยังไม่มีบาร์โค้ด ไม่ต้องทำอะไรเลย
    if (!_c.canTakePhoto) return;

    final file = await pickScanImage(context);
    if (file == null || !mounted) return;

    // ส่งทันทีที่ได้รูป ไม่มีปุ่มยืนยัน
    final outcome = await _c.upload(file);
    if (outcome == null || !mounted) return;

    if (!outcome.success) {
      // ข้อความอ้างบาร์โค้ดใบที่ส่งจริง ไม่ใช่ค่าที่อยู่ในช่องตอนนี้
      // และไม่เคลียร์ช่อง ผู้ใช้ต้องถ่ายใบเดิมใหม่
      await _showFailedDialog(outcome.errorMessage!);
      return;
    }

    // สำเร็จ: ไม่มี alert เคลียร์ช่องแล้วโฟกัสกลับให้ยิงใบถัดไปต่อได้ทันที
    _c.clearForNext();
    _focusField();

    final bytes = outcome.bytes;
    if (bytes == null) return;

    final saved = await saveScanImageToGallery(
      bytes: bytes,
      barcode: outcome.barcode,
    );
    if (!saved && mounted) {
      // บันทึกลงเครื่องไม่ได้ไม่กระทบการส่งที่สำเร็จไปแล้ว บอกให้รู้พอ
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถบันทึกภาพลงเครื่องได้'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showFailedDialog(String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.error_outline,
          size: 34,
          color: AppColors.danger,
        ),
        title: const Text('ส่งไม่สำเร็จ', textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _focusField();
              },
              child: const Text('ตกลง'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    if (!PermissionService.I.canAccess(scanModule)) {
      return const _NoPermissionView();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('สแกนบาร์โค้ด')),
      body: SafeArea(
        child: ListView(
          padding: AppSizes.pagePadding,
          children: [
            _barcodeField(),
            const SizedBox(height: AppSizes.gap),
            ScanCheckCard(checking: _c.checking, result: _c.checkResult),
            const SizedBox(height: AppSizes.gap),
            ScanPhotoBox(
              hasBarcode: _c.barcode.isNotEmpty,
              uploading: _c.uploading,
              uploadingFile: _c.uploadingFile,
              onTap: _takePhotoAndSend,
            ),
            const SizedBox(height: 12),
            _hint(),
          ],
        ),
      ),
    );
  }

  Widget _barcodeField() {
    return TextField(
      controller: _field,
      focusNode: _fieldFocus,
      autofocus: true,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _focusField(),
      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
      onChanged: _c.onBarcodeChanged,
      decoration: InputDecoration(
        labelText: 'บาร์โค้ดพัสดุ',
        hintText: 'สแกนบาร์โค้ด หรือพิมพ์เอง',
        suffixIcon: IconButton(
          tooltip: 'สแกนด้วยกล้อง',
          icon: const Icon(AppIcons.scan),
          onPressed: _scanWithCamera,
        ),
      ),
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    );
  }

  Widget _hint() {
    final scheme = Theme.of(context).colorScheme;

    final String text;
    if (_c.uploading) {
      text = 'กำลังส่งรูป รอสักครู่';
    } else if (_c.barcode.isEmpty) {
      text = 'ช่องพร้อมรับการยิงแล้ว ไม่ต้องแตะจอ';
    } else {
      text = 'ถ่ายรูปแล้วระบบส่งให้ทันที ส่งเสร็จช่องจะเคลียร์ให้ยิงใบต่อไป';
    }

    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
    );
  }
}

/// ไม่มีสิทธิ์ module scan บอกให้ไปขอสิทธิ์ ไม่ใช่ปล่อยหน้าว่าง
class _NoPermissionView extends StatelessWidget {
  const _NoPermissionView();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('สแกนบาร์โค้ด')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 56, color: scheme.outline),
              const SizedBox(height: 16),
              const Text(
                'ยังไม่มีสิทธิ์ใช้งานเมนูนี้',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'การสแกนบาร์โค้ดและส่งรูปหลักฐานต้องเปิดสิทธิ์ให้ก่อน '
                'กรุณาติดต่อผู้ดูแลระบบเพื่อขอเปิดสิทธิ์',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
