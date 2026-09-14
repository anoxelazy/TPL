import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/repair/repair_api.dart';
import 'package:claim/page/repair/repair_form_page.dart';

void main() {
  group('ฟอร์มแจ้งซ่อม: บังคับเลือกเครื่องจากทะเบียน', () {
    testWidgets('เปิดมายังไม่มีเครื่อง ต้องชวนให้ไปเลือกจากทะเบียน', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: RepairFormPage()));
      await tester.pump();

      expect(find.text('เลือกเครื่องจากทะเบียน'), findsOneWidget);
      expect(
        find.text('แจ้งซ่อมได้เฉพาะเครื่องที่อยู่ในทะเบียน'),
        findsOneWidget,
      );
    });

    testWidgets('ไม่มีช่องให้พิมพ์ชื่อเครื่องหรือ S/N เองแล้ว', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RepairFormPage()));
      await tester.pump();

      // เหลือช่องพิมพ์เดียวคืออาการเสีย
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('ชื่อเครื่อง'), findsNothing);
      expect(find.text('S/N หรือรหัสเครื่อง'), findsNothing);
    });

    testWidgets('ยังไม่เลือกเครื่อง ปุ่มส่งต้องกดไม่ได้ แม้กรอกอาการแล้ว', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: RepairFormPage()));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'เปิดไม่ติด');
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      expect(find.text('ส่งใบแจ้งซ่อม'), findsOneWidget);
      final send = tester
          .widgetList<FilledButton>(
            find.byWidgetPredicate((w) => w is FilledButton),
          )
          .single;
      expect(send.onPressed, isNull);
    });
  });

  group('createRepair: กันใบที่ผูกเครื่องไม่ได้', () {
    test('เครื่องไม่มี S/N ต้องไม่ยิง API และบอกให้แจ้ง IT', () async {
      const noSn = RepairAsset(id: 1, assetCode: 'IT-001', brand: 'Dell');

      await expectLater(
        createRepair(
          asset: noSn,
          issueDescription: 'เปิดไม่ติด',
          requesterName: 'ทดสอบ',
          branch: 'BKK10',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('ยังไม่มี S/N'),
          ),
        ),
      );
    });
  });

  group('snFromScannedCode', () {
    test('QR ที่เป็น URL ดึง sn ออกมาได้', () {
      expect(
        snFromScannedCode('https://tpl.example/asset?sn=ABC123&x=1'),
        'ABC123',
      );
    });

    test('บาร์โค้ดที่เป็น S/N ตรง ๆ ใช้ค่าเดิม', () {
      expect(snFromScannedCode('  ABC123  '), 'ABC123');
    });

    test('URL ที่ไม่มี sn คืนค่าเดิม ไม่ throw', () {
      expect(
        snFromScannedCode('https://tpl.example/asset?id=9'),
        'https://tpl.example/asset?id=9',
      );
    });
  });

  group('RepairAsset.displayName', () {
    test('ใช้ยี่ห้อกับรุ่นก่อน', () {
      const asset = RepairAsset(brand: 'Dell', model: 'OptiPlex 3080');
      expect(asset.displayName, 'Dell OptiPlex 3080');
    });

    test('ไม่มียี่ห้อ/รุ่น ไล่ไปใช้ประเภท แล้วรหัส แล้ว S/N', () {
      expect(const RepairAsset(deviceType: 'Notebook').displayName, 'Notebook');
      expect(const RepairAsset(assetCode: 'IT-001').displayName, 'IT-001');
      expect(const RepairAsset(sn: 'SN-9').displayName, 'SN-9');
    });
  });
}
