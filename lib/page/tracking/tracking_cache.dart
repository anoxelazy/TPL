/// เก็บผลค้นหาล่าสุดของหน้าเช็คสถานะไว้ ให้ออกจากหน้าแล้วกลับเข้ามาไม่ต้องค้นซ้ำ
///
/// เก็บในหน่วยความจำเท่านั้น ไม่ลงดิสก์ เพราะสถานะพัสดุเปลี่ยนได้ทุกชั่วโมง
/// ถ้าเก็บข้ามการปิดแอป ผู้ใช้อาจเปิดมาเจอสถานะของเมื่อวานแล้วเข้าใจผิด
/// ว่าเป็นของตอนนี้ ภายในรอบการใช้งานเดียวความเสี่ยงนั้นต่ำกว่ามาก และ
/// หน้าจอยังดึงข้อมูลใหม่เบื้องหลังทุกครั้งที่กลับเข้ามาอยู่แล้ว
library;

import 'package:claim/page/tracking/models.dart';

class TrackingCache {
  TrackingCache._();

  static final TrackingCache I = TrackingCache._();

  /// เลขที่ค้นไปจริง ใช้เติมกลับในช่องกรอกและใช้ดึงข้อมูลใหม่
  String? code;

  TrackingResult? result;

  /// เวลาที่ดึงข้อมูลชุดนี้มา ใช้บอกผู้ใช้ว่าข้อมูลเก่าแค่ไหน
  DateTime? fetchedAt;

  bool get hasData => code != null && result != null;

  void save({required String code, required TrackingResult result}) {
    this.code = code;
    this.result = result;
    fetchedAt = DateTime.now();
  }

  void clear() {
    code = null;
    result = null;
    fetchedAt = null;
  }
}
