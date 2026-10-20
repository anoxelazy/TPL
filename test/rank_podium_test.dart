import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/dashboard/rank_podium_card.dart';
import 'package:claim/utils/rank_service.dart';
import 'package:claim/widgets/rank_medal.dart';

RankEntry _entry(int rank, String name, {String empId = '', int reports = 0}) =>
    RankEntry(
      empId: empId.isEmpty ? 'E$rank' : empId,
      name: name,
      rank: rank,
      reports: reports,
      images: 0,
    );

Future<void> _pump(WidgetTester tester, List<RankEntry> entries) async {
  RankService.I.board.value = entries.isEmpty
      ? null
      : RankBoard(period: 'กันยายน 2569', entries: entries);

  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: RankPodiumCard())),
  );

  // เหรียญหน่วงก่อนเริ่มเล่นตามอันดับ เดินนาฬิกาให้พ้นตัวที่หน่วงนานสุดก่อน
  // ไม่งั้น timer ค้างอยู่ตอนจบเทสต์
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => RankService.I.board.value = null);

  group('โพเดียมอันดับบนหน้าหลัก', () {
    testWidgets('ยังไม่มีตาราง ไม่กินที่บนหน้าหลักเลย', (tester) async {
      await _pump(tester, const []);

      expect(find.byType(RankMedal), findsNothing);
      expect(
        find.text('ตารางอันดับผู้ส่งบันทึกสินค้าเสียหายสูญหาย'),
        findsNothing,
      );
    });

    testWidgets('โชว์สามอันดับแรกพร้อมรอบที่สำรวจ', (tester) async {
      await _pump(tester, [
        _entry(1, 'สมชาย ใจดี', reports: 12),
        _entry(2, 'สมหญิง รักงาน', reports: 9),
        _entry(3, 'มานะ อดทน', reports: 7),
      ]);

      expect(
        find.text('ตารางอันดับผู้ส่งบันทึกสินค้าเสียหายสูญหาย'),
        findsOneWidget,
      );
      expect(find.text('รอบ กันยายน 2569'), findsOneWidget);
      expect(find.byType(RankMedal), findsNWidgets(3));
      expect(find.text('12 บันทึก'), findsOneWidget);
    });

    testWidgets('โชว์ชื่อต้นอย่างเดียว ชื่อเต็มไปดูในตาราง', (tester) async {
      await _pump(tester, [_entry(1, 'สมชาย ใจดี', reports: 3)]);

      expect(find.text('สมชาย'), findsOneWidget);
      expect(find.text('สมชาย ใจดี'), findsNothing);
    });

    testWidgets('มีคนเดียวก็ยังขึ้นได้ ไม่พังเพราะขาดที่ 2 กับ 3', (
      tester,
    ) async {
      await _pump(tester, [_entry(1, 'สมชาย ใจดี', reports: 3)]);

      expect(find.byType(RankMedal), findsOneWidget);
    });

    testWidgets('ตารางที่ไม่มีอันดับ 1 คนที่ 2 ต้องไม่โผล่สองแท่น', (
      tester,
    ) async {
      await _pump(tester, [_entry(2, 'สมหญิง รักงาน', reports: 5)]);

      // แท่นกลางว่างไว้ ไม่ใช่ยกคนแรกที่มีในตารางไปวางแทนอันดับ 1
      expect(find.text('สมหญิง'), findsOneWidget);
      expect(find.byType(RankMedal), findsOneWidget);
    });
  });
}
