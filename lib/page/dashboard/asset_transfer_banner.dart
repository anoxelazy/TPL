import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:claim/page/asset/transfer_api.dart';
import 'package:claim/page/asset/transfer_list_page.dart';
import 'package:claim/page/dashboard/dashboard_banner.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/mobile_api.dart';

/// แถบใบโอนย้ายเต็มความกว้าง วางแยกออกมาจากตารางเมนูเหมือนแถบแจ้งเคส
///
/// ย้ายออกมาจากตารางเพราะเป็นงานที่มีของจริงเคลื่อนที่ตามและมีคนปลายทางรอรับ
/// ไม่ใช่หน้าจอไว้เปิดดูข้อมูลเฉย ๆ แบบเมนูอื่นในตาราง — ทะเบียนทรัพย์สินซึ่ง
/// เป็นหน้าค้นข้อมูลล้วน ๆ จึงอยู่ในตารางเมนูแทน
///
/// **เดิมแถบนี้ชื่อ "โอนย้ายทรัพย์สิน" แต่กดแล้วลงที่หน้าค้นทะเบียน** ส่วนใบ
/// โอนย้ายจริงซ่อนอยู่ในเมนูสามจุดอีกชั้น กว่าจะถึงต้องกดสามที ตอนนี้กดทีเดียว
/// ถึงของที่ชื่อแถบสัญญาไว้
///
/// ตัวเลขบนแถบคือจำนวนใบที่รอคนคนนี้ทำ (`/transfers/pending` เซิร์ฟเวอร์คัดตาม
/// สิทธิ์ให้แล้ว) คนที่มีใบรออนุมัติจะได้รู้ตั้งแต่เปิดแอป ไม่ต้องเข้าไปดูเอง
class AssetTransferBanner extends StatefulWidget {
  /// ดู [DashboardBanner.framed]
  final bool framed;

  const AssetTransferBanner({super.key, this.framed = true});

  @override
  State<AssetTransferBanner> createState() => _AssetTransferBannerState();
}

class _AssetTransferBannerState extends State<AssetTransferBanner> {
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  /// นับใบที่รออยู่แบบเงียบ ๆ
  ///
  /// ล้มเหลวไม่ต้องบอกใคร — คนที่ไม่มีสิทธิ์ระบบทรัพย์สินหรือยังไม่ได้ล็อกอิน
  /// Mobile API ก็เปิดหน้าหลักได้ตามปกติ แถบยังกดเข้าไปได้เหมือนเดิม แค่ไม่มี
  /// ตัวเลข ขึ้น error บนหน้าแรกเพราะนับเลขไม่ได้คือเสียมากกว่าได้
  Future<void> _loadPending() async {
    try {
      final rows = await fetchPendingTransfers();
      if (!mounted) return;
      setState(() => _pending = rows.length);
    } on MobileApiException {
      return;
    }
  }

  Future<void> _open() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TransferListPage()));

    // กลับมาแล้วนับใหม่ เขาเพิ่งไปอนุมัติหรือรับของมา ตัวเลขเดิมไม่จริงแล้ว
    if (!mounted) return;
    await _loadPending();
  }

  @override
  Widget build(BuildContext context) {
    return DashboardBanner(
      framed: widget.framed,
      icon: PhosphorIconsDuotone.arrowsLeftRight,
      color: AppColors.brandText,
      background: AppColors.brandBg,
      title: 'ใบโอนย้าย',
      subtitle: _pending > 0
          ? 'มี $_pending ใบรอคุณอนุมัติหรือรับของ'
          : 'ขอย้ายทรัพย์สิน อนุมัติ ส่งออก รับเข้า',
      badgeCount: _pending,
      onTap: _open,
    );
  }
}
