import 'package:flutter/material.dart';
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
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                    );
                  },
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<String>(
                  valueListenable: currentStatus,
                  builder: (context, status, child) {
                    return Text(
                      status,
                      style: const TextStyle(fontSize: 12, color: Colors.black),
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
          child: SendingAnimation(
            statusNotifier: notifier,
            message: message,
          ),
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
          style: TextStyle(
            color: title == 'ผิดพลาด' ? Colors.red : null,
          ),
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

Future<bool> showConfirmResendDialog(
  BuildContext context, {
  String title = 'ยืนยันการส่งอีกครั้ง',
  String message = 'รายการนี้ได้ส่งไปแล้ว คุณแน่ใจว่าต้องการส่งอีกครั้งหรือไม่?',
}) async {
  final result = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('ส่งอีกครั้ง'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}


