import 'dart:convert';

import 'package:cross_file/cross_file.dart';

import 'package:claim/utils/image_encode.dart';
import 'package:claim/utils/mobile_api.dart';

const String _solveTypePath = '/api/ITRepair/repairsolvetype';
const String _statusListPath = '/api/ITRepair/repairstatuslist';
const String _jobListPath = '/api/ITRepair/joblist';
const String _jobDetailsPath = '/api/ITRepair/jobdetails/';
const String _insertJobPath = '/api/ITRepair/insertjob';
const String kItCaseImageExtension = '.jpg';

/// รหัสโปรแกรมที่ส่งเมื่อเคสไม่ได้ผูกกับโปรแกรมไหน
///
/// ประเภทปัญหา 5 จาก 7 ตัวไม่มีโปรแกรมให้เลือกเลย (มีแค่ S002 โปรแกรม กับ
/// S003 ระบบ) เคสพวกนั้นต้องส่งรหัสนี้แทน ห้ามส่งค่าว่าง
const String kItCaseNoProgramId = 'P000';

class ItCaseProgram {
  final String id;
  final String name;

  const ItCaseProgram({required this.id, required this.name});
  factory ItCaseProgram.fromJson(Map<String, dynamic> json) => ItCaseProgram(
    id: _str(json['program_id']),
    name: _str(json['program_deatils']),
  );
}

class ItCaseSolveType {
  final String id;
  final String nameTh;
  final String nameEn;
  final List<ItCaseProgram> programs;

  const ItCaseSolveType({
    required this.id,
    required this.nameTh,
    required this.nameEn,
    required this.programs,
  });

  factory ItCaseSolveType.fromJson(Map<String, dynamic> json) {
    final raw = json['programs'];

    return ItCaseSolveType(
      id: _str(json['solve_id']),
      nameTh: _str(json['details_th']),
      nameEn: _str(json['details_en']),
      programs: raw is! List
          ? const []
          : [
              for (final item in raw)
                if (item is Map)
                  ItCaseProgram.fromJson(Map<String, dynamic>.from(item)),
            ],
    );
  }

  String get label =>
      nameTh.isNotEmpty ? nameTh : (nameEn.isNotEmpty ? nameEn : id);

  bool get hasPrograms => programs.isNotEmpty;
}

class ItCaseStatus {
  final String id;
  final String informer;
  final String officer;

  const ItCaseStatus({
    required this.id,
    required this.informer,
    required this.officer,
  });

  factory ItCaseStatus.fromJson(Map<String, dynamic> json) => ItCaseStatus(
    id: _str(json['status_id']),
    informer: _str(json['informer_details']),
    officer: _str(json['officer_details']),
  );

  String get label => informer.isNotEmpty ? informer : officer;
}

Future<List<ItCaseSolveType>> fetchSolveTypes() async {
  final rows = await _fetchList(_solveTypePath);
  return [
    for (final row in rows) ItCaseSolveType.fromJson(row),
  ].where((e) => e.id.isNotEmpty).toList();
}

Future<List<ItCaseStatus>> fetchCaseStatuses() async {
  final rows = await _fetchList(_statusListPath);
  return [
    for (final row in rows) ItCaseStatus.fromJson(row),
  ].where((e) => e.id.isNotEmpty).toList();
}

/// ขั้นของเคสแบบหยาบ ๆ ใช้เลือกสีป้ายสถานะและสีพื้นการ์ด
///
/// รหัสสถานะจริงมี 8 ตัว (ดูหน้าขั้นตอนการดำเนินงาน) แต่ผู้แจ้งสนใจแค่ว่า
/// "ถึงคิวหรือยัง กำลังทำอยู่ไหม ต้องไปตรวจรับหรือเปล่า จบหรือยัง"
/// จึงยุบเหลือ 4 ขั้น ข้อความเต็มยังโชว์บนป้ายเหมือนเดิม
enum ItCaseStage {
  /// เปิดเอกสารแล้ว รอทีม IT รับเรื่อง
  waiting,

  /// มีคนรับงานและกำลังแก้อยู่
  working,

  /// ทีม IT บอกว่าเสร็จแล้ว รอผู้แจ้งตรวจ
  review,

  /// ตรวจรับเรียบร้อย ปิดงาน
  done,
}

/// รหัสสถานะไหนอยู่ขั้นไหน อิงรายการจริงจาก repairstatuslist
///
/// รหัสที่ไม่รู้จัก (backend เพิ่มใหม่ทีหลัง) นับเป็น [ItCaseStage.working]
/// เพราะเดาผิดทางนั้นเสียหายน้อยสุด ไม่ไปบอกผู้ใช้ว่าจบแล้วทั้งที่ยังไม่จบ
ItCaseStage itCaseStageOf(String statusId) {
  switch (statusId.toUpperCase()) {
    case 'OP':
      return ItCaseStage.waiting;
    case 'FN':
      return ItCaseStage.review;
    case 'CF':
      return ItCaseStage.done;
    default:
      return ItCaseStage.working;
  }
}

/// ความคืบหน้าเป็นเปอร์เซ็นต์ของแต่ละสถานะ
///
/// ⚠️ API ไม่ได้ส่ง % มาให้ ตัวเลขชุดนี้เรากำหนดเองจากลำดับที่เอกสารเดิน
/// เปิดเอกสาร → รับทราบปัญหา → มอบหมายผู้ทำ → กำลังแก้ → รอผู้แจ้งตรวจ → ปิดงาน
///
/// IN2 คืองานที่ผู้แจ้งตีกลับให้ทำใหม่ จึงถอยลงมาต่ำกว่า IN ที่กำลังแก้อยู่
/// ไม่ใช่เดินหน้าต่อจาก FN ที่ 90
///
/// รหัสที่ไม่รู้จักคืน 0 หน้าจอจะซ่อนแถบไปเลย ดีกว่าโชว์ตัวเลขที่เดาเอาเอง
int itCaseProgressOf(String statusId) {
  switch (statusId.toUpperCase()) {
    case 'OP':
      return 10;
    case 'RC':
      return 25;
    case 'AS1':
    case 'AS2':
      return 40;
    case 'IN':
      return 60;
    case 'IN2':
      return 55;
    case 'FN':
      return 90;
    case 'CF':
      return 100;
    default:
      return 0;
  }
}

/// ช่องหนึ่งช่องจากแถวดิบ ที่ยังไม่มีที่อยู่ประจำบนหน้าจอ
class ItCaseField {
  /// ชื่อช่องตามที่ API ส่งมา เก็บไว้เผื่อต้องไล่ดูว่าอันไหนมาจากไหน
  final String key;

  /// ชื่อที่เอาไปโชว์ ไม่รู้จักช่องนั้นก็ใช้ชื่อดิบไปก่อน
  final String label;

  final String value;

  const ItCaseField({
    required this.key,
    required this.label,
    required this.value,
  });
}

/// ช่องที่เหลือจากแถวดิบ หลังตัดช่องที่หน้าจอเอาไปโชว์แล้วออก
///
/// รายชื่อช่องของ endpoint ชุดนี้ยังไม่ยืนยัน (swagger เขียน response ไว้แค่
/// "Success") ถ้าอ่านเฉพาะช่องที่รู้จักแล้วทิ้งที่เหลือ ข้อมูลที่ backend
/// ตั้งใจส่งมาให้ผู้ใช้เห็นจะหายไปเงียบ ๆ โดยไม่มีใครรู้ จึงกวาดที่เหลือมาโชว์
/// ต่อท้ายไว้ก่อน ได้ response จริงเมื่อไหร่ค่อยเลือกว่าช่องไหนควรอยู่ตรงไหน
///
/// [consumed] คือชื่อช่องที่เอาไปโชว์แล้ว เขียนแบบตัดตัวคั่นและพิมพ์เล็กล้วน
List<ItCaseField> itCaseExtraFields(
  Map<String, dynamic> raw,
  Set<String> consumed,
) {
  final fields = <ItCaseField>[];

  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is Map || value is List || value is bool) continue;

    final key = _normalizedKey(entry.key);
    if (consumed.contains(key) || _noiseKeys.contains(key)) continue;

    final text = _str(value);
    // ก้อนยาว ๆ คือรูป base64 หรือ log ไม่ใช่ของที่คนอ่านบนการ์ด
    if (text.isEmpty || text.length > 200) continue;

    fields.add(
      ItCaseField(
        key: entry.key,
        label: _fieldLabels[key] ?? entry.key,
        value: text,
      ),
    );
  }

  return fields;
}

/// ช่องที่ไม่ต้องเอามาโชว์ ถึงจะยังไม่มีใครใช้ก็ตาม
///
/// พวกรหัสอ้างอิงภายในกับรูปที่ส่งมาเป็น base64 โชว์ไปก็ไม่มีความหมายกับผู้แจ้ง
const Set<String> _noiseKeys = {
  // ข้อความสถานะฝั่งเจ้าหน้าที่ IT ผู้แจ้งไม่ได้เห็นอันนี้ในเว็บอยู่แล้ว
  'jobsdetailso',
  'officerdetails',
  'empno',
  'employeeno',
  'userid',
  'username',
  'rownum',
  'rowno',
  'row',
  'seq',
  'index',
  'imagebase64',
  'imageextension',
  'image',
  'picture',
  'pic',
  'token',
};

/// ชื่อไทยของช่องที่พอเดาได้ ไม่มีในนี้ก็โชว์ชื่อช่องดิบไป
const Map<String, String> _fieldLabels = {
  'branch': 'สาขา',
  'branchname': 'สาขา',
  'department': 'แผนก',
  'dept': 'แผนก',
  'deptname': 'แผนก',
  'companyname': 'บริษัท',
  'location': 'สถานที่',
  'tel': 'เบอร์ติดต่อ',
  'phone': 'เบอร์ติดต่อ',
  'mobile': 'เบอร์ติดต่อ',
  'priority': 'ความเร่งด่วน',
  'remark': 'หมายเหตุ',
  'note': 'หมายเหตุ',
  'comment': 'หมายเหตุ',
  'solution': 'การแก้ไข',
  'solvedetails': 'การแก้ไข',
  'solvedescription': 'การแก้ไข',
  'informername': 'ผู้แจ้ง',
  'requestername': 'ผู้แจ้ง',
  'comname': 'ชื่อเครื่อง',
  'fixasset': 'รหัสทรัพย์สิน',
  'receivedate': 'รับงานเมื่อ',
  'startdate': 'เริ่มทำเมื่อ',
  'finishdate': 'เสร็จเมื่อ',
  'closedate': 'ปิดงานเมื่อ',
  'recivedate': 'รับงานเมื่อ',
  'createby': 'ผู้แจ้ง',
  'updatedate': 'อัปเดตล่าสุด',
};

/// ชื่อช่องที่เป็นไปได้ของแต่ละค่าในแถวเคส
///
/// แยกออกมาตั้งชื่อ เพราะใช้สองที่: ตอนอ่านค่า กับตอนหาว่าช่องไหนยังไม่ได้โชว์
/// ถ้าเขียนซ้ำสองชุดแล้วแก้ไม่ครบ ช่องที่โชว์อยู่แล้วจะไปโผล่ซ้ำท้ายการ์ด
const List<String> _jobIdKeys = [
  'jobid',
  'jobno',
  'caseno',
  'caseid',
  'docno',
  'documentno',
  'repairid',
  'repairno',
  'no',
  'id',
];
const List<String> _statusIdKeys = [
  'jobstatus',
  'jobstatusid',
  'statusid',
  'status',
];
const List<String> _statusLabelKeys = [
  // `job_s_details_i` คือข้อความสถานะฝั่งผู้แจ้ง ตรงกับ informer_details
  // ใน repairstatuslist ส่วนตัวที่ลงท้าย _o เป็นของฝั่ง IT ไม่ใช่ของเรา
  'jobsdetailsi',
  'informerdetails',
  'statusdetails',
  'statusdetail',
  'statusname',
  'statusdescription',
];
const List<String> _typeIdKeys = ['jobtype', 'solveid', 'solvetype', 'typeid'];
const List<String> _typeLabelKeys = [
  'jobtypedetails',
  'solvedetails',
  'detailsth',
  'typename',
  'jobtypename',
];
const List<String> _programIdKeys = ['programid'];
// `deatils` ไม่ใช่พิมพ์ผิดตรงนี้ API สะกดแบบนั้นจริงใน repairsolvetype
const List<String> _programLabelKeys = [
  'programdeatils',
  'programdetails',
  'programname',
];
const List<String> _descriptionKeys = [
  'description',
  'jobdescription',
  'jobdetails',
  'problemdetails',
  'problem',
  'details',
  'detail',
];
const List<String> _createdKeys = [
  'createdate',
  'createddate',
  'docdate',
  'jobdate',
  'insertdate',
  'datetime',
  'date',
];
const List<String> _officerKeys = [
  // `recive_by` ไม่ใช่พิมพ์ผิดตรงนี้ API สะกดตก e ไปตัวหนึ่งจริง ๆ
  // ตัวที่สะกดถูกใส่ไว้ด้วยเผื่อวันหลัง backend แก้คำ
  'reciveby',
  'recivename',
  'officername',
  'solvername',
  'operatorname',
  'receivename',
  'receiveby',
  'assignto',
  'empname',
  'fullname',
  'officer',
  'updateby',
];

/// ช่องที่การ์ดเคสเอาไปโชว์แล้ว ที่เหลือถึงจะไปอยู่ท้ายการ์ด
const Set<String> _jobConsumedKeys = {
  ..._jobIdKeys,
  ..._statusIdKeys,
  ..._statusLabelKeys,
  ..._typeIdKeys,
  ..._typeLabelKeys,
  ..._programIdKeys,
  ..._programLabelKeys,
  ..._descriptionKeys,
  ..._createdKeys,
  ..._officerKeys,
};

/// เคสหนึ่งใบที่ผู้ใช้คนนี้เคยแจ้งไว้ หนึ่งแถวจาก `/api/ITRepair/joblist`
///
/// ⚠️ swagger ของ endpoint นี้เขียน response ไว้แค่ "Success" ไม่ได้บอกชื่อช่อง
/// และ backend ตัวนี้สะกดไม่เหมือนกันในแต่ละที่ (ITRepair ใช้ snake_case อย่าง
/// `status_id` ส่วน PM ใช้ camelCase อย่าง `createDate` แถม `program_deatils`
/// ยังพิมพ์ตกอีกตัว) จึงไม่ผูกกับชื่อช่องเดียว แต่ไล่หาจากชื่อที่เป็นไปได้
/// โดยตัดตัวคั่นและตัวพิมพ์ใหญ่เล็กทิ้งก่อนเทียบ รับได้ทั้งสองสไตล์
///
/// ช่องที่หาไม่เจอเป็นค่าว่าง การ์ดจะซ่อนบรรทัดนั้นไปเอง ไม่พัง
/// ส่วนช่องที่ไม่รู้จักไม่ได้ทิ้ง แต่ไปโผล่ที่ [extras] (ดู [itCaseExtraFields])
class ItCaseJob {
  /// เลขเคสที่ทีม IT ใช้อ้างอิง เช่น IT1234567
  final String id;

  final String statusId;

  /// ข้อความสถานะที่ติดมากับแถว ว่างได้ หน้าจอจะไปเทียบจาก repairstatuslist แทน
  final String statusLabel;

  /// รหัสประเภทปัญหา เช่น S001 (ช่อง jobType ตอนส่งเคส)
  final String typeId;
  final String typeLabel;

  final String programId;
  final String programLabel;

  final String description;
  final DateTime? createdAt;

  /// ชื่อเจ้าหน้าที่ IT ที่รับงาน ว่างได้เมื่อยังไม่มีคนรับ
  final String officer;

  /// แถวดิบทั้งแถว เก็บไว้เพื่อโชว์ช่องที่ยังไม่รู้จัก
  final Map<String, dynamic> raw;

  const ItCaseJob({
    required this.id,
    required this.statusId,
    required this.statusLabel,
    required this.typeId,
    required this.typeLabel,
    required this.programId,
    required this.programLabel,
    required this.description,
    required this.createdAt,
    required this.officer,
    this.raw = const {},
  });

  factory ItCaseJob.fromJson(Map<String, dynamic> json) {
    // เว็บโชว์สถานะงานเป็น "CF:ตรวจสอบเรียบร้อยแล้ว" รหัสกับคำอธิบายติดกันมา
    // ถ้า API ส่งแบบเดียวกัน ต้องแยกรหัสออกมาเอง ไม่งั้นสีป้ายเดาผิดทั้งหมด
    final rawStatus = _pickField(json, _statusIdKeys);
    final rawLabel = _pickField(json, _statusLabelKeys);

    final statusId = itCaseStatusIdIn(rawStatus.isEmpty ? rawLabel : rawStatus);
    // คำอธิบายอาจติดมาในช่องเดียวกับรหัส ("CF:ตรวจสอบเรียบร้อยแล้ว")
    final label = itCaseStatusTextOf(rawLabel.isEmpty ? rawStatus : rawLabel);

    return ItCaseJob(
      id: _pickField(json, _jobIdKeys),
      statusId: statusId,
      // เหลือแต่รหัสหลังตัดคำนำหน้าก็เท่ากับไม่มีคำอธิบาย ปล่อยว่างไว้
      // ให้ไปเทียบเอาจาก repairstatuslist แทน
      statusLabel: label.toUpperCase() == statusId ? '' : label,
      typeId: _pickField(json, _typeIdKeys),
      typeLabel: _pickField(json, _typeLabelKeys),
      programId: _pickField(json, _programIdKeys),
      programLabel: _pickField(json, _programLabelKeys),
      description: _pickField(json, _descriptionKeys),
      createdAt: itCaseDateOf(_pickField(json, _createdKeys)),
      officer: _pickField(json, _officerKeys),
      raw: json,
    );
  }

  /// เคสที่เพิ่งแจ้งสำเร็จ รู้แค่เลขเคสที่เซิร์ฟเวอร์ตอบกลับมา
  ///
  /// ป๊อปอัปตอนส่งสำเร็จได้มาแค่เลขเคส ([ItCaseResult]) ไม่ได้ทั้งแถวแบบหน้า
  /// รายการ แต่หน้ารายละเอียดต้องมีหัวเรื่องไว้วาดก่อนโหลดเสร็จ จึงปั้นแถวจาก
  /// สิ่งที่รู้แน่ ๆ คือเคสที่เพิ่งเปิดย่อมอยู่สถานะ `OP` รอทีม IT รับเรื่อง
  /// ที่เหลือหน้ารายละเอียดโหลดทับให้เองภายในไม่กี่วินาที
  factory ItCaseJob.justSent(String id) => ItCaseJob(
    id: id,
    statusId: 'OP',
    statusLabel: '',
    typeId: '',
    typeLabel: '',
    programId: '',
    programLabel: '',
    description: '',
    createdAt: null,
    officer: '',
  );

  /// ช่องอื่นในแถวที่ยังไม่มีที่อยู่บนการ์ด
  List<ItCaseField> get extras => itCaseExtraFields(raw, _jobConsumedKeys);

  ItCaseStage get stage => itCaseStageOf(statusId);

  /// ความคืบหน้าเป็น % ตามสถานะ 0 แปลว่ายังบอกไม่ได้
  int get progress => itCaseProgressOf(statusId);

  /// ปิดงานแล้วหรือยัง ใช้คัดเคสที่จบแล้วออกจากหน้าหลัก
  bool get isClosed => statusId.toUpperCase() == kItCaseClosedStatusId;

  /// ทีม IT แก้เสร็จแล้ว รอผู้แจ้งตรวจและกดปิด ลูกบอลอยู่ฝั่งเรา
  bool get needsConfirm => statusId.toUpperCase() == kItCaseWaitConfirmStatusId;

  /// แถวที่ไม่มีทั้งเลขเคสและรายละเอียด เอาไปโชว์ก็เป็นการ์ดเปล่า ทิ้งไปเลย
  bool get isUsable => id.isNotEmpty || description.isNotEmpty;

  /// ข้อความทั้งหมดของแถวนี้ที่ช่องค้นหาเอาไปเทียบ พิมพ์เล็กล้วน
  ///
  /// ไม่รวมข้อความสถานะที่ต้องแปลจาก repairstatuslist เพราะตารางนั้นอยู่ที่
  /// หน้าจอ ไม่ได้อยู่ในแถว หน้าจอจึงต้องเทียบส่วนนั้นเพิ่มเอง
  String get searchIndex => [
    id,
    description,
    officer,
    typeLabel,
    programLabel,
    statusLabel,
  ].join(' ').toLowerCase();

  /// ป้ายสถานะที่จะโชว์ ใช้ข้อความจากแถวก่อน ไม่มีค่อยเทียบจาก [statuses]
  ///
  /// สุดท้ายจริง ๆ ถึงโชว์รหัสดิบ ดีกว่าป้ายว่างจนไม่รู้ว่าเคสไปถึงไหนแล้ว
  String statusTextFrom(List<ItCaseStatus> statuses) {
    if (statusLabel.isNotEmpty) return statusLabel;

    for (final status in statuses) {
      if (status.id.toUpperCase() == statusId.toUpperCase()) {
        return status.label;
      }
    }
    return statusId;
  }

  /// ชื่อประเภทปัญหา ใช้ของที่ติดมากับแถวก่อน ไม่มีค่อยเทียบจาก [types]
  String typeTextFrom(List<ItCaseSolveType> types) {
    if (typeLabel.isNotEmpty) return typeLabel;
    if (typeId.isEmpty) return '';

    for (final type in types) {
      if (type.id.toUpperCase() == typeId.toUpperCase()) return type.label;
    }
    return typeId;
  }

  /// ชื่อโปรแกรม เทียบจาก [types] เมื่อแถวส่งมาแต่รหัส
  ///
  /// [kItCaseNoProgramId] แปลว่าเคสนี้ไม่ได้ผูกกับโปรแกรมไหน ไม่ต้องโชว์อะไร
  String programTextFrom(List<ItCaseSolveType> types) {
    if (programLabel.isNotEmpty) return programLabel;
    if (programId.isEmpty || programId.toUpperCase() == kItCaseNoProgramId) {
      return '';
    }

    for (final type in types) {
      for (final program in type.programs) {
        if (program.id.toUpperCase() == programId.toUpperCase()) {
          return program.name;
        }
      }
    }
    return programId;
  }
}

/// เคสที่ผู้ใช้คนนี้เคยแจ้งไว้ ใหม่สุดขึ้นก่อน
///
/// ยังไม่เคยแจ้งเคสเลยไม่ใช่ความผิดพลาด แต่ API ตอบ 404 มาเหมือนกรณีหาไม่เจอ
/// จึงกลืนไว้แล้วคืนรายการเปล่า ให้หน้าจอขึ้นว่ายังไม่มีเคส แทนกล่องแดง
Future<List<ItCaseJob>> fetchCaseJobs() async {
  List<Map<String, dynamic>> rows;

  try {
    rows = await _fetchList(_jobListPath);
  } on MobileApiException catch (e) {
    if (!e.needLogin && e.message.contains('ไม่พบ')) return const [];
    rethrow;
  }

  final jobs = [
    for (final row in rows) ItCaseJob.fromJson(row),
  ].where((e) => e.isUsable).toList();

  sortItCaseJobs(jobs);
  return jobs;
}

/// เรียงใหม่สุดขึ้นก่อน แถวที่ไม่มีวันที่ไปต่อท้าย
///
/// ไม่ไว้ใจลำดับที่ API ส่งมา endpoint อื่นของระบบนี้ก็ไม่ได้เรียงมาให้
void sortItCaseJobs(List<ItCaseJob> jobs) {
  jobs.sort((a, b) {
    final left = a.createdAt;
    final right = b.createdAt;

    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return right.compareTo(left);
  });
}

/// รหัสสถานะที่ห้อยอยู่หน้าข้อความ เช่น `CF:ตรวจสอบเรียบร้อยแล้ว` ได้ `CF`
///
/// เว็บของระบบนี้โชว์สถานะงานเป็นรหัสคั่นด้วย `:` แล้วตามด้วยคำอธิบาย ถ้า API
/// ส่งมาแบบเดียวกันโดยไม่มีช่องรหัสแยก เราก็ยังต้องรู้รหัสให้ได้ ไม่งั้นสีป้าย
/// จะเดาผิดหมด (เคสปิดแล้วขึ้นเหลืองว่ากำลังทำ)
///
/// ส่ง `CF` เปล่า ๆ มาก็ได้รหัสเหมือนกัน ส่วนคำอธิบายยาว ๆ ที่ไม่มีรหัสคืนค่าว่าง
String itCaseStatusIdIn(String value) {
  final text = value.trim();
  if (text.isEmpty) return '';

  final prefix = _statusPrefix.firstMatch(text);
  if (prefix != null) return prefix.group(1)!.toUpperCase();

  // สั้นและไม่มีเว้นวรรค แปลว่าเป็นรหัสมาเลย ไม่ใช่คำอธิบาย
  return text.length <= 4 && !text.contains(' ') ? text.toUpperCase() : '';
}

/// ข้อความสถานะที่ตัดรหัสนำหน้าออกแล้ว ป้ายจะได้ไม่ขึ้นว่า `CF:ตรวจสอบ...`
String itCaseStatusTextOf(String value) =>
    value.trim().replaceFirst(_statusPrefix, '').trim();

final RegExp _statusPrefix = RegExp(r'^\s*([A-Za-z]{1,3}\d{0,2})\s*[:：]\s*');

/// ชื่อช่องที่เป็นไปได้ของรายละเอียดเคส
///
/// อ้างจากหน้าเว็บของระบบเดียวกัน ซึ่งโชว์ช่องพวกนี้ในป๊อปอัปรายละเอียด:
/// เลขเอกสาร วันที่แจ้ง ผู้แจ้ง ประเภทปัญหา ระบบหรือโปรแกรมที่เป็นปัญหา
/// รายละเอียด ภาพประกอบ สถานะ รายละเอียดการแก้ไข รูปภาพปิดงาน ผู้รับงาน
///
/// ⚠️ ชื่อช่องจริงยังไม่ยืนยัน (swagger เขียน response ไว้แค่ "Success")
/// ช่องที่เดาไม่ถูกจะไปโผล่ที่ [ItCaseJobDetail.extras] ไม่ได้หายไปไหน
const List<String> _informerKeys = [
  'informername',
  'informer',
  'informby',
  'informname',
  'requestername',
  'requester',
  'createname',
  'createby',
];
const List<String> _informDateKeys = [
  'informdate',
  'createdate',
  'createddate',
  'jobdate',
  'docdate',
  'insertdate',
  'datetime',
  'date',
];
const List<String> _imageKeys = [
  'imgopen',
  'imageopen',
  'imgjob',
  'imagelink',
  'imglink',
  'imageurl',
  'imagepath',
  'imagebefore',
  'beforelink',
  'picbefore',
  'image',
  'img',
  'picture',
  'pic',
  'imagebase64',
];
const List<String> _solveImageKeys = [
  'imgclose',
  'imageclose',
  'solveimagelink',
  'solveimage',
  'solveimg',
  'imageafter',
  'afterlink',
  'picafter',
  'closeimage',
  'finishimage',
];
const List<String> _ratingKeys = [
  'ratingjob',
  'jobrating',
  'rating',
  'score',
  'star',
];
const List<String> _solveNoteKeys = [
  // ข้อความที่ทีม IT เขียนตอนปิดงาน เป็นช่องที่ผู้แจ้งอยากอ่านที่สุด
  'descclosejob',
  'closejobdesc',
  'solvedescription',
  'repairdetails',
  'repairdescription',
  'fixdetails',
  'solvedetail',
  'solveremark',
  'officerremark',
  'solution',
  'remark',
  'note',
];

/// ช่องที่หน้ารายละเอียดเอาไปโชว์แล้ว ที่เหลือถึงจะไปอยู่ท้ายหน้า
const Set<String> _detailConsumedKeys = {
  ..._jobIdKeys,
  ..._statusIdKeys,
  ..._statusLabelKeys,
  ..._typeIdKeys,
  ..._typeLabelKeys,
  ..._programIdKeys,
  ..._programLabelKeys,
  ..._descriptionKeys,
  ..._informerKeys,
  ..._informDateKeys,
  ..._imageKeys,
  ..._solveImageKeys,
  ..._solveNoteKeys,
  ..._ratingKeys,
  ..._officerKeys,
};

/// รายละเอียดเคสหนึ่งใบจาก `/api/ITRepair/jobdetails/{เลขเคส}`
///
/// เป็นข้อมูลใบเดียว ไม่ใช่ประวัติหลายขั้น หน้าจอจึงเรียงเป็นฟอร์มอ่านอย่างเดียว
/// แบบเดียวกับป๊อปอัปในเว็บ ไม่ใช่เส้นเวลา
class ItCaseJobDetail {
  final String id;

  /// วันที่แจ้ง เว็บโชว์เป็น `15-09-2026 23:11`
  final DateTime? createdAt;

  final String informer;

  final String statusId;
  final String statusLabel;

  final String typeId;
  final String typeLabel;
  final String programId;
  final String programLabel;

  /// รายละเอียดปัญหาที่ผู้แจ้งเขียนไว้
  final String description;

  /// ช่อง `job_description` ที่ API ส่งมาต่างหาก
  ///
  /// ปกติเป็นตัวเดียวกับ [description] แล้ว ([_descriptionKeys] หาเจอ) ช่องนี้
  /// จะว่าง แต่ถ้าแถวไหนส่งมาทั้งสองช่องและเขียนไม่เหมือนกัน หน้าจอจะโชว์เพิ่ม
  /// อีกบรรทัด ดีกว่าเลือกมาโชว์ช่องเดียวแล้วอีกช่องหายไปเงียบ ๆ
  final String jobDescription;

  /// ภาพประกอบที่ผู้แจ้งแนบมา ค่าดิบตามที่ API ส่ง (ลิงก์ พาธ หรือ base64)
  final String image;

  /// รายละเอียดการแก้ไขที่เจ้าหน้าที่เขียนไว้
  final String solveNote;

  /// รูปภาพปิดงาน ว่างได้ ไม่ใช่ทุกงานจะถ่ายรูปตอนปิด
  final String solveImage;

  final String officer;

  /// คะแนน 1-5 ที่ผู้แจ้งให้ไว้ 0 แปลว่ายังไม่ได้ให้คะแนน
  final int rating;

  /// แถวดิบทั้งแถว เก็บไว้เพื่อโชว์ช่องที่ยังไม่รู้จัก
  final Map<String, dynamic> raw;

  const ItCaseJobDetail({
    required this.id,
    required this.createdAt,
    required this.informer,
    required this.statusId,
    required this.statusLabel,
    required this.typeId,
    required this.typeLabel,
    required this.programId,
    required this.programLabel,
    required this.description,
    required this.jobDescription,
    required this.image,
    required this.solveNote,
    required this.solveImage,
    required this.officer,
    required this.rating,
    this.raw = const {},
  });

  factory ItCaseJobDetail.fromJson(Map<String, dynamic> json) {
    final rawStatus = _pickField(json, _statusIdKeys);
    final rawLabel = _pickField(json, _statusLabelKeys);

    final statusId = itCaseStatusIdIn(rawStatus.isEmpty ? rawLabel : rawStatus);
    // คำอธิบายอาจติดมาในช่องเดียวกับรหัส ("CF:ตรวจสอบเรียบร้อยแล้ว")
    final label = itCaseStatusTextOf(rawLabel.isEmpty ? rawStatus : rawLabel);

    return ItCaseJobDetail(
      id: _pickField(json, _jobIdKeys),
      createdAt: itCaseDateOf(_pickField(json, _informDateKeys)),
      informer: _pickField(json, _informerKeys),
      statusId: statusId,
      // เหลือแต่รหัสหลังตัดคำนำหน้าก็เท่ากับไม่มีคำอธิบาย ปล่อยว่างไว้
      // ให้ไปเทียบเอาจาก repairstatuslist แทน
      statusLabel: label.toUpperCase() == statusId ? '' : label,
      typeId: _pickField(json, _typeIdKeys),
      typeLabel: _pickField(json, _typeLabelKeys),
      programId: _pickField(json, _programIdKeys),
      programLabel: _pickField(json, _programLabelKeys),
      description: _pickField(json, _descriptionKeys),
      jobDescription: _pickField(json, const ['jobdescription']),
      image: _pickField(json, _imageKeys),
      solveNote: _pickField(json, _solveNoteKeys),
      solveImage: _pickField(json, _solveImageKeys),
      officer: _pickField(json, _officerKeys),
      rating: itCaseRatingOf(_pickField(json, _ratingKeys)),
      raw: json,
    );
  }

  ItCaseStage get stage => itCaseStageOf(statusId);

  /// ความคืบหน้าเป็น % ตามสถานะ 0 แปลว่ายังบอกไม่ได้
  int get progress => itCaseProgressOf(statusId);

  /// ช่องอื่นในแถวที่ยังไม่มีที่อยู่บนหน้าจอ
  List<ItCaseField> get extras => itCaseExtraFields(raw, _detailConsumedKeys);

  /// ข้อความสถานะที่จะโชว์ ใช้ของที่ติดมากับแถวก่อน ไม่มีค่อยเทียบจาก [statuses]
  String statusTextFrom(List<ItCaseStatus> statuses) {
    if (statusLabel.isNotEmpty) return statusLabel;

    for (final status in statuses) {
      if (status.id.toUpperCase() == statusId.toUpperCase()) {
        return status.label;
      }
    }
    return statusId;
  }

  /// ชื่อประเภทปัญหา ใช้ของที่ติดมากับแถวก่อน ไม่มีค่อยเทียบจาก [types]
  String typeTextFrom(List<ItCaseSolveType> types) {
    if (typeLabel.isNotEmpty) return typeLabel;
    if (typeId.isEmpty) return '';

    for (final type in types) {
      if (type.id.toUpperCase() == typeId.toUpperCase()) return type.label;
    }
    return typeId;
  }

  /// ชื่อโปรแกรม เว็บโชว์ว่า "ไม่ระบุ" เมื่อเคสไม่ได้ผูกกับโปรแกรมไหน
  String programTextFrom(List<ItCaseSolveType> types) {
    if (programLabel.isNotEmpty) return programLabel;
    if (programId.isEmpty || programId.toUpperCase() == kItCaseNoProgramId) {
      return '';
    }

    for (final type in types) {
      for (final program in type.programs) {
        if (program.id.toUpperCase() == programId.toUpperCase()) {
          return program.name;
        }
      }
    }
    return programId;
  }
}

/// รายละเอียดของเคสหนึ่งใบ ไม่เจอก็คืน null
///
/// [jobId] คือเลขเอกสารที่เห็นบนการ์ด เช่น IT2026106446
///
/// ตอบมาหลายแถวก็เอาแถวแรก เว็บโชว์ใบเดียวต่อหนึ่งเลขเอกสารอยู่แล้ว
Future<ItCaseJobDetail?> fetchCaseJobDetail(String jobId) async {
  final id = jobId.trim();
  if (id.isEmpty) return null;

  List<Map<String, dynamic>> rows;
  try {
    rows = await _fetchList(
      '$_jobDetailsPath${Uri.encodeComponent(id)}',
      decode: itCaseDetailRows,
    );
  } on MobileApiException catch (e) {
    if (!e.needLogin && e.message.contains('ไม่พบ')) return null;
    rethrow;
  }

  if (rows.isEmpty) return null;
  return ItCaseJobDetail.fromJson(rows.first);
}

/// รหัสสถานะที่แปลว่าผู้แจ้งปิดงานไปแล้ว
const String kItCaseClosedStatusId = 'CF';

/// รหัสสถานะที่ทีม IT แก้เสร็จแล้ว รอผู้แจ้งตรวจและกดปิดงาน
const String kItCaseWaitConfirmStatusId = 'FN';

/// รหัสสถานะที่ผู้แจ้งตีงานกลับให้ทีม IT ทำใหม่
///
/// เว็บใช้รหัสนี้กับงานที่ผู้แจ้งตรวจแล้วยังไม่ผ่าน ([itCaseProgressOf] จึงให้
/// 55% ต่ำกว่า IN ที่กำลังแก้อยู่ ไม่ใช่เดินหน้าต่อจาก FN)
const String kItCaseRedoStatusId = 'IN2';

/// endpoint เปลี่ยนสถานะเคส ยืนยันด้วย cURL จริงแล้วว่าเป็น PUT ตัวนี้
///
/// body ที่รับคือ `{"jobId","status","descCreator","ratings"}`
const String _updateStatusPath = '/api/ITRepair/updatejobstatus';

/// ผู้แจ้งตอบผลการตรวจงานกลับไป
///
/// [status] ใช้ได้สองค่าจากฝั่งผู้แจ้ง คือ [kItCaseClosedStatusId] เมื่อตรวจ
/// แล้วผ่านและปิดงาน กับ [kItCaseRedoStatusId] เมื่อยังไม่ผ่านและตีกลับให้ทำใหม่
/// สถานะที่เหลือเป็นของฝั่งทีม IT ไม่ใช่ของที่แอปนี้ส่ง
///
/// [rating] คือดาว 1-5 ที่ผู้แจ้งให้ 0 แปลว่าไม่ให้คะแนน (ช่วงเดียวกับ
/// [itCaseRatingOf] ที่ใช้อ่านค่ากลับมา) ส่วน [note] คือความเห็นสั้น ๆ
/// ที่ไปลงช่อง `descCreator`
///
/// สำเร็จคือไม่โยนอะไรออกมา ล้มเหลวโยน [MobileApiException] พร้อมข้อความไทย
/// ที่เอาไปโชว์ได้ตรง ๆ
Future<void> updateCaseJobStatus(
  String jobId, {
  required String status,
  int rating = 0,
  String note = '',
}) async {
  final id = jobId.trim();
  if (id.isEmpty) {
    throw const MobileApiException('ไม่มีเลขเคส ส่งผลตรวจงานไม่ได้');
  }

  final options = MobileSession.I.authOptions();
  if (options == null) {
    throw const MobileApiException(
      'ยังไม่ได้เชื่อมต่อระบบ กรุณาเข้าสู่ระบบใหม่',
      needLogin: true,
    );
  }

  try {
    final response = await mobileDio.put(
      _updateStatusPath,
      data: {
        'jobId': id,
        'status': status,
        'descCreator': note.trim(),
        // นอกช่วง 1-5 ถือว่าไม่ให้คะแนน ส่ง 0 ไปตรง ๆ ดีกว่าส่งเลขมั่ว
        'ratings': rating >= 1 && rating <= 5 ? rating : 0,
      },
      options: options,
    );

    unwrapMobileResponse(response);
  } on MobileApiException {
    rethrow;
  } catch (e) {
    throw MobileApiException(mobileNetworkMessage(e));
  }
}

/// แถวความคืบหน้าจาก body ที่ endpoint ตอบมา
///
/// เผื่อไว้สามแบบเพราะยังไม่เห็นของจริง: เป็น array ตรง ๆ, เป็นก้อนเดียวที่ห่อ
/// array ไว้ข้างใน (เช่น `{"jobNo":"IT..","details":[...]}`) และเป็น object
/// เดี่ยวที่มีข้อมูลขั้นเดียว แบบไหนก็ได้แถวกลับไปเหมือนกัน
List<Map<String, dynamic>> itCaseDetailRows(dynamic data) {
  dynamic decoded = data;

  if (decoded is String) {
    final text = decoded.trim();
    if (text.isEmpty) return const [];
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return const [];
    }
  }

  if (decoded is List) return _rowsIn(decoded);

  if (decoded is Map) {
    // ก้อนที่ห่อ array ไว้ข้างใน เอา array ที่เจอตัวแรกที่มีแถวจริง
    for (final value in decoded.values) {
      if (value is! List) continue;

      final rows = _rowsIn(value);
      if (rows.isNotEmpty) return rows;
    }

    return [Map<String, dynamic>.from(decoded)];
  }

  return const [];
}

List<Map<String, dynamic>> _rowsIn(List<dynamic> items) => [
  for (final item in items)
    if (item is Map) Map<String, dynamic>.from(item),
];

/// แปลงวันที่จาก API เป็น [DateTime] อ่านไม่ออกก็คืน null
///
/// รับทั้ง `2026-09-15T10:30:00` ที่ .NET ส่งมาปกติ และ `15/09/2569` เผื่อบาง
/// endpoint ส่งเป็นวันที่แบบไทย ปี พ.ศ. แปลงเป็น ค.ศ. ให้ด้วย ไม่งั้นการ์ดจะ
/// ขึ้นปี 2569 ทั้งที่ทั้งแอปโชว์เป็น ค.ศ.
DateTime? itCaseDateOf(String text) {
  if (text.isEmpty) return null;

  final iso = RegExp(
    r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:[T ](\d{1,2}):(\d{2})(?::(\d{2}))?)?',
  ).firstMatch(text);
  if (iso != null) {
    return DateTime(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
      int.parse(iso.group(4) ?? '0'),
      int.parse(iso.group(5) ?? '0'),
      int.parse(iso.group(6) ?? '0'),
    );
  }

  final slash = RegExp(
    r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})(?:[ ,T]+(\d{1,2}):(\d{2})(?::(\d{2}))?)?',
  ).firstMatch(text);
  if (slash != null) {
    final year = int.parse(slash.group(3)!);

    return DateTime(
      year > 2400 ? year - 543 : year,
      int.parse(slash.group(2)!),
      int.parse(slash.group(1)!),
      int.parse(slash.group(4) ?? '0'),
      int.parse(slash.group(5) ?? '0'),
      int.parse(slash.group(6) ?? '0'),
    );
  }

  return null;
}

/// ค่าแรกที่หาเจอจากชื่อช่องที่เป็นไปได้ [keys]
///
/// [keys] ต้องเขียนเป็นตัวพิมพ์เล็กล้วนและไม่มีตัวคั่น เพราะชื่อช่องฝั่ง API
/// ถูกตัดขีดล่างและแปลงเป็นพิมพ์เล็กก่อนเทียบ `status_id` กับ `statusId`
/// จึงเจอด้วยคีย์ `statusid` ตัวเดียวกัน
String _pickField(Map<String, dynamic> json, List<String> keys) {
  final byKey = <String, String>{};

  for (final entry in json.entries) {
    final value = entry.value;
    // ช่องที่ห่อของซ้อนอีกชั้นไม่ใช่ข้อความ เอามาโชว์จะได้วงเล็บปีกกาติดมา
    if (value is Map || value is List || value is bool) continue;

    final text = _str(value);
    if (text.isEmpty) continue;
    byKey.putIfAbsent(_normalizedKey(entry.key), () => text);
  }

  for (final key in keys) {
    final value = byKey[key];
    if (value != null) return value;
  }
  return '';
}

String _normalizedKey(String key) =>
    key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

/// [programId] ปล่อยว่างหรือ null ได้เมื่อประเภทปัญหาไม่มีโปรแกรมให้เลือก
/// จะถูกแทนด้วย [kItCaseNoProgramId] ให้เอง ผู้เรียกไม่ต้องจำเอง
Future<ItCaseResult> createItCase({
  required String jobType,
  required String description,
  String? programId,
  XFile? image,
}) async {
  final options = MobileSession.I.authOptions(
    receiveTimeout: const Duration(seconds: 60),
  );
  if (options == null) {
    throw const MobileApiException(
      'ยังไม่ได้เชื่อมต่อระบบ กรุณาเข้าสู่ระบบใหม่',
      needLogin: true,
    );
  }

  String imageBase64 = '';
  if (image != null) {
    final picked = await image.readAsBytes();
    final bytes = await compressImageBytes(picked);
    imageBase64 = await encodeBase64InBackground(bytes);
  }

  try {
    final response = await mobileDio.post(
      _insertJobPath,
      data: {
        'jobType': jobType,
        'description': description,
        'programId': itCaseProgramIdOf(programId),
        'imageBase64': imageBase64,
        'imageExtension': imageBase64.isEmpty ? '' : kItCaseImageExtension,
      },
      options: options,
    );

    return itCaseResultOf(unwrapMobileResponse(response));
  } on MobileApiException {
    rethrow;
  } catch (e) {
    throw MobileApiException(mobileNetworkMessage(e));
  }
}

Future<List<Map<String, dynamic>>> _fetchList(
  String path, {
  List<Map<String, dynamic>> Function(dynamic) decode = decodeItCaseList,
}) async {
  final options = MobileSession.I.authOptions();
  if (options == null) {
    throw const MobileApiException(
      'ยังไม่ได้เชื่อมต่อระบบ กรุณาเข้าสู่ระบบใหม่',
      needLogin: true,
    );
  }

  try {
    final response = await mobileDio.get(path, options: options);
    return decode(unwrapMobileResponse(response));
  } on MobileApiException {
    rethrow;
  } catch (e) {
    throw MobileApiException(mobileNetworkMessage(e));
  }
}

List<Map<String, dynamic>> decodeItCaseList(dynamic data) {
  dynamic decoded = data;

  if (decoded is String) {
    final text = decoded.trim();
    if (text.isEmpty) return const [];
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return const [];
    }
  }

  if (decoded is! List) return const [];
  return [
    for (final item in decoded)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

/// ช่องที่อาจเก็บข้อความตอบกลับไว้ ไล่หาตามลำดับนี้
///
/// ชื่อช่องไม่ตรงกันในแต่ละ endpoint และตัวพิมพ์ใหญ่เล็กก็ไม่แน่นอน
/// จึงเทียบแบบไม่สนตัวพิมพ์
const List<String> _messageKeys = ['message', 'msg', 'result', 'description'];

/// รูปแบบเลขเคสของทีม IT เช่น IT1234567 หรือ IT-1234567
final RegExp _caseNumberPattern = RegExp(
  r'IT[-/]?\d{3,}',
  caseSensitive: false,
);

/// ข้อความสำรอง ใช้เมื่อเซิร์ฟเวอร์ตอบ 200 มาแต่ไม่ได้ส่งข้อความอะไรมาด้วย
const String _sentFallback = 'ส่งเรื่องแจ้งเคสแล้ว';

/// ผลลัพธ์ของการส่งเคส เอาไปโชว์บนป๊อปอัปตอนส่งสำเร็จ
class ItCaseResult {
  /// ข้อความจากเซิร์ฟเวอร์ ไม่มีทางว่าง มีข้อความสำรองให้แล้ว
  final String message;

  /// เลขเคสที่ทีม IT ใช้อ้างอิง เช่น IT1234567
  ///
  /// ว่างได้ เซิร์ฟเวอร์ไม่ได้ส่งมาทุกครั้ง ป๊อปอัปจะซ่อนช่องคัดลอกไปเลย
  final String caseNumber;

  const ItCaseResult({required this.message, required this.caseNumber});

  bool get hasCaseNumber => caseNumber.isNotEmpty;
}

/// แกะ response ของการส่งเคสออกเป็นข้อความกับเลขเคส
///
/// บาง endpoint ตอบข้อความมาเปล่า ๆ บางอันห่อเป็น json มาแบบ
/// `{"success": true, "message": "บันทึกเอกสารสำเร็จ เลขเคส IT1234567"}`
/// เอา `toString()` ของ Map ไปโชว์ตรง ๆ ผู้ใช้จะเห็นวงเล็บปีกกากับ `success:`
/// ติดมาทั้งก้อน
ItCaseResult itCaseResultOf(dynamic data) {
  final decoded = _decodeBody(data);
  final caseNumber = _caseNumberIn(decoded);
  final message = _withoutCaseNumber(_messageIn(decoded), caseNumber);

  return ItCaseResult(
    message: message.isEmpty ? _sentFallback : message,
    caseNumber: caseNumber,
  );
}

/// body ที่พร้อมอ่าน Map ตรง ๆ หรือ String เมื่อไม่ใช่ json
///
/// dio คืนมาเป็น String เมื่อ content-type ไม่ใช่ json ทั้งที่ข้างในเป็น json
/// ส่วน array ที่มีแถวเดียวก็เอาแถวแรกมาอ่านต่อ
dynamic _decodeBody(dynamic data) {
  dynamic decoded = data;

  if (decoded is String) {
    final text = decoded.trim();
    if (!text.startsWith('{') && !text.startsWith('[')) return text;

    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return text;
    }
  }

  if (decoded is List) decoded = decoded.isEmpty ? null : decoded.first;
  return decoded;
}

String _messageIn(dynamic decoded) {
  if (decoded is! Map) return _str(decoded);

  for (final key in _messageKeys) {
    for (final entry in decoded.entries) {
      if (entry.key.toString().toLowerCase() != key) continue;

      final value = entry.value;
      // ช่องที่ห่อของซ้อนอีกชั้นไม่ใช่ข้อความ ข้ามไปหาช่องถัดไป
      if (value is Map || value is List || value is bool) continue;

      final text = _str(value);
      if (text.isNotEmpty) return text;
    }
  }

  return '';
}

/// เลขเคสจาก body ไม่เจอก็คืนค่าว่าง
///
/// ไม่ไล่เดาชื่อช่อง (jobNo / caseNo / docNo แล้วแต่ endpoint) เพราะเดาไม่หมด
/// กวาดทุกช่องที่เป็นข้อความแล้วจับด้วยรูปแบบเลขเคสเอาแทน เผื่อบางทีเซิร์ฟเวอร์
/// ไม่ได้แยกช่องให้ แต่พ่วงมาในข้อความเลยว่า "บันทึกสำเร็จ เลขเคส IT1234567"
String _caseNumberIn(dynamic decoded) {
  if (decoded is Map) {
    for (final value in decoded.values) {
      if (value is Map || value is List || value is bool) continue;

      final found = _caseNumberPattern.stringMatch(_str(value));
      if (found != null) return found.toUpperCase();
    }
    return '';
  }

  return _caseNumberPattern.stringMatch(_str(decoded))?.toUpperCase() ?? '';
}

/// ตัดเลขเคสออกจากข้อความ เพราะป๊อปอัปแยกโชว์ให้กดคัดลอกอยู่แล้ว
///
/// ตัดคำนำหน้าที่ห้อยอยู่ออกด้วย ไม่งั้นจะเหลือ "บันทึกเอกสารสำเร็จ เลขเคส"
/// ค้างอยู่ลอย ๆ ตัดแล้วไม่เหลืออะไรก็คืนข้อความเดิมไป ดีกว่าโชว์ช่องว่าง
String _withoutCaseNumber(String message, String caseNumber) {
  if (message.isEmpty || caseNumber.isEmpty) return message;

  final withLabel = RegExp(
    r'(เลขที่เคส|เลขเคส|เลขที่|เคส|no\.?)?\s*' + RegExp.escape(caseNumber),
    caseSensitive: false,
  );

  final stripped = message
      .replaceAll(withLabel, '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .replaceAll(RegExp(r'[\s:：,\-–]+$'), '')
      .trim();

  return stripped.isEmpty ? message : stripped;
}

/// รหัสโปรแกรมที่จะส่งจริง ไม่มีก็ใช้ [kItCaseNoProgramId] แทนค่าว่าง
String itCaseProgramIdOf(String? programId) {
  final id = programId?.trim() ?? '';
  return id.isEmpty ? kItCaseNoProgramId : id;
}

String _str(dynamic value) {
  if (value == null) return '';
  final text = value.toString().trim();
  return text == 'null' ? '' : text;
}

/// คะแนน 1-5 ที่ผู้แจ้งให้ไว้ อ่านไม่ออกหรือนอกช่วงคืน 0
///
/// 0 แปลว่ายังไม่ได้ให้คะแนน ไม่ใช่ให้ศูนย์ดาว หน้าจอจะซ่อนแถวนั้นไปเลย
/// รับทั้ง `4` และ `"4.0"` เผื่อ backend ส่งมาเป็นทศนิยม
int itCaseRatingOf(String text) {
  final value = double.tryParse(text.trim());
  if (value == null) return 0;

  final score = value.round();
  return score >= 1 && score <= 5 ? score : 0;
}
