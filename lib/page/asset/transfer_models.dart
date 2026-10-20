/// ใบโอนย้ายทรัพย์สิน — กลุ่ม AssetTransfer บน Mobile API (เพิ่มมา 28 ก.ย. 2026)
///
/// ก่อนหน้านี้แอปโอนย้ายด้วยการ `PUT /asset/{id}` เปลี่ยนสาขากับผู้ครอบครองตรง ๆ
/// เพราะยังไม่มีอย่างอื่นให้ใช้ Spec v3.0 กำกับไว้ชัดว่านั่นคือ "การแก้ข้อมูลให้
/// ถูกต้อง" ไม่ใช่การโอนย้าย — **การย้ายของจริงต้องเป็นใบโอนย้าย** ตอนนี้ใบจริง
/// มาแล้ว
///
/// ใบหนึ่งใบเดินผ่านห้าขั้น: สร้าง → ส่งอนุมัติ → อนุมัติ → ส่งออก → รับเข้า
/// และยกเลิกได้ระหว่างทาง แต่ละขั้นเป็น endpoint ของตัวเอง
///
/// **ไม่ฮาร์ดโค้ดว่าสถานะไหนกดอะไรได้** เพราะ `responseTransferDetail` ส่ง
/// `can_submit` / `can_approve` / `can_dispatch` / `can_receive` / `can_cancel`
/// มาให้แล้ว เซิร์ฟเวอร์รู้กติกาดีกว่าเรา และกติกาจะเปลี่ยนโดยที่แอปไม่ต้องแก้
library;

import 'package:claim/page/asset/asset_json.dart';
import 'package:claim/page/asset/asset_models.dart';

const int kTransferReasonMax = 500;
const int kTransferCrNoMax = 30;
const int kTransferCourierMax = 100;
const int kTransferTrackingMax = 50;
const int kTransferConditionMax = 20;

/// รหัสสภาพของปกติ ใช้ทั้ง `condition_out` ตอนส่งและ `condition_in` ตอนรับ
const String kTransferConditionGood = 'GOOD';
const int kTransferNoteMax = 500;

/// `to_custodian` ของใบโอนย้ายสั้นกว่า `current_custodian` ของทรัพย์สิน (50)
/// ทั้งที่เก็บรหัสพนักงานเหมือนกัน — ยึดตาม schema ของแต่ละเส้น
const int kTransferCustodianMax = 20;

/// จำนวนใบต่อหน้าของ `/transfers`
const int kTransferPageSize = 20;

/// ผลการรับของรายชิ้น ค่าตายตัวตาม regex ใน `requestReceiveLine`
const String kReceiveOk = 'RECEIVED_OK';
const String kReceiveDamaged = 'RECEIVED_DAMAGED';
const String kReceiveNotArrived = 'NOT_ARRIVED';
const String kReceiveRejected = 'REJECTED';

/// ผลการรับพร้อมคำอธิบายไทย เรียงตามที่คนกดน่าจะเลือกบ่อยสุดลงไปหาน้อยสุด
const Map<String, String> kReceiveOutcomes = {
  kReceiveOk: 'รับปกติ',
  kReceiveDamaged: 'รับไว้แต่ชำรุด',
  kReceiveNotArrived: 'ของไม่มาถึง',
  kReceiveRejected: 'ปฏิเสธการรับ',
};

/// ผลการรับที่แปลว่ามีปัญหา ต้องเด่นกว่าปกติบนหน้าจอ
bool transferOutcomeIsProblem(String outcome) =>
    outcome.isNotEmpty && outcome.toUpperCase() != kReceiveOk;

/// ทรัพย์สิน 1 ชิ้นในใบโอนย้าย
///
/// ชื่อกับประเภทลงท้าย `_snap` เพราะเป็น **ภาพถ่าย ณ วันที่สร้างใบ** ไม่ใช่ค่า
/// ปัจจุบันของทรัพย์สิน ของชิ้นเดียวกันอาจถูกเปลี่ยนชื่อไปแล้วหลังใบนี้ปิด —
/// ใบเก่าต้องยังอ่านได้ว่าตอนนั้นย้ายอะไรไป
class AssetTransferLine {
  final String assetId;
  final String assetName;
  final String assetType;
  final String serialNo;

  /// สภาพตอนส่งออกและตอนรับเข้า เช่น `GOOD`
  final String conditionOut;
  final String conditionIn;

  /// ผลการรับ ว่าง = ยังไม่ได้รับชิ้นนี้
  final String outcome;
  final String outcomeLabel;
  final String note;

  final String receiptBy;
  final String receiptByName;
  final DateTime? receiptAt;
  final String photoPath;

  /// มีคนอื่นรับแทนผู้ครอบครองที่ระบุไว้ในใบ
  final bool receivedOnBehalf;

  /// สถานะของทรัพย์สินชิ้นนี้ตอนนี้ (ค่าปัจจุบัน ไม่ใช่ snapshot)
  final String assetCurrentStatus;

  const AssetTransferLine({
    required this.assetId,
    this.assetName = '',
    this.assetType = '',
    this.serialNo = '',
    this.conditionOut = '',
    this.conditionIn = '',
    this.outcome = '',
    this.outcomeLabel = '',
    this.note = '',
    this.receiptBy = '',
    this.receiptByName = '',
    this.receiptAt,
    this.photoPath = '',
    this.receivedOnBehalf = false,
    this.assetCurrentStatus = '',
  });

  factory AssetTransferLine.fromJson(Map<String, dynamic> json) =>
      AssetTransferLine(
        assetId: jsonPick(json, const ['assetid']),
        assetName: jsonPick(json, const ['assetnamesnap', 'assetname']),
        assetType: jsonPick(json, const ['assettypesnap', 'assettype']),
        serialNo: jsonPick(json, const ['serialnosnap', 'serialno']),
        conditionOut: jsonPick(json, const ['conditionout']),
        conditionIn: jsonPick(json, const ['conditionin']),
        outcome: jsonPick(json, const ['receiptoutcome', 'outcome']),
        outcomeLabel: jsonPick(json, const ['outcomedesc']),
        note: jsonPick(json, const ['receiptnote', 'note']),
        receiptBy: jsonPick(json, const ['receiptby']),
        receiptByName: jsonPick(json, const ['receiptbyname']),
        receiptAt: assetDateOf(jsonPick(json, const ['receiptdate'])),
        photoPath: jsonPick(json, const ['photopath']),
        receivedOnBehalf: jsonBool(
          jsonRaw(json, const ['receivedonbehalf']),
          fallback: false,
        ),
        assetCurrentStatus: jsonPick(json, const ['assetcurrentstatus']),
      );

  /// ชิ้นนี้ถูกรับไปแล้วหรือยัง
  bool get isReceived => outcome.isNotEmpty;

  bool get hasProblem => transferOutcomeIsProblem(outcome);

  /// ชื่อที่โชว์ ไม่มีชื่อก็ใช้รหัส
  String get label => assetName.isEmpty ? assetId : assetName;

  /// คำอธิบายผลการรับ ใช้ของที่เซิร์ฟเวอร์แปลมาก่อน ไม่มีค่อยแปลเอง
  String get outcomeText {
    if (outcomeLabel.isNotEmpty) return outcomeLabel;
    return kReceiveOutcomes[outcome.toUpperCase()] ?? outcome;
  }
}

/// ใบโอนย้าย 1 ใบแบบย่อ สำหรับหน้ารายการ
class AssetTransferItem {
  final String transferNo;
  final DateTime? transferDate;

  /// รหัสสถานะ (`RECEIVED`) กับคำอธิบายไทยที่เซิร์ฟเวอร์แปลมาให้ (`รับครบแล้ว`)
  final String status;
  final String statusLabel;

  final String requestBy;
  final String requestByName;
  final String requestDept;
  final String fromDeptName;
  final String fromSiteId;
  final String fromSiteName;
  final String toDeptCode;
  final String toDeptName;
  final String toSiteId;
  final String toSiteName;
  final String toCustodian;
  final String toCustodianName;

  final DateTime? expectedArrival;
  final String reason;

  final int lineCount;

  /// จำนวนชิ้นที่ยังไม่ได้รับ 0 = รับครบแล้ว
  final int pendingCount;

  /// เกินกำหนดมากี่วัน null = ยังไม่เกิน หรือปิดใบไปแล้ว
  final int? daysOverdue;
  final String severity;

  const AssetTransferItem({
    required this.transferNo,
    this.transferDate,
    this.status = '',
    this.statusLabel = '',
    this.requestBy = '',
    this.requestByName = '',
    this.requestDept = '',
    this.fromDeptName = '',
    this.fromSiteId = '',
    this.fromSiteName = '',
    this.toDeptCode = '',
    this.toDeptName = '',
    this.toSiteId = '',
    this.toSiteName = '',
    this.toCustodian = '',
    this.toCustodianName = '',
    this.expectedArrival,
    this.reason = '',
    this.lineCount = 0,
    this.pendingCount = 0,
    this.daysOverdue,
    this.severity = '',
  });

  factory AssetTransferItem.fromJson(Map<String, dynamic> json) =>
      AssetTransferItem(
        transferNo: jsonPick(json, const ['transferno']),
        transferDate: assetDateOf(jsonPick(json, const ['transferdate'])),
        status: jsonPick(json, const ['headerstatus', 'status']),
        statusLabel: jsonPick(json, const ['statusdesc']),
        requestBy: jsonPick(json, const ['requestby']),
        requestByName: jsonPick(json, const ['requestbyname']),
        requestDept: jsonPick(json, const ['requestdept']),
        fromDeptName: jsonPick(json, const ['fromdeptname']),
        fromSiteId: jsonPick(json, const ['fromsiteid']),
        fromSiteName: jsonPick(json, const ['fromsitename']),
        toDeptCode: jsonPick(json, const ['todeptcode']),
        toDeptName: jsonPick(json, const ['todeptname']),
        toSiteId: jsonPick(json, const ['tositeid']),
        toSiteName: jsonPick(json, const ['tositename']),
        toCustodian: jsonPick(json, const ['tocustodian']),
        toCustodianName: jsonPick(json, const ['tocustodianname']),
        expectedArrival: assetDateOf(
          jsonPick(json, const ['expectedarrivaldate']),
        ),
        reason: jsonPick(json, const ['reason']),
        lineCount: jsonInt(jsonPick(json, const ['linecount'])),
        pendingCount: jsonInt(jsonPick(json, const ['pendingcount'])),
        daysOverdue: jsonIntOrNull(jsonPick(json, const ['daysoverdue'])),
        severity: jsonPick(json, const ['severity']),
      );

  /// ชื่อสถานะที่เอาไปโชว์ ไม่มีคำแปลก็ใช้รหัส
  String get statusText => statusLabel.isEmpty ? status : statusLabel;

  /// ต้นทาง → ปลายทาง แบบอ่านรวดเดียว ใช้ชื่อสาขาถ้ามี ไม่มีก็รหัส
  String get routeLabel {
    final from = fromSiteName.isEmpty ? fromSiteId : fromSiteName;
    final to = toSiteName.isEmpty ? toSiteId : toSiteName;
    if (from.isEmpty && to.isEmpty) return '';
    return '${from.isEmpty ? '—' : from} → ${to.isEmpty ? '—' : to}';
  }

  /// ใบนี้เลยกำหนดรับแล้วหรือยัง
  bool get isOverdue => (daysOverdue ?? 0) > 0;

  bool get isDone => pendingCount == 0 && lineCount > 0;
}

/// ใบโอนย้ายแบบเต็ม พร้อมรายการทรัพย์สินและปุ่มที่กดได้
class AssetTransferDoc {
  final AssetTransferItem header;

  final String crNo;

  final String approvedBy;
  final String approvedByName;
  final DateTime? approvedAt;
  final String rejectReason;

  final String dispatchBy;
  final String dispatchByName;
  final DateTime? dispatchAt;
  final String courierName;
  final String trackingNo;

  final DateTime? receiptAt;
  final String discrepancyNote;
  final String cancelReason;

  final String createBy;
  final DateTime? createAt;

  /// จำนวนชิ้นที่มีคนรับแทน
  final int behalfCount;

  final List<AssetTransferLine> lines;

  /// ปุ่มที่กดได้ตอนนี้ — เซิร์ฟเวอร์เป็นคนตัดสิน ไม่ใช่แอป
  final bool canEdit;
  final bool canSubmit;
  final bool canApprove;
  final bool canDispatch;
  final bool canReceive;
  final bool canCancel;

  const AssetTransferDoc({
    required this.header,
    this.crNo = '',
    this.approvedBy = '',
    this.approvedByName = '',
    this.approvedAt,
    this.rejectReason = '',
    this.dispatchBy = '',
    this.dispatchByName = '',
    this.dispatchAt,
    this.courierName = '',
    this.trackingNo = '',
    this.receiptAt,
    this.discrepancyNote = '',
    this.cancelReason = '',
    this.createBy = '',
    this.createAt,
    this.behalfCount = 0,
    this.lines = const [],
    this.canEdit = false,
    this.canSubmit = false,
    this.canApprove = false,
    this.canDispatch = false,
    this.canReceive = false,
    this.canCancel = false,
  });

  factory AssetTransferDoc.fromJson(Map<String, dynamic> json) {
    bool can(String key) => jsonBool(jsonRaw(json, [key]), fallback: false);

    return AssetTransferDoc(
      header: AssetTransferItem.fromJson(json),
      crNo: jsonPick(json, const ['crno']),
      approvedBy: jsonPick(json, const ['approvedby']),
      approvedByName: jsonPick(json, const ['approvedbyname']),
      approvedAt: assetDateOf(jsonPick(json, const ['approveddate'])),
      rejectReason: jsonPick(json, const ['rejectreason']),
      dispatchBy: jsonPick(json, const ['dispatchby']),
      dispatchByName: jsonPick(json, const ['dispatchbyname']),
      dispatchAt: assetDateOf(jsonPick(json, const ['dispatchdate'])),
      courierName: jsonPick(json, const ['couriername']),
      trackingNo: jsonPick(json, const ['trackingno']),
      receiptAt: assetDateOf(jsonPick(json, const ['receiptdate'])),
      discrepancyNote: jsonPick(json, const ['discrepancynote']),
      cancelReason: jsonPick(json, const ['cancelreason']),
      createBy: jsonPick(json, const ['createby']),
      createAt: assetDateOf(jsonPick(json, const ['createdate'])),
      behalfCount: jsonInt(jsonPick(json, const ['behalfcount'])),
      lines: jsonRows(
        jsonRaw(json, const ['lines']),
        AssetTransferLine.fromJson,
        keep: (line) => line.assetId.isNotEmpty,
      ),
      canEdit: can('canedit'),
      canSubmit: can('cansubmit'),
      canApprove: can('canapprove'),
      canDispatch: can('candispatch'),
      canReceive: can('canreceive'),
      canCancel: can('cancancel'),
    );
  }

  String get transferNo => header.transferNo;

  /// มีปุ่มให้กดสักปุ่มไหม ไม่มีก็ไม่ต้องวาดแถบปุ่มล่างจอ
  bool get hasActions =>
      canSubmit || canApprove || canDispatch || canReceive || canCancel;

  /// ชิ้นที่ยังไม่ได้รับ ใช้ตั้งต้นหน้าจอรับของ
  List<AssetTransferLine> get pendingLines =>
      lines.where((e) => !e.isReceived).toList();

  /// ชิ้นที่รับแล้วแต่มีปัญหา
  List<AssetTransferLine> get problemLines =>
      lines.where((e) => e.hasProblem).toList();
}

/// ผลค้นใบโอนย้ายพร้อมข้อมูลแบ่งหน้า
class AssetTransferSearchResult {
  final List<AssetTransferItem> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  const AssetTransferSearchResult({
    this.items = const [],
    this.page = 1,
    this.pageSize = kTransferPageSize,
    this.total = 0,
    this.totalPages = 0,
  });

  factory AssetTransferSearchResult.fromJson(Map<String, dynamic> json) {
    final page = jsonInt(jsonPick(json, const ['page']));
    final pageSize = jsonInt(jsonPick(json, const ['pagesize']));

    return AssetTransferSearchResult(
      items: jsonRows(
        jsonRaw(json, const ['items', 'data', 'rows']),
        AssetTransferItem.fromJson,
        keep: (item) => item.transferNo.isNotEmpty,
      ),
      page: page == 0 ? 1 : page,
      pageSize: pageSize == 0 ? kTransferPageSize : pageSize,
      total: jsonInt(jsonPick(json, const ['total'])),
      totalPages: jsonInt(jsonPick(json, const ['totalpages'])),
    );
  }

  bool get hasMore => page < totalPages;
}

/// ของที่ส่งออกไปแล้วแต่ยังไม่มีใครรับ เกินกำหนดมาแล้ว
///
/// หนึ่งแถวคือหนึ่งชิ้น ไม่ใช่หนึ่งใบ — ใบเดียวที่มีของค้างสามชิ้นจะได้สามแถว
class AssetTransitAging {
  final String transferNo;
  final String fromSiteId;
  final String toSiteId;
  final String toSiteName;
  final String toDeptCode;
  final DateTime? expectedArrival;
  final DateTime? dispatchAt;
  final String assetId;
  final String assetName;
  final int daysOverdue;
  final String severity;

  /// สิ่งที่เซิร์ฟเวอร์แนะนำให้ทำกับแถวนี้
  final String actionRequired;

  const AssetTransitAging({
    required this.transferNo,
    this.fromSiteId = '',
    this.toSiteId = '',
    this.toSiteName = '',
    this.toDeptCode = '',
    this.expectedArrival,
    this.dispatchAt,
    this.assetId = '',
    this.assetName = '',
    this.daysOverdue = 0,
    this.severity = '',
    this.actionRequired = '',
  });

  factory AssetTransitAging.fromJson(Map<String, dynamic> json) =>
      AssetTransitAging(
        transferNo: jsonPick(json, const ['transferno']),
        fromSiteId: jsonPick(json, const ['fromsiteid']),
        toSiteId: jsonPick(json, const ['tositeid']),
        toSiteName: jsonPick(json, const ['tositename']),
        toDeptCode: jsonPick(json, const ['todeptcode']),
        expectedArrival: assetDateOf(
          jsonPick(json, const ['expectedarrivaldate']),
        ),
        dispatchAt: assetDateOf(jsonPick(json, const ['dispatchdate'])),
        assetId: jsonPick(json, const ['assetid']),
        assetName: jsonPick(json, const ['assetnamesnap', 'assetname']),
        daysOverdue: jsonInt(jsonPick(json, const ['daysoverdue'])),
        severity: jsonPick(json, const ['severity']),
        actionRequired: jsonPick(json, const ['actionrequired']),
      );

  String get label => assetName.isEmpty ? assetId : assetName;
}

/// ตัวกรองของ `/transfers` ครบทุกตัวที่ endpoint รับ
class AssetTransferQuery {
  final String keyword;
  final String status;
  final String requestDept;
  final String toDeptCode;
  final String fromSiteId;
  final String toSiteId;
  final String requestBy;
  final String assetId;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  /// เอาเฉพาะใบที่ยังไม่ปิด
  final bool openOnly;

  /// เอาเฉพาะใบที่เลยกำหนดรับ
  final bool overdueOnly;

  final int page;
  final int pageSize;
  final String sortBy;
  final bool sortDesc;

  const AssetTransferQuery({
    this.keyword = '',
    this.status = '',
    this.requestDept = '',
    this.toDeptCode = '',
    this.fromSiteId = '',
    this.toSiteId = '',
    this.requestBy = '',
    this.assetId = '',
    this.dateFrom,
    this.dateTo,
    this.openOnly = false,
    this.overdueOnly = false,
    this.page = 1,
    this.pageSize = kTransferPageSize,
    this.sortBy = '',
    this.sortDesc = true,
  });

  AssetTransferQuery copyWith({
    String? keyword,
    String? status,
    String? requestDept,
    String? toDeptCode,
    String? fromSiteId,
    String? toSiteId,
    String? requestBy,
    String? assetId,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool? openOnly,
    bool? overdueOnly,
    int? page,
    int? pageSize,
    String? sortBy,
    bool? sortDesc,
    bool clearDates = false,
  }) => AssetTransferQuery(
    keyword: keyword ?? this.keyword,
    status: status ?? this.status,
    requestDept: requestDept ?? this.requestDept,
    toDeptCode: toDeptCode ?? this.toDeptCode,
    fromSiteId: fromSiteId ?? this.fromSiteId,
    toSiteId: toSiteId ?? this.toSiteId,
    requestBy: requestBy ?? this.requestBy,
    assetId: assetId ?? this.assetId,
    dateFrom: clearDates ? null : (dateFrom ?? this.dateFrom),
    dateTo: clearDates ? null : (dateTo ?? this.dateTo),
    openOnly: openOnly ?? this.openOnly,
    overdueOnly: overdueOnly ?? this.overdueOnly,
    // เปลี่ยนตัวกรองแล้วต้องกลับไปหน้าแรกเสมอ ไม่งั้นค้างอยู่หน้า 3 ของผลเก่า
    page: page ?? 1,
    pageSize: pageSize ?? this.pageSize,
    sortBy: sortBy ?? this.sortBy,
    sortDesc: sortDesc ?? this.sortDesc,
  );

  /// มีตัวกรองอะไรเปิดอยู่ไหม ไม่นับหน้าที่กำลังดู
  bool get hasFilter =>
      keyword.trim().isNotEmpty ||
      status.isNotEmpty ||
      requestDept.isNotEmpty ||
      toDeptCode.isNotEmpty ||
      fromSiteId.isNotEmpty ||
      toSiteId.isNotEmpty ||
      requestBy.isNotEmpty ||
      assetId.isNotEmpty ||
      dateFrom != null ||
      dateTo != null ||
      openOnly ||
      overdueOnly;

  Map<String, dynamic> toParams() {
    final params = <String, dynamic>{'page': page, 'page_size': pageSize};

    void put(String key, String value) {
      final text = value.trim();
      if (text.isNotEmpty) params[key] = text;
    }

    put('keyword', keyword);
    put('header_status', status);
    put('request_dept', requestDept);
    put('to_dept_code', toDeptCode);
    put('from_site_id', fromSiteId);
    put('to_site_id', toSiteId);
    put('request_by', requestBy);
    put('asset_id', assetId);
    put('sort_by', sortBy);

    final from = dateFrom;
    final to = dateTo;
    if (from != null) params['date_from'] = assetDateText(from);
    if (to != null) params['date_to'] = assetDateText(to);

    if (openOnly) params['open_only'] = true;
    if (overdueOnly) params['overdue_only'] = true;
    if (!sortDesc) params['sort_desc'] = false;

    return params;
  }
}

/// body ของ POST /api/AssetTransfer/transfer
///
/// ใบหนึ่งใบมีทรัพย์สินได้หลายชิ้น ต่างจากหน้าโอนย้ายเดิมของแอปที่ทำทีละชิ้น
Map<String, dynamic> buildTransferCreatePayload({
  required String toDeptCode,
  required String toSiteId,
  required DateTime expectedArrival,
  required String reason,
  required List<String> assetIds,
  String toCustodian = '',
  String crNo = '',
}) {
  final payload = <String, dynamic>{
    'to_dept_code': toDeptCode.trim(),
    'to_site_id': toSiteId.trim(),
    'expected_arrival_date': assetDateText(expectedArrival),
    'reason': reason.trim(),
    'asset_ids': [
      for (final id in assetIds)
        if (id.trim().isNotEmpty) id.trim(),
    ],
  };

  if (toCustodian.trim().isNotEmpty) {
    payload['to_custodian'] = toCustodian.trim();
  }
  if (crNo.trim().isNotEmpty) payload['cr_no'] = crNo.trim();

  return payload;
}

/// body ของ POST /transfer/{no}/approve — อนุมัติกับไม่อนุมัติใช้เส้นเดียวกัน
Map<String, dynamic> buildTransferApprovePayload({
  required bool approve,
  String reason = '',
}) {
  final payload = <String, dynamic>{'approve': approve};
  if (reason.trim().isNotEmpty) payload['reason'] = reason.trim();
  return payload;
}

/// body ของ POST /transfer/{no}/dispatch — ไม่บังคับสักช่อง
Map<String, dynamic> buildTransferDispatchPayload({
  String courierName = '',
  String trackingNo = '',
  String conditionOut = '',
}) {
  final payload = <String, dynamic>{};

  void put(String key, String value) {
    final text = value.trim();
    if (text.isNotEmpty) payload[key] = text;
  }

  put('courier_name', courierName);
  put('tracking_no', trackingNo);
  put('condition_out', conditionOut);

  return payload;
}

/// body ของ POST /transfer/{no}/receive — รับทีละชิ้น
Map<String, dynamic> buildTransferReceivePayload({
  required String assetId,
  required String outcome,
  String note = '',
  String conditionIn = '',
  String photoPath = '',
}) {
  final payload = <String, dynamic>{
    'asset_id': assetId.trim(),
    'outcome': outcome.trim().toUpperCase(),
  };

  void put(String key, String value) {
    final text = value.trim();
    if (text.isNotEmpty) payload[key] = text;
  }

  put('note', note);
  put('condition_in', conditionIn);
  put('photo_path', photoPath);

  return payload;
}

/// body ของ POST /transfer/{no}/cancel — เหตุผลบังคับ
Map<String, dynamic> buildTransferCancelPayload({required String reason}) => {
  'reason': reason.trim(),
};

/// ข้อความบอกว่าเหตุผลใช้ได้ไหม คืน null เมื่อผ่าน
String? transferReasonError(String value) =>
    assetRequiredError(value, label: 'เหตุผล', max: kTransferReasonMax);

/// เหตุผลยกเลิกใบสั้นสุดที่ Stored Procedure ยอม
const int kTransferCancelReasonMin = 10;

/// เหตุผลยกเลิกใบ — เข้มกว่าเหตุผลทั่วไปตรงที่ต้องยาว [kTransferCancelReasonMin]
/// ตัวขึ้นไป ดักไว้ฝั่งแอปก่อน ไม่งั้นพิมพ์ "ผิด" แล้วกดไปโดนเซิร์ฟเวอร์ตีกลับ
String? transferCancelReasonError(String value) {
  final error = transferReasonError(value);
  if (error != null) return error;
  if (value.trim().length < kTransferCancelReasonMin) {
    return 'เหตุผลต้องยาวอย่างน้อย $kTransferCancelReasonMin ตัวอักษร';
  }
  return null;
}

/// วันที่คาดว่าของจะถึงใช้ได้ไหม คืน null เมื่อผ่าน
///
/// ห้ามเป็นวันในอดีต เพราะใบที่คาดว่าถึงเมื่อวานจะขึ้นเป็นของค้างทางทันทีที่ส่ง
String? transferArrivalError(DateTime? date) {
  if (date == null) return 'เลือกวันที่คาดว่าของจะถึง';

  final today = DateTime.now();
  final midnight = DateTime(today.year, today.month, today.day);
  if (date.isBefore(midnight)) {
    return 'วันที่ของจะถึงต้องไม่ใช่วันที่ผ่านมาแล้ว';
  }

  return null;
}
