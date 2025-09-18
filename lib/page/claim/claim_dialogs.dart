import 'package:flutter/material.dart';

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
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    );
                  },
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<String>(
                  valueListenable: currentStatus,
                  builder: (context, status, child) {
                    return Text(
                      status,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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

Future<void> showLoadingDialog(BuildContext context, {String message = 'กำลังส่งข้อมูล...'}) async {
  await showDialog(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (context) {
      return WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Flexible(child: Text(message)),
              ],
            ),
          ),
        ),
      );
    },
  );
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
        content: Text(message),
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


