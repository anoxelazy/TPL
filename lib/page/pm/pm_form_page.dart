import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:claim/page/pm/pm_api.dart';
import 'package:claim/page/pm/pm_location.dart';
import 'package:claim/page/pm/pm_models.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/mobile_api.dart';
import 'package:claim/widgets/app_card.dart';
import 'package:claim/widgets/info_row.dart';
import 'package:claim/widgets/remote_image.dart';

/// หน้าทำ PM ของเครื่องเดียวในปีเดียว
///
/// 6 หัวข้อ แต่ละหัวข้อถ่ายรูปก่อนทำกับหลังทำ รูปที่เคยถ่ายไว้แล้วจะโชว์จาก
/// เซิร์ฟเวอร์ ถ่ายใหม่ทับได้ ส่งเฉพาะหัวข้อที่ถ่ายใหม่ หัวข้อที่ไม่แตะไม่ถูกส่ง
class PmFormPage extends StatefulWidget {
  final PmHead head;
  final int year;

  const PmFormPage({super.key, required this.head, required this.year});

  @override
  State<PmFormPage> createState() => _PmFormPageState();
}

class _PmFormPageState extends State<PmFormPage> {
  final _picker = ImagePicker();
  late final TextEditingController _remarkField;

  /// รหัสสถานที่ที่เลือกอยู่ เก็บเป็นรหัสไม่ใช่ชื่อ เพราะ API รับรหัส
  late String _locationCode;

  /// รูปที่ถ่ายใหม่ในรอบนี้ key คือ subNo
  final Map<int, File> _newBefore = {};
  final Map<int, File> _newAfter = {};

  bool _saving = false;

  /// หัวข้อที่มีอยู่แล้วของปีนี้ ใช้โชว์รูปเดิม
  late final Map<int, PmDetail> _existing = {
    for (final d in widget.head.detailsOf(widget.year)) d.subNo: d,
  };

  bool get _hasChanges => _newBefore.isNotEmpty || _newAfter.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _remarkField = TextEditingController(text: widget.head.remark ?? '');
    _locationCode = widget.head.location?.trim() ?? '';
  }

  @override
  void dispose() {
    _remarkField.dispose();
    super.dispose();
  }

  Future<void> _pick(int subNo, bool isBefore) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('ถ่ายรูป'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกจากคลังรูป'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _picker.pickImage(source: source);
    if (picked == null || !mounted) return;

    setState(() {
      final file = File(picked.path);
      if (isBefore) {
        _newBefore[subNo] = file;
      } else {
        _newAfter[subNo] = file;
      }
    });
  }

  Future<void> _save() async {
    if (!_hasChanges || _saving) return;
    setState(() => _saving = true);

    // ส่งเฉพาะหัวข้อที่ถ่ายรูปใหม่ หัวข้อที่ไม่แตะไม่ต้องส่งไป
    // ไม่งั้นถ้า API เขียนทับทั้งชุด รูปเดิมของหัวข้ออื่นจะหาย
    final photos = <PmTaskPhotos>[];
    for (var subNo = 1; subNo <= pmTaskCount; subNo++) {
      final before = _newBefore[subNo];
      final after = _newAfter[subNo];
      if (before == null && after == null) continue;
      photos.add(PmTaskPhotos(subNo: subNo, before: before, after: after));
    }

    try {
      await updatePmHead(
        no: widget.head.no,
        fixAsset: widget.head.fixAsset ?? '',
        empNo: widget.head.empNo ?? '',
        location: _locationCode,
        remark: _remarkField.text.trim(),
        yearCheck: widget.year,
        photos: photos,
      );
      if (!mounted) return;
      _message('บันทึก PM เรียบร้อย');
      Navigator.of(context).pop(true);
    } on MobileApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message(e.message);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.head.comName)),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: ListView(
          padding: AppSizes.pagePadding,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            _infoCard(),
            const SizedBox(height: AppSizes.gap),
            for (var subNo = 1; subNo <= pmTaskCount; subNo++) ...[
              _taskCard(subNo),
              const SizedBox(height: AppSizes.gap),
            ],
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _hasChanges && !_saving ? _save : null,
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
                _saving ? 'กำลังบันทึก...' : 'บันทึก PM ปี ${widget.year}',
              ),
            ),
            if (!_hasChanges)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'ถ่ายรูปอย่างน้อย 1 หัวข้อก่อนถึงจะบันทึกได้',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard() {
    final done = widget.head.completedCount(widget.year);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ข้อมูลเครื่อง',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                'ปี ${widget.year} · $done/$pmTaskCount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: done >= pmTaskCount
                      ? AppColors.success
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InfoRow(icon: Icons.tag, value: widget.head.fixAsset),
          InfoRow(icon: Icons.badge_outlined, value: widget.head.empNo),
          const SizedBox(height: 4),
          TextField(
            controller: _remarkField,
            style: const TextStyle(fontSize: 14),
            // หมายเหตุของจริงยาวได้ถึง 30 ตัวอักษร ("ต่อคิวเปลี่ยนจอ F600-...")
            // บรรทัดเดียวจะอ่านไม่ครบตอนพิมพ์
            maxLines: 2,
            minLines: 1,
            decoration: const InputDecoration(
              labelText: 'หมายเหตุ',
              hintText: 'เช่น ไฟล์ขยะเยอะ, ต่อคิวเปลี่ยนจอ',
              hintStyle: TextStyle(fontSize: 13),
              isDense: true,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          _locationPicker(),
        ],
      ),
    );
  }

  /// เลือกสถานที่จากรายการชื่อ แต่ส่งเป็นรหัสให้ API
  ///
  /// เดิมเป็นช่องพิมพ์อิสระ ซึ่งผิดตั้งแต่ต้น เพราะ API เก็บเป็นรหัส
  /// ("2" = IT) พิมพ์คำว่า "IT" ลงไปตรง ๆ จะได้ค่าที่เว็บอ่านไม่ออก
  ///
  /// ฟังรายการผ่าน ValueListenableBuilder เพราะตารางแปลงโหลดเสร็จทีหลัง
  /// ตอนเปิดหน้าอาจยังเป็นค่าสำรองที่ติดมากับแอปอยู่
  Widget _locationPicker() {
    return ValueListenableBuilder<List<PmLocation>>(
      valueListenable: PmLocations.I.items,
      builder: (context, locations, _) {
        // รหัสเดิมของเครื่องอาจไม่มีในรายการ (เว็บลบทิ้งหรือยังไม่ได้อัปไฟล์)
        // ต้องใส่กลับเข้าไปเอง ไม่งั้น DropdownButtonFormField จะ assert ตาย
        // เพราะ value ไม่ตรงกับ item ไหนเลย
        final items = [...locations];
        final known = items.any((l) => l.code == _locationCode);
        if (_locationCode.isNotEmpty && !known) {
          items.add(
            PmLocation(code: _locationCode, name: 'รหัส $_locationCode'),
          );
        }

        return DropdownButtonFormField<String>(
          initialValue: _locationCode.isEmpty ? null : _locationCode,
          isExpanded: true,
          // ⚠️ ต้องระบุสีเอง ห้ามใส่แค่ fontSize
          //
          // ธีมของแอปสร้างจาก GoogleFonts ซึ่งฝังสีตัวอักษรมาใน titleMedium
          // ส่วน DropdownButton ใช้ `style ?? textTheme.titleMedium` คือทับ
          // ทั้งก้อน ไม่ได้ merge ใส่แค่ fontSize เลยทำให้สีหลุดจนตัวหนังสือหาย
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          decoration: const InputDecoration(
            labelText: 'สถานที่',
            isDense: true,
          ),
          items: [
            for (final location in items)
              DropdownMenuItem(
                value: location.code,
                child: Text(
                  location.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _locationCode = value);
          },
        );
      },
    );
  }

  Widget _taskCard(int subNo) {
    final detail = _existing[subNo];
    final title = subNo <= pmTaskTitles.length
        ? pmTaskTitles[subNo - 1]
        : 'หัวข้อที่ $subNo';

    final beforeReady = _newBefore[subNo] != null || detail?.hasBefore == true;
    final afterReady = _newAfter[subNo] != null || detail?.hasAfter == true;
    final complete = beforeReady && afterReady;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                complete ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 18,
                color: complete
                    ? AppColors.success
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$subNo. $title',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _photoSlot(
                  label: 'ก่อนทำ',
                  file: _newBefore[subNo],
                  url: detail?.picBefore,
                  onTap: () => _pick(subNo, true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _photoSlot(
                  label: 'หลังทำ',
                  file: _newAfter[subNo],
                  url: detail?.picAfter,
                  onTap: () => _pick(subNo, false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ช่องรูป 1 ช่อง แตะเพื่อถ่าย/เลือกใหม่ได้เสมอ แม้มีรูปเดิมอยู่แล้ว
  Widget _photoSlot({
    required String label,
    required File? file,
    required String? url,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isNew = file != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            if (isNew) ...[
              const SizedBox(width: 6),
              const Text(
                'ใหม่',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.pending,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isNew ? AppColors.pending : scheme.outlineVariant,
                  width: isNew ? 1.5 : 1,
                ),
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              ),
              clipBehavior: Clip.antiAlias,
              child: file != null
                  ? Image.file(file, fit: BoxFit.cover)
                  : url != null
                  ? RemoteImage(source: url)
                  : Center(
                      child: Icon(
                        Icons.add_a_photo_outlined,
                        size: 22,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
