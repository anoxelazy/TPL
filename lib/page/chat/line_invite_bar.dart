import 'package:flutter/material.dart';

import 'package:claim/page/chat/chat_api.dart';
import 'package:claim/utils/app_colors.dart';

/// แถบเตี้ยชวนแอด LINE วางไว้หัวหน้าจอที่เกี่ยวกับงานซ่อม
///
/// ใช้ในหน้าที่คนกำลังตามงานอยู่พอดี (รายการใบแจ้งซ่อม หน้าแชท) เป็นจังหวะ
/// ที่บอกว่า "ไม่ต้องเปิดแอปมาดูก็ได้" แล้วเข้าใจทันที
///
/// เตี้ยกว่าแถบบนหน้าหลัก ([LineInviteBanner]) มาก เพราะหน้าพวกนี้ต้องเหลือที่
/// ให้เนื้อหาเป็นหลัก ส่วนหน้าหลักมีที่ว่างพอจะอธิบายยาวได้
///
/// เกณฑ์ว่าจะโชว์ไหมใช้ [shouldInviteLine] ตัวเดียวกับทุกที่ ไม่ได้ตัดสินเอง
class LineInviteBar extends StatefulWidget {
  /// ข้อความชวน เปลี่ยนตามหน้าที่เอาไปวางได้
  final String message;

  const LineInviteBar({
    super.key,
    this.message = 'รับแจ้งเตือนงานซ่อมทาง LINE ไม่ต้องเปิดแอปมาดู',
  });

  @override
  State<LineInviteBar> createState() => _LineInviteBarState();
}

class _LineInviteBarState extends State<LineInviteBar> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final invite = await shouldInviteLine();
    if (!mounted || !invite) return;

    setState(() => _show = true);
  }

  @override
  Widget build(BuildContext context) {
    // ยังไม่รู้ผล หรือผูกแล้ว ก็ไม่กินที่เลย
    if (!_show) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: AppColors.lineGreen.withValues(alpha: 0.10),
      child: InkWell(
        onTap: openLineAddFriend,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
          child: Row(
            children: [
              const Icon(
                Icons.chat_bubble,
                size: 17,
                color: AppColors.lineGreen,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  widget.message,
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurface),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'เพิ่มเพื่อน',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.lineGreen,
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: AppColors.lineGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
