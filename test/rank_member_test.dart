import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/utils/rank_service.dart';
import 'package:claim/widgets/rank_badge.dart';
import 'package:claim/widgets/rank_medal.dart';

const _member = UserRank(
  rank: null,
  tier: RankTier.member,
  reports: 0,
  images: 0,
  period: 'กันยายน 2569',
);

const _top10 = UserRank(
  rank: 7,
  tier: RankTier.top10,
  reports: 30,
  images: 40,
  period: 'กันยายน 2569',
);

void main() {
  group('ยศผู้ใช้งานทั่วไป', () {
    test('ชื่อยศไม่มีเลขอันดับต่อท้าย', () {
      expect(_member.title, 'ผู้ใช้งานทั่วไป');
      expect(_member.isMember, isTrue);
      expect(_member.isDiamond, isFalse);
    });

    test('คนที่ติดอันดับไม่ถูกเหมารวมเป็นผู้ใช้งานทั่วไป', () {
      expect(_top10.isMember, isFalse);
      expect(_top10.title, contains('อันดับ 7'));
    });

    test('แถวในตารางอันดับไม่ใช้ยศนี้', () {
      // ตารางเก็บสิบแถว ทุกแถวติดอันดับหมด ยศนี้จึงไม่ควรโผล่ในตาราง
      const entry = RankEntry(
        empId: 'E1',
        name: 'ทดสอบ',
        rank: 11,
        reports: 1,
        images: 1,
      );

      expect(entry.tier, isNull);
    });
  });

  group('ป้ายบนรูปโปรไฟล์', () {
    Future<void> pumpBadge(WidgetTester tester, UserRank rank) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: RankBadge(rank: rank, avatarRadius: 18)),
          ),
        );

    testWidgets('ผู้ใช้งานทั่วไปไม่ติดป้าย', (tester) async {
      await pumpBadge(tester, _member);

      // ป้ายที่เกือบทุกคนมีเหมือนกันหมดไม่ได้บอกอะไร เลยไม่ต้องวาด
      expect(find.byType(Container), findsNothing);
      expect(find.text('null'), findsNothing);
    });

    testWidgets('คนที่ติดอันดับยังมีป้ายเลขเหมือนเดิม', (tester) async {
      await pumpBadge(tester, _top10);

      expect(find.text('7'), findsOneWidget);
    });
  });

  group('การ์ดตอนกดรูป', () {
    testWidgets('ผู้ใช้งานทั่วไปเห็นการ์ดบอกยศ ไม่มีเลขอันดับ', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showRankCard(context, _member),
                child: const Text('เปิด'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('เปิด'));
      await tester.pumpAndSettle();

      expect(find.text('ผู้ใช้งานทั่วไป'), findsOneWidget);
      expect(find.byType(RankMedal), findsOneWidget);
      // เหรียญต้องเป็นไอคอนคน ไม่ใช่ตัวหนังสือ null
      expect(find.text('null'), findsNothing);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      // ยอดเป็นศูนย์เพราะไม่รู้ ไม่ใช่เพราะส่งศูนย์ใบ จึงไม่ต้องโชว์
      expect(find.text('จำนวนรายงาน'), findsNothing);
      // ยังกดไปดูตารางเต็มได้
      expect(find.text('ดูตารางอันดับ'), findsOneWidget);
    });
  });
}
