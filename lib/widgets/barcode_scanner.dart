import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

/// เปิดกล้องสแกนบาร์โค้ด/QR คืนค่าที่อ่านได้ (trim แล้ว) หรือ null เมื่อยกเลิก
///
/// ขอสิทธิ์กล้องก่อนเปิดหน้า ถ้าไม่ได้จะขึ้น dialog บอกเหตุผล ไม่ใช่จอดำ
/// และเด้งกลับทันทีที่อ่านค่าได้ครั้งแรก กันอ่านซ้ำหลายครั้ง
Future<String?> openBarcodeScannerPage(
  BuildContext context, {
  required String title,
  String hint = 'วางบาร์โค้ดให้อยู่กลางจอ ระบบจะกรอกให้อัตโนมัติ',
}) async {
  var status = await Permission.camera.status;
  if (!status.isGranted) {
    status = await Permission.camera.request();
  }
  if (!context.mounted) return null;

  if (!status.isGranted) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('กรุณาอนุญาตการเข้าถึงกล้อง'),
        content: const Text(
          'การสแกนต้องใช้กล้อง กรุณาอนุญาตสิทธิ์กล้องให้แอปก่อน '
          'แล้วลองสแกนอีกครั้ง หรือพิมพ์รหัสด้วยมือก็ได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
          if (status.isPermanentlyDenied)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('ไปตั้งค่า'),
            ),
        ],
      ),
    );
    return null;
  }

  final result = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => _BarcodeScannerPage(title: title, hint: hint),
    ),
  );

  // ค่าที่สแกนได้อาจมี whitespace ติดมา และต้องไม่คืนค่าว่างให้ผู้เรียก
  final trimmed = result?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

class _BarcodeScannerPage extends StatefulWidget {
  final String title;
  final String hint;

  const _BarcodeScannerPage({required this.title, required this.hint});

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  /// one-time detect: mobile_scanner ยิง onDetect ซ้ำ ๆ ตลอดที่โค้ดอยู่ในเฟรม
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        _handled = true;
        Navigator.pop(context, value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Positioned.fill(child: CustomPaint(painter: _ScanFramePainter())),
          Positioned(
            left: 20,
            right: 20,
            bottom: 60,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.hint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// มุมกรอบสี่มุมกลางจอ ให้ผู้ใช้รู้ว่าต้องเล็งที่ไหน
class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const frameHeight = 200.0;
    final frameWidth = size.width * 0.8;
    final left = (size.width - frameWidth) / 2;
    final top = (size.height - frameHeight) / 2;
    const corner = 30.0;

    void drawCorner(Offset origin, double dx, double dy) {
      canvas.drawLine(origin, origin.translate(dx * corner, 0), paint);
      canvas.drawLine(origin, origin.translate(0, dy * corner), paint);
    }

    drawCorner(Offset(left, top), 1, 1);
    drawCorner(Offset(left + frameWidth, top), -1, 1);
    drawCorner(Offset(left, top + frameHeight), 1, -1);
    drawCorner(Offset(left + frameWidth, top + frameHeight), -1, -1);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

/// เครื่องนี้สแกนบาร์โค้ดได้ไหม
///
/// เว็บบนคอมไม่มีกล้องหลัง เปิดขึ้นมาก็ได้กล้องหน้าที่ส่องบาร์โค้ดไม่ถนัด
/// และคนที่นั่งหน้าคอมมักถือของอยู่ตรงหน้าแล้วพิมพ์เองได้เร็วกว่าอยู่ดี
/// หน้าจอที่มีปุ่มสแกนจึงซ่อนปุ่มไปเลยบนเว็บ เหลือช่องให้พิมพ์เหมือนเดิม
///
/// ไม่ได้เช็คว่ามีกล้องจริงไหม เพราะการถามสิทธิ์กล้องต้องเกิดจากการกดของผู้ใช้
/// เช็คตอนวาดหน้าจอจะเด้งขอสิทธิ์ทั้งที่ยังไม่มีใครจะสแกน
bool get canScanBarcode => !kIsWeb;
