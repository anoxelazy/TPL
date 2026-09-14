/// โมเดลของหน้าเช็คสถานะพัสดุ (tracking.aspx)
///
/// ทุกฟิลด์นอกจากแกนหลักเป็น nullable เพราะ API ส่งฟิลด์เสริมมาเฉพาะบางสถานะ
/// (คนขับมีเฉพาะสถานะ 6 ลายเซ็น/รูปมีเฉพาะ 7 กับ 9) และค่าที่ไม่มีข้อมูล
/// มาเป็นสตริงว่าง ไม่ใช่ null — ตัวแปลงในไฟล์นี้ยุบสตริงว่างเป็น null ให้หมด
library;

/// อ่านค่าเป็นข้อความ คืน null เมื่อไม่มีค่าหรือเป็นสตริงว่าง
///
/// แปลงผ่าน toString() ไม่ cast ตรง ๆ เพราะ lat/lon เซิร์ฟเวอร์ส่งมาเป็น
/// string บ้าง number บ้าง
String? readText(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

/// แปลง `yyyy-MM-ddTHH:mm:ss` เป็น DateTime โดยไม่แตะ timezone
///
/// เวลาที่ API ส่งมาเป็นเวลาไทยอยู่แล้วและไม่มี offset ต่อท้าย ถ้าใช้
/// DateTime.parse แล้วเผลอ toLocal() หรือเซิร์ฟเวอร์เติม `Z` มาวันหนึ่ง
/// เวลาจะเพี้ยนไป 7 ชั่วโมง จึงดึงตัวเลขออกมาประกอบเองให้แสดงตรงตามที่ส่งมาเสมอ
DateTime? parseStatusDate(dynamic value) {
  final text = readText(value);
  if (text == null) return null;

  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2}))?',
  ).firstMatch(text);
  if (match == null) return null;

  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6) ?? '0'),
  );
}

/// แก้ URL รูปให้ใช้งานได้จริง คืน null เมื่อไม่มีค่า
///
/// ⚠️ เซิร์ฟเวอร์ต่อ path ด้วย backslash ปนมากลางทาง เช่น
/// `.../SiteImages/11092026\Success/HVR.../signature.png`
/// ถ้าส่งเข้า Image.network ตามนั้นรูปจะโหลดไม่ขึ้น ต้องแปลงเป็น `/` ก่อน
/// (ทดสอบแล้วว่าแปลงแล้วโหลดได้จริง)
String? normalizeImageUrl(dynamic value) {
  final url = readText(value);
  if (url == null) return null;
  return url.replaceAll(r'\', '/');
}

/// ดึงเลข 4 ตัวท้ายของเบอร์โทร คืน null เมื่อได้ไม่ถึง 4 หลัก
///
/// API รับเฉพาะ 4 ตัวท้าย ผู้ใช้กรอกมาได้ทุกรูปแบบ (`095-105-8256`,
/// `095 1058256`) จึงตัดอักขระที่ไม่ใช่ตัวเลขออกก่อนแล้วค่อยตัดท้าย
String? lastFourDigits(String? phone) {
  if (phone == null) return null;
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 4) return null;
  return digits.substring(digits.length - 4);
}

/// เหตุการณ์ 1 บรรทัดบนไทม์ไลน์
class TrackingEvent {
  /// รหัสสถานะ เป็น **String เสมอ** มีค่าอย่าง "6-1", "7-3", "B00"
  /// ห้าม parse เป็น int ใช้เลือกสี/ไอคอนเท่านั้น
  final String statusId;

  /// ชื่อสถานะภาษาไทยจาก API แสดงตรง ๆ ห้าม hardcode ทับ
  final String statusName;
  final String? statusNameEn;

  /// null เมื่อ API ส่งรูปแบบวันที่ที่อ่านไม่ออก
  final DateTime? statusDate;
  final String? location;
  final String? tp;
  final String? tk;

  /// ลายเซ็นผู้รับ มีเฉพาะสถานะ 7 กับ 9
  final String? signature;

  /// pic1-pic3 เฉพาะตัวที่มีค่าจริง แก้ backslash ให้แล้ว
  final List<String> pictures;
  final String? remark;
  final String? lat;
  final String? lon;

  /// คนขับกับเบอร์ มีเฉพาะสถานะ 6
  final String? driver;
  final String? tel;

  /// เหตุผลที่นำจ่ายไม่สำเร็จ มีเฉพาะสถานะ 6-1
  final String? reasonTh;
  final String? reasonEn;

  const TrackingEvent({
    required this.statusId,
    required this.statusName,
    this.statusNameEn,
    this.statusDate,
    this.location,
    this.tp,
    this.tk,
    this.signature,
    this.pictures = const <String>[],
    this.remark,
    this.lat,
    this.lon,
    this.driver,
    this.tel,
    this.reasonTh,
    this.reasonEn,
  });

  /// รูปทั้งหมดของเหตุการณ์นี้ เรียงลายเซ็นไว้ท้ายสุด
  List<String> get allImages => [
    ...pictures,
    if (signature != null) signature!,
  ];

  /// พิกัดที่บันทึกตอนนำจ่าย null เมื่อไม่มีหรืออ่านไม่ออก
  String? get coordinates {
    final la = lat;
    final lo = lon;
    if (la == null || lo == null) return null;
    // ค่า "0" กับ "0.0" คือยังไม่ได้พิกัด ไม่ใช่พิกัดกลางมหาสมุทร
    if (double.tryParse(la) == 0 && double.tryParse(lo) == 0) return null;
    return '$la, $lo';
  }

  factory TrackingEvent.fromJson(Map<String, dynamic> json) {
    final pictures = <String>[];
    for (final key in const ['pic1', 'pic2', 'pic3']) {
      final url = normalizeImageUrl(json[key]);
      if (url != null) pictures.add(url);
    }

    return TrackingEvent(
      statusId: readText(json['jobstatusid']) ?? '',
      // ไม่มีชื่อไทยให้ใช้ชื่ออังกฤษแทน ดีกว่าปล่อยบรรทัดว่าง
      statusName:
          readText(json['jobstatusname']) ??
          readText(json['jobstatusname_en']) ??
          '-',
      statusNameEn: readText(json['jobstatusname_en']),
      statusDate: parseStatusDate(json['statusdate']),
      location: readText(json['location']),
      tp: readText(json['tp']),
      tk: readText(json['tk']),
      signature: normalizeImageUrl(json['signature']),
      pictures: pictures,
      remark: readText(json['remark']),
      lat: readText(json['lat']),
      lon: readText(json['lon']),
      driver: readText(json['driver']),
      tel: readText(json['tel']),
      reasonTh: readText(json['reason_th']),
      reasonEn: readText(json['reason_en']),
    );
  }
}

/// ผลการเช็คสถานะของพัสดุ 1 ใบ
class TrackingResult {
  /// เลข tracking ของร้านค้า
  final String? cusTracking;

  /// เลขพัสดุของ Thai Parcels
  final String? tpTracking;
  final String? currentStatusCode;
  final String? currentStatus;
  final DateTime? currentStatusTime;
  final String? currentStatusLocation;

  /// เรียงใหม่ → เก่า แล้วจาก [TrackingResult.fromJson]
  final List<TrackingEvent> events;

  const TrackingResult({
    this.cusTracking,
    this.tpTracking,
    this.currentStatusCode,
    this.currentStatus,
    this.currentStatusTime,
    this.currentStatusLocation,
    this.events = const <TrackingEvent>[],
  });

  bool get isEmpty => events.isEmpty && currentStatus == null;

  factory TrackingResult.fromJson(Map<String, dynamic> json) {
    final raw = json['all_status'];
    final events = <TrackingEvent>[];

    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          events.add(TrackingEvent.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return TrackingResult(
      cusTracking: readText(json['cus_tracking']),
      tpTracking: readText(json['tp_tracking']),
      currentStatusCode: readText(json['current_status_code']),
      currentStatus: readText(json['current_status']),
      currentStatusTime: parseStatusDate(json['current_status_time']),
      currentStatusLocation: readText(json['current_status_location']),
      events: sortEventsNewestFirst(events),
    );
  }
}

/// เรียงเหตุการณ์ใหม่ → เก่า ด้วย statusdate ของเราเอง
///
/// ห้ามเชื่อลำดับที่ server ส่งมา เพราะแถว "B00" (รับข้อมูลเข้าระบบ)
/// ถูกต่อท้าย list ทั้งที่เป็นเหตุการณ์แรกสุด และสถานะที่เวลาใกล้กันมาก
/// (เจอ 3 กับ 5 ห่างกัน 3 วินาที) ก็สลับที่กันได้
///
/// แถวที่อ่านวันที่ไม่ออกจะถูกดันไปท้ายสุด ไม่ทิ้ง เพราะยังมีชื่อสถานะให้อ่าน
List<TrackingEvent> sortEventsNewestFirst(List<TrackingEvent> events) {
  final sorted = [...events];
  sorted.sort((a, b) {
    final left = a.statusDate;
    final right = b.statusDate;
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return right.compareTo(left);
  });
  return sorted;
}
