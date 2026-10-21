/// สี ไอคอน และรูปแบบวันที่ของหน้าเช็คสถานะ
///
/// แยกไว้ที่เดียวเพราะทั้งการ์ดสรุป แถบไทม์ไลน์ และการ์ดรายละเอียดต้องใช้
/// ชุดเดียวกัน ถ้ากระจายไปแต่ละไฟล์แล้วแก้ไม่ครบ สถานะเดียวกันจะคนละสี
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:claim/utils/app_colors.dart';

/// สีประจำสถานะ เลือกจาก [statusId] เท่านั้น
///
/// ห้ามใช้ค่านี้ตัดสินใจว่าจะแสดงข้อความอะไร ชื่อสถานะต้องมาจาก
/// `jobstatusname` ที่ API ส่งมาเสมอ ที่นี่แค่เลือกสีให้ไล่สายตาได้
///
/// สถานะ 1-5 เป็นขั้นตอนกลางทาง (คีย์เอกสาร เข้าคลัง ส่งต่อศูนย์) ตกมาที่
/// เทาเข้มตามค่าเริ่มต้น เพราะเป็นเรื่องปกติที่ไม่ต้องดึงสายตา ส่วนรหัสที่
/// ไม่รู้จัก (เซิร์ฟเวอร์เพิ่มสถานะใหม่) ก็ตกมาที่เดียวกัน ไม่พัง
///
/// เทาสองโทน (ตั้งต้น / ยังไม่จัดกลุ่ม) เอามาจาก [scheme] ได้ เพราะธีมตั้ง
/// เส้นขอบกับตัวหนังสือรองเป็นเทากลางไว้แล้ว ไม่ออกเขียวตาม seed จนกลืนกับ
/// สถานะ "ส่งถึง" และเปลี่ยนตามโหมดมืดให้เอง
Color trackingStatusColor(String? statusId, ColorScheme scheme) {
  switch (statusId?.trim().toUpperCase()) {
    case 'B00':
      return scheme.outline;
    case '6':
      return AppColors.stageOrigin;
    case '6-1':
    case '7-3':
      return AppColors.pending;
    case '7':
      return AppColors.success;
    case '8-1':
    case '8-2':
    case '8-3':
    case '9':
      return AppColors.danger;
    default:
      return scheme.onSurfaceVariant;
  }
}

/// ไอคอนประจำสถานะ ใช้เกณฑ์เดียวกับ [trackingStatusColor]
IconData trackingStatusIcon(String? statusId) {
  switch (statusId?.trim().toUpperCase()) {
    case 'B00':
      return Icons.receipt_long_outlined;
    case '6':
      return Icons.local_shipping_outlined;
    case '6-1':
    case '7-3':
      return Icons.error_outline;
    case '7':
      return Icons.check_circle_outline;
    case '8-1':
    case '8-2':
    case '8-3':
    case '9':
      return Icons.cancel_outlined;
    default:
      return Icons.inventory_2_outlined;
  }
}

/// เวลาจาก API เป็นเวลาไทยอยู่แล้ว format ตรง ๆ ห้าม toLocal()
final DateFormat _dateFormat = DateFormat('d MMM yyyy HH:mm', 'th');

/// คืน null เมื่อไม่มีวันที่ เพื่อให้ฝั่ง UI ซ่อนบรรทัดนั้นได้เลย
String? formatTrackingDate(DateTime? date) =>
    date == null ? null : _dateFormat.format(date);

final DateFormat _timeFormat = DateFormat('HH:mm', 'th');
final DateFormat _dayTimeFormat = DateFormat('d MMM HH:mm', 'th');

/// บอกว่าข้อมูลบนจอถูกดึงมาเมื่อไร
///
/// ถ้าเป็นวันนี้บอกแค่เวลา ("14:32") เพราะเห็นวันที่ซ้ำกับวันนี้ก็ไม่ได้ช่วยอะไร
/// ข้ามวันแล้วค่อยเติมวันที่ ("11 ก.ย. 14:32") ให้รู้ว่าเก่ากว่าที่คิด
String formatTrackingTime(DateTime time) {
  final now = DateTime.now();
  final sameDay =
      time.year == now.year && time.month == now.month && time.day == now.day;
  return sameDay ? _timeFormat.format(time) : _dayTimeFormat.format(time);
}
