/// ประวัติเลขเอกสารที่เช็คสถานะไปแล้วในวันนี้ ให้กดเช็คซ้ำได้โดยไม่ต้องพิมพ์ใหม่
///
/// เก็บลงดิสก์เฉพาะ "เลข" กับเวลาที่เช็ค ไม่เก็บผลลัพธ์ จึงไม่มีปัญหาสถานะเก่า
/// ค้างแบบที่ `TrackingCache` เลี่ยงไว้ กดเลขในประวัติแล้วจะดึงสถานะใหม่ทุกครั้ง
///
/// ผูกไว้กับวันที่ ข้ามวันแล้วล้างทิ้งทั้งชุด เลขของเมื่อวานส่วนใหญ่ไม่ได้ใช้แล้ว
/// ปล่อยค้างไว้จะกลายเป็นรายการยาวที่ต้องไล่หาเลขของวันนี้
library;

import 'package:shared_preferences/shared_preferences.dart';

/// เลข 1 รายการในประวัติ
class TrackingHistoryEntry {
  final String code;

  /// null เฉพาะรายการที่บันทึกไว้ก่อนเริ่มเก็บเวลา
  final DateTime? checkedAt;

  const TrackingHistoryEntry(this.code, this.checkedAt);

  /// เก็บเป็น "เลข|มิลลิวินาที" ในรายการสตริงเดียว ไม่ต้องแยกคีย์
  /// เลขเอกสารไม่มีทางมี `|` เพราะช่องกรอกรับแค่ตัวอักษรกับตัวเลข
  String encode() => '$code|${checkedAt?.millisecondsSinceEpoch ?? ''}';

  static TrackingHistoryEntry decode(String raw) {
    final cut = raw.lastIndexOf('|');
    if (cut < 0) return TrackingHistoryEntry(raw, null);
    final millis = int.tryParse(raw.substring(cut + 1));
    return TrackingHistoryEntry(
      raw.substring(0, cut),
      millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis),
    );
  }
}

class TrackingHistory {
  TrackingHistory._();

  static const _codesKey = 'tracking_history_codes';
  static const _dayKey = 'tracking_history_day';

  /// เกินนี้ตัดเลขเก่าสุดทิ้ง รายการยาวเกินก็ไม่มีใครเลื่อนไปดู
  static const _maxItems = 20;

  static String _today() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  /// เลขที่เช็ควันนี้ ใหม่สุดอยู่หน้า ถ้าที่เก็บไว้เป็นของวันอื่นจะล้างทิ้งก่อน
  static Future<List<TrackingHistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_dayKey) != _today()) {
      await prefs.remove(_codesKey);
      await prefs.setString(_dayKey, _today());
      return [];
    }
    final raw = prefs.getStringList(_codesKey) ?? const <String>[];
    return raw.map(TrackingHistoryEntry.decode).toList();
  }

  /// ย้ายเลขขึ้นหน้าสุดพร้อมเวลาล่าสุด เลขเดิมจะไม่ซ้ำ คืนรายการชุดใหม่
  static Future<List<TrackingHistoryEntry>> add(String code) async {
    final entries = await load();
    entries
      ..removeWhere((e) => e.code == code)
      ..insert(0, TrackingHistoryEntry(code, DateTime.now()));
    if (entries.length > _maxItems) {
      entries.removeRange(_maxItems, entries.length);
    }
    await _save(entries);
    return entries;
  }

  static Future<List<TrackingHistoryEntry>> remove(String code) async {
    final entries = await load();
    entries.removeWhere((e) => e.code == code);
    await _save(entries);
    return entries;
  }

  static Future<void> _save(List<TrackingHistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dayKey, _today());
    await prefs.setStringList(
      _codesKey,
      entries.map((e) => e.encode()).toList(),
    );
  }
}
