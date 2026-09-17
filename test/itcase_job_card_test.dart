import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:claim/page/itcase/itcase_api.dart';
import 'package:claim/page/itcase/itcase_job_card.dart';
import 'package:claim/utils/app_colors.dart';

const List<ItCaseStatus> _statuses = [
  ItCaseStatus(
    id: 'IN',
    informer: 'อยู่ระหว่างดำเนินการแก้ไขปัญหา',
    officer: 'กำลังดำเนินการ',
  ),
];

Future<void> _pumpCard(WidgetTester tester, ItCaseJob job) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ItCaseJobCard(job: job, statuses: _statuses),
      ),
    ),
  );
}

void main() {
  // การ์ดโชว์วันที่ด้วย DateFormat ภาษาไทย ไม่โหลดไว้ก่อนจะโยนตั้งแต่ pump
  setUpAll(() => initializeDateFormatting('th', null));

  testWidgets('โชว์ครบห้าอย่างที่ตกลงกันไว้', (tester) async {
    await _pumpCard(
      tester,
      ItCaseJob.fromJson(const {
        'job_id': 'IT2026106446',
        'job_status': 'IN',
        'job_description': 'เข้าโปรแกรมไม่ได้',
        'create_date': '15-09-2026 23:11',
        'receive_by': 'ทักษิณ โพงจ่าม',
      }),
    );

    expect(find.text('IT2026106446'), findsOneWidget);
    expect(find.text('อยู่ระหว่างดำเนินการแก้ไขปัญหา'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('เข้าโปรแกรมไม่ได้'), findsOneWidget);
    expect(find.text('ทักษิณ โพงจ่าม'), findsOneWidget);
    expect(find.text('15 ก.ย. 2026 23:11'), findsOneWidget);
  });

  testWidgets('ช่องอื่นไม่โผล่บนการ์ด ไปดูในหน้ารายละเอียดเอา', (tester) async {
    await _pumpCard(
      tester,
      ItCaseJob.fromJson(const {
        'job_id': 'IT2026106446',
        'job_status': 'IN',
        'job_s_details_o': 'กำลังดำเนินการ',
        'branch': 'สำนักงานใหญ่',
        'job_type': 'S002',
      }),
    );

    expect(find.textContaining('สำนักงานใหญ่'), findsNothing);
    expect(find.textContaining('S002'), findsNothing);
    expect(
      find.textContaining('กำลังดำเนินการ'),
      findsNothing,
      reason: 'ข้อความฝั่ง IT ไม่ใช่ของผู้แจ้ง',
    );
  });

  testWidgets('job_s_details_i คือข้อความสถานะที่ผู้แจ้งเห็น', (tester) async {
    await _pumpCard(
      tester,
      ItCaseJob.fromJson(const {
        'job_id': 'IT2026106446',
        'job_status': 'FN',
        'job_s_details_i': 'แก้ไขเสร็จสิ้น กรุณาตรวจสอบความเรียบร้อย',
        'job_s_details_o': 'แก้ไขเสร็จสิ้น อยู่ระหว่างผู้แจ้งยืนยันปิดงาน',
      }),
    );

    expect(
      find.text('แก้ไขเสร็จสิ้น กรุณาตรวจสอบความเรียบร้อย'),
      findsOneWidget,
    );
    expect(find.text('90%'), findsOneWidget);
  });

  testWidgets('กดการ์ดแล้วเรียก onTap เพื่อไปหน้ารายละเอียด', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ItCaseJobCard(
            job: ItCaseJob.fromJson(const {'job_id': 'IT2026106446'}),
            statuses: _statuses,
            onTap: () => taps++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('IT2026106446'));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  test('สีของแต่ละขั้นแยกออกจากกัน', () {
    const scheme = ColorScheme.light();
    final colors = [
      for (final stage in ItCaseStage.values) itCaseStageColor(stage, scheme),
    ];

    expect(colors.toSet().length, ItCaseStage.values.length);
    expect(itCaseStageColor(ItCaseStage.done, scheme), AppColors.success);
    expect(itCaseStageColor(ItCaseStage.working, scheme), AppColors.pending);
  });

  group('แถบความคืบหน้า', () {
    /// วาดแถบเดี่ยว ๆ แล้วเปลี่ยน % ระหว่างทาง เลียนแบบรอบดึงข้อมูลเงียบ ๆ
    Future<void> pumpBar(WidgetTester tester, int percent) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItCaseProgressBar(
              percent: percent,
              color: AppColors.caseIcon,
            ),
          ),
        ),
      );
    }

    testWidgets('เปิดมาเห็นค่าจริงทันที ไม่ต้องรอแถบไต่จาก 0', (tester) async {
      await pumpBar(tester, 60);

      expect(find.text('60%'), findsOneWidget);
    });

    testWidgets('สถานะขยับแล้วแถบไหลไปหาค่าใหม่ ไม่กระโดด', (tester) async {
      await pumpBar(tester, 60);
      await pumpBar(tester, 90);

      // กลางทางต้องอยู่ระหว่างค่าเก่ากับค่าใหม่ ไม่ใช่ถึงที่หมายตั้งแต่เฟรมแรก
      await tester.pump(const Duration(milliseconds: 150));
      final midway = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(midway.value, greaterThan(0.6));
      expect(midway.value, lessThan(0.9));

      await tester.pumpAndSettle();
      expect(find.text('90%'), findsOneWidget);
    });

    testWidgets('รหัสสถานะที่ยังไม่รู้จัก ซ่อนแถบไปเลย', (tester) async {
      await pumpBar(tester, 0);

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  group('ปุ่มปิดงานบนการ์ด', () {
    Future<void> pumpWithClose(
      WidgetTester tester,
      String status, {
      required VoidCallback? onClose,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItCaseJobCard(
              job: ItCaseJob.fromJson({
                'job_id': 'IT2026106446',
                'job_status': status,
              }),
              statuses: _statuses,
              onClose: onClose,
            ),
          ),
        ),
      );
    }

    testWidgets('เคสที่รอเราตรวจ (FN) มีปุ่มปิดงานให้กดจากการ์ดเลย', (
      tester,
    ) async {
      var tapped = 0;
      await pumpWithClose(tester, 'FN', onClose: () => tapped++);

      expect(find.text('ปิดงาน'), findsOneWidget);

      await tester.tap(find.text('ปิดงาน'));
      expect(tapped, 1);
    });

    testWidgets('เคสที่ทีม IT ยังทำอยู่ ไม่มีปุ่มปิดงานให้กดผิด', (
      tester,
    ) async {
      await pumpWithClose(tester, 'IN', onClose: () {});

      expect(find.text('ปิดงาน'), findsNothing);
    });

    testWidgets('เคสที่ปิดไปแล้ว ไม่มีปุ่มให้ปิดซ้ำ', (tester) async {
      await pumpWithClose(tester, 'CF', onClose: () {});

      expect(find.text('ปิดงาน'), findsNothing);
    });

    testWidgets('หน้าที่ไม่รองรับการปิดงาน ไม่ส่ง onClose มาก็ไม่มีปุ่ม', (
      tester,
    ) async {
      await pumpWithClose(tester, 'FN', onClose: null);

      expect(find.text('ปิดงาน'), findsNothing);
    });
  });
}
