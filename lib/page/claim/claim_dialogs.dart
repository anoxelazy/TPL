import 'package:flutter/material.dart';

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


