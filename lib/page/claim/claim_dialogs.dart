import 'package:flutter/material.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/theme.dart';
import 'sending_animation.dart';
export 'sending_animation.dart' show SendingStatus;

Future<void> showImageUploadDialog(
  BuildContext context, {
  required int totalImages,
  required ValueNotifier<int> uploadedCount,
  required ValueNotifier<String> currentStatus,
}) async {
  await showDialog(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (context) {
      return WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 16),
                const Text(
                  'กำลังอัพโหลดรูปภาพ...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<int>(
                  valueListenable: uploadedCount,
                  builder: (context, count, child) {
                    return Text(
                      '$count / $totalImages รูป',
                      style: const TextStyle(fontSize: 14),
                    );
                  },
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<String>(
                  valueListenable: currentStatus,
                  builder: (context, status, child) {
                    return Text(
                      status,
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<ValueNotifier<SendingStatus>> showSmartLoadingDialog(
  BuildContext context, {
  String message = 'กำลังส่งข้อมูล...',
}) async {
  final notifier = ValueNotifier<SendingStatus>(SendingStatus.sending);
  showDialog(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (context) {
      return WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: SendingAnimation(statusNotifier: notifier, message: message),
        ),
      );
    },
  );
  return notifier;
}

// Keep the old one for backward compatibility if needed, or redirect
Future<void> showLoadingDialog(
  BuildContext context, {
  String message = 'กำลังส่งข้อมูล...',
}) async {
  await showSmartLoadingDialog(context, message: message);
}

Future<void> showResultDialog(
  BuildContext context, {
  String title = 'สำเร็จ',
  String message = 'ทำรายการสำเร็จ',
}) async {
  await showDialog(
    context: context,
    useRootNavigator: true,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(
          message,
          style: TextStyle(color: title == 'ผิดพลาด' ? AppColors.danger : null),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Text('ปิด'),
          ),
        ],
      );
    },
  );
}

/// หน้าต่างยืนยันลบรายการ หน้าตาตามธีมของแอป
///
/// เดิมเป็น AlertDialog เปล่า ๆ ปุ่ม "ลบ" เป็นตัวหนังสือเขียวเหมือนปุ่มทั่วไป
/// ทั้งที่เป็นการกระทำที่ย้อนกลับไม่ได้ ตอนนี้มีไอคอนถังขยะบอกตั้งแต่แวบแรก
/// บอกเลขเอกสารของใบที่จะลบ (กันลบผิดใบ) และปุ่มลบเป็นแดงทึบแยกจากปุ่มยกเลิก
Future<bool> showConfirmDeleteDialog(
  BuildContext context, {
  required String docNumber,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _ConfirmDialog(
      icon: Icons.delete_outline_rounded,
      title: 'ลบรายการนี้?',
      message: docNumber.isEmpty
          ? 'ลบแล้วรูปและข้อมูลของรายการนี้จะหายจากเครื่อง กู้คืนไม่ได้'
          : 'เลขเอกสาร $docNumber\nลบแล้วรูปและข้อมูลจะหายจากเครื่อง กู้คืนไม่ได้',
      confirmLabel: 'ลบ',
    ),
  );
  return result ?? false;
}

/// กล่องยืนยันการกระทำที่ต้องระวัง (ไอคอน หัวข้อ คำอธิบาย ปุ่มยกเลิก/ยืนยัน)
class _ConfirmDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;

  const _ConfirmDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.dangerBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: AppColors.dangerText),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    // ยกเลิกเป็นทางที่ปลอดภัย ไม่ต้องเด่น ใช้เทาไม่ใช่เขียวแบรนด์
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.onSurface,
                      side: BorderSide(
                        color: scheme.outlineVariant,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('ยกเลิก'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.dangerText,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// หน้าต่างยืนยันส่งรายการที่เคยส่งไปแล้วซ้ำอีกรอบ หน้าตาเดียวกับยืนยันลบ
///
/// ส่งซ้ำคือข้อมูลขึ้น Sheet เป็นแถวใหม่อีกแถว ต้องระวังพอ ๆ กับการลบ
/// จึงใช้กล่องแบบเดียวกัน ส่ง [docNumber] มาเมื่อเป็นการส่งทีละใบ
Future<bool> showConfirmResendDialog(
  BuildContext context, {
  String? docNumber,
  String? message,
}) async {
  final doc = docNumber ?? '';
  final result = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (context) => _ConfirmDialog(
      icon: Icons.refresh_rounded,
      title: 'ส่งอีกครั้ง?',
      message:
          message ??
          (doc.isEmpty
              ? 'รายการนี้ส่งไปแล้ว ส่งอีกครั้งจะขึ้น Sheet เป็นแถวใหม่'
              : 'เลขเอกสาร $doc ส่งไปแล้ว\nส่งอีกครั้งจะขึ้น Sheet เป็นแถวใหม่'),
      confirmLabel: 'ส่งอีกครั้ง',
    ),
  );
  return result ?? false;
}

/// เตือนก่อนออกจากฟอร์มที่กรอกค้างไว้ คืน true เมื่อผู้ใช้ยืนยันทิ้งข้อมูล
///
/// เรียกเฉพาะตอนมีอะไรเปลี่ยนจากตอนเปิดฟอร์มแล้ว ฟอร์มว่างกดกลับออกได้เลย
/// ไม่ต้องถาม (ผู้เรียกเช็กเอง)
///
/// ปุ่มหลักคือ "กรอกต่อ" ไม่ใช่ปุ่มทิ้ง กดพลาดเพราะนิ้วโดนปุ่มเด่นสุดแล้วข้อมูล
/// ไม่หาย ส่วนปุ่มทิ้งเป็นตัวหนังสือสีแดงอยู่ล่าง ต้องตั้งใจกดถึงจะโดน
///
/// [editing] = แก้ไขรายการเดิม ข้อความเปลี่ยนเป็นเรื่องการแก้ไขไม่ถูกบันทึก
Future<bool> showDiscardChangesDialog(
  BuildContext context, {
  bool editing = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;

      return Dialog(
        backgroundColor: AppTheme.cardColor(scheme),
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.dangerBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_off_outlined,
                  size: 28,
                  color: AppColors.dangerText,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                editing ? 'ยกเลิกการแก้ไข?' : 'ทิ้งข้อมูลที่กรอกไว้?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                editing
                    ? 'สิ่งที่แก้ไขในรายการนี้จะไม่ถูกบันทึก'
                    : 'ข้อมูลและรูปที่กรอกในฟอร์มนี้จะหายไป',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(editing ? 'แก้ไขต่อ' : 'กรอกต่อ'),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.dangerText,
                  ),
                  child: Text(editing ? 'ยกเลิกการแก้ไข' : 'ทิ้งข้อมูลแล้วออก'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}
