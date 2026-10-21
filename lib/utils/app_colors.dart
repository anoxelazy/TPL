import 'package:flutter/material.dart';

// ชุดสีต้นฉบับจากฝั่งออกแบบ ใช้ prefix เพราะในไฟล์นั้นชื่อคลาสก็เป็น AppColors
import 'package:claim/colors.dart' as palette;

/// สีเชิงความหมายที่ใช้ร่วมกันทุกฟีเจอร์
///
/// ค่าสีมาจากชุดสีของฝั่งออกแบบ ([palette.AppColors] ใน lib/colors.dart)
/// ไฟล์นี้แค่บอกว่าสีไหนใช้ทำหน้าที่อะไร จะเปลี่ยนโทนให้แก้ที่ชุดสีต้นฉบับ
///
/// มีสองสามตัวที่ไม่ได้มาจากชุดสีตรง ๆ (ติดป้าย "นอกชุดสี") เพราะใช้เป็น
/// ตัวหนังสือเล็กบนพื้นขาว แล้วสีในชุดอ่อนเกินเกณฑ์ contrast 4.5:1
///
/// ไม่ได้ดึงจาก colorScheme เพราะ seed ของแอปเป็นสีเขียว ทุกโทนที่ได้จะเขียว
/// จนแยกสถานะไม่ออก
class AppColors {
  const AppColors._();

  /// สีแบรนด์ของบริษัท ใช้เป็น seed ของธีมและเป็นสีของปุ่มหลัก
  ///
  /// ⚠️ ตัวหนังสือขาวบนสีนี้ได้ contrast 3.1:1 ผ่านเกณฑ์ AA เฉพาะตัวอักษรใหญ่
  /// และหนา (หัวเรื่อง ปุ่ม) เหมือนกับ [repairIcon] ห้ามเอาไปเป็นสีตัวหนังสือ
  /// เล็กบนพื้นขาว ใช้ [brandText] แทน
  static const Color brand = palette.AppColors.greenPrimary;

  /// สีเขียวที่ใช้เป็นตัวหนังสือ ไอคอน และเส้น
  ///
  /// เป็นเขียวหลักตัวเดียวกับ [brand] ทั้งแอปจึงมีเขียวเดียว เคยแยกเป็นเขียว
  /// เข้มนอกชุดสี (#0E7A3B) เพื่อให้ตัวหนังสือเล็กได้ contrast 4.5:1 แต่พอวาง
  /// คู่กับปุ่มเขียวหลักแล้วเห็นเป็นเขียวสองเฉดชัดเจน เลยเลือกความเป็นชุดเดียว
  ///
  /// ⚠️ บนพื้นขาวได้ contrast 3.1:1 ผ่านเกณฑ์สำหรับไอคอนและตัวหนังสือ
  /// ใหญ่/หนา ตัวหนังสือเขียวเล็ก ๆ ให้ใช้ตัวหนา หรือใช้สีตัวหนังสือปกติแทน
  static const Color brandText = brand;

  /// สำเร็จ / ผ่านขั้นตอนแล้ว
  ///
  /// ใช้เขียวหลัก ไม่ใช่ greenSuccess ของชุดสี เพราะตัวนั้นสดจนบนพื้นขาวได้
  /// contrast แค่ 2:1 ไอคอนกับป้ายสถานะจะจางจนแทบมองไม่เห็น
  static const Color success = palette.AppColors.greenPrimary;

  /// พัก / รอดำเนินการ
  ///
  /// ใช้ส้มเข้ม (300) ไม่ใช่ orangeWarning เพราะตัวกลางอ่อนเกินจะเป็นสีไอคอน
  static const Color pending = palette.AppColors.orangeWarning300;

  /// ไม่สำเร็จ / ตีกลับ
  static const Color danger = palette.AppColors.redError;

  /// สีของระยะการเดินทางบนกราฟหน้าคลังสินค้า
  /// (พัก/ตีกลับ/ส่งถึง ใช้ pending/danger/success ร่วมกับที่อื่น)
  static const Color stageOrigin = Color(0xFF3B82F6);
  static const Color stageWarehouse = Color(0xFF0EA5A4);
  static const Color stageDelivering = Color(0xFF8B5CF6);

  /// กล่องสรุปยอดเงิน
  ///
  /// ตัวหนังสือเป็นส้มเข้มนอกชุดสี เพราะมีบรรทัดขนาด 13 ที่ส้ม 300 ของชุดสี
  /// (3.1:1) อ่านไม่ผ่านเกณฑ์ ตัวนี้ได้ 4.9:1 ขอบกับพื้นใช้ของชุดสีตรง ๆ
  static const Color moneyText = Color(0xFFA06400);
  static const Color moneyBorder = palette.AppColors.orangeWarning;

  /// สีสถานะแบบเข้ม สำหรับตัวหนังสือเล็กบนพื้นขาวหรือพื้นอ่อน
  ///
  /// [pending] กับ [success] ได้ contrast แค่ราว 3:1 ใช้กับไอคอนและพื้นได้
  /// แต่ตัวหนังสือขนาด 14 ลงมาจะอ่านยาก ใช้คู่นี้แทนเมื่อสีนั้นเป็นตัวหนังสือ
  static const Color pendingText = moneyText;
  static const Color successText = brandText;
  static const Color dangerText = palette.AppColors.redSecondary;

  /// พื้นอ่อนของสีลบ/ผิดพลาด คู่กับ [dangerText] เช่นปุ่มลบที่โผล่ตอนปัดการ์ด
  static const Color dangerBg = palette.AppColors.redSecondary100;
  static const Color moneyBg = palette.AppColors.orangeWarning100;

  /// พื้นการ์ดรายการสินค้าเสียหาย แยกตามสถานะการส่ง
  ///
  /// ยังไม่ส่ง = ส้มอ่อน ส่งแล้ว = เขียวอ่อน เห็นจากสีการ์ดทันทีว่ารายการไหนค้าง
  /// ใช้ขั้นอ่อน (100) ของชุดสี ไม่ใช่ตัวเต็ม ตัวเต็มทั้งใบฉูดฉาดเกินไป
  /// ตัวหนังสือและไอคอนบนการ์ดใช้ [ink] อ่านออกบนพื้นทั้งสองสี
  static const Color claimPendingBg = palette.AppColors.orangeWarning100;
  static const Color claimSentBg = palette.AppColors.greenPrimary100;

  /// พื้นปุ่มแก้ไข (ปากกา) บนการ์ดรายการ
  static const Color claimEditFill = palette.AppColors.orangeWarning;

  /// ส่งรอบก่อนไม่สำเร็จ หรือเซิร์ฟเวอร์ไม่ตอบ รอกดส่งใหม่ = แดงอ่อน
  static const Color claimFailedBg = palette.AppColors.redSecondary100;

  /// พื้นอ่อนของสีแบรนด์ สำหรับวงหลังไอคอนของสิ่งที่ต้องเด่น
  static const Color brandBg = palette.AppColors.greenPrimary100;

  /// สีหมึกสำหรับไอคอนเมนูทั่วไป
  static const Color ink = palette.AppColors.baseBlack;

  /// พื้นเทาอ่อนคู่กับ [ink]
  static const Color inkBg = palette.AppColors.greyNeutral100;

  /// สีไอคอนเมนูบนหน้าหลัก คู่ละ (ไอคอน, พื้นหลัง)
  ///
  /// ทุกเมนูใช้เขียวแบรนด์อ่อน ๆ คู่เดียวกันหมด หมึกเทาล้วนดูจืดเกินไป
  /// ส่วนเขียว-ส้ม-แดงสลับกันก็ฉูดฉาดเกินไป (ลองมาแล้วทั้งสองแบบ)
  /// เขียวคู่เดียวมีสีพอให้หน้ามีชีวิต แต่ยังเรียบเป็นโทนเดียวกับแบรนด์
  ///
  /// แยกชื่อไว้ทีละเมนู อยากเปลี่ยนสีเมนูไหนก็แก้ที่นี่ที่เดียว
  static const Color menuIcon = brandText;
  static const Color menuBg = brandBg;

  static const Color claimIcon = menuIcon;
  static const Color claimBg = menuBg;
  static const Color stockIcon = menuIcon;
  static const Color stockBg = menuBg;
  static const Color trackingIcon = menuIcon;
  static const Color trackingBg = menuBg;
  static const Color planIcon = menuIcon;
  static const Color planBg = menuBg;
  static const Color scanIcon = menuIcon;
  static const Color scanBg = menuBg;
  static const Color meterIcon = menuIcon;
  static const Color meterBg = menuBg;
  static const Color repairMenuIcon = menuIcon;
  static const Color repairMenuBg = menuBg;
  static const Color assetIcon = menuIcon;
  static const Color assetBg = menuBg;
  static const Color pmIcon = menuIcon;
  static const Color pmBg = menuBg;

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

  /// ผู้ใช้งานทั่วไป ไม่ติดสิบอันดับ
  ///
  /// เทากลาง ๆ ไม่ใช่สีของรางวัล เพราะชั้นนี้ไม่ได้แปลว่าได้อะไรมา
  /// ใช้แค่บนการ์ดตอนกดรูป ไม่มีป้ายบนรูปโปรไฟล์
  static const Color rankMember = Color(0xFF8A9099);

  /// สีของปุ่มและแถบที่พาไป LINE
  ///
  /// เดิมเป็นเขียว LINE (#06C755) ซึ่งเป็นเขียวคนละเฉดกับแบรนด์ วางใกล้กัน
  /// แล้วดูเป็นเขียวปนกัน ตอนนี้ใช้เขียวแบรนด์ตัวเดียวทั้งแอป ยังสื่อว่าเป็น
  /// LINE ได้จากไอคอนแชทกับข้อความบนปุ่ม
  static const Color lineGreen = brand;

  /// สีเน้นของระบบแจ้งซ่อม (ปุ่ม แถบการ์ด ตัวเลขค้าง)
  ///
  /// เดิมใช้เขียว LINE ซึ่งเป็นเขียวคนละเฉดกับแบรนด์ ทั้งแอปเลยมีเขียวสองตัว
  /// ปนกัน ตอนนี้ใช้เขียวแบรนด์ตัวเดียวกับทั้งแอป
  static const Color repairIcon = brandText;

  /// พื้นอ่อนของสีข้างบน สำหรับกล่องไอคอนและพื้นการ์ด
  static const Color repairBg = brandBg;

  /// สีเน้นของระบบแจ้งเคส IT
  ///
  /// เดิมเป็นม่วงทั้งระบบ แยกจากแจ้งซ่อมด้วยสี ตอนนี้ใช้เขียวแบรนด์เหมือนกัน
  /// แยกด้วยไอคอนกับชื่อแทน สีม่วงที่ไม่เกี่ยวกับแบรนด์ทำให้แอปดูเป็นสองแอป
  static const Color caseIcon = brandText;
  static const Color caseBg = brandBg;
}

/// ค่ามาตรฐานของการ์ดและระยะห่าง ให้ทุกหน้าหน้าตาเท่ากัน
class AppSizes {
  const AppSizes._();

  static const double cardRadius = 16;
  static const double cardBorder = 0.5;
  static const EdgeInsets cardPadding = EdgeInsets.all(16);

  /// มุมโค้งของกล่องเล็กที่อยู่ในการ์ดหรือในหน้า: ช่องค้นหา ช่องกรอก
  /// กล่องสรุปยอด รูปย่อ แถวตัวเลือก
  ///
  /// เดิมแต่ละเมนูตั้งเองเป็น 8, 9, 10, 12 ปนกัน หน้าตาเลยไม่เป็นชุดเดียวกัน
  /// ตอนนี้กล่องเล็กใช้ค่านี้ค่าเดียว การ์ดใช้ [cardRadius]
  static const double innerRadius = 12;

  /// มุมของป้าย/ชิปทรงแคปซูล
  static const double pillRadius = 20;

  /// ระยะขอบของ list ในหน้าเนื้อหา
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(16, 16, 16, 24);

  /// ระยะห่างระหว่างการ์ด
  static const double gap = 12;
}
