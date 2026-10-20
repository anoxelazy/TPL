import 'package:claim/page/chat/chat_api.dart';

/// ข้อความหนึ่งบรรทัดในห้องแชท
///
/// ของผู้ใช้มีแค่ข้อความ ของบอทถือ [ChatReply] ทั้งก้อนไว้ เพราะต้องวาดการ์ด
/// เคสต่อจากข้อความด้วย
class ChatMessage {
  final bool fromUser;
  final String text;
  final ChatReply? reply;

  /// เวลาที่ข้อความนี้โผล่บนจอ ใช้โชว์ข้าง ๆ ฟองแบบแอปแชตทั่วไป
  ///
  /// ไม่ใช่เวลาจากเซิร์ฟเวอร์ บอทไม่ได้ส่งมาให้ และคนอ่านสนใจแค่ว่าคุยกันตอนไหน
  final DateTime at;

  ChatMessage.user(this.text)
    : fromUser = true,
      reply = null,
      at = DateTime.now();

  ChatMessage.bot(this.reply)
    : fromUser = false,
      text = '',
      at = DateTime.now();

  /// ข้อความที่จะโชว์ ของบอทเอามาจากคำตอบ
  String get body => fromUser ? text : (reply?.text ?? '');
}

/// บทสนทนากับบอทของรอบนี้ อยู่นอกตัว widget จึงไม่หายตอนปิดแผ่น
///
/// ห้องแชทเปิดเป็นแผ่นเลื่อน ซึ่งปัดปิดง่ายกว่าหน้าเต็มมาก ถ้าเก็บข้อความไว้ใน
/// state ของ widget เผลอปัดทีเดียวคำตอบที่เพิ่งได้มาหายหมด ต้องถามใหม่ตั้งแต่ต้น
///
/// **อยู่ในหน่วยความจำเท่านั้น ไม่ลงดิสก์** ปิดแอปแล้วหายไปพร้อมกระบวนการ
/// ในบทสนทนามีรายละเอียดใบซ่อม (เลขที่ใบ เครื่อง สาขา ชื่อคน) ซึ่งยังไม่ได้
/// ตกลงกันว่าเก็บลงเครื่องได้แค่ไหน จึงยังไม่เขียนลง SharedPreferences
class ChatSession {
  ChatSession._();

  static final ChatSession I = ChatSession._();

  final List<ChatMessage> messages = [];

  /// ล้างบทสนทนาตอน logout
  ///
  /// logout ไม่ได้ปิดแอป ตัวนี้จึงยังมีชีวิตอยู่พร้อมข้อความของคนก่อนหน้า
  /// ถ้าไม่ล้าง คนถัดไปที่ล็อกอินบนเครื่องเดียวกันจะเปิดแชทมาเจอใบซ่อมของคนอื่น
  /// (เรียกจาก [forgetSignedInUser] ที่รวมการล้างทุกอย่างไว้ที่เดียว)
  void forgetCurrentUser() => messages.clear();
}
