/// โมเดลของระบบ PM (บำรุงรักษาคอมพิวเตอร์ประจำปี)
///
/// รูปร่างอ้างจากข้อมูลจริงที่ /api/PMDetails/list ตอบกลับมา ไม่ใช่จาก swagger
/// เพราะ swagger เขียน response ไว้แค่ "Success" ไม่ได้บอกโครงสร้าง
library;

/// จำนวนหัวข้อที่ต้องทำต่อเครื่องต่อปี
///
/// ข้อมูลจริงทั้ง 241 ชุด (เครื่อง × ปี) มีครบ 6 แถวเสมอ ไม่มีชุดไหนขาดหรือเกิน
/// จึงยึดเลขนี้เป็นหลัก ถ้าวันหลัง backend เพิ่มหัวข้อ ให้แก้ที่ [pmTaskTitles]
const int pmTaskCount = 6;

/// ชื่อหัวข้อ PM เรียงตาม subNo 1-6
///
/// ⚠️ API ไม่ได้ส่งชื่อหัวข้อมาให้ (`title` เป็น "-" ทั้ง 1,446 แถว) แอปจึงต้อง
/// รู้ชื่อเอง 5 ข้อแรกมาจากต้นแบบเดิมใน pm.dart ข้อที่ 6 ยังไม่รู้ว่าคืออะไร
///
/// **ต้องยืนยันชื่อทั้งหมดกับทีม IT ก่อนใช้งานจริง** แก้ที่นี่ที่เดียว
/// ทุกหน้าจออ่านจากตัวนี้
const List<String> pmTaskTitles = [
  'ตรวจประสิทธิภาพเครื่อง',
  'ตรวจ My Computer',
  'ล้างไฟล์ขยะ (Temp)',
  'อัปเดต Windows / Antivirus',
  'สแกนไวรัส',
  'ทำความสะอาดตัวเครื่อง',
];

/// ค่าที่ API ใช้แทน "ไม่มีรูป" — เป็นขีดเดียว ไม่ใช่สตริงว่างหรือ null
///
/// เจอในข้อมูลจริง 367 แถวจาก 1,446 แถว (ราวหนึ่งในสี่) จึงเป็นเรื่องปกติ
/// ไม่ใช่ข้อมูลเสีย ต้องกรองออกทุกที่ที่เอาไปแสดงรูป
const String pmNoImage = '-';

/// แปลงค่าเป็นข้อความ คืน null เมื่อว่างหรือเป็นขีด
String? pmText(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty || text == pmNoImage) return null;
  return text;
}

int? pmInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString().trim() ?? '');
}

/// วันเวลาที่ API ส่งมาเป็นเวลาไทยอยู่แล้ว ไม่มี timezone ต่อท้าย
///
/// ประกอบจากตัวเลขเองเหมือนหน้าเช็คสถานะพัสดุ ถ้าใช้ DateTime.parse แล้ว
/// เผลอ toLocal() หรือ backend เติม Z มาวันหนึ่ง เวลาจะเพี้ยนไป 7 ชั่วโมง
DateTime? pmDate(dynamic value) {
  final text = pmText(value);
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

/// หัวข้อ PM 1 ข้อของเครื่องหนึ่งในปีหนึ่ง
class PmDetail {
  /// ลำดับหัวข้อ 1-6 ตรงกับ subNo ที่ใช้ตอนส่งข้อมูลกลับ
  final int subNo;

  final int yearCheck;
  final String? picBefore;
  final String? picAfter;
  final String? location;
  final DateTime? createDate;
  final String? createBy;
  final DateTime? updateDate;
  final String? updateBy;

  const PmDetail({
    required this.subNo,
    required this.yearCheck,
    this.picBefore,
    this.picAfter,
    this.location,
    this.createDate,
    this.createBy,
    this.updateDate,
    this.updateBy,
  });

  /// ชื่อหัวข้อตาม subNo ไม่รู้จักก็บอกเลขไป ดีกว่าปล่อยว่าง
  String get title => subNo >= 1 && subNo <= pmTaskTitles.length
      ? pmTaskTitles[subNo - 1]
      : 'หัวข้อที่ $subNo';

  bool get hasBefore => picBefore != null;
  bool get hasAfter => picAfter != null;

  /// ถือว่าทำครบเมื่อมีรูปทั้งก่อนและหลัง
  bool get isComplete => hasBefore && hasAfter;

  factory PmDetail.fromJson(Map<String, dynamic> json) => PmDetail(
    subNo: pmInt(json['no']) ?? 0,
    yearCheck: pmInt(json['yearCheck']) ?? 0,
    picBefore: pmText(json['picBefore']),
    picAfter: pmText(json['picAfter']),
    location: pmText(json['location']),
    createDate: pmDate(json['createDate']),
    createBy: pmText(json['createBy']),
    updateDate: pmDate(json['updateDate']),
    updateBy: pmText(json['updateBy']),
  );
}

/// เครื่อง 1 เครื่องในระบบ PM พร้อมประวัติทุกปี
class PmHead {
  /// เลขที่ใบ ใช้ตอนแก้ไข (update-head)
  final int no;

  /// ชื่อเครื่อง เช่น TP-COM-300 ใช้เป็น id ตอนเรียก details ด้วย
  final String comName;

  final String? fixAsset;
  final String? empNo;
  final String? location;

  /// หมายเหตุแบบพิมพ์อิสระ
  ///
  /// ของจริงมี 72 จาก 134 ใบที่กรอกไว้ และปนกันหลายแบบ ทั้งชื่อคนที่ใช้เครื่อง
  /// ("ชัชวาลย์ จันทรเสนา") และหมายเหตุจริง ("ไฟล์ขยะเยอะ", "ต่อคิวเปลี่ยนจอ")
  /// จึงห้ามเอาไปตีความว่าเป็นชื่อคนหรืออย่างอื่น แสดงตามที่กรอกมาเท่านั้น
  final String? remark;

  final DateTime? createDate;
  final String? createBy;
  final List<PmDetail> details;

  const PmHead({
    required this.no,
    required this.comName,
    this.fixAsset,
    this.empNo,
    this.location,
    this.remark,
    this.createDate,
    this.createBy,
    this.details = const [],
  });

  factory PmHead.fromJson(Map<String, dynamic> json) {
    final raw = json['details'];
    final details = <PmDetail>[];

    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          details.add(PmDetail.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return PmHead(
      no: pmInt(json['no']) ?? 0,
      comName: pmText(json['comName']) ?? '',
      fixAsset: pmText(json['fixAsset']),
      empNo: pmText(json['empNo']),
      location: pmText(json['location']),
      remark: pmText(json['remark']),
      createDate: pmDate(json['createDate']),
      createBy: pmText(json['createBy']),
      details: details,
    );
  }

  /// หัวข้อของปีที่ระบุ เรียงตาม subNo
  List<PmDetail> detailsOf(int year) {
    final list = details.where((d) => d.yearCheck == year).toList()
      ..sort((a, b) => a.subNo.compareTo(b.subNo));
    return list;
  }

  /// ปีที่เคยทำ PM เรียงใหม่ไปเก่า
  List<int> get years {
    final set = details.map((d) => d.yearCheck).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    return set;
  }

  /// ทำครบทุกหัวข้อของปีนั้นหรือยัง
  ///
  /// นับจากจำนวนหัวข้อที่มีรูปครบทั้งก่อนและหลัง ไม่ได้นับแค่ว่ามีแถวในปีนั้น
  /// เพราะข้อมูลจริงมีแถวที่สร้างไว้แล้วแต่ยังไม่ได้ถ่ายรูปหลังทำอยู่เยอะ
  int completedCount(int year) =>
      detailsOf(year).where((d) => d.isComplete).length;

  bool isDone(int year) => completedCount(year) >= pmTaskCount;

  /// เริ่มทำแล้วแต่ยังไม่ครบ
  bool isPartial(int year) {
    final done = completedCount(year);
    return done > 0 && done < pmTaskCount;
  }

  String get searchIndex => [
    comName,
    fixAsset,
    empNo,
    location,
    remark,
  ].nonNulls.join(' ').toLowerCase();
}
