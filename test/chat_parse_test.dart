import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/chat/chat_api.dart';

/// ⚠️ ตัวอย่างในไฟล์นี้อ้างจากเอกสาร TPL Repair API ฉบับ 17 ก.ย. 2569
/// ไม่ใช่ response ที่ดึงมาจากเซิร์ฟเวอร์จริง
///
/// ที่ยืนยันกับของจริงแล้วคือคำสั่ง "ช่วยเหลือ" ซึ่งตอบกลับมาเป็น
/// text + quickReplies โดยไม่มี tickets
void main() {
  group('คำตอบของบอท', () {
    test('ข้อความล้วนพร้อมปุ่มลัด แบบที่ "ช่วยเหลือ" ตอบกลับมาจริง', () {
      final reply = ChatReply.fromJson(const {
        'text': 'ผมช่วยติดตามสถานะงานซ่อมได้ครับ ลองพิมพ์:\n• เคสของฉัน',
        'quickReplies': ['เคสของฉัน', 'ค้นจาก S/N', 'ช่วยเหลือ'],
      });

      expect(reply.text, contains('เคสของฉัน'));
      expect(reply.quickReplies, hasLength(3));
      expect(reply.tickets, isEmpty);
      expect(reply.link, isNull);
    });

    test('อ่านการ์ดเคสกับลิงก์ได้ครบ', () {
      final reply = ChatReply.fromJson(const {
        'text': 'เคสของคุณที่ยังไม่ปิด 1 รายการ',
        'tickets': [
          {
            'id': 42,
            'status': 'IN_PROGRESS',
            'statusLabel': 'กำลังดำเนินการ',
            'deviceName': 'Dell Latitude 3420',
            'sn': 'SN12345',
            'issue': 'เปิดไม่ติด',
            'technician': 'ช่างเอ',
            'branch': 'สำนักงานใหญ่',
            'requesterName': 'สมชาย ใจดี',
            'createdAt': '2026-09-16T08:12:00Z',
            'completedAt': null,
            'imageCount': 2,
          },
        ],
        'link': {'label': 'เปิดหน้าแจ้งซ่อม', 'url': 'https://example.com'},
      });

      final ticket = reply.tickets.single;

      expect(ticket.id, 42);
      expect(ticket.code, 'TK-42');
      expect(ticket.statusLabel, 'กำลังดำเนินการ');
      expect(ticket.technician, 'ช่างเอ');
      expect(ticket.imageCount, 2);
      expect(ticket.completedAt, isNull);
      expect(reply.link!.isUsable, isTrue);
    });

    test('เวลาจากบอทเป็น UTC ต้องแปลงเป็นเวลาเครื่อง', () {
      final ticket = ChatTicket.fromJson(const {
        'id': 1,
        'createdAt': '2026-09-16T08:12:00Z',
      });

      expect(
        ticket.createdAt!.isUtc,
        isFalse,
        reason: 'ไม่แปลงแล้วเคสที่แจ้งบ่ายจะขึ้นเป็นเช้า ไทยเร็วกว่า UTC 7 ชม.',
      );
      expect(ticket.createdAt, DateTime.utc(2026, 9, 16, 8, 12).toLocal());
    });

    test('ช่องที่ไม่มีไม่ทำให้พัง โชว์เป็นค่าว่างแทน', () {
      final reply = ChatReply.fromJson(const {'text': 'ไม่พบเคส'});

      expect(reply.tickets, isEmpty);
      expect(reply.quickReplies, isEmpty);
      expect(reply.link, isNull);
    });

    test('ยังไม่มีช่างรับงาน ช่องว่างไม่ใช่ null ค้าง', () {
      final ticket = ChatTicket.fromJson(const {
        'id': 7,
        'technician': null,
        'imageCount': null,
      });

      expect(ticket.technician, isEmpty);
      expect(ticket.imageCount, 0);
    });

    test('ลิงก์ที่ไม่มี url ถือว่าใช้ไม่ได้ ปุ่มจะไม่ขึ้น', () {
      final link = ChatLink.fromJson(const {'label': 'เปิด', 'url': ''});

      expect(link.isUsable, isFalse);
    });
  });
}
