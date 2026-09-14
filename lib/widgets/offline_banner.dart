import 'package:flutter/material.dart';

import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/network_status.dart';

/// แถบแดงล่างสุดของจอ ขึ้นตอนต่อเซิร์ฟเวอร์ไม่ได้และค้างไว้จนต่อได้อีกครั้ง
///
/// ลอยทับเนื้อหาแทนที่จะดันลง หน้าที่เปิดอยู่จะได้ไม่ต้องจัด layout ใหม่
/// และไม่กินการกด ผู้ใช้ยังกดแถบเมนูล่างที่อยู่ข้างใต้ได้
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  static const Duration _duration = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: IgnorePointer(
        child: ValueListenableBuilder<bool>(
          valueListenable: NetworkStatus.I.isOffline,
          builder: (context, offline, child) => AnimatedSlide(
            duration: _duration,
            curve: Curves.easeOut,
            offset: offline ? Offset.zero : const Offset(0, 1),
            child: AnimatedOpacity(
              duration: _duration,
              opacity: offline ? 1 : 0,
              child: child,
            ),
          ),
          child: Material(
            color: AppColors.danger,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 7, 16, bottomInset + 7),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 15, color: Colors.white),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'ไม่มีอินเทอร์เน็ต กำลังเชื่อมต่อใหม่',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
