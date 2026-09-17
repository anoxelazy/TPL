import 'package:flutter/material.dart';

import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/theme.dart';

/// แถบหัวเรื่องของระบบแจ้งซ่อม
///
/// ทั้งแอปใช้แถบสีเขียวแบรนด์ แต่แจ้งซ่อมมีสีประจำของตัวเองเป็นน้ำตาล
/// (ตั้งแต่ไอคอนเมนูบนหน้าหลัก ยันแถบสีการ์ด) เดิมหน้าในนี้ใช้แถบเขียวตามธีม
/// รวม กดเข้ามาจากเมนูน้ำตาลแล้วเจอหัวเขียวจะสะดุด เหมือนหลุดไปอีกระบบ
///
/// ทำแบบเดียวกับ [itCaseAppBar] ของหน้าแจ้งเคส คือแถบสีทึบ ตัวหนังสือขาว
/// ไม่มีเงา เปลี่ยนแค่สีเดียว ไม่ได้เปลี่ยนรูปแบบ
///
/// ⚠️ ต้องส่ง systemOverlayStyle เองด้วย ไม่งั้นไอคอนแบตกับสัญญาณบนสุดของจอ
/// จะยังใช้ค่าที่คำนวณจากสีเขียวของธีม
PreferredSizeWidget repairAppBar({
  required String title,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
}) => AppBar(
  title: Text(title),
  actions: actions,
  bottom: bottom,
  backgroundColor: AppColors.repairIcon,
  foregroundColor: Colors.white,
  iconTheme: const IconThemeData(color: Colors.white),
  actionsIconTheme: const IconThemeData(color: Colors.white),
  systemOverlayStyle: AppTheme.statusBarStyleFor(AppColors.repairIcon),
);
