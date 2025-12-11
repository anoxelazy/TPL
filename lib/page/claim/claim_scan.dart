import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

Future<String?> openBarcodeScanner(BuildContext context) async {
  bool isScanned = false;
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('สแกนบาร์โค้ด')),
        body: Stack(
          children: [
            MobileScanner(
              onDetect: (BarcodeCapture capture) {
                if (isScanned) return;
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                  isScanned = true;
                  Navigator.pop(context, barcodes.first.rawValue);
                }
              },
            ),
            // Scanning frame overlay
            Positioned.fill(
              child: CustomPaint(
                painter: ScannerOverlayPainter(),
              ),
            ),
            // Red scanning line
            // Positioned(
            //   top: MediaQuery.of(context).size.height / 2 - 2,
            //   left: MediaQuery.of(context).size.width * 0.1,
            //   right: MediaQuery.of(context).size.width * 0.1,
            //   child: Container(
            //     height: 4,
            //     color: Colors.red,
            //   ),
            // ),
            // Instruction text
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'วางบาร์โค้ดให้อยู่ในกรอบและตรงกับเส้นสีแดง',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (result != null && result is String) {
    return result;
  }
  return null;
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final double scanAreaWidth = size.width * 0.8;
    final double scanAreaHeight = 200;
    final double left = (size.width - scanAreaWidth) / 2;
    final double top = (size.height - scanAreaHeight) / 2;

    // Draw the scanning rectangle corners
    final cornerLength = 30.0;

    // Top-left corner
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left, top + cornerLength), paint);

    // Top-right corner
    canvas.drawLine(Offset(left + scanAreaWidth, top), Offset(left + scanAreaWidth - cornerLength, top), paint);
    canvas.drawLine(Offset(left + scanAreaWidth, top), Offset(left + scanAreaWidth, top + cornerLength), paint);

    // Bottom-left corner
    canvas.drawLine(Offset(left, top + scanAreaHeight), Offset(left + cornerLength, top + scanAreaHeight), paint);
    canvas.drawLine(Offset(left, top + scanAreaHeight), Offset(left, top + scanAreaHeight - cornerLength), paint);

    // Bottom-right corner
    canvas.drawLine(Offset(left + scanAreaWidth, top + scanAreaHeight), Offset(left + scanAreaWidth - cornerLength, top + scanAreaHeight), paint);
    canvas.drawLine(Offset(left + scanAreaWidth, top + scanAreaHeight), Offset(left + scanAreaWidth, top + scanAreaHeight - cornerLength), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
