import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:claim/widgets/barcode_scanner.dart';
import 'package:claim/widgets/remote_image.dart';

import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/app_icons.dart';

final NumberFormat _thousands = NumberFormat('#,###');

/// ตัวเลขในรูปแบบมีคอมมาคั่นหลักพัน
String formatThousands(num value) => _thousands.format(value);

/// ตัวเลขทศนิยม 2 ตำแหน่งพร้อมคอมมา ใช้กับราคาและปริมาณน้ำมัน
String formatDecimal(num value) => NumberFormat('#,##0.##').format(value);

/// อ่านเลขไมล์จากข้อความในช่องกรอก ต้องตัดคอมมาออกก่อนทุกครั้ง
int parseMeterInput(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  return int.tryParse(digits) ?? 0;
}

/// ใส่คอมมาคั่นหลักพันให้ระหว่างพิมพ์ และคงตำแหน่ง cursor ไว้ท้ายข้อความ
class ThousandsInputFormatter extends TextInputFormatter {
  const ThousandsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');

    // เลขไมล์ยาวสุดหลักแสน ตัดที่ 9 หลักกัน overflow ตอน parse
    final trimmed = digits.length > 9 ? digits.substring(0, 9) : digits;
    final formatted = _thousands.format(int.parse(trimmed));

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// ช่องกรอกเลขไมล์
///
/// ตัวเลขตัวใหญ่กว่าปกติเพราะคนกรอกมักอยู่ในรถและอ่านเทียบกับหน้าปัดจริง
class MeterNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<int> onChanged;
  final FocusNode? focusNode;

  /// ข้อความช่วยใต้ช่อง เช่น ระยะทางที่คำนวณคร่าว ๆ
  final String? helperText;

  const MeterNumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
    this.focusNode,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: const [ThousandsInputFormatter()],
      onChanged: (text) => onChanged(parseMeterInput(text)),
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: '0',
        border: const OutlineInputBorder(),
        suffixText: 'กม.',
        helperText: helperText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 18,
        ),
      ),
    );
  }
}

/// ช่องกรอกที่มีปุ่มสแกน QR ต่อท้าย ใช้กับรหัสคนขับและหมายเลขรถ
class ScannableField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;

  /// ช่องถัดไปที่จะเด้ง cursor ไปให้เองหลังสแกนติด
  /// ผู้ใช้ยกกล้องอยู่ ไม่ควรต้องมาแตะช่องต่อไปเอง
  final FocusNode? nextFocusNode;

  final IconData icon;

  const ScannableField({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
    required this.icon,
    this.enabled = true,
    this.focusNode,
    this.nextFocusNode,
  });

  Future<void> _scan(BuildContext context) async {
    final code = await openBarcodeScannerPage(
      context,
      title: 'สแกน$label',
      hint: 'วาง QR ให้อยู่กลางจอ ระบบจะกรอกให้อัตโนมัติ',
    );
    if (code == null || !context.mounted) return;

    controller.text = code;
    onChanged(code);
    nextFocusNode?.requestFocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('สแกนได้: $code'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      textCapitalization: TextCapitalization.characters,
      textInputAction: nextFocusNode == null
          ? TextInputAction.done
          : TextInputAction.next,
      onSubmitted: (_) => nextFocusNode?.requestFocus(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: const OutlineInputBorder(),
        suffixIcon: enabled
            ? IconButton(
                tooltip: 'สแกน QR',
                icon: const Icon(AppIcons.scan),
                onPressed: () => _scan(context),
              )
            : const Icon(Icons.lock_outline, size: 20),
      ),
    );
  }
}

/// ให้ผู้ใช้เลือกว่าจะถ่ายใหม่หรือหยิบจากคลังรูป คืน null เมื่อยกเลิก
Future<File?> pickMeterImage(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'รูปหน้าปัดไมล์',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('ถ่ายรูป'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('เลือกจากคลังรูป'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (source == null) return null;

  final picked = await ImagePicker().pickImage(
    source: source,
    imageQuality: 85,
  );
  if (picked == null) return null;

  return File(picked.path);
}

/// กรอบรูปไมล์ 1 ช่วง แสดงไฟล์ในเครื่องหรือรูปจากเซิร์ฟเวอร์
///
/// [imageUrl] มาก่อน [localFile] เสมอไม่ได้ เพราะตอนเพิ่งถ่ายยังไม่มี URL
/// จึงเลือกไฟล์ในเครื่องก่อนถ้ามี
class MeterImageSlot extends StatelessWidget {
  final String label;
  final File? localFile;
  final String? imageUrl;
  final bool uploading;
  final VoidCallback? onPick;

  const MeterImageSlot({
    super.key,
    required this.label,
    required this.localFile,
    required this.imageUrl,
    required this.uploading,
    required this.onPick,
  });

  bool get _hasImage => localFile != null || imageUrl != null;

  /// อัปโหลดขึ้นเซิร์ฟเวอร์เรียบร้อยแล้ว ต้องบอกให้ผู้ใช้เห็นชัด
  /// ไม่งั้นจะไม่รู้ว่ากดบันทึกได้แล้วหรือยัง
  bool get _uploaded => !uploading && imageUrl != null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (_uploaded)
              Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'อัปโหลดแล้ว',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: uploading ? null : onPick,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 190,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hasImage
                    ? AppColors.success.withValues(alpha: 0.5)
                    : scheme.outlineVariant,
                // ขอบหนาตอนยังไม่มีรูป ให้เห็นว่ายังต้องทำอะไรต่อ
                width: _hasImage ? 1 : 1.5,
              ),
              color: scheme.surfaceContainerHighest,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_hasImage) _image() else _placeholder(context),
                if (uploading)
                  ColoredBox(
                    color: Colors.black.withValues(alpha: 0.45),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 10),
                          Text(
                            'กำลังอัปโหลด...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                // ถ่ายไม่ชัดต้องถ่ายใหม่ได้ทันทีโดยไม่ต้องเดาว่าแตะที่ไหน
                if (_hasImage && !uploading)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: onPick,
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.refresh,
                                size: 16,
                                color: Colors.white,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'ถ่ายใหม่',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _image() {
    final file = localFile;
    if (file != null) return Image.file(file, fit: BoxFit.cover);
    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, _, __) =>
          const Center(child: Text('โหลดรูปไม่ได้')),
    );
  }

  Widget _placeholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_a_photo_outlined,
            size: 34,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'แตะเพื่อถ่ายรูปหน้าปัดไมล์',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// สรุปข้อมูลของช่วงที่บันทึกไปแล้ว
///
/// ใช้แทนช่องกรอกที่ถูกล็อก เพราะช่องกรอกสีเทากดไม่ได้ทำให้คนเข้าใจผิดว่าแอปค้าง
/// แบบนี้อ่านง่ายกว่าและบอกชัดว่าบันทึกเรียบร้อยแล้ว
class MeterSavedTile extends StatelessWidget {
  final String label;
  final int meter;
  final String? imageUrl;

  const MeterSavedTile({
    super.key,
    required this.label,
    required this.meter,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = imageUrl;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          if (url != null)
            GestureDetector(
              onTap: () =>
                  showFullScreenImage(context, source: url, title: label),
              child: Container(
                width: 62,
                height: 62,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, __) =>
                      const Icon(Icons.broken_image_outlined, size: 20),
                ),
              ),
            ),
          if (url != null) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 15,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$label · บันทึกแล้ว',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatThousands(meter)} กม.',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (url != null)
            IconButton(
              tooltip: 'ดูรูปเต็ม',
              icon: const Icon(Icons.zoom_in),
              onPressed: () =>
                  showFullScreenImage(context, source: url, title: label),
            ),
        ],
      ),
    );
  }
}
