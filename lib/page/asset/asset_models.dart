/// ทะเบียนทรัพย์สิน — กลุ่ม AssetTransfer บน Mobile API
///
/// ข้อจำกัดของแต่ละช่อง (ความยาว/รูปแบบ) ลอกมาจาก schema `requestInsertAsset`
/// กับ `requestInsertAssetType` ตรง ๆ เช็คฝั่งแอปก่อนยิงจะได้ไม่เสียรอบไปโดน
/// 400 กลับมาแล้วผู้ใช้ไม่รู้ว่าผิดช่องไหน
///
/// ชื่อช่องของ response ยืนยันกับ API ของจริงแล้วเมื่อ 23 ก.ย. 2026 ไม่ใช่การ
/// เดาจาก schema ฝั่งส่งเหมือนตอนเขียนครั้งแรก
library;

import 'package:intl/intl.dart';

import 'package:claim/page/asset/asset_json.dart';

/// รหัสทรัพย์สินและรหัสประเภทต้องเป็น A-Z a-z 0-9 คั่นด้วยขีดเท่านั้น
/// ห้ามขึ้นต้นหรือลงท้ายด้วยขีด และห้ามมีขีดติดกันสองตัว
final RegExp kAssetCodePattern = RegExp(r'^[A-Za-z0-9]+(-[A-Za-z0-9]+)*$');

const int kAssetIdMax = 20;
const int kAssetNameMax = 250;
const int kAssetTypeMax = 25;
const int kAssetSerialMax = 100;
const int kAssetBrandMax = 100;
const int kAssetModelMax = 100;
const int kAssetStatusMax = 20;
const int kAssetSiteMax = 20;
const int kAssetCustodianMax = 50;
const int kAssetRemarkMax = 500;
const int kAssetTypeDescMax = 100;

/// เพดานราคาที่ schema ยอมรับ ส่งเกินนี้เซิร์ฟเวอร์ตีกลับ
const double kAssetPriceMax = 9999999999999.99;

/// รายการ lookup 1 แถว ใช้ได้ทั้งประเภททรัพย์สินและสถานะทรัพย์สิน
///
/// swagger เขียน response ไว้แค่ "Success" ไม่ได้บอกชื่อช่อง แต่ยิงของจริงดูแล้ว
/// เมื่อ 23 ก.ย. 2026: เป็น `type_id` / `desc_th` / `desc_en` และ `status_id` /
/// `desc_th` / `desc_en` ตรงตามที่เดาไว้ ชื่อที่เหลือในลิสต์เก็บไว้เป็นตาข่ายรอง
class AssetLookup {
  /// ค่าที่ส่งกลับไปตอนบันทึก (`asset_type` หรือ `status_id`)
  final String code;
  final String nameTh;
  final String nameEn;

  const AssetLookup({required this.code, this.nameTh = '', this.nameEn = ''});

  factory AssetLookup.fromJson(Map<String, dynamic> json) => AssetLookup(
    code: _pick(json, const [
      'typeid',
      'statusid',
      'assettype',
      'assetstatus',
      'code',
      'id',
    ]),
    nameTh: _pick(json, const [
      'descth',
      'detailsth',
      'nameth',
      'desc',
      'details',
      'description',
      'name',
    ]),
    nameEn: _pick(json, const ['descen', 'detailsen', 'nameen']),
  );

  /// ข้อความที่โชว์ในช่องเลือก ไม่มีชื่อไทยก็ใช้อังกฤษ ไม่มีทั้งคู่ก็โชว์รหัส
  /// ดีกว่าโชว์ว่างเปล่าจนผู้ใช้เลือกไม่ถูก
  String get label {
    if (nameTh.isNotEmpty) return nameTh;
    if (nameEn.isNotEmpty) return nameEn;
    return code;
  }

  /// โชว์รหัสต่อท้ายเมื่อมีชื่อกำกับ คนกรอกจะได้เทียบกับเอกสารที่ถืออยู่ได้
  String get detailLabel => label == code ? code : '$label ($code)';
}

/// ข้อความบอกว่ารหัสผิดตรงไหน คืน null เมื่อใช้ได้
///
/// [label] คือชื่อช่องที่เอาไปขึ้นต้นข้อความ ใช้ร่วมกันได้ทั้งรหัสทรัพย์สินและ
/// รหัสประเภท เพราะกติกาเดียวกันเป๊ะ ต่างแค่ความยาวสูงสุด
String? assetCodeError(
  String value, {
  required String label,
  required int max,
}) {
  final text = value.trim();
  if (text.isEmpty) return 'กรอก$label';
  if (text.length > max) return '$labelยาวเกิน $max ตัวอักษร';
  if (!kAssetCodePattern.hasMatch(text)) {
    return '$labelใช้ได้แค่ A-Z 0-9 และขีด (-) คั่นกลาง';
  }
  return null;
}

String? assetIdError(String value) =>
    assetCodeError(value, label: 'รหัสทรัพย์สิน', max: kAssetIdMax);

String? assetTypeIdError(String value) =>
    assetCodeError(value, label: 'รหัสประเภท', max: kAssetTypeMax);

/// ช่องบังคับกรอกที่ไม่มีรูปแบบตายตัว เช็คแค่ว่ามีค่าและไม่ยาวเกิน
String? assetRequiredError(
  String value, {
  required String label,
  required int max,
}) {
  final text = value.trim();
  if (text.isEmpty) return 'กรอก$label';
  if (text.length > max) return '$labelยาวเกิน $max ตัวอักษร';
  return null;
}

/// ราคาที่พิมพ์มาใช้ได้หรือไม่ คืน null เมื่อผ่าน (ปล่อยว่างได้ ไม่บังคับ)
String? assetPriceError(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;

  final price = assetPriceOf(text);
  if (price == null) return 'ราคาต้องเป็นตัวเลข';
  if (price < 0) return 'ราคาติดลบไม่ได้';
  if (price > kAssetPriceMax) return 'ราคาสูงเกินกว่าที่ระบบรับได้';
  return null;
}

/// แปลงราคาที่พิมพ์เป็นตัวเลข คืน null เมื่อว่างหรืออ่านไม่ออก
///
/// ตัดลูกน้ำออกก่อน เพราะคนกรอกราคามักพิมพ์ 25,900 ตามที่เห็นในใบเสร็จ
double? assetPriceOf(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  return double.tryParse(text.replaceAll(',', ''));
}

/// วันที่ในรูปแบบที่ .NET รับ ไม่ใส่ timezone และไม่ใส่มิลลิวินาที
///
/// ตัดเวลาทิ้งเป็นเที่ยงคืนเสมอ เพราะทั้งสามช่อง (รับเข้า/ซื้อ/หมดประกัน)
/// เป็นวันที่ล้วน ติดเวลาไปด้วยจะทำให้รายงานฝั่งเว็บเทียบวันไม่ตรง
String assetDateText(DateTime date) =>
    '${DateFormat('yyyy-MM-dd').format(date)}T00:00:00';

/// วันที่แบบที่คนอ่าน เป็น พ.ศ. ตามที่หน้าอื่นในแอปใช้
///
/// บวก 543 เอง ไม่ปล่อยให้ `DateFormat('…y', 'th')` จัดการ เพราะ locale `th`
/// ของ intl ใช้ปฏิทินเกรกอเรียน — ได้ชื่อเดือนไทยแต่ปียังเป็น ค.ศ. เดิมเขียนไว้
/// แบบนั้นแล้วคอมเมนต์บอกว่าเป็น พ.ศ. ซึ่งไม่ตรงกับของที่ออกมาจริง ทำให้ทะเบียน
/// ทรัพย์สินโชว์ปี 2026 ขณะที่ใบแจ้งซ่อมโชว์ 69 อยู่คนละหน้าจอในแอปเดียวกัน
String assetDateLabel(DateTime date) =>
    '${DateFormat('d MMM', 'th').format(date)} ${date.year + 543}';

/// วันที่พร้อมเวลา ใช้ในประวัติที่มีหลายเหตุการณ์ในวันเดียวกัน
///
/// ประวัติที่บอกแค่วันทำให้เรียงลำดับเหตุการณ์ในวันเดียวกันไม่ออก ซึ่งเป็น
/// กรณีปกติของการโอนย้าย (ส่งออกกับรับเข้าห่างกันไม่กี่นาที)
String assetDateTimeLabel(DateTime at) =>
    '${assetDateLabel(at)} ${DateFormat('HH:mm').format(at)} น.';

/// body ของ POST /api/AssetTransfer/asset
///
/// ช่องที่ไม่บังคับและผู้ใช้ไม่ได้กรอก จะไม่ใส่ key ไปเลย ไม่ส่งสตริงว่าง
/// เพราะฝั่งเซิร์ฟเวอร์ประกาศเป็น nullable ไว้ ถ้าส่ง "" ไปจะได้ค่าว่างค้างใน
/// ฐานข้อมูลแทนที่จะเป็น null แล้วรายงานที่กรองว่า "ยังไม่ระบุ" จะนับไม่ครบ
Map<String, dynamic> buildAssetPayload({
  required String assetId,
  required String assetName,
  required String assetType,
  String serialNo = '',
  String brand = '',
  String model = '',
  String statusId = '',
  String siteId = '',
  String custodian = '',
  String remark = '',
  DateTime? acceptDate,
  DateTime? purchaseDate,
  DateTime? warrantyExpireDate,
  double? purchasePrice,
}) {
  final payload = <String, dynamic>{
    'asset_id': assetId.trim(),
    'asset_name': assetName.trim(),
    'asset_type': assetType.trim(),
  };

  void put(String key, String value) {
    final text = value.trim();
    if (text.isNotEmpty) payload[key] = text;
  }

  put('serial_no', serialNo);
  put('brand', brand);
  put('model', model);
  put('status_id', statusId);
  put('current_site_id', siteId);
  put('current_custodian', custodian);

  if (acceptDate != null) payload['accept_date'] = assetDateText(acceptDate);
  if (purchaseDate != null) {
    payload['purchase_date'] = assetDateText(purchaseDate);
  }
  if (purchasePrice != null) payload['purchase_price'] = purchasePrice;
  if (warrantyExpireDate != null) {
    payload['warranty_expire_date'] = assetDateText(warrantyExpireDate);
  }

  put('remark', remark);
  return payload;
}

/// body ของ POST /api/AssetTransfer/assettype — ทั้งสามช่องบังคับหมด
Map<String, dynamic> buildAssetTypePayload({
  required String typeId,
  required String descTh,
  required String descEn,
}) => {
  'type_id': typeId.trim(),
  'desc_th': descTh.trim(),
  'desc_en': descEn.trim(),
};

/// จำนวนต่อหน้าของ `/assets` เพดานของ endpoint คือ 200
///
/// เอา 50 เพราะแต่ละรายการเป็นการ์ดสี่บรรทัด โหลดทีละ 200 จะสะดุดตอนวาดครั้งแรก
/// บนมือถือรุ่นที่สาขาใช้ และของที่ตามหามักอยู่ในหน้าแรกอยู่แล้ว
const int kAssetPageSize = 50;

/// จำนวนบรรทัดประวัติที่ขอมาต่อครั้ง ตรงกับ default ของ endpoint
const int kAssetLogTake = 50;

/// จำนวนพนักงานที่ขอมาต่อการค้นหนึ่งครั้ง
///
/// น้อยกว่า default ของ endpoint (100) เพราะช่องเลือกคนมีช่องค้นอยู่แล้ว
/// คนที่เลื่อนหาเกิน 40 รายชื่อควรพิมพ์ค้นแทน ไม่ใช่รอโหลดเพิ่ม
const int kAssetEmployeeTake = 40;

const int kAssetChangeNoteMax = 500;
const int kAssetRefNoMax = 30;

/// วันเวลาที่ API ส่งมาเป็นเวลาไทยอยู่แล้ว ไม่มี timezone ต่อท้าย
///
/// ประกอบจากตัวเลขเอง ไม่ใช้ DateTime.parse แบบเดียวกับระบบ PM ถ้าวันหนึ่ง
/// backend เติม Z มาแล้วมีใครเผลอ toLocal() เวลาจะเพี้ยนไป 7 ชั่วโมง
DateTime? assetDateOf(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;

  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?)?',
  ).firstMatch(text);
  if (match == null) return null;

  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4) ?? '0'),
    int.parse(match.group(5) ?? '0'),
    int.parse(match.group(6) ?? '0'),
  );
}

/// ทรัพย์สิน 1 ชิ้นที่อ่านมาจาก `/assets` หรือ `/asset/{assetId}`
///
/// ชื่อช่องอ่านแบบไม่ยึดตายตัวเหมือน [AssetLookup] เพราะ swagger เขียน response
/// ไว้แค่ "Success" ยึด snake_case ตาม schema ฝั่งส่งเป็นหลัก แล้วเผื่อชื่ออื่นที่
/// query แบบ join มักตั้ง (เช่น `status_desc_th` ที่มาจากตารางสถานะ)
class Asset {
  final String id;
  final String name;
  final String typeId;
  final String typeName;
  final String serialNo;
  final String brand;
  final String model;
  final String statusId;
  final String statusName;
  final String siteId;
  final String custodian;
  final String remark;
  final DateTime? acceptDate;
  final DateTime? purchaseDate;
  final DateTime? warrantyExpireDate;
  final double? purchasePrice;

  const Asset({
    required this.id,
    this.name = '',
    this.typeId = '',
    this.typeName = '',
    this.serialNo = '',
    this.brand = '',
    this.model = '',
    this.statusId = '',
    this.statusName = '',
    this.siteId = '',
    this.custodian = '',
    this.remark = '',
    this.acceptDate,
    this.purchaseDate,
    this.warrantyExpireDate,
    this.purchasePrice,
  });

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
    id: _pick(json, const ['assetid', 'id', 'code']),
    name: _pick(json, const ['assetname', 'name']),
    typeId: _pick(json, const ['assettype', 'typeid']),
    typeName: _pick(json, const [
      'assettypedesc',
      'assettypename',
      'typedescth',
      'typedesc',
      'typenameth',
      'typename',
      'descth',
    ]),
    serialNo: _pick(json, const ['serialno', 'sn', 'serial']),
    brand: _pick(json, const ['brand']),
    model: _pick(json, const ['model']),
    statusId: _pick(json, const ['statusid', 'status']),
    statusName: _pick(json, const [
      'statusname',
      'statusdescth',
      'statusdesc',
      'statusth',
    ]),
    siteId: _pick(json, const ['currentsiteid', 'siteid', 'branchid', 'site']),
    custodian: _pick(json, const [
      'currentcustodian',
      'custodian',
      'holder',
      'owner',
    ]),
    remark: _pick(json, const ['remark']),
    acceptDate: assetDateOf(_pick(json, const ['acceptdate'])),
    purchaseDate: assetDateOf(_pick(json, const ['purchasedate'])),
    warrantyExpireDate: assetDateOf(
      _pick(json, const [
        'warrantyexpiredate',
        'warrantyexpire',
        'warrantydate',
      ]),
    ),
    purchasePrice: assetPriceOf(_pick(json, const ['purchaseprice', 'price'])),
  );

  /// สถานะที่อยากให้เป็นหลังแก้ไข ส่งเฉพาะช่องที่เปลี่ยน ที่เหลือคงของเดิม
  ///
  /// ใช้ตอนโอนย้าย: หยิบของเดิมมาเปลี่ยนแค่สาขากับผู้ครอบครอง แล้วส่งทั้งก้อน
  /// กลับไป (เหตุผลอยู่ที่ [buildAssetUpdatePayload])
  ///
  /// รหัสทรัพย์สินกับสถานะเปลี่ยนไม่ได้ อันแรกเป็น path ของ endpoint อันหลัง
  /// ไม่มีใน `requestUpdateAsset` เลย
  Asset copyWith({
    String? name,
    String? typeId,
    String? serialNo,
    String? brand,
    String? model,
    String? siteId,
    String? custodian,
    String? remark,
    DateTime? acceptDate,
    DateTime? purchaseDate,
    DateTime? warrantyExpireDate,
    double? purchasePrice,
  }) => Asset(
    id: id,
    name: name ?? this.name,
    typeId: typeId ?? this.typeId,
    typeName: typeName,
    serialNo: serialNo ?? this.serialNo,
    brand: brand ?? this.brand,
    model: model ?? this.model,
    statusId: statusId,
    statusName: statusName,
    siteId: siteId ?? this.siteId,
    custodian: custodian ?? this.custodian,
    remark: remark ?? this.remark,
    acceptDate: acceptDate ?? this.acceptDate,
    purchaseDate: purchaseDate ?? this.purchaseDate,
    warrantyExpireDate: warrantyExpireDate ?? this.warrantyExpireDate,
    purchasePrice: purchasePrice ?? this.purchasePrice,
  );

  /// ชื่อประเภทถ้าส่งมาด้วย ไม่มีก็รหัสประเภท
  String get typeLabel => typeName.isNotEmpty ? typeName : typeId;

  /// ชื่อสถานะถ้าส่งมาด้วย ไม่มีก็รหัสสถานะ
  String get statusLabel => statusName.isNotEmpty ? statusName : statusId;

  /// ที่อยู่ตอนนี้แบบอ่านรวดเดียว ใช้บนการ์ดในลิสต์และหน้าโอนย้าย
  String get placeLabel {
    final parts = [
      if (siteId.isNotEmpty) siteId,
      if (custodian.isNotEmpty) custodian,
    ];
    return parts.isEmpty ? 'ยังไม่ระบุที่อยู่' : parts.join(' · ');
  }

  /// ประกันหมดแล้วหรือยัง ไม่รู้วันหมดประกันคืน null
  bool? get warrantyExpired {
    final date = warrantyExpireDate;
    if (date == null) return null;
    return date.isBefore(DateTime.now());
  }

  /// ข้อความไว้ค้นในเครื่อง ใช้กรองของที่โหลดมาแล้วโดยไม่ยิงซ้ำ
  String get searchIndex => [
    id,
    name,
    typeLabel,
    serialNo,
    brand,
    model,
    siteId,
    custodian,
  ].join(' ').toLowerCase();
}

/// ประวัติการเปลี่ยนแปลง 1 บรรทัดจาก `/asset/{assetId}/log`
///
/// เป็นตัวที่ทำให้การโอนย้ายตรวจย้อนหลังได้ ทุก PUT บังคับให้มี `change_note`
/// ฝั่งเซิร์ฟเวอร์จึงมีเหตุผลของทุกการเปลี่ยนแปลงเก็บไว้
class AssetLogEntry {
  final DateTime? at;
  final String by;
  final String note;
  final String refNo;

  /// ช่องที่ถูกแก้พร้อมค่าเก่า/ค่าใหม่ ถ้า backend เก็บละเอียดถึงระดับช่อง
  ///
  /// [field] เป็นชื่อคอลัมน์ดิบ (`status_id`, `current_site_id`) ห้ามเอาไปโชว์
  /// ตรง ๆ ใช้ [assetFieldLabel] แปลงก่อน
  final String field;
  final String oldValue;
  final String newValue;

  /// `UPDATE` = แก้ข้อมูล, `TRANSFER` = ส่ง/รับของ ค่าอื่นถือเป็นการแก้ธรรมดา
  final String actionType;

  const AssetLogEntry({
    this.at,
    this.by = '',
    this.note = '',
    this.refNo = '',
    this.field = '',
    this.oldValue = '',
    this.newValue = '',
    this.actionType = '',
  });

  factory AssetLogEntry.fromJson(Map<String, dynamic> json) => AssetLogEntry(
    at: assetDateOf(
      _pick(json, const [
        'changedate',
        'changedat',
        'logdate',
        'actiondate',
        'updatedate',
        'createdate',
        'createddate',
        'datetime',
        'date',
      ]),
    ),
    // `actionby` คือชื่อที่ของจริงใช้ — ตกไปจากลิสต์ตอนเขียนครั้งแรก ทำให้
    // บรรทัด "โดย …" ไม่เคยขึ้นเลยสักครั้ง
    by: _pick(json, const [
      'actionby',
      'changedby',
      'changeby',
      'updatedby',
      'updateby',
      'createdby',
      'createby',
      'empno',
      'username',
      'user',
    ]),
    actionType: _pick(json, const ['actiontype', 'action']),
    note: _pick(json, const [
      'changenote',
      'note',
      'reason',
      'description',
      'details',
      'detail',
    ]),
    refNo: _pick(json, const ['refno', 'ref', 'docno', 'documentno']),
    field: _pick(json, const ['fieldname', 'field', 'columnname', 'column']),
    oldValue: _pick(json, const ['oldvalue', 'valueold', 'oldval', 'before']),
    newValue: _pick(json, const ['newvalue', 'valuenew', 'newval', 'after']),
  );

  /// มีอะไรให้อ่านบ้างไหม แถวที่ว่างทั้งบรรทัดไม่ต้องเอามาโชว์
  bool get isUsable =>
      at != null ||
      note.isNotEmpty ||
      field.isNotEmpty ||
      newValue.isNotEmpty ||
      by.isNotEmpty;

  /// ชื่อช่องแบบที่คนอ่านออก ว่างเมื่อแถวนี้ไม่ได้ระบุช่อง
  String get fieldLabel => assetFieldLabel(field);

  bool get isTransfer => actionType.toUpperCase() == 'TRANSFER';
}

/// ชื่อคอลัมน์ที่ `/log` ส่งมา แปลงเป็นคำที่คนอ่านออก
///
/// ประวัติเป็นหน้าที่คนทั่วไปเปิดดูเวลาตามหาว่าของไปอยู่ไหน เห็น
/// `current_site_id` แล้วเดาไม่ออกว่าคืออะไร ชื่อที่ไม่รู้จักคืนของเดิมไป
/// ดีกว่าซ่อนทั้งบรรทัดจนไม่รู้ว่ามีอะไรเปลี่ยน
const Map<String, String> kAssetFieldLabels = {
  'assetname': 'ชื่อทรัพย์สิน',
  'assettype': 'ประเภท',
  'statusid': 'สถานะ',
  'serialno': 'Serial Number',
  'brand': 'ยี่ห้อ',
  'model': 'รุ่น',
  'currentsiteid': 'แผนกที่ดูแล',
  'currentcustodian': 'ผู้ครอบครอง',
  'acceptdate': 'วันที่รับเข้า',
  'purchasedate': 'วันที่ซื้อ',
  'purchaseprice': 'ราคาซื้อ',
  'warrantyexpiredate': 'วันหมดประกัน',
  'remark': 'หมายเหตุ',
  'isactive': 'สถานะการใช้งาน',
};

String assetFieldLabel(String fieldName) {
  final raw = fieldName.trim();
  if (raw.isEmpty) return '';
  return kAssetFieldLabels[_normalizedKey(raw)] ?? raw;
}

/// ช่องที่แปลได้แต่ไม่เอามาโชว์ในประวัติ
///
/// `asset_type` ถูกตัดเพราะค่าที่เก็บเป็นรหัสประเภท และตารางประเภทของจริงมีแถว
/// ขยะจากคนกดทดสอบผ่าน swagger ปนอยู่ (`desc_th` เป็นคำว่า "string") เปลี่ยน
/// ประเภทหนึ่งครั้งจึงกลายเป็นบรรทัด "ประเภท: string → string" ที่ไม่บอกอะไรเลย
///
/// ที่เหลือเป็นค่าภายในของระบบ คนใช้งานไม่ได้เป็นคนแก้และไม่รู้ว่าคืออะไร
const Set<String> kAssetLogHiddenFields = {
  'assettype',
  'isactive',
  'createby',
  'createdate',
  'modifyby',
  'modifydate',
};

/// ค่าที่ไม่ได้แปลว่าอะไร มาจากคนกดทดสอบผ่าน swagger แล้วปล่อยค่าตั้งต้นไว้
const Set<String> kAssetPlaceholderValues = {'string', 'null', 'undefined'};

bool assetLogValueIsPlaceholder(String value) =>
    kAssetPlaceholderValues.contains(value.trim().toLowerCase());

/// ช่องนี้เอาไปโชว์ในประวัติได้ไหม
///
/// เป็น whitelist ไม่ใช่ blacklist — ช่องที่ไม่รู้จักถูกซ่อน ไม่ใช่โชว์ชื่อ
/// คอลัมน์ดิบ เพราะประวัติเป็นหน้าที่คนทั่วไปเปิดดู เห็นชื่อคอลัมน์ที่แปลไม่ออก
/// แล้วได้แต่งง ดีกว่าไม่เห็นบรรทัดนั้นเลย ถ้า backend เพิ่มช่องใหม่ที่ควรโชว์
/// ให้ไปเพิ่มใน [kAssetFieldLabels]
bool assetLogShowsField(String fieldName) {
  final key = _normalizedKey(fieldName.trim());
  if (key.isEmpty) return false;
  if (kAssetLogHiddenFields.contains(key)) return false;
  return kAssetFieldLabels.containsKey(key);
}

/// การแก้ไขหนึ่งครั้งที่กระทบหลายช่องพร้อมกัน
///
/// `/log` เก็บทีละช่อง แก้ทีเดียว 6 ช่องได้ 6 แถวที่มีเวลา เหตุผล คนทำ และ
/// เลขเอกสารเหมือนกันเป๊ะ (เห็นของจริงมาแล้ว) โชว์ดิบ ๆ คือผู้ใช้เห็นเหตุผล
/// เดียวกันซ้ำหกรอบติดกันโดยไม่รู้ว่ามันคือการกดบันทึกครั้งเดียว
class AssetLogEvent {
  final DateTime? at;
  final String by;
  final String note;
  final String refNo;
  final String actionType;

  /// ช่องที่เปลี่ยนในครั้งนี้ เรียงตามที่ API ส่งมา
  final List<AssetLogEntry> changes;

  const AssetLogEvent({
    this.at,
    this.by = '',
    this.note = '',
    this.refNo = '',
    this.actionType = '',
    this.changes = const [],
  });

  bool get isTransfer => actionType.toUpperCase() == 'TRANSFER';

  String get actionLabel => isTransfer ? 'โอนย้าย' : 'แก้ไขข้อมูล';

  /// เฉพาะช่องที่เอาไปโชว์ให้คนอ่านได้ ดู [assetLogShowsField]
  ///
  /// ว่างได้ แปลว่าการแก้ครั้งนั้นแตะแต่ช่องที่เราไม่โชว์ — ยังต้องขึ้นเหตุการณ์
  /// อยู่ เพราะเวลา คนทำ และเหตุผลยังเป็นข้อมูลที่มีค่า แค่ไม่มีตารางใต้มัน
  List<AssetLogEntry> get visibleChanges =>
      changes.where((e) => assetLogShowsField(e.field)).toList();
}

/// รวมแถวที่มาจากการกดบันทึกครั้งเดียวกันเป็นเหตุการณ์เดียว
///
/// จับคู่ด้วยเวลา + คนทำ + เหตุผล + เลขเอกสาร + ประเภท ครบทั้งห้าถึงถือว่า
/// เป็นครั้งเดียวกัน ใช้แค่เวลาไม่พอเพราะสองคนกดพร้อมกันในวินาทีเดียวกันได้
///
/// ลำดับของ [entries] ถูกรักษาไว้ ผู้เรียกเรียงมายังไงก็ได้ผลตามนั้น
List<AssetLogEvent> groupAssetLog(List<AssetLogEntry> entries) {
  final order = <String>[];
  final grouped = <String, List<AssetLogEntry>>{};

  for (final entry in entries) {
    final key = [
      entry.at?.toIso8601String() ?? '',
      entry.by,
      entry.note,
      entry.refNo,
      entry.actionType,
    ].join('|');

    grouped
        .putIfAbsent(key, () {
          order.add(key);
          return <AssetLogEntry>[];
        })
        .add(entry);
  }

  return [
    for (final key in order)
      AssetLogEvent(
        at: grouped[key]!.first.at,
        by: grouped[key]!.first.by,
        note: grouped[key]!.first.note,
        refNo: grouped[key]!.first.refNo,
        actionType: grouped[key]!.first.actionType,
        changes: grouped[key]!,
      ),
  ];
}

/// ผลการค้นหาจาก `/assets` พร้อมข้อมูลแบ่งหน้า
class AssetSearchResult {
  final List<Asset> items;

  /// จำนวนทั้งหมดถ้าเซิร์ฟเวอร์บอกมา ไม่บอกก็เป็น null
  final int? total;
  final int page;
  final int pageSize;

  const AssetSearchResult({
    required this.items,
    required this.page,
    required this.pageSize,
    this.total,
  });

  /// ยังมีหน้าถัดไปให้โหลดอีกไหม
  ///
  /// รู้ยอดรวมก็คิดจากยอดรวม ไม่รู้ก็ดูว่าหน้านี้เต็มพอดีหรือเปล่า เดาผิดได้แค่
  /// ตอนจำนวนลงตัวพอดี ซึ่งเสียแค่การยิงเปล่าหนึ่งครั้ง
  bool get hasMore {
    final count = total;
    if (count != null) return page * pageSize < count;
    return items.length >= pageSize;
  }
}

/// ตัวกรองของ `/assets` ครบทุกตัวที่ endpoint รับ
class AssetQuery {
  final String keyword;
  final String typeId;
  final String statusId;
  final String siteId;
  final String custodian;

  /// เอาเฉพาะของที่ประกันใกล้หมด (นับกี่วันเป็นเรื่องของฝั่งเซิร์ฟเวอร์)
  final bool warrantyExpiring;

  /// เอาเฉพาะของที่กรอกข้อมูลไม่ครบ ใช้ตามเก็บตกให้ทะเบียนสมบูรณ์
  final bool incompleteOnly;

  /// รวมของที่ถูกปิดใช้งานไปแล้วด้วย ปกติเซิร์ฟเวอร์ซ่อนไว้
  final bool includeInactive;

  final int page;
  final int pageSize;
  final String sortBy;
  final bool sortDesc;

  const AssetQuery({
    this.keyword = '',
    this.typeId = '',
    this.statusId = '',
    this.siteId = '',
    this.custodian = '',
    this.warrantyExpiring = false,
    this.incompleteOnly = false,
    this.includeInactive = false,
    this.page = 1,
    this.pageSize = kAssetPageSize,
    this.sortBy = '',
    this.sortDesc = false,
  });

  AssetQuery copyWith({
    String? keyword,
    String? typeId,
    String? statusId,
    String? siteId,
    String? custodian,
    bool? warrantyExpiring,
    bool? incompleteOnly,
    bool? includeInactive,
    int? page,
    int? pageSize,
    String? sortBy,
    bool? sortDesc,
  }) => AssetQuery(
    keyword: keyword ?? this.keyword,
    typeId: typeId ?? this.typeId,
    statusId: statusId ?? this.statusId,
    siteId: siteId ?? this.siteId,
    custodian: custodian ?? this.custodian,
    warrantyExpiring: warrantyExpiring ?? this.warrantyExpiring,
    incompleteOnly: incompleteOnly ?? this.incompleteOnly,
    includeInactive: includeInactive ?? this.includeInactive,
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
    sortBy: sortBy ?? this.sortBy,
    sortDesc: sortDesc ?? this.sortDesc,
  );

  /// จำนวนตัวกรองที่เปิดอยู่ ใช้เป็นตัวเลขบนปุ่มตัวกรอง
  ///
  /// ไม่นับคำค้นเพราะมีช่องของตัวเองอยู่ข้าง ๆ อยู่แล้ว นับซ้ำจะทำให้ตัวเลข
  /// ไม่ตรงกับจำนวนชิปที่โชว์อยู่ใต้ช่องค้นหา
  int get filterCount => [
    typeId.isNotEmpty,
    statusId.isNotEmpty,
    siteId.isNotEmpty,
    custodian.isNotEmpty,
    warrantyExpiring,
    incompleteOnly,
    includeInactive,
  ].where((on) => on).length;

  /// ล้างตัวกรองทั้งหมด เก็บคำค้นกับขนาดหน้าไว้
  ///
  /// คำค้นไม่ถูกล้างเพราะคนพิมพ์ไว้ในช่องที่เห็นอยู่ ถ้าหายไปพร้อมตัวกรองจะงง
  /// ว่าทำไมคำที่พิมพ์ไว้หายไปด้วย
  AssetQuery cleared() => AssetQuery(keyword: keyword, pageSize: pageSize);

  /// มีตัวกรองอะไรเปิดอยู่บ้าง ไม่นับหน้าที่กำลังดู
  bool get hasFilter =>
      keyword.isNotEmpty ||
      typeId.isNotEmpty ||
      statusId.isNotEmpty ||
      siteId.isNotEmpty ||
      custodian.isNotEmpty ||
      warrantyExpiring ||
      incompleteOnly ||
      includeInactive;

  /// query string ที่แนบไปกับ GET
  ///
  /// ช่องว่างกับ false ไม่ส่งไปเลย ปล่อยให้ค่า default ฝั่งเซิร์ฟเวอร์ทำงาน
  /// ส่ง `keyword=` ว่าง ๆ ไปบาง backend ตีความเป็นค้นหาสตริงว่างแล้วไม่เจออะไร
  Map<String, dynamic> toParams() {
    final params = <String, dynamic>{'page': page, 'page_size': pageSize};

    void put(String key, String value) {
      final text = value.trim();
      if (text.isNotEmpty) params[key] = text;
    }

    put('keyword', keyword);
    put('asset_type', typeId);
    put('status_id', statusId);
    put('current_site_id', siteId);
    put('current_custodian', custodian);
    put('sort_by', sortBy);

    if (warrantyExpiring) params['warranty_expiring'] = true;
    if (incompleteOnly) params['incomplete_only'] = true;
    if (includeInactive) params['include_inactive'] = true;
    if (sortDesc) params['sort_desc'] = true;

    return params;
  }
}

/// body ของ PUT /api/AssetTransfer/asset/{assetId}
///
/// **ส่งสถานะที่อยากให้เป็นทั้งก้อน ไม่ใช่เฉพาะช่องที่แก้** เพราะ schema ประกาศ
/// ทุกช่องเป็น nullable แต่ swagger ไม่ได้บอกว่า null แปลว่า "ไม่แก้" หรือ
/// "ล้างค่า" ถ้าเป็นอย่างหลังแล้วเราส่งแค่ช่องที่แก้ การโอนย้ายหนึ่งครั้งจะลบ
/// ยี่ห้อ รุ่น และวันที่ซื้อทิ้งหมด ส่งทั้งก้อนแล้วปลอดภัยทั้งสองแบบ
///
/// ⚠️ ผลข้างเคียงคือช่องที่ว่างอยู่แล้วจะไม่ถูกส่งไป จึงล้างค่าที่เคยกรอกไว้ให้
/// กลับเป็นว่างผ่านแอปไม่ได้ ต้องไปล้างที่เว็บ แก้ตรงนี้ได้เมื่อ backend ยืนยัน
/// ว่า null คือการล้างค่า
///
/// [changeNote] บังคับตาม schema เป็นเหตุผลที่จะไปโผล่ในประวัติ
Map<String, dynamic> buildAssetUpdatePayload({
  required Asset next,
  required String changeNote,
  String refNo = '',
}) {
  final payload = <String, dynamic>{'change_note': changeNote.trim()};

  void put(String key, String value) {
    final text = value.trim();
    if (text.isNotEmpty) payload[key] = text;
  }

  put('asset_name', next.name);
  put('asset_type', next.typeId);
  put('serial_no', next.serialNo);
  put('brand', next.brand);
  put('model', next.model);
  put('current_site_id', next.siteId);
  put('current_custodian', next.custodian);

  final accept = next.acceptDate;
  if (accept != null) payload['accept_date'] = assetDateText(accept);

  final purchase = next.purchaseDate;
  if (purchase != null) payload['purchase_date'] = assetDateText(purchase);

  final price = next.purchasePrice;
  if (price != null) payload['purchase_price'] = price;

  final warranty = next.warrantyExpireDate;
  if (warranty != null) {
    payload['warranty_expire_date'] = assetDateText(warranty);
  }

  put('remark', next.remark);
  put('ref_no', refNo);

  return payload;
}

/// เหตุผลของการแก้ไข/โอนย้าย บังคับกรอกเพราะ `change_note` เป็นช่อง required
String? assetChangeNoteError(String value) =>
    assetRequiredError(value, label: 'เหตุผล', max: kAssetChangeNoteMax);

/// สาขา 1 แห่งจาก `/api/AssetTransfer/branch`
///
/// ลิสต์ทั้งก้อนมี 260 สาขา (~66 KB) เล็กพอจะโหลดครั้งเดียวแล้วกรองในเครื่อง
/// จึงไม่ต้องยิงซ้ำทุกตัวอักษรที่พิมพ์ ต่างจากลิสต์พนักงานที่ใหญ่กว่ามาก
class AssetBranch {
  final String id;
  final String name;
  final String typeName;
  final String regionName;
  final String cityName;
  final int typeId;

  /// จำนวนพนักงานประจำสาขา 0 แปลว่าสาขานี้ไม่มีคนประจำ (หรือปิดไปแล้ว)
  final int staffCount;

  const AssetBranch({
    required this.id,
    this.name = '',
    this.typeName = '',
    this.regionName = '',
    this.cityName = '',
    this.typeId = 0,
    this.staffCount = 0,
  });

  factory AssetBranch.fromJson(Map<String, dynamic> json) => AssetBranch(
    id: _pick(json, const ['branchid', 'id', 'code']),
    name: _pick(json, const ['branchname', 'name']),
    typeName: _pick(json, const ['branchtypename', 'branchtype']),
    regionName: _pick(json, const ['regionname', 'region']),
    cityName: _pick(json, const ['cityname', 'city', 'province']),
    typeId: _int(_pick(json, const ['branchtypeid'])),
    staffCount: _int(_pick(json, const ['staffcount'])),
  );

  /// ชื่อสาขาพร้อมรหัส คนกรอกจะได้เทียบกับเอกสารที่ถืออยู่ได้
  String get label => name.isEmpty ? id : '$name ($id)';

  /// บรรทัดรองในลิสต์เลือกสาขา — ประเภท จังหวัด ภาค เท่าที่ส่งมา
  String get placeLabel => [
    if (typeName.isNotEmpty) typeName,
    if (cityName.isNotEmpty) cityName,
    if (regionName.isNotEmpty) regionName,
  ].join(' · ');

  /// ข้อความไว้กรองในเครื่อง รวมรหัสไว้ด้วยเพราะคนที่รู้รหัสอยู่แล้วพิมพ์รหัส
  String get searchIndex =>
      [id, name, typeName, cityName, regionName].join(' ').toLowerCase();
}

/// พนักงาน 1 คนจาก `/api/AssetTransfer/employee`
///
/// endpoint ค้นได้ทั้งรหัสพนักงานและชื่อไทยผ่าน `keyword` จึงให้เซิร์ฟเวอร์ค้น
/// ไม่โหลดมาทั้งบริษัท (ไม่ใส่ `take` ได้มา 100 แถว ใส่ 500 ก็ได้ครบ 500)
class AssetEmployee {
  final String id;
  final String fullName;
  final String deptCode;
  final String deptName;
  final String branchId;
  final String positionName;
  final int positionLevel;

  const AssetEmployee({
    required this.id,
    this.fullName = '',
    this.deptCode = '',
    this.deptName = '',
    this.branchId = '',
    this.positionName = '',
    this.positionLevel = 0,
  });

  factory AssetEmployee.fromJson(Map<String, dynamic> json) => AssetEmployee(
    id: _pick(json, const ['empid', 'empno', 'id']),
    fullName: _pick(json, const ['empfullname', 'fullname', 'empname', 'name']),
    deptCode: _pick(json, const ['deptcode']),
    deptName: _pick(json, const ['deptname']),
    branchId: _pick(json, const ['branchid']),
    positionName: _pick(json, const ['positionname', 'position']),
    positionLevel: _int(_pick(json, const ['positionlevel'])),
  );

  /// ชื่อพร้อมรหัสพนักงาน รูปแบบเดียวกับ [AssetBranch.label]
  String get label => fullName.isEmpty ? id : '$fullName ($id)';

  /// บรรทัดรองในลิสต์เลือกคน — ตำแหน่ง แผนก สาขา เท่าที่ส่งมา
  String get roleLabel => [
    if (positionName.isNotEmpty) positionName,
    if (deptName.isNotEmpty) deptName,
    if (branchId.isNotEmpty) branchId,
  ].join(' · ');
}

/// ผู้อนุมัติของแผนกหนึ่ง จาก `/api/AssetTransfer/approver/{deptCode}`
///
/// โผล่ในช่อง `my_approvers` ของ `/me` ด้วย รูปร่างเดียวกันเป๊ะ
///
/// ⚠️ `deptCode` ที่ endpoint นี้รับคือรหัสแผนก (เช่น `F0001`) ไม่ใช่ตัวย่อ
/// อย่าง `IT` — ส่งตัวย่อไปได้ลิสต์ว่างกลับมาโดยไม่มี error
/// `/approvers` ส่งช่องเพิ่มมาอีกชุดที่สองเส้นแรกไม่มี ([isActive] [isEffective]
/// [blockedReason] ช่วงวันที่ [remark]) เก็บไว้ในคลาสเดียวกันแล้วให้เส้นที่ไม่ส่ง
/// มาใช้ค่าตั้งต้นแทน ดีกว่าแยกเป็นสองคลาสที่ซ้ำกันเจ็ดช่อง
class AssetApprover {
  final String deptCode;
  final String deptName;
  final String id;
  final String name;
  final String position;

  /// แผนกที่ตัวผู้อนุมัติสังกัด ต่างจาก [deptCode] ที่เป็นแผนกที่เขาอนุมัติให้
  ///
  /// หัวหน้าฝ่ายมักถูกตั้งเป็นผู้อนุมัติของแผนกลูกหลายแผนก สองช่องนี้จึงไม่ตรงกัน
  /// เป็นเรื่องปกติ ไม่ใช่ข้อมูลผิด
  final String approverDept;

  /// ลำดับการอนุมัติ 1–5 ใช้เรียงเมื่อแผนกหนึ่งมีผู้อนุมัติหลายชั้น
  final int order;

  final DateTime? validFrom;
  final DateTime? validTo;

  /// ถูกปิดใช้งานไว้หรือยัง คนตั้งค่าเป็นคนกด ต่างจาก [isEffective]
  final bool isActive;

  /// ใช้อนุมัติได้จริงตอนนี้หรือไม่ — เซิร์ฟเวอร์เป็นคนตัดสิน
  ///
  /// `is_active` เป็น true ได้ทั้งที่ `is_effective` เป็น false เช่นผู้อนุมัติ
  /// ลาออกไปแล้ว หรืออยู่นอกช่วงวันที่ เหตุผลอยู่ใน [blockedReason]
  final bool isEffective;

  /// เหตุผลที่ใช้ไม่ได้ เช่น "ไม่ใช่พนักงานปัจจุบันแล้ว" ว่างเมื่อใช้ได้ปกติ
  final String blockedReason;

  final String remark;

  const AssetApprover({
    required this.id,
    this.deptCode = '',
    this.deptName = '',
    this.name = '',
    this.position = '',
    this.approverDept = '',
    this.order = 0,
    this.validFrom,
    this.validTo,
    this.isActive = true,
    this.isEffective = true,
    this.blockedReason = '',
    this.remark = '',
  });

  factory AssetApprover.fromJson(Map<String, dynamic> json) => AssetApprover(
    id: _pick(json, const ['approverid', 'empid', 'id']),
    deptCode: _pick(json, const ['deptcode']),
    deptName: _pick(json, const ['deptname']),
    name: _pick(json, const ['approvername', 'empfullname', 'name']),
    position: _pick(json, const ['approverposition', 'positionname']),
    approverDept: _pick(json, const ['approverdept']),
    order: _int(_pick(json, const ['approveorder', 'order'])),
    validFrom: assetDateOf(_pick(json, const ['validfrom'])),
    validTo: assetDateOf(_pick(json, const ['validto'])),
    // ไม่มีช่องมา = ใช้ได้ (`/me` กับ `/approver/{deptCode}` ส่งเฉพาะตัวที่ใช้ได้
    // อยู่แล้ว) ตั้งค่าตั้งต้นเป็น false จะทำให้ทั้งสองเส้นนั้นดูเหมือนพังทั้งชุด
    isActive: _bool(_raw(json, const ['isactive']), fallback: true),
    isEffective: _bool(_raw(json, const ['iseffective']), fallback: true),
    blockedReason: _pick(json, const ['blockedreason']),
    remark: _pick(json, const ['remark']),
  );

  String get label => name.isEmpty ? id : '$name ($id)';

  /// ผู้อนุมัติลำดับแรก ที่เหลือคือตัวสำรอง
  bool get isPrimary => order <= 1;

  /// ข้อความบอกว่าตอนนี้ใช้ได้ไหม ว่างแปลว่าปกติ ไม่ต้องขึ้นอะไรเลย
  String get problemLabel {
    if (!isActive) return 'ปิดใช้งานไว้';
    if (isEffective) return '';
    return blockedReason.isEmpty ? 'ใช้อนุมัติไม่ได้ตอนนี้' : blockedReason;
  }
}

/// แผนกพร้อมผู้อนุมัติทั้งชุด จาก `/api/AssetTransfer/approvers/summary`
///
/// เส้นนี้ให้ทุกอย่างที่หน้าตั้งผู้อนุมัติต้องใช้ในคำขอเดียว ไม่ต้องยิง
/// `/approvers` ต่อทีละแผนก
class AssetDeptApprovers {
  final String deptCode;
  final String deptName;
  final int staffCount;
  final int approverCount;

  /// มีผู้อนุมัติลำดับ 1 ที่ใช้ได้จริง
  final bool hasPrimary;

  /// มีตัวสำรอง (ลำดับ 2 ขึ้นไป) ที่ใช้ได้จริง
  final bool hasBackup;

  /// อนุมัติได้จริงตอนนี้ — นับเฉพาะผู้อนุมัติที่ `is_effective`
  final bool isReady;

  final List<AssetApprover> approvers;

  const AssetDeptApprovers({
    required this.deptCode,
    this.deptName = '',
    this.staffCount = 0,
    this.approverCount = 0,
    this.hasPrimary = false,
    this.hasBackup = false,
    this.isReady = false,
    this.approvers = const [],
  });

  factory AssetDeptApprovers.fromJson(Map<String, dynamic> json) {
    final rows = [
      for (final item in _list(_raw(json, const ['approvers'])))
        if (item is Map)
          AssetApprover.fromJson(Map<String, dynamic>.from(item)),
    ].where((e) => e.id.isNotEmpty).toList();

    rows.sort((a, b) => a.order.compareTo(b.order));

    return AssetDeptApprovers(
      deptCode: _pick(json, const ['deptcode', 'code']),
      deptName: _pick(json, const ['deptname', 'name']),
      staffCount: _int(_pick(json, const ['staffcount'])),
      approverCount: _int(_pick(json, const ['approvercount'])),
      hasPrimary: _bool(_raw(json, const ['hasprimary']), fallback: false),
      hasBackup: _bool(_raw(json, const ['hasbackup']), fallback: false),
      isReady: _bool(_raw(json, const ['isready']), fallback: false),
      approvers: rows,
    );
  }

  String get label => deptName.isEmpty ? deptCode : '$deptName ($deptCode)';

  /// สิ่งที่ยังขาดอยู่ ว่างแปลว่าครบแล้วทั้งตัวจริงและตัวสำรอง
  String get gapLabel {
    if (!isReady) {
      return approverCount == 0
          ? 'ยังไม่มีผู้อนุมัติ'
          : 'มีผู้อนุมัติแต่ใช้ไม่ได้';
    }
    return hasBackup ? '' : 'ยังไม่มีตัวสำรอง';
  }

  /// ข้อความไว้กรองในเครื่อง ลิสต์แผนกโหลดมาทั้งก้อนแล้วกรองเอง เพราะ
  /// `keyword` ฝั่งเซิร์ฟเวอร์ค้นได้แค่ในชุด 100 แถวที่ถูกตัดมาแล้ว
  String get searchIndex => [
    deptCode,
    deptName,
    for (final approver in approvers) ...[approver.id, approver.name],
  ].join(' ').toLowerCase();
}

/// ลำดับการอนุมัติต่ำสุด/สูงสุดที่ schema `requestInsertApprover` ยอมรับ
const int kApproverOrderMin = 1;
const int kApproverOrderMax = 5;

const int kApproverRemarkMax = 300;

/// body ของ POST /api/AssetTransfer/approver
Map<String, dynamic> buildApproverInsertPayload({
  required String deptCode,
  required String approverId,
  int order = kApproverOrderMin,
  DateTime? validFrom,
  DateTime? validTo,
  String remark = '',
}) {
  final payload = <String, dynamic>{
    'dept_code': deptCode.trim(),
    'approver_id': approverId.trim(),
    'approve_order': order.clamp(kApproverOrderMin, kApproverOrderMax),
  };

  if (validFrom != null) payload['valid_from'] = assetDateText(validFrom);
  if (validTo != null) payload['valid_to'] = assetDateText(validTo);
  if (remark.trim().isNotEmpty) payload['remark'] = remark.trim();

  return payload;
}

/// body ของ PUT /api/AssetTransfer/approver/{deptCode}/{approverId}
///
/// ส่งเฉพาะช่องที่ตั้งใจแก้ ต่างจาก `requestUpdateAsset` ที่ต้องส่งทั้งก้อน
/// เพราะที่นี่มีแค่ห้าช่องและทุกช่องอยู่ในมือคนกดอยู่แล้ว ไม่มีช่องที่อ่าน
/// กลับมาไม่ได้แบบ `purchase_price`
Map<String, dynamic> buildApproverUpdatePayload({
  int? order,
  DateTime? validFrom,
  DateTime? validTo,
  bool? isActive,
  String? remark,
}) {
  final payload = <String, dynamic>{};

  if (order != null) {
    payload['approve_order'] = order.clamp(
      kApproverOrderMin,
      kApproverOrderMax,
    );
  }
  if (validFrom != null) payload['valid_from'] = assetDateText(validFrom);
  if (validTo != null) payload['valid_to'] = assetDateText(validTo);
  if (isActive != null) payload['is_active'] = isActive;
  if (remark != null) payload['remark'] = remark.trim();

  return payload;
}

/// ข้อความบอกว่าหมายเหตุยาวเกินไหม คืน null เมื่อใช้ได้ (ปล่อยว่างได้)
String? approverRemarkError(String value) {
  if (value.trim().length > kApproverRemarkMax) {
    return 'หมายเหตุยาวเกิน $kApproverRemarkMax ตัวอักษร';
  }
  return null;
}

/// สิทธิ์ที่ `/me` ส่งกลับมาในช่อง `permissions`
///
/// เป็นค่าที่เห็นจาก API ของจริง ไม่ได้อยู่ใน swagger ที่ไหน ตัวที่ขึ้นต้นด้วย
/// `TRANSFER_` มีมาแล้วทั้งที่ยังไม่มี endpoint โอนย้ายแยก — ของพวกนี้เตรียมไว้
/// ให้ flow ส่ง/รับที่ backend ยังทำไม่เสร็จ อย่าเพิ่งเอาไปกั้นเมนู
const String kAssetPermCreate = 'ASSET_CREATE';
const String kAssetPermEdit = 'ASSET_EDIT';
const String kAssetPermTransferCreate = 'TRANSFER_CREATE';
const String kAssetPermTransferDispatch = 'TRANSFER_DISPATCH';
const String kAssetPermTransferReceive = 'TRANSFER_RECEIVE';

/// ตัวตนของคนที่ล็อกอินอยู่ จาก `/api/AssetTransfer/me`
///
/// เป็นแหล่งเดียวที่บอกชื่อ-นามสกุล สาขา และแผนกของคนกดในระบบทรัพย์สิน
/// ต่างจาก `PermissionService` ที่มาจาก API หลักคนละตัว ทั้งสองอาจไม่ตรงกัน
class AssetProfile {
  final String empId;
  final String fullName;
  final String deptCode;
  final String deptName;
  final String branchId;
  final String branchName;
  final String positionName;
  final int positionLevel;
  final List<String> permissions;

  /// ผู้อนุมัติของแผนกตัวเอง ติดมากับ `/me` เลย ไม่ต้องยิง `/approver` ซ้ำ
  final List<AssetApprover> approvers;

  const AssetProfile({
    required this.empId,
    this.fullName = '',
    this.deptCode = '',
    this.deptName = '',
    this.branchId = '',
    this.branchName = '',
    this.positionName = '',
    this.positionLevel = 0,
    this.permissions = const [],
    this.approvers = const [],
  });

  factory AssetProfile.fromJson(Map<String, dynamic> json) => AssetProfile(
    empId: _pick(json, const ['empid', 'empno', 'id']),
    fullName: _pick(json, const ['empfullname', 'fullname', 'empname', 'name']),
    deptCode: _pick(json, const ['deptcode']),
    deptName: _pick(json, const ['deptname']),
    branchId: _pick(json, const ['branchid']),
    branchName: _pick(json, const ['branchname']),
    positionName: _pick(json, const ['positionname', 'position']),
    positionLevel: _int(_pick(json, const ['positionlevel'])),
    permissions: [
      for (final item in _list(_raw(json, const ['permissions'])))
        if (item != null && item is! Iterable && item is! Map)
          item.toString().trim(),
    ].where((e) => e.isNotEmpty).toList(),
    approvers: [
      for (final item in _list(_raw(json, const ['myapprovers', 'approvers'])))
        if (item is Map)
          AssetApprover.fromJson(Map<String, dynamic>.from(item)),
    ].where((e) => e.id.isNotEmpty).toList(),
  );

  /// สาขาพร้อมรหัส ใช้บนปุ่มลัด "สาขาฉัน"
  String get branchLabel =>
      branchName.isEmpty ? branchId : '$branchName ($branchId)';

  bool can(String permission) => permissions.contains(permission);
}

/// ── ตัวช่วยอ่าน JSON ──────────────────────────────────────────────────
///
/// ตัวจริงอยู่ใน [asset_json.dart] เพราะไฟล์อื่นในโฟลเดอร์นี้ใช้ชุดเดียวกัน
/// ชื่อสั้นตรงนี้เก็บไว้เพราะมีที่เรียกใช้หลายสิบจุดในไฟล์นี้
String _pick(Map<String, dynamic> json, List<String> keys) =>
    jsonPick(json, keys);

String _normalizedKey(String key) => normalizedJsonKey(key);

dynamic _raw(Map<String, dynamic> json, List<String> keys) =>
    jsonRaw(json, keys);

int _int(String value) => jsonInt(value);

bool _bool(dynamic value, {required bool fallback}) =>
    jsonBool(value, fallback: fallback);

List<dynamic> _list(dynamic value) => jsonListOf(value);

/// แผนก 1 แผนกจาก `/api/AssetTransfer/deptlist`
///
/// ใช้เป็นที่อยู่ของทรัพย์สิน — ช่อง `current_site_id` เก็บ**รหัสแผนกของผู้
/// ครอบครอง** ไม่ใช่รหัสสาขา แม้ชื่อช่องจะอ่านว่า site
///
/// ⚠️ ชื่อช่องกับของที่อยู่ข้างในไม่ตรงกัน และเอกสาร Data Dictionary v3.0 ยัง
/// เขียนว่าเป็น "รหัสสถานที่ตั้ง" อยู่ ใครมาอ่านทีหลังอย่าเชื่อชื่อช่อง
class AssetDept {
  final String code;
  final String name;
  final int staffCount;
  final int approverCount;

  const AssetDept({
    required this.code,
    this.name = '',
    this.staffCount = 0,
    this.approverCount = 0,
  });

  factory AssetDept.fromJson(Map<String, dynamic> json) => AssetDept(
    code: _pick(json, const ['deptcode', 'code']),
    name: _pick(json, const ['deptname', 'name']),
    staffCount: _int(_pick(json, const ['staffcount'])),
    approverCount: _int(_pick(json, const ['approvercount'])),
  );

  String get label => name.isEmpty ? code : '$name ($code)';

  /// ข้อความไว้กรองในเครื่อง ลิสต์แผนกโหลดมาทั้งก้อนแล้วค้นเอง เพราะ `keyword`
  /// ฝั่งเซิร์ฟเวอร์ค้นได้แค่ในชุด 100 แถวที่ถูกตัดมาแล้ว
  String get searchIndex => [code, name].join(' ').toLowerCase();
}
