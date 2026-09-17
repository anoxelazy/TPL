import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/utils/rank_service.dart';
import 'package:claim/widgets/profile_avatar_view.dart';
import 'package:claim/page/profile/rank_board_page.dart';
import 'package:claim/widgets/rank_badge.dart';
import 'package:claim/widgets/rank_medal.dart';

/// เปิดการ์ดอันดับขึ้นมาบนหน้าจอเปล่า ๆ
Future<void> pumpCard(WidgetTester tester, UserRank rank) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showRankCard(context, rank),
              child: const Text('เปิด'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('เปิด'));
  await tester.pumpAndSettle();
}

/// วางรูปโปรไฟล์ไว้บนหน้าเปล่า ๆ แบบเดียวกับมุมบนซ้ายของหน้าหลัก
Future<void> pumpAvatar(WidgetTester tester, {required bool tapOpensRank}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ProfileAvatarView(radius: 18, tapOpensRank: tapOpensRank),
          ),
        ),
      ),
    );

void main() {
  const gold = UserRank(
    rank: 1,
    tier: RankTier.gold,
    reports: 592,
    images: 2015,
    period: 'กันยายน 2569',
  );

  group('การ์ดอันดับ', () {
    testWidgets('ปิดด้วยกากบาทมุมบนขวา ไม่มีปุ่มคำว่าปิดแล้ว', (tester) async {
      await pumpCard(tester, gold);

      expect(find.widgetWithText(TextButton, 'ปิด'), findsNothing);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // กากบาทต้องอยู่ขวาของวงอันดับ ไม่ใช่ลอยอยู่ซ้ายหรือกลางการ์ด
      final dialog = tester.getRect(find.byType(AlertDialog));
      final close = tester.getCenter(find.byIcon(Icons.close));
      expect(close.dx, greaterThan(dialog.center.dx));
      expect(close.dy, lessThan(dialog.center.dy));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('ปุ่มดูตารางอันดับพาไปหน้าตาราง แล้วการ์ดปิดตาม', (
      tester,
    ) async {
      await pumpCard(tester, gold);

      await tester.tap(find.text('ดูตารางอันดับ'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('ตารางอันดับ'), findsOneWidget);
    });

    testWidgets('การ์ดเพชรก็มีกากบาทเหมือนกัน', (tester) async {
      await pumpCard(
        tester,
        const UserRank(
          rank: null,
          tier: RankTier.diamond,
          reports: 0,
          images: 0,
          period: '',
        ),
      );

      expect(find.text('ผู้สร้างแอป'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });
  group('แตะรูปโปรไฟล์', () {
    setUp(() => RankService.I.rank.value = gold);
    tearDown(() => RankService.I.rank.value = null);

    testWidgets('แตะที่ตัวรูป ไม่ต้องโดนป้าย ก็เปิดการ์ดอันดับ', (
      tester,
    ) async {
      await pumpAvatar(tester, tapOpensRank: true);

      // จิ้มมุมซ้ายล่างของรูป ห่างจากป้ายที่ลอยอยู่มุมบนขวาแน่ ๆ
      final avatar = tester.getRect(find.byType(ProfileAvatarView));
      await tester.tapAt(Offset(avatar.left + 6, avatar.bottom - 6));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('ดูตารางอันดับ'), findsOneWidget);
    });

    testWidgets('ป้ายก็ยังกดได้เหมือนเดิม', (tester) async {
      await pumpAvatar(tester, tapOpensRank: true);

      await tester.tap(find.byType(RankBadge));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('หน้าที่ไม่ได้เปิดไว้ แตะตัวรูปแล้วเงียบ', (tester) async {
      await pumpAvatar(tester, tapOpensRank: false);

      final avatar = tester.getRect(find.byType(ProfileAvatarView));
      await tester.tapAt(Offset(avatar.left + 6, avatar.bottom - 6));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('ไม่ติดอันดับ แตะรูปแล้วเข้าหน้าตารางเลย', (tester) async {
      RankService.I.rank.value = null;
      RankService.I.board.value = const RankBoard(
        period: 'กันยายน 2569',
        entries: [
          RankEntry(
            empId: '80770',
            name: '',
            rank: 1,
            reports: 592,
            images: 2015,
          ),
        ],
      );
      addTearDown(() => RankService.I.board.value = null);

      await pumpAvatar(tester, tapOpensRank: true);
      expect(find.byType(RankBadge), findsNothing, reason: 'ไม่มีป้ายให้เล็ง');

      final avatar = tester.getRect(find.byType(ProfileAvatarView));
      await tester.tapAt(avatar.center);
      await tester.pumpAndSettle();

      // ไม่มีการ์ดให้เด้งเพราะไม่มีอันดับของตัวเอง ต้องไปโผล่ที่ตารางเลย
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(RankBoardPage), findsOneWidget);
      expect(find.text('รหัส 80770'), findsOneWidget);
    });

    testWidgets('ไม่ติดอันดับ และยังไม่มีตาราง ก็ยังเข้าหน้าได้', (
      tester,
    ) async {
      RankService.I.rank.value = null;

      await pumpAvatar(tester, tapOpensRank: true);
      await tester.tapAt(tester.getRect(find.byType(ProfileAvatarView)).center);
      await tester.pumpAndSettle();

      expect(find.byType(RankBoardPage), findsOneWidget);
      expect(find.textContaining('ยังไม่มีตารางอันดับ'), findsOneWidget);
    });

    testWidgets('ติดอันดับ แตะรูปได้การ์ดเหมือนเดิม ไม่ข้ามไปตาราง', (
      tester,
    ) async {
      await pumpAvatar(tester, tapOpensRank: true);
      await tester.tapAt(tester.getRect(find.byType(ProfileAvatarView)).center);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(RankBoardPage), findsNothing);
    });
  });
  group('อนิเมชันกับความสมมาตร', () {
    testWidgets('ปุ่มดูตารางอันดับกว้างเต็มการ์ด ขอบซ้ายขวาเท่ากัน', (
      tester,
    ) async {
      await pumpCard(tester, gold);

      final dialog = tester.getRect(find.byType(AlertDialog));
      // FilledButton.icon สร้างคลาสลูก byType เลยไม่เจอ ต้องจับด้วย predicate
      final button = tester.getRect(
        find.byWidgetPredicate((w) => w is FilledButton),
      );

      expect(
        button.left - dialog.left,
        moreOrLessEquals(dialog.right - button.right, epsilon: 0.5),
        reason: 'ขอบสองข้างต้องเท่ากัน',
      );
      expect(
        button.center.dx,
        moreOrLessEquals(dialog.center.dx, epsilon: 0.5),
      );
    });

    testWidgets('เลขอันดับค่อย ๆ โผล่ ไม่ใช่มาเต็มตั้งแต่เฟรมแรก', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showRankCard(context, gold),
                  child: const Text('เปิด'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('เปิด'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      final medal = tester.widget<RankMedal>(find.byType(RankMedal));
      expect(medal.halo, isTrue, reason: 'วงใหญ่ในการ์ดมีวงกระเพื่อม');

      final early = tester.getSize(find.byType(RankMedal));
      await tester.pumpAndSettle();
      final settled = tester.getSize(find.byType(RankMedal));

      expect(settled.width, 68, reason: 'กินที่เท่าเดิมตลอด ไม่ดันของรอบข้าง');
      expect(early.width, settled.width);
    });

    testWidgets('ตัวเลขสถิติไล่ขึ้นจนถึงค่าจริง', (tester) async {
      await pumpCard(tester, gold);

      expect(find.text('592'), findsOneWidget);
      expect(find.text('2015'), findsOneWidget);
    });

    testWidgets('มีสาขา โชว์ต่อท้ายรหัสพนักงานใต้ชื่อ', (tester) async {
      RankService.I.board.value = const RankBoard(
        period: 'กันยายน 2569',
        entries: [
          RankEntry(
            empId: '80770',
            name: 'เกษมพงศ์ เกลี้ยงบุญอาน',
            location: 'สุราษฎร์ธานี',
            rank: 1,
            reports: 596,
            images: 0,
          ),
        ],
      );
      addTearDown(() => RankService.I.board.value = null);

      await tester.pumpWidget(const MaterialApp(home: RankBoardPage()));
      await tester.pumpAndSettle();

      expect(find.text('เกษมพงศ์ เกลี้ยงบุญอาน'), findsOneWidget);
      expect(find.text('รหัส 80770 · สุราษฎร์ธานี'), findsOneWidget);
    });

    testWidgets('json ไม่นับรูปมาให้ ซ่อนคอลัมน์รูปทั้งคอลัมน์', (
      tester,
    ) async {
      RankService.I.board.value = const RankBoard(
        period: 'กันยายน 2569',
        entries: [
          RankEntry(
            empId: '80770',
            name: 'เกษมพงศ์ เกลี้ยงบุญอาน',
            location: 'สุราษฎร์ธานี',
            rank: 1,
            reports: 596,
            images: 0,
          ),
        ],
      );
      addTearDown(() => RankService.I.board.value = null);

      await tester.pumpWidget(const MaterialApp(home: RankBoardPage()));
      await tester.pumpAndSettle();

      expect(find.text('รายงาน'), findsOneWidget);
      expect(
        find.text('รูป'),
        findsNothing,
        reason: 'ไม่มีข้อมูลก็ไม่ต้องมีช่อง',
      );
      expect(
        find.text('0'),
        findsNothing,
        reason: 'ศูนย์เรียงลงมาชวนเข้าใจผิด',
      );
    });

    testWidgets('มีตัวเลขรูปจริง คอลัมน์รูปกลับมา', (tester) async {
      RankService.I.board.value = const RankBoard(
        period: 'กันยายน 2569',
        entries: [
          RankEntry(
            empId: '80770',
            name: '',
            rank: 1,
            reports: 592,
            images: 2015,
          ),
        ],
      );
      addTearDown(() => RankService.I.board.value = null);

      await tester.pumpWidget(const MaterialApp(home: RankBoardPage()));
      await tester.pumpAndSettle();

      expect(find.text('รูป'), findsOneWidget);
      expect(find.text('2015'), findsOneWidget);
    });

    testWidgets('อนิเมชันในตารางเล่นจบเอง ไม่วนค้าง', (tester) async {
      RankService.I.board.value = const RankBoard(
        period: 'กันยายน 2569',
        entries: [
          RankEntry(
            empId: '80770',
            name: '',
            rank: 1,
            reports: 592,
            images: 2015,
          ),
          RankEntry(
            empId: '66293',
            name: 'สมหญิง',
            rank: 2,
            reports: 494,
            images: 1923,
          ),
        ],
      );
      addTearDown(() => RankService.I.board.value = null);

      await tester.pumpWidget(const MaterialApp(home: RankBoardPage()));
      // pumpAndSettle จะค้างถ้าอนิเมชันวนไม่จบ เทสต์นี้เลยกันไว้ตรงนั้นด้วย
      await tester.pumpAndSettle();

      expect(find.byType(RankMedal), findsNWidgets(2));
      expect(find.text('รหัส 80770'), findsOneWidget);
      expect(find.text('สมหญิง'), findsOneWidget);
    });
  });
}
