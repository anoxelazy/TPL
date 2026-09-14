import 'package:claim/page/stock/stock_api.dart';
import 'package:claim/page/stock/stock_detail_page.dart';
import 'package:claim/widgets/donut_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 1 แถวของ /api/Bill_Stock ตามรูปที่ endpoint ตอบกลับ
BillStockItem billItem({
  String? jobStatusId,
  String? statusName,
  Map<String, dynamic> extra = const {},
}) => BillStockItem({
  'bill_code': 'HVR012609071881',
  'jobstatusid': jobStatusId,
  'statusName': statusName,
  'customerName': 'จอย (C301205502)',
  'qty': 2,
  ...extra,
});

void main() {
  // mapping ตัวจริงโหลดจาก status.json ระยะไกล ในเทสต์ต้องใส่ให้เอง
  setUp(() {
    setJobStatusStagesForTest({
      '3': ShipmentStage.warehouse,
      '6-1': ShipmentStage.parked,
    });
  });

  group('ค้นหาในหน้าคลัง', () {
    // ช่องค้นหาใช้ searchIndex ที่รวมทุกค่าในแถวมาต่อกัน
    final items = [
      BillStockItem({
        'bill_code': 'HVR012609071881',
        'customerName': 'จอย (C301205502)',
        'jobstatusid': '3',
      }),
      BillStockItem({
        'bill_code': 'SAL012609070101',
        'customerName': 'ฮัต',
        'jobstatusid': '6-1',
      }),
    ];

    List<BillStockItem> search(String keyword) {
      final query = keyword.trim().toLowerCase();
      return items
          .where((item) => query.isEmpty || item.searchIndex.contains(query))
          .toList();
    }

    test('ค้นด้วยเลขบิลบางส่วน', () {
      final found = search('188');
      expect(found, hasLength(1));
      expect(found.first.billCode, 'HVR012609071881');
    });

    test('ค้นด้วยชื่อลูกค้า', () {
      expect(search('จอย'), hasLength(1));
    });

    test('ค้นด้วยตัวพิมพ์เล็กก็เจอ', () {
      expect(search('hvr'), hasLength(1));
    });

    test('คำค้นว่างคืนทุกแถว', () {
      expect(search('   '), hasLength(2));
    });

    test('ไม่ตรงคืนลิสต์ว่าง', () {
      expect(search('ไม่มีบิลนี้'), isEmpty);
    });
  });

  testWidgets('DonutChart วาดได้ในกล่องที่ความสูงไม่จำกัด', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              DonutChart(
                centerTop: '16',
                centerBottom: 'รายการ',
                hideEmpty: true,
                slices: [
                  DonutSlice(
                    label: 'อยู่ที่คลัง',
                    value: 10,
                    color: Colors.green,
                  ),
                  DonutSlice(label: 'พักสินค้า', value: 6, color: Colors.amber),
                  DonutSlice(
                    label: 'ตีกลับสินค้า',
                    value: 0,
                    color: Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('16'), findsOneWidget);
    expect(find.text('อยู่ที่คลัง'), findsOneWidget);
    // hideEmpty ตัดส่วนที่เป็น 0 ออกจากคำอธิบาย
    expect(find.text('ตีกลับสินค้า'), findsNothing);
    expect(find.text('63%'), findsOneWidget);
  });

  testWidgets('DonutChart ที่ยังไม่มีข้อมูลไม่พัง', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DonutChart(
            centerTop: '-',
            centerBottom: 'รายการ',
            slices: [
              DonutSlice(label: 'อยู่ที่คลัง', value: 0, color: Colors.green),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('หน้าพักสถานะแสดงข้อมูลบิลและปุ่มบันทึก', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StockDetailPage(item: billItem(jobStatusId: '3')),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('HVR012609071881'), findsOneWidget);
    expect(find.text('บันทึกพักสถานะ'), findsOneWidget);
    expect(
      find.text('ใช้เมื่อสินค้าค้างในคลัง ยังไม่เข้าคิวจัดส่ง'),
      findsOneWidget,
    );
  });

  group('บิลที่พักสถานะไว้แล้ว', () {
    testWidgets('ปุ่มพักสถานะต้องไม่มีให้กด', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StockDetailPage(item: billItem(jobStatusId: '6-1')),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.text('รายการนี้พักสถานะอยู่แล้ว พักซ้ำไม่ได้'),
        findsOneWidget,
      );
      expect(find.text('พักสถานะแล้ว'), findsOneWidget);
      // ทั้งปุ่มและช่องเหตุผลต้องหายไป ไม่ใช่แค่กดไม่ได้
      expect(find.text('บันทึกพักสถานะ'), findsNothing);
      expect(find.text('เลือกเหตุผล'), findsNothing);
    });

    testWidgets('status.json โหลดไม่ได้ ก็ยังกันพักซ้ำจากชื่อสถานะ', (
      tester,
    ) async {
      // จำลองว่า mapping ว่าง (เน็ตล่ม/ไม่มี cache) stage จะเป็น null
      setJobStatusStagesForTest(const {});

      await tester.pumpWidget(
        MaterialApp(
          home: StockDetailPage(
            item: billItem(jobStatusId: '6-1', statusName: 'พักสินค้า'),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('บันทึกพักสถานะ'), findsNothing);
    });
  });

  group('isParked', () {
    test('อ่านจาก stage เมื่อ mapping มีข้อมูล', () {
      expect(billItem(jobStatusId: '6-1').isParked, isTrue);
      expect(billItem(jobStatusId: '3').isParked, isFalse);
    });

    test('mapping ว่าง ให้ใช้ชื่อสถานะจาก API แทน', () {
      setJobStatusStagesForTest(const {});

      expect(billItem(statusName: 'พักสินค้า').isParked, isTrue);
      expect(billItem(statusName: 'อยู่ที่คลัง').isParked, isFalse);
      // ไม่มีทั้ง stage และชื่อสถานะ ต้องไม่เดาว่าพักอยู่ ไม่งั้นพักไม่ได้เลย
      expect(billItem().isParked, isFalse);
    });

    test('stage ที่รู้จักแล้วมีน้ำหนักกว่าชื่อสถานะ', () {
      // stage บอกว่าอยู่ที่คลัง แม้ชื่อสถานะจะมีคำว่าพัก ก็ยังพักได้
      expect(
        billItem(jobStatusId: '3', statusName: 'รอพักสถานะ').isParked,
        isFalse,
      );
    });
  });

  group('ข้อมูลลูกค้าในหน้ารายละเอียด', () {
    testWidgets('แสดงชื่อ เบอร์ และที่อยู่ที่ API ส่งมา', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StockDetailPage(
            item: billItem(
              jobStatusId: '3',
              extra: const {
                'tel': '081-234-5678',
                'address': '99/1 ถ.สุขุมวิท กรุงเทพฯ 10110',
              },
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('ข้อมูลลูกค้า'), findsOneWidget);
      expect(find.text('จอย (C301205502)'), findsOneWidget);
      expect(find.text('081-234-5678'), findsOneWidget);
      expect(find.text('99/1 ถ.สุขุมวิท กรุงเทพฯ 10110'), findsOneWidget);
      expect(find.text('โทร'), findsOneWidget);
    });

    testWidgets('ฟิลด์ที่ API ไม่ส่งมาต้องไม่ขึ้นแถวว่าง', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StockDetailPage(item: billItem(jobStatusId: '3')),
        ),
      );

      expect(tester.takeException(), isNull);
      // แถวนี้มีแต่ชื่อลูกค้า ไม่มีเบอร์ให้โทร
      expect(find.text('ข้อมูลลูกค้า'), findsOneWidget);
      expect(find.text('โทร'), findsNothing);
    });

    test('hasCustomerInfo เป็น false เมื่อไม่มีข้อมูลลูกค้าเลย', () {
      final bare = BillStockItem({'bill_code': 'X', 'qty': 1});
      expect(bare.hasCustomerInfo, isFalse);
      expect(billItem().hasCustomerInfo, isTrue);
    });
  });
}
