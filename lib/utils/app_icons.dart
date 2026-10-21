/// ไอคอนที่ใช้ร่วมกันหลายฟีเจอร์ รวมไว้ที่เดียวเพื่อให้เปลี่ยนครั้งเดียวได้ทั้งแอป
///
/// ใส่เฉพาะไอคอนที่โผล่หลายที่และต้องหน้าตาตรงกัน ไอคอนที่ใช้ที่เดียว
/// เรียก [Icons] ตรง ๆ ในไฟล์นั้นได้เลย ไม่ต้องมาลงทะเบียนที่นี่
library;

import 'package:flutter/widgets.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:claim/utils/app_colors.dart';

class AppIcons {
  const AppIcons._();

  /// ไอคอนสองโทนของหน้าหลัก: เส้นเป็น [color] ไส้เป็นเขียวแบรนด์โปร่ง ๆ
  ///
  /// ส่งไอคอนจาก `PhosphorIconsDuotone` มา ไส้ (ส่วนพื้นที่ข้างในไอคอน เช่น
  /// ตัวกล่อง ตัวรถ) จะได้สีที่สองเอง ถ้าส่งไอคอนแบบเส้นธรรมดามาก็ยังวาดได้
  /// แค่ไม่มีไส้
  ///
  /// ไส้ใช้เขียวสด ([AppColors.brand]) โปร่ง 30% ไม่ใช่เขียวอ่อนทึบ
  /// greenPrimary100 ทึบอ่อนเกินจนบนการ์ดขาวแทบมองไม่เห็นว่ามีสองสี
  static Widget duotone(IconData icon, {required double size, Color? color}) {
    return PhosphorIcon(
      icon,
      size: size,
      color: color,
      duotoneSecondaryColor: AppColors.brand,
      duotoneSecondaryOpacity: 0.3,
    );
  }

  /// ไอคอนสแกนบาร์โค้ด/QR: กรอบสี่มุมพร้อมเส้นกลาง
  ///
  /// ใช้ของ Fluent ไม่ใช่ `Icons.qr_code_scanner` ของ Material เพราะตัวของ
  /// Material วาดลาย QR ไว้ในกรอบ ทำให้ดูรกและสื่อว่าสแกนได้แต่ QR
  /// ทั้งที่งานจริงยิงบาร์โค้ดเป็นหลัก ตัวนี้เป็นกรอบเล็งเปล่า ๆ กับเส้นกวาด
  /// ตรงกลาง อ่านออกว่า "สแกน" ทันทีและเข้ากับทั้งบาร์โค้ดและ QR
  static const IconData scan = FluentIcons.scan_dash_24_regular;
}
