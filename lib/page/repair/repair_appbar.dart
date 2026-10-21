import 'package:flutter/material.dart';

/// แถบหัวเรื่องของระบบแจ้งซ่อม
///
/// เดิมเป็นแถบเขียว LINE ทึบ ให้ต่อเนื่องกับสีประจำของแจ้งซ่อม ตอนนี้ทั้งแอป
/// ใช้แถบสีเดียวกับพื้นหน้า และเลิกใช้สีประจำแยกระบบแล้ว แถบนี้จึงเป็นแถบ
/// ปกติของธีม
///
/// เก็บฟังก์ชันไว้ให้ทุกหน้าในแจ้งซ่อมเรียกที่เดียว เหมือน `itCaseAppBar`
PreferredSizeWidget repairAppBar({
  required String title,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
}) => AppBar(title: Text(title), actions: actions, bottom: bottom);
