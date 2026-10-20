import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:claim/page/plan/route_plan_api.dart';
import 'package:claim/page/plan/route_plan_models.dart';

List<RoutePlan> _fixturePlans() =>
    parseRoutePlans(File('test/fixtures/route_plan.json').readAsStringSync());

RouteStop _stop({
  required int seq,
  double? lat,
  double? lon,
  String status = '',
  String docId = 'D1',
}) => RouteStop(
  seq: seq,
  docId: docId,
  lat: lat,
  lon: lon,
  statusOnline: status,
);

void main() {
  // rootBundle ต้องมี binding ก่อนถึงจะอ่าน asset ได้
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ที่มาของข้อมูล', () {
    test('ดึงจากไฟล์ plan.json บน repo เป็นหลัก', () {
      expect(
        kRoutePlanJsonUrl,
        'https://raw.githubusercontent.com/anoxelazy/API_json/main/plan.json',
      );
    });
  });

  group('ไฟล์ที่ติดมากับแอป', () {
    test('อ่าน asset ได้จริง ไม่ใช่ลืมใส่ใน pubspec', () async {
      // ลืมประกาศใน pubspec แล้วจะพังตอนเปิดหน้าจริงเท่านั้น ซึ่งรู้ช้าไป
      final body = await rootBundle.loadString(kRoutePlanAsset);
      final plans = parseRoutePlans(body);

      expect(plans, isNotEmpty);
      expect(plans.where((p) => p.driverId == '68148'), hasLength(2));
    });
  });

  group('อ่านไฟล์แผน', () {
    test('อ่านได้ครบทุกแผนและหัวแผนมีพิกัดคลัง', () {
      final plans = _fixturePlans();

      expect(plans, hasLength(3));

      final first = plans.first;
      expect(first.truckSendId, 'TS26092101');
      expect(first.driverId, '68148');
      expect(first.hasDepot, isTrue);
      expect(first.stops, hasLength(8));
    });

    test('ไฟล์เสียหรือว่างคืนลิสต์ว่าง ไม่ throw', () {
      expect(parseRoutePlans(null), isEmpty);
      expect(parseRoutePlans(''), isEmpty);
      expect(parseRoutePlans('ไม่ใช่ json'), isEmpty);
      expect(parseRoutePlans('{"plans": "ไม่ใช่ลิสต์"}'), isEmpty);
    });

    test('รับทั้งแบบห่อด้วย plans และแบบเป็น array ตรง ๆ', () {
      const row =
          '{"trucksendid":"T1","lat_branch":13.7,"lon_branch":100.5,"stops":[]}';

      expect(parseRoutePlans('[$row]'), hasLength(1));
      expect(parseRoutePlans('{"plans":[$row]}'), hasLength(1));
    });
  });

  group('จุดส่งที่เอาเข้าเส้นทางได้', () {
    test('พิกัดว่างหรือเป็นศูนย์ ถือว่าไม่มีพิกัด', () {
      expect(_stop(seq: 1, lat: null, lon: null).hasPoint, isFalse);
      expect(_stop(seq: 1, lat: 13.7, lon: null).hasPoint, isFalse);
      // 0,0 คือกลางมหาสมุทรแอตแลนติก ไม่ใช่บ้านลูกค้าแน่ ๆ
      expect(_stop(seq: 1, lat: 0, lon: 0).hasPoint, isFalse);
      expect(_stop(seq: 1, lat: 13.7, lon: 100.5).hasPoint, isTrue);
    });

    test('ใบที่ส่งไปแล้วไม่ต้องเอาเข้าเส้นทาง', () {
      final done = _stop(seq: 1, lat: 13.7, lon: 100.5, status: '1');

      expect(done.isDelivered, isTrue);
      expect(done.isRoutable, isFalse);
    });

    test('ใบที่ส่งที่เดียวกันนับเป็นจุดจอดเดียว', () {
      final groups = groupStopsByPoint([
        _stop(seq: 1, lat: 13.6301, lon: 100.7448, docId: 'A'),
        _stop(seq: 2, lat: 13.6301, lon: 100.7448, docId: 'B'),
        _stop(seq: 3, lat: 13.7, lon: 100.5, docId: 'C'),
      ]);

      expect(groups, hasLength(2));
      expect(groups.firstWhere((g) => g.billCount == 2).stops, hasLength(2));
    });
  });

  group('ระยะทาง', () {
    test('ละติจูดต่างกัน 1 องศา ได้ราว 111 กม.', () {
      final meters = distanceMeters(13.0, 100.0, 14.0, 100.0);

      expect(meters, closeTo(111000, 500));
    });

    test('จุดเดียวกันได้ศูนย์', () {
      expect(distanceMeters(13.7, 100.5, 13.7, 100.5), closeTo(0, 0.001));
    });

    test('ต่ำกว่าหนึ่งกิโลบอกเป็นเมตร', () {
      expect(distanceLabel(850), '850 ม.');
      expect(distanceLabel(1500), '1.5 กม.');
    });
  });

  group('จัดลำดับเส้นทาง', () {
    test('ไปจุดใกล้ก่อนเสมอ ถึงลำดับที่ระบบให้มาจะสลับกัน', () {
      // วางเรียงเป็นเส้นตรงออกจากคลัง แต่ให้ seq กลับหัว
      final route = planRoute(
        depotLat: 13.7,
        depotLon: 100.5,
        stops: [
          _stop(seq: 3, lat: 13.7, lon: 100.53, docId: 'ไกลสุด'),
          _stop(seq: 2, lat: 13.7, lon: 100.52, docId: 'กลาง'),
          _stop(seq: 1, lat: 13.7, lon: 100.51, docId: 'ใกล้สุด'),
        ],
      );

      expect(route.order.map((g) => g.first.docId).toList(), [
        'ใกล้สุด',
        'กลาง',
        'ไกลสุด',
      ]);
    });

    test('ลำดับเดิมที่วิ่งไขว้ไปมา จัดใหม่แล้วต้องสั้นลง', () {
      // สี่จุดเป็นสี่เหลี่ยมรอบคลัง ลำดับเดิมวิ่งทแยงข้ามไปมา
      final route = planRoute(
        depotLat: 13.7,
        depotLon: 100.5,
        stops: [
          _stop(seq: 1, lat: 13.72, lon: 100.52, docId: 'มุมไกล'),
          _stop(seq: 2, lat: 13.7, lon: 100.52, docId: 'ฝั่งตะวันออก'),
          _stop(seq: 3, lat: 13.72, lon: 100.5, docId: 'ฝั่งเหนือ'),
        ],
      );

      expect(route.order, hasLength(3));
      expect(route.totalMeters, lessThan(route.originalMeters));
      expect(route.savedPercent, greaterThan(0));
    });

    test('คัดใบที่ส่งแล้วกับใบที่ไม่มีพิกัดออกจากเส้นทาง', () {
      final route = planRoute(
        depotLat: 13.62,
        depotLon: 100.72,
        stops: [
          _stop(seq: 1, lat: 13.63, lon: 100.74, docId: 'ปกติ'),
          _stop(seq: 2, lat: 13.61, lon: 100.7, docId: 'ส่งแล้ว', status: '1'),
          _stop(seq: 3, lat: null, lon: null, docId: 'ไม่มีพิกัด'),
          _stop(seq: 4, lat: 0, lon: 0, docId: 'พิกัดศูนย์'),
        ],
      );

      expect(route.order.map((g) => g.first.docId).toList(), ['ปกติ']);
    });

    test('ไม่มีใบที่จัดได้เลย คืนเส้นทางว่าง ไม่ throw', () {
      final route = planRoute(
        depotLat: 13.62,
        depotLon: 100.72,
        stops: [_stop(seq: 1, lat: null, lon: null)],
      );

      expect(route.isEmpty, isTrue);
      expect(route.totalMeters, 0);
      expect(route.savedPercent, 0);
    });

    test('ระยะแต่ละช่วงเท่ากับจำนวนจุด และรวมแล้วตรงกับยอดรวม', () {
      final plan = _fixturePlans().first;
      final route = planRoute(
        depotLat: plan.depotLat!,
        depotLon: plan.depotLon!,
        stops: plan.stops,
      );

      expect(route.legMeters, hasLength(route.order.length));

      final sum =
          route.legMeters.fold(0.0, (total, m) => total + m) +
          route.returnMeters;
      expect(route.totalMeters, closeTo(sum, 0.001));
    });

    test('เลือกวิธีเรียงได้ ได้ลำดับต่างกันตามที่สั่ง', () {
      // สามจุดห่างจากคลังไม่เท่ากัน: ใกล้ กลาง ไกล
      final stops = [
        _stop(seq: 2, lat: 13.7, lon: 100.52, docId: 'กลาง'),
        _stop(seq: 3, lat: 13.7, lon: 100.53, docId: 'ไกล'),
        _stop(seq: 1, lat: 13.7, lon: 100.51, docId: 'ใกล้'),
      ];

      List<String> orderOf(RouteStrategy strategy) => planRoute(
        depotLat: 13.7,
        depotLon: 100.5,
        stops: stops,
        strategy: strategy,
      ).order.map((g) => g.first.docId).toList();

      expect(orderOf(RouteStrategy.nearestFirst), ['ใกล้', 'กลาง', 'ไกล']);
      expect(orderOf(RouteStrategy.farthestFirst), ['ไกล', 'กลาง', 'ใกล้']);
      // ลำดับเดิมเรียงตาม seq ที่ระบบวางมา ไม่ใช่ลำดับใน list
      expect(orderOf(RouteStrategy.original), ['ใกล้', 'กลาง', 'ไกล']);
    });

    test('ไม่ระบุวิธี ใช้แบบสั้นที่สุดให้', () {
      final stops = [
        _stop(seq: 1, lat: 13.72, lon: 100.52, docId: 'มุมไกล'),
        _stop(seq: 2, lat: 13.7, lon: 100.52, docId: 'ตะวันออก'),
        _stop(seq: 3, lat: 13.72, lon: 100.5, docId: 'เหนือ'),
      ];

      final byDefault = planRoute(
        depotLat: 13.7,
        depotLon: 100.5,
        stops: stops,
      );
      final shortest = planRoute(
        depotLat: 13.7,
        depotLon: 100.5,
        stops: stops,
        strategy: RouteStrategy.shortest,
      );

      expect(byDefault.totalMeters, shortest.totalMeters);
    });

    test('ทุกวิธีเทียบกับลำดับเดิมชุดเดียวกัน', () {
      final stops = [
        _stop(seq: 1, lat: 13.72, lon: 100.52, docId: 'A'),
        _stop(seq: 2, lat: 13.7, lon: 100.52, docId: 'B'),
        _stop(seq: 3, lat: 13.72, lon: 100.5, docId: 'C'),
      ];

      final all = [
        for (final strategy in RouteStrategy.values)
          planRoute(
            depotLat: 13.7,
            depotLon: 100.5,
            stops: stops,
            strategy: strategy,
          ),
      ];

      // ฐานที่เอาไปเทียบต้องเป็นตัวเดียวกันหมด ไม่งั้น % ที่โชว์จะเทียบกันไม่ได้
      expect(all.map((r) => r.originalMeters).toSet(), hasLength(1));

      // เลือกแบบที่วิ่งไกลกว่าเดิม ต้องบอกว่ายาวขึ้น ไม่ใช่โชว์ 0
      final original = all[RouteStrategy.original.index];
      expect(original.changePercent, closeTo(0, 0.001));
      expect(
        all[RouteStrategy.shortest.index].changePercent,
        lessThanOrEqualTo(0),
      );
    });

    test('แผนที่มีเคสกวน จัดได้ 3 จุดจอดจาก 4 ใบที่ยังไม่ส่ง', () {
      final plan = _fixturePlans().firstWhere(
        (p) => p.truckSendId == 'TS26092102',
      );
      final route = planRoute(
        depotLat: plan.depotLat!,
        depotLon: plan.depotLon!,
        stops: plan.stops,
      );

      // 5 ใบ: ส่งแล้ว 1, ไม่มีพิกัด 1, พิกัดศูนย์ 1, เหลือ 2 ใบที่พิกัดเดียวกัน
      expect(plan.pending, hasLength(4));
      expect(plan.withoutPoint, hasLength(2));
      expect(route.order, hasLength(1));
      expect(route.order.single.billCount, 2);
    });
  });
}
