/// ไอคอนที่ใช้ร่วมกันหลายฟีเจอร์ รวมไว้ที่เดียวเพื่อให้เปลี่ยนครั้งเดียวได้ทั้งแอป
///
/// ใส่เฉพาะไอคอนที่โผล่หลายที่และต้องหน้าตาตรงกัน ไอคอนที่ใช้ที่เดียว
/// เรียก [Icons] ตรง ๆ ในไฟล์นั้นได้เลย ไม่ต้องมาลงทะเบียนที่นี่
library;

import 'package:flutter/widgets.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class AppIcons {
  const AppIcons._();

  /// ไอคอนสแกนบาร์โค้ด/QR: กรอบสี่มุมพร้อมเส้นกลาง
  ///
  /// ใช้ของ Fluent ไม่ใช่ `Icons.qr_code_scanner` ของ Material เพราะตัวของ
  /// Material วาดลาย QR ไว้ในกรอบ ทำให้ดูรกและสื่อว่าสแกนได้แต่ QR
  /// ทั้งที่งานจริงยิงบาร์โค้ดเป็นหลัก ตัวนี้เป็นกรอบเล็งเปล่า ๆ กับเส้นกวาด
  /// ตรงกลาง อ่านออกว่า "สแกน" ทันทีและเข้ากับทั้งบาร์โค้ดและ QR
  static const IconData scan = FluentIcons.scan_dash_24_regular;
}
