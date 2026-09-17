import 'package:flutter/material.dart';

import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/theme.dart';

/// แถบหัวเรื่องของหน้าแจ้งเคส
///
/// ทั้งแอปใช้แถบสีเขียวแบรนด์ แต่หน้าแจ้งเคสมีสีประจำของตัวเองเป็นม่วง
/// (ตั้งแต่แถบบนหน้าหลัก ไอคอนหัวการ์ด ยันปุ่มส่ง) เขียวชนม่วงเต็มแถบแล้วตัดกัน
/// จนอ่านยาก แถบของหน้านี้จึงใช้สีเดียวกับเนื้อหา กดเข้ามาจากแถบม่วงแล้วเจอ
/// หัวม่วงต่อเนื่องกัน ไม่ใช่สะดุดตรงหัวหน้าเดียว
///
/// ยังเป็นภาษาเดียวกับแอป คือแถบสีทึบ ตัวหนังสือขาว จัดกลาง ไม่มีเงา
/// เปลี่ยนแค่สีเดียว ไม่ได้เปลี่ยนรูปแบบ
///
/// ⚠️ ต้องส่ง systemOverlayStyle เองด้วย ไม่งั้นไอคอนแบตกับสัญญาณบนสุดของจอ
/// จะยังใช้ค่าที่คำนวณจากสีเขียวของธีม
PreferredSizeWidget itCaseAppBar({
  required String title,
  List<Widget>? actions,
}) => AppBar(
  title: Text(title),
  actions: actions,
  backgroundColor: AppColors.caseIcon,
  foregroundColor: Colors.white,
  iconTheme: const IconThemeData(color: Colors.white),
  actionsIconTheme: const IconThemeData(color: Colors.white),
  systemOverlayStyle: AppTheme.statusBarStyleFor(AppColors.caseIcon),
);
