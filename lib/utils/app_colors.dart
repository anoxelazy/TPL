import 'package:flutter/material.dart';

/// สีเชิงความหมายที่ใช้ร่วมกันทุกฟีเจอร์
///
/// ไม่ได้ดึงจาก colorScheme เพราะ seed ของแอปเป็นสีเขียว ทุกโทนที่ได้จะเขียว
/// จนแยกสถานะไม่ออก ค่าพวกนี้เลือกให้อ่านออกทั้งธีมสว่างและมืด
class AppColors {
  const AppColors._();

  /// สำเร็จ / ผ่านขั้นตอนแล้ว
  static const Color success = Color(0xFF16A34A);

  /// พัก / รอดำเนินการ
  static const Color pending = Color(0xFFF9A825);

  /// ไม่สำเร็จ / ตีกลับ
  static const Color danger = Color(0xFFEF4444);

  /// สีของระยะการเดินทางบนกราฟหน้าคลังสินค้า
  /// (พัก/ตีกลับ/ส่งถึง ใช้ pending/danger/success ร่วมกับที่อื่น)
  static const Color stageOrigin = Color(0xFF3B82F6);
  static const Color stageWarehouse = Color(0xFF0EA5A4);
  static const Color stageDelivering = Color(0xFF8B5CF6);

  /// กล่องสรุปยอดเงิน
  static const Color moneyText = Color(0xFFB26A00);
  static const Color moneyBorder = Color(0xFFE8A33D);
  static const Color moneyBg = Color(0xFFFCE8CC);

  /// สีไอคอนเมนูบนหน้าหลัก คู่ละ (ไอคอน, พื้นหลัง)
  static const Color claimIcon = Color(0xFFE65100);
  static const Color claimBg = Color(0xFFFFF3E0);
  static const Color stockIcon = Color(0xFF2E7D32);
  static const Color stockBg = Color(0xFFE8F5E9);
  static const Color planIcon = Color(0xFF6A1B9A);
  static const Color planBg = Color(0xFFF3E5F5);
  static const Color pmIcon = Color(0xFF1565C0);
  static const Color pmBg = Color(0xFFE3F2FD);
  static const Color assetIcon = Color(0xFF00695C);
  static const Color assetBg = Color(0xFFE0F2F1);
  static const Color meterIcon = Color(0xFFAD1457);
  static const Color meterBg = Color(0xFFFCE4EC);
  static const Color scanIcon = Color(0xFF00838F);
  static const Color scanBg = Color(0xFFE0F7FA);
  static const Color trackingIcon = Color(0xFF3949AB);
  static const Color trackingBg = Color(0xFFE8EAF6);

  /// ป้ายอันดับผู้ส่งรายงานบนรูปโปรไฟล์
  static const Color rankGold = Color(0xFFD9A11B);
  static const Color rankSilver = Color(0xFF8D97A5);
  static const Color rankBronze = Color(0xFFB5713C);
  static const Color rankDiamond = Color(0xFF2AA9C7);

  /// อันดับ 4-10 ยังติดสิบอันดับ แต่ไม่ใช่เหรียญ
  ///
  /// เลือกน้ำเงินอมม่วงเพราะต้องไม่ถูกเข้าใจผิดว่าเป็นเหรียญเงิน
  /// ที่จางและออกเทากว่านี้
  static const Color rankTop10 = Color(0xFF5A6EA8);

  /// สีแบรนด์ LINE ใช้กับปุ่มติดต่อผู้ดูแลและเป็นสีประจำระบบแจ้งซ่อม
  static const Color lineGreen = Color(0xFF06C755);

  /// สีประจำระบบแจ้งซ่อม ใช้สีแบรนด์ LINE เพราะระบบนี้ผูกกับ LINE OA
  /// (บอทติดตามสถานะ ผูกบัญชี แจ้งเตือน) คนที่คุ้นกับบอทในไลน์อยู่แล้ว
  /// จะเห็นว่าเป็นเรื่องเดียวกัน
  ///
  /// ⚠️ ตัวหนังสือขาวบนสีนี้ contrast ต่ำกว่าเกณฑ์ AA ใช้ได้กับหัวเรื่องและ
  /// ปุ่มที่ตัวอักษรใหญ่และหนา แต่อย่าเอาไปใช้เป็นสีข้อความเนื้อหาบนพื้นขาว
  static const Color repairIcon = lineGreen;

  /// พื้นอ่อนของสีข้างบน สำหรับกล่องไอคอนและพื้นการ์ด
  static const Color repairBg = Color(0xFFE3F9EC);

  /// แจ้งเคสให้ทีม IT คนละเมนูกับแจ้งซ่อม สีจึงต้องแยกจากกันให้เห็น
  static const Color caseIcon = Color(0xFF5B21B6);
  static const Color caseBg = Color(0xFFEDE9FE);
}

/// ค่ามาตรฐานของการ์ดและระยะห่าง ให้ทุกหน้าหน้าตาเท่ากัน
class AppSizes {
  const AppSizes._();

  static const double cardRadius = 16;
  static const double cardBorder = 0.5;
  static const EdgeInsets cardPadding = EdgeInsets.all(16);

  /// ระยะขอบของ list ในหน้าเนื้อหา
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(16, 16, 16, 24);

  /// ระยะห่างระหว่างการ์ด
  static const double gap = 12;
}
