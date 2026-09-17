import 'package:flutter/material.dart';
import 'package:claim/page/chat/chat_api.dart';
import 'package:claim/utils/app_colors.dart';

/// แถบชวนแอด LINE OA เพื่อรับแจ้งเตือนสถานะงานซ่อม
///
/// ค้างอยู่บนหน้าหลักตลอดจนกว่าผู้ใช้จะผูกบัญชีกับบอทจริง ไม่มีปุ่มปิด
/// เพราะแถบนี้ไม่ใช่โฆษณา แต่เป็นขั้นตอนที่ยังทำไม่เสร็จ ปิดไปแล้วคนจะลืม
/// แล้วไม่ได้รับแจ้งเตือนตลอดไปโดยไม่รู้ตัว ผูกเสร็จเมื่อไหร่ก็หายไปเอง
///
/// เช็คใหม่ทุกครั้งที่กลับเข้าแอป เพราะขั้นตอนผูกบัญชีเกิดนอกแอป (ไปทักบอทใน
/// LINE) กลับมาแล้วแถบต้องหายทันที ไม่ใช่ค้างอยู่จนกว่าจะปิดแอปเปิดใหม่
///
/// ⚠️ ระบบส่งแจ้งเตือนตอนสถานะเปลี่ยนฝั่ง backend ยังไม่ได้ทำ ณ วันที่เขียน
/// คนที่แอดตอนนี้จะยังไม่ได้รับอะไรจนกว่าจะทำเสร็จ ข้อความบนแถบจึงไม่ได้สัญญา
/// ว่าจะได้เมื่อไหร่ แต่ทักถามสถานะเองได้ทันที
class LineInviteBanner extends StatefulWidget {
  const LineInviteBanner({super.key});

  @override
  State<LineInviteBanner> createState() => _LineInviteBannerState();
}

class _LineInviteBannerState extends State<LineInviteBanner>
    with WidgetsBindingObserver {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// กลับเข้าแอปมาแล้วเช็คใหม่ เผื่อเพิ่งไปผูกบัญชีใน LINE มา
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  /// เช็คว่าควรโชว์ไหม เกณฑ์อยู่ที่ [shouldInviteLine] ที่เดียว
  ///
  /// แถบในหน้าแชทใช้ตัวเดียวกัน แยกกันเขียนแล้ววันหลังแก้เกณฑ์จะแก้ไม่ครบ
  /// แล้วสองที่ตอบไม่ตรงกัน
  Future<void> _check() async {
    final invite = await shouldInviteLine();
    if (!mounted || _show == invite) return;

    setState(() => _show = invite);
  }

  @override
  Widget build(BuildContext context) {
    // ยังไม่รู้ผล หรือผูกแล้ว ก็ไม่กินที่บนหน้าหลักเลย
    if (!_show) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        child: InkWell(
          // แตะที่แถบก็เพิ่มเพื่อนได้ ไม่ต้องเล็งปุ่มเล็ก ๆ
          onTap: openLineAddFriend,
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                        'แอดบอทไว้ แล้วทักถามสถานะเคสได้เลย',
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
                          onPressed: openLineAddFriend,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
