import 'package:claim/utils/claim_reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = ClaimReminderService.I;

  group('resolveFireTime', () {
    test('ก่อนเวลาเตือน ใช้ 20:00 ของวันนั้น', () {
      final now = DateTime(2026, 9, 7, 9, 30);
      expect(
        service.resolveFireTime(now),
        DateTime(2026, 9, 7, ClaimReminderService.reminderHour),
      );
    });

    test('ใกล้ 20:00 แต่ยังไม่ถึงระยะเว้น ก็ยังใช้ 20:00', () {
      final now = DateTime(2026, 9, 7, 19, 50);
      expect(
        service.resolveFireTime(now),
        DateTime(2026, 9, 7, ClaimReminderService.reminderHour),
      );
    });

    test('เลย 20:00 มาแล้ว เลื่อนไปอีก 15 นาทีเพื่อให้ทันก่อนเที่ยงคืน', () {
      final now = DateTime(2026, 9, 7, 21, 0);
      expect(service.resolveFireTime(now), DateTime(2026, 9, 7, 21, 15));
    });

    test('ดึกจนเตือนไม่ทันก่อนล้างข้อมูล คืน null', () {
      final now = DateTime(2026, 9, 7, 23, 50);
      expect(service.resolveFireTime(now), isNull);
    });

    test('เที่ยงคืนพอดีนับเป็นเตือนไม่ทัน', () {
      final now = DateTime(2026, 9, 7, 23, 45);
      expect(service.resolveFireTime(now), isNull);
    });

    test('ข้ามเดือนไม่หลุดไปวันอื่น', () {
      final now = DateTime(2026, 9, 30, 22, 30);
      expect(service.resolveFireTime(now), DateTime(2026, 9, 30, 22, 45));
    });
  });
}
