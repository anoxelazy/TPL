import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:claim/page/repair/repair_api.dart';
import 'package:claim/page/repair/repair_card.dart';
import 'package:claim/page/repair/repair_style.dart';

RepairTicket _ticket({
  int? id = 28,
  String deviceName = 'DELL Optiplex 3010',
  String issue = 'จอไม่ติด เปิดไม่ขึ้น',
  String branch = 'ลาดกระบัง',
  String requester = 'สมชาย',
  String technician = '',
  String sn = '6YZ46Z1',
  DateTime? createdAt,
  DateTime? completedAt,
  RepairStatus status = RepairStatus.pending,
}) => RepairTicket(
  id: id,
  assetId: 1,
  assetCode: 'A-1',
  sn: sn,
  branch: branch,
  deviceName: deviceName,
  issueDescription: issue,
  requesterName: requester,
  approverName: '',
  technicianName: technician,
  note: '',
  status: status,
  createdAt: createdAt,
  completedAt: completedAt,
);

Future<void> _pump(WidgetTester tester, RepairTicket ticket) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RepairTicketCard(ticket: ticket, onTap: () {}),
      ),
    ),
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('th', null));

  group('วันที่บนการ์ด', () {
    test('เขียนเป็น พ.ศ. สองหลักเหมือนหน้าเว็บ', () {
      expect(repairDateLabel(DateTime(2026, 9, 21)), '21 ก.ย. 69');
    });

    test('ปีที่ลงท้ายด้วยศูนย์ต้องไม่หายไปหนึ่งหลัก', () {
      // พ.ศ. 2600 -> "00" ไม่ใช่ "0"
      expect(repairDateLabel(DateTime(2057, 1, 5)), '5 ม.ค. 00');
    });
  });

  group('การ์ดใบแจ้งซ่อม', () {
    testWidgets('ชั้นบนเป็นเลขที่ใบกับวันที่แจ้ง', (tester) async {
      await _pump(tester, _ticket(createdAt: DateTime(2026, 9, 21)));

      expect(find.text('#TK-28'), findsOneWidget);
      expect(find.text('แจ้งเมื่อ 21 ก.ย. 69'), findsOneWidget);
    });

    testWidgets('ปิดงานแล้วมีวันที่เสร็จใต้ป้ายสถานะ', (tester) async {
      await _pump(
        tester,
        _ticket(
          status: RepairStatus.completed,
          createdAt: DateTime(2026, 9, 21),
          completedAt: DateTime(2026, 9, 22),
        ),
      );

      expect(find.text('เสร็จ 22 ก.ย. 69'), findsOneWidget);
      expect(find.text('ปิดงานแล้ว'), findsOneWidget);
    });

    testWidgets('ยังไม่ปิดงานก็ไม่มีบรรทัดวันที่เสร็จ', (tester) async {
      await _pump(tester, _ticket(createdAt: DateTime(2026, 9, 21)));

      expect(find.textContaining('เสร็จ'), findsNothing);
    });

    testWidgets('ชั้นล่างเป็นเครื่องกับอาการ', (tester) async {
      await _pump(tester, _ticket());

      expect(find.text('DELL Optiplex 3010'), findsOneWidget);
      expect(find.text('6YZ46Z1'), findsOneWidget);
      expect(find.text('จอไม่ติด เปิดไม่ขึ้น'), findsOneWidget);
    });

    testWidgets('ชิปมีเฉพาะช่องที่มีข้อมูล', (tester) async {
      await _pump(tester, _ticket(technician: ''));

      expect(find.byType(RepairInfoChip), findsNWidgets(2));
      expect(find.text('ลาดกระบัง'), findsOneWidget);
      expect(find.text('สมชาย'), findsOneWidget);
    });

    testWidgets('รับงานแล้วมีชิปช่างเพิ่มมา', (tester) async {
      await _pump(
        tester,
        _ticket(technician: 'อนุชา', status: RepairStatus.inProgress),
      );

      expect(find.byType(RepairInfoChip), findsNWidgets(3));
      expect(find.text('อนุชา'), findsOneWidget);
    });

    testWidgets('ใบที่ไม่มี id ถอยไปใช้ชื่อเครื่องแทนเลขที่ใบ', (tester) async {
      await _pump(tester, _ticket(id: null));

      expect(find.textContaining('#TK-'), findsNothing);
      // ชื่อเครื่องโผล่สองที่: หัวการ์ดแทนเลขที่ใบ และชั้นล่างตามปกติ
      expect(find.text('DELL Optiplex 3010'), findsNWidgets(2));
    });
  });
}
