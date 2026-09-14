import 'dart:convert';

import 'package:claim/page/plan/plan_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// ข้อมูลจริงที่ /api/GetPlanJob ตอบกลับมาสำหรับ driverId 11260
const String _planResponse =
    '[{"driverid":"11260","typejobid":"2",'
    '"trucksendid":"BB1418XBKK08X26090884220",'
    '"BillRemain":11,"BillSuccess":5,"BillFail":0,"BillTotal":16,'
    '"COD":0.0,"PriceDelivery":0.0000,"DatePlan":"2026-09-08T00:00:00"}]';

void main() {
  test('แปลง response ของ GetPlanJob ได้ครบทุกฟิลด์', () {
    final decoded = jsonDecode(_planResponse) as List;
    final plans = decoded
        .whereType<Map>()
        .map((e) => PlanJobItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    expect(plans, hasLength(1));

    final plan = plans.first;
    expect(plan.driverId, '11260');
    expect(plan.truckSendId, 'BB1418XBKK08X26090884220');
    expect(plan.billTotal, 16);
    expect(plan.billSuccess, 5);
    expect(plan.billRemain, 11);
    expect(plan.billFail, 0);
    expect(plan.cod, 0);
    expect(plan.priceDelivery, 0);
    expect(plan.totalCollect, 0);
    expect(plan.datePlan, DateTime(2026, 9, 8));
  });

  test('สถานะบิลอ่านจาก Status_Online', () {
    BillItem bill(dynamic statusOnline) =>
        BillItem.fromJson({'A1': 'X', 'Status_Online': statusOnline});

    expect(bill('1').status, BillStatus.success);
    expect(bill(null).status, BillStatus.remaining);
    expect(bill('').status, BillStatus.remaining);
    expect(bill('2').status, BillStatus.failed);
  });
}
