import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:claim/page/chat/chat_api.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/app_config.dart';
import 'package:claim/utils/role_service.dart';

/// คีย์เก็บว่าเคยกดปิดแถบนี้ไปแล้ว แยกตามรหัสพนักงาน
///
/// แยกตามคนเพราะเครื่องเดียวมีคนใช้หลายคนได้ คนแรกกดปิดแล้วคนถัดไปต้องยังเห็น
String lineBannerDismissKey(String empId) => 'line_banner_dismissed_$empId';

/// แถบชวนแอด LINE OA เพื่อรับแจ้งเตือนสถานะงานซ่อม
///
/// โผล่เฉพาะคนที่ยังไม่ได้ผูกบัญชีกับบอท ผูกแล้วหายไปเอง ไม่ต้องกดปิด
/// และกดปิดแล้วไม่กลับมาอีกจนกว่าจะล้างข้อมูลแอป
///
/// ⚠️ ระบบส่งแจ้งเตือนตอนสถานะเปลี่ยนฝั่ง backend ยังไม่ได้ทำ ณ วันที่เขียน
/// คนที่แอดตอนนี้จะยังไม่ได้รับอะไรจนกว่าจะทำเสร็จ ข้อความบนแถบจึงเขียนว่า
/// "รับแจ้งเตือน" ไม่ใช่ "แจ้งเตือนทันที" และไม่ได้สัญญาว่าจะได้เมื่อไหร่
class LineInviteBanner extends StatefulWidget {
  const LineInviteBanner({super.key});

  @override
  State<LineInviteBanner> createState() => _LineInviteBannerState();
}

class _LineInviteBannerState extends State<LineInviteBanner> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  /// เช็คเงียบ ๆ ว่าควรโชว์ไหม พังก็ไม่โชว์
  /// เช็คว่าควรโชว์ไหม พังก็ไม่โชว์ แต่บอกเหตุผลลง log ทุกทาง
  ///
  /// อ่าน driverID จาก prefs ตรง ๆ ไม่ผ่าน [RoleService] เพราะตัวนั้นอ่านค่า
  /// ตอนเปิดแอปครั้งเดียว ถ้าหน้าจอนี้ถูกสร้างก่อนมันอ่านเสร็จจะได้ค่าว่าง
  /// แล้วแถบจะเงียบไปตลอดโดยไม่มีอะไรบอก
  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final empId = prefs.getString('driverID')?.trim() ?? '';

    if (empId.isEmpty) {
      debugPrint('line banner: ไม่มี driverID ใน prefs ยังไม่ได้ล็อกอิน?');
      return;
    }

    if (prefs.getBool(lineBannerDismissKey(empId)) == true) {
      debugPrint('line banner: เคยกดปิดไปแล้ว ($empId)');
      return;
    }

    final empNumber = int.tryParse(empId);
    if (empNumber == null) {
      debugPrint('line banner: driverID "$empId" ไม่ใช่ตัวเลข');
      return;
    }

    final linked = await isLineLinked(empNumber);
    if (!mounted) return;

    if (linked) {
      debugPrint('line banner: ผูกบัญชีแล้ว หรือถามไม่สำเร็จ ($empNumber)');
      return;
    }

    debugPrint('line banner: ยังไม่ผูก โชว์แถบ ($empNumber)');
    setState(() => _show = true);
  }

  Future<void> _dismiss() async {
    setState(() => _show = false);

    final empId = RoleService.I.empId;
    if (empId == null || empId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(lineBannerDismissKey(empId), true);
  }

  /// เปิดหน้าเพิ่มเพื่อนของ LINE
  ///
  /// ต้องเปิดออกนอกแอป ไม่ใช่ webview ในตัว ระบบปฏิบัติการจะได้เด้งเข้าแอป LINE
  /// ให้เอง ถ้าเปิดใน webview จะค้างอยู่ที่หน้าเว็บแล้วกดเพิ่มเพื่อนไม่ได้
  Future<void> _addFriend() async {
    final uri = Uri.tryParse(AppConfig.repairLineOaUrl);
    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    // ยังไม่รู้ผล ผูกแล้ว หรือกดปิดไปแล้ว ก็ไม่กินที่บนหน้าหลักเลย
    if (!_show) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppColors.lineGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          border: Border.all(
            color: AppColors.lineGreen.withValues(alpha: 0.35),
            width: AppSizes.cardBorder,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.lineGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.chat_bubble,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'รับแจ้งเตือนงานซ่อมทาง LINE',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'แอดบอทไว้ แล้วทักถามสถานะเคสได้เลย ไม่ต้องเปิดแอป',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 34,
                    child: FilledButton.icon(
                      onPressed: _addFriend,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.lineGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.person_add_alt, size: 16),
                      label: const Text(
                        'เพิ่มเพื่อน',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'ไม่ต้องแสดงอีก',
              onPressed: _dismiss,
              iconSize: 18,
              color: scheme.onSurfaceVariant,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
