import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/repair/repair_api.dart';
import 'package:claim/page/repair/repair_list_header.dart';

RepairTicket _ticket(RepairStatus status) => RepairTicket(
  id: 1,
  assetId: 1,
  assetCode: 'A-1',
  sn: '',
  branch: '',
  deviceName: 'เครื่อง',
  issueDescription: '',
  requesterName: '',
  approverName: '',
  technicianName: '',
  note: '',
  status: status,
  createdAt: null,
  completedAt: null,
);

/// สามใบรอ IT รับเรื่อง หนึ่งใบกำลังซ่อม ไม่มีใบที่ปิดงานแล้ว
final _tickets = [
  _ticket(RepairStatus.pending),
  _ticket(RepairStatus.pending),
  _ticket(RepairStatus.pending),
  _ticket(RepairStatus.inProgress),
];

void main() {
  group('การ์ดสรุปสี่ใบ', () {
    Future<RepairStatus?> pickFrom(
      WidgetTester tester,
      String cardTitle,
    ) async {
      RepairStatus? picked;
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepairStatGrid(
              tickets: _tickets,
              filter: null,
              onPick: (status) {
                picked = status;
                tapped = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text(cardTitle));
      await tester.pump();

      expect(tapped, isTrue, reason: 'กดการ์ด "$cardTitle" แล้วต้องมีการกรอง');
      return picked;
    }

    testWidgets('นับจำนวนใบแยกตามสถานะ', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepairStatGrid(
              tickets: _tickets,
              filter: null,
              onPick: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('4'), findsOneWidget); // ใบทั้งหมด
      expect(find.text('3'), findsOneWidget); // รอ IT รับเรื่อง
      expect(find.text('1'), findsOneWidget); // กำลังซ่อม
      expect(find.text('0'), findsOneWidget); // ปิดงานแล้ว
    });

    testWidgets('ใบที่ยังไม่มีงานค้างบอกไว้ใต้ตัวเลข', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepairStatGrid(
              tickets: _tickets,
              filter: null,
              onPick: (_) {},
            ),
          ),
        ),
      );

      // มีแต่ "ปิดงานแล้ว" ที่เป็นศูนย์
      expect(find.text('ไม่มีงานค้าง'), findsOneWidget);
    });

    testWidgets('กดการ์ดสถานะแล้วกรองสถานะนั้น', (tester) async {
      expect(
        await pickFrom(tester, RepairStatus.inProgress.label),
        RepairStatus.inProgress,
      );
    });

    testWidgets('กดการ์ดใบทั้งหมดแล้วเลิกกรอง', (tester) async {
      expect(await pickFrom(tester, 'ใบทั้งหมด'), isNull);
    });
  });

  group('การ์ดทางลัด', () {
    testWidgets('มีชื่อกำกับ ไม่ใช่ไอคอนเปล่า', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RepairShortcuts(onAssets: () {})),
        ),
      );

      expect(find.text('ทะเบียนเครื่อง'), findsOneWidget);
      // ถามบอทย้ายไปเป็นปุ่มลอยของหน้าแล้ว ไม่ใช่การ์ดตรงนี้
      expect(find.text('ถามบอท'), findsNothing);
    });

    testWidgets('กดแล้วเปิดทะเบียนเครื่อง', (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RepairShortcuts(onAssets: () => taps++)),
        ),
      );

      await tester.tap(find.text('ทะเบียนเครื่อง'));
      await tester.pump();

      expect(taps, 1);
    });
  });
}
