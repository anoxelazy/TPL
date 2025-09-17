import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

Future<String?> openBarcodeScanner(BuildContext context) async {
  bool isScanned = false;
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('สแกนบาร์โค้ด')),
        body: MobileScanner(
          onDetect: (BarcodeCapture capture) {
            if (isScanned) return;
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
              isScanned = true;
              Navigator.pop(context, barcodes.first.rawValue);
            }
          },
        ),
      ),
    ),
  );
  if (result != null && result is String) {
    return result;
  }
  return null;
}


