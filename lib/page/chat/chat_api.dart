import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/utils/role_service.dart';
import 'package:claim/utils/supabase_config.dart';

const String _chatPath = '/functions/v1/chat';

/// บอทตอบกลับหนึ่งครั้ง
///
/// บอทไม่ได้ใช้ LLM แต่เป็นเมนูกับคำสั่งตายตัวฝั่งเซิร์ฟเวอร์ ตอบเป็นโครงสร้าง
/// มาให้แอปวาดเอง ไม่ใช่ข้อความก้อนเดียว หน้าจอจึงทำปุ่มลัดกับการ์ดเคสได้
/// โดยไม่ต้องแกะข้อความ
class ChatReply {
  /// ข้อความตอบ มีเสมอ อาจมีหลายบรรทัด
  final String text;

  /// รายการเคส ว่างเมื่อเป็นคำตอบข้อความล้วน
  final List<ChatTicket> tickets;

  /// ปุ่มลัด กดแล้วส่งข้อความนั้นกลับไปได้ตรง ๆ
  final List<String> quickReplies;

  /// ลิงก์ไปทำต่อบนเว็บ ว่างได้
  final ChatLink? link;

  const ChatReply({
    required this.text,
    this.tickets = const [],
    this.quickReplies = const [],
    this.link,
  });

  factory ChatReply.fromJson(Map<String, dynamic> json) {
    final rawTickets = json['tickets'];
    final rawReplies = json['quickReplies'];
    final rawLink = json['link'];

    return ChatReply(
      text: _str(json['text']),
      tickets: rawTickets is! List
          ? const []
          : [
              for (final item in rawTickets)
                if (item is Map)
                  ChatTicket.fromJson(Map<String, dynamic>.from(item)),
            ],
      quickReplies: rawReplies is! List
          ? const []
          : [
              for (final item in rawReplies)
                if (_str(item).isNotEmpty) _str(item),
            ],
      link: rawLink is Map
          ? ChatLink.fromJson(Map<String, dynamic>.from(rawLink))
          : null,
    );
  }
}

/// ลิงก์ที่บอทแนบมาให้กดไปทำต่อ
class ChatLink {
  final String label;
  final String url;

  const ChatLink({required this.label, required this.url});

  factory ChatLink.fromJson(Map<String, dynamic> json) =>
      ChatLink(label: _str(json['label']), url: _str(json['url']));

  bool get isUsable => url.isNotEmpty;
}

/// เคสหนึ่งใบที่บอทส่งมาให้โชว์เป็นการ์ด
///
/// ไม่ใช้ [RepairTicket] ของหน้าแจ้งซ่อม เพราะบอทส่งมาคนละรูปแบบ (camelCase
/// และแปลป้ายสถานะไทยมาให้แล้ว) ยัดเข้าโมเดลเดิมต้องแปลงสองรอบและจะพังเงียบ ๆ
/// ถ้าฝั่งใดฝั่งหนึ่งเปลี่ยนชื่อช่อง
class ChatTicket {
  final int? id;

  /// รหัสสถานะดิบ เช่น IN_PROGRESS ใช้เลือกสีอย่างเดียว
  final String status;

  /// ป้ายสถานะภาษาไทยที่เซิร์ฟเวอร์แปลมาให้แล้ว
  ///
  /// ห้ามแปลซ้ำในแอป วันหลัง IT เพิ่มสถานะใหม่ แอปจะได้ป้ายใหม่เองโดยไม่ต้อง
  /// ปล่อยเวอร์ชันใหม่
  final String statusLabel;

  final String deviceName;
  final String sn;
  final String issue;

  /// ช่างที่รับงาน ว่างเมื่อยังไม่มีคนรับ
  final String technician;

  final String branch;
  final String requesterName;
  final DateTime? createdAt;
  final DateTime? completedAt;

  /// จำนวนรูปอาการเสียที่แนบไว้
  final int imageCount;

  const ChatTicket({
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.deviceName,
    required this.sn,
    required this.issue,
    required this.technician,
    required this.branch,
    required this.requesterName,
    required this.createdAt,
    required this.completedAt,
    required this.imageCount,
  });

  factory ChatTicket.fromJson(Map<String, dynamic> json) => ChatTicket(
    id: int.tryParse(_str(json['id'])),
    status: _str(json['status']).toUpperCase(),
    statusLabel: _str(json['statusLabel']),
    deviceName: _str(json['deviceName']),
    sn: _str(json['sn']),
    issue: _str(json['issue']),
    technician: _str(json['technician']),
    branch: _str(json['branch']),
    requesterName: _str(json['requesterName']),
    createdAt: _date(json['createdAt']),
    completedAt: _date(json['completedAt']),
    imageCount: int.tryParse(_str(json['imageCount'])) ?? 0,
  );

  /// เลขเคสแบบที่พิมพ์ถามบอทได้ เช่น TK-42
  String get code => id == null ? '' : 'TK-$id';
}

/// ถามบอท คืนคำตอบที่พร้อมวาด
///
/// แนบรหัสพนักงานกับสิทธิ์ไปด้วยทุกครั้ง บอทใช้รหัสพนักงานหาว่า "เคสของฉัน"
/// คือใบไหน และใช้สิทธิ์ตัดสินว่าคำสั่งของทีม IT (เช่น "เคสรอรับ") ใช้ได้ไหม
///
/// [name] เป็นทางสำรองของฝั่งเซิร์ฟเวอร์ ใช้หาใบเก่าที่สร้างก่อนระบบจะเริ่ม
/// เก็บรหัสพนักงาน ใบพวกนั้นมีแต่ชื่อผู้แจ้ง
Future<ChatReply> askChatbot(String text) async {
  final message = text.trim();
  if (message.isEmpty) {
    throw Exception('ยังไม่ได้พิมพ์อะไร');
  }

  if (!await SupabaseConfig.ensureKey()) {
    throw Exception('โหลดคีย์ระบบแจ้งซ่อมไม่ได้ กรุณาตรวจสอบอินเทอร์เน็ต');
  }

  final prefs = await SharedPreferences.getInstance();

  try {
    final response = await supabaseDio.post(
      _chatPath,
      data: {
        'text': message,
        if (RoleService.I.empNumber != null)
          'employee_number': RoleService.I.empNumber,
        'role': RoleService.I.role.value.name.toUpperCase(),
        'name': prefs.getString('fullname')?.trim() ?? '',
      },
      options: Options(validateStatus: (_) => true),
    );

    final body = response.data;
    final ok = response.statusCode != null && response.statusCode! < 300;

    if (body is Map) {
      // ข้อความ error เป็นภาษาไทยที่เขียนให้ผู้ใช้อ่านอยู่แล้ว แสดงต่อได้เลย
      final error = body['error'];
      if (error != null) throw Exception(error.toString());

      if (ok && body['success'] == true && body['data'] is Map) {
        return ChatReply.fromJson(Map<String, dynamic>.from(body['data']));
      }
    }

    throw Exception('บอทตอบไม่ได้ (HTTP ${response.statusCode})');
  } on DioException catch (e) {
    debugPrint('chat api error: ${e.type} ${e.message}');
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw Exception('เชื่อมต่อบอทหมดเวลา กรุณาลองใหม่');
    }
    throw Exception('เชื่อมต่อบอทไม่ได้ กรุณาตรวจสอบอินเทอร์เน็ต');
  }
}

String _str(dynamic value) {
  if (value == null) return '';
  final text = value.toString().trim();
  return text == 'null' ? '' : text;
}

/// วันที่จากบอทเป็น ISO ที่มี Z ต่อท้าย แปลงเป็นเวลาเครื่องให้ด้วย
///
/// ไม่แปลงแล้วเคสที่แจ้งตอนบ่ายจะขึ้นเป็นตอนเช้า เพราะไทยเร็วกว่า UTC 7 ชั่วโมง
DateTime? _date(dynamic value) {
  final text = _str(value);
  if (text.isEmpty) return null;

  return DateTime.tryParse(text)?.toLocal();
}

/// ผู้ใช้คนนี้ผูกบัญชี LINE กับระบบแล้วหรือยัง
///
/// ใช้ตัดสินว่าจะชวนให้แอด LINE OA ไหม ผูกแล้วก็ไม่ต้องชวนซ้ำ
///
/// เกณฑ์คือ "ผูกบัญชีแล้ว" ไม่ใช่ "แอดแล้ว" เพราะ LINE ไม่มี API ให้ถามว่าใคร
/// แอด OA แล้วบ้างโดยอ้างจากรหัสพนักงาน แต่การผูกบัญชีเริ่มจากการทักบอท
/// คนที่ผูกแล้วจึงแอดแล้วแน่นอน
///
/// ⚠️ ถามไม่สำเร็จคืน true คือถือว่าผูกแล้ว แถบชวนจะได้ไม่โผล่
/// เน็ตสะดุดทีเดียวแล้วไปเด้งแถบใส่คนที่ผูกไปนานแล้ว น่ารำคาญกว่าประโยชน์ที่ได้
Future<bool> isLineLinked(int empNumber) async {
  if (!await SupabaseConfig.ensureKey()) {
    debugPrint('line link: โหลดคีย์ Supabase ไม่ได้');
    return true;
  }

  try {
    final response = await supabaseDio.post(
      _chatPath,
      data: {
        'action': 'link_status',
        'employee_number': empNumber,
        'role': RoleService.I.role.value.name.toUpperCase(),
      },
      options: Options(validateStatus: (_) => true),
    );

    final body = response.data;
    if (body is! Map || body['success'] != true) {
      debugPrint('line link: ตอบผิดรูป HTTP ${response.statusCode} $body');
      return true;
    }

    final data = body['data'];
    final linked = data is! Map || data['linked'] != false;
    debugPrint('line link: emp $empNumber linked=$linked');
    return linked;
  } catch (e) {
    debugPrint('line link: ถามไม่สำเร็จ $e');
    return true;
  }
}
