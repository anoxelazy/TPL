import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:claim/page/dashboard/support_links.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/update_service.dart';

/// ปุ่มติดต่อผู้ดูแลแอปผ่าน LINE อยู่มุมขวาของแถบทักทายบนหน้าหลัก
class LineSupportButton extends StatelessWidget {
  const LineSupportButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'แจ้งปัญหาการใช้งานแอป',
      child: InkWell(
        onTap: () => showLineSupportSheet(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.lineGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.support_agent, size: 17, color: AppColors.lineGreen),
              SizedBox(width: 5),
              Text(
                'แจ้งปัญหา',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.lineGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// แผ่นด้านล่างที่มีทั้ง QR ให้สแกนจากอีกเครื่อง และปุ่มเปิด LINE ในเครื่องเดียวกัน
Future<void> showLineSupportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // ไม่เปิดตัวนี้ sheet จะสูงได้แค่ 9/16 ของจอ เนื้อหาชุดนี้ล้นแน่นอน
    isScrollControlled: true,
    builder: (sheetContext) => ValueListenableBuilder<SupportLinks>(
      valueListenable: SupportLinksService.I.links,
      builder: (context, links, _) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'แจ้งปัญหาการใช้งานแอป',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'ทัก LINE ผู้ดูแลโดยตรง หรือแจ้งเคสผ่านเว็บของทีม IT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              // QR ต้องอยู่บนพื้นขาวเสมอ ธีมมืดถ้าใช้สีตามธีมจะสแกนไม่ติด
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: links.line,
                  version: QrVersions.auto,
                  size: MediaQuery.of(sheetContext).size.width * 0.42,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openLine(sheetContext, links.line),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('เปิด LINE'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lineGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openWeb(sheetContext, links.web),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('แจ้งเคสผ่านเว็บ IT'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => _copyLink(sheetContext, links.line),
                icon: const Icon(Icons.copy, size: 17),
                label: const Text('คัดลอกลิงก์'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _openLine(BuildContext context, String url) async {
  final opened = await UpdateService.launchExternalUrl(url);
  if (!context.mounted) return;

  if (opened) {
    Navigator.of(context).pop();
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('เปิด LINE ไม่ได้ ลองคัดลอกลิงก์แทน')),
  );
}

/// เปิดเว็บแจ้งเคสของ IT ในเบราว์เซอร์
Future<void> _openWeb(BuildContext context, String url) async {
  final opened = await UpdateService.launchExternalUrl(url);
  if (!context.mounted) return;

  if (opened) {
    Navigator.of(context).pop();
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('เปิดเว็บแจ้งเคสไม่ได้ กรุณาลองใหม่')),
  );
}

Future<void> _copyLink(BuildContext context, String url) async {
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('คัดลอกลิงก์แล้ว')));
}
