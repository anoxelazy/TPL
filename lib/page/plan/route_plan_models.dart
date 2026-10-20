/// แผนเดินรถ: อ่านพิกัดบ้านลูกค้าแล้วจัดลำดับจุดส่งให้วิ่งสั้นที่สุด
///
/// ชื่อฟิลด์ทั้งหมดตรงกับไฟล์ Excel ที่ระบบออกให้ (`docid`, `poslat`, `poslon`,
/// `odraddress`, `lat_branch`, `lon_branch`) ไม่ได้ตั้งใหม่ พอ backend ใส่
/// พิกัดมากับ `GetBillList` เมื่อไหร่ ตัวอ่านชุดนี้ใช้ต่อได้เลย
///
/// การคำนวณทั้งหมดทำในเครื่อง ไม่ยิงบริการข้างนอก: ระยะทางใช้สูตร haversine
/// (ระยะบนผิวโลกเป็นเส้นตรง ไม่ใช่ระยะตามถนน) แล้วจัดลำดับด้วยเพื่อนบ้านใกล้สุด
/// ตามด้วย 2-opt
///
/// ⚠️ ระยะที่ได้เป็นเส้นตรง ของจริงตามถนนจะไกลกว่าเสมอ ตัวเลขนี้จึงใช้เทียบว่า
/// ลำดับไหนดีกว่ากัน ไม่ใช่เอาไปบอกคนขับว่าต้องวิ่งกี่กิโล
library;

import 'dart:math' as math;

/// พิกัดที่เป็น 0 ถือว่าไม่มีพิกัด ไม่ใช่จุดกลางมหาสมุทรแอตแลนติก
///
/// ข้อมูลจริงใช้ 0 แทนค่าว่างอยู่ ถ้าไม่กันไว้ รถจะถูกจัดให้วิ่งออกนอกโลก
bool hasPosition(double? lat, double? lon) =>
    lat != null && lon != null && lat != 0 && lon != 0;

/// จุดส่ง 1 ใบ
class RouteStop {
  /// ลำดับที่ระบบวางมาให้ก่อนจัดใหม่ ใช้เทียบว่าจัดแล้วดีขึ้นแค่ไหน
  final int seq;

  final String docId;
  final String receiverName;
  final String address;
  final double? lat;
  final double? lon;
  final String tel;
  final double cod;
  final int qty;
  final String memo;

  /// `1` = ส่งแล้ว, ว่าง = ยังไม่ได้ส่ง (ค่าเดียวกับ `Status_Online` ของแผนรถ)
  final String statusOnline;

  const RouteStop({
    required this.seq,
    required this.docId,
    this.receiverName = '',
    this.address = '',
    this.lat,
    this.lon,
    this.tel = '',
    this.cod = 0,
    this.qty = 0,
    this.memo = '',
    this.statusOnline = '',
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) => RouteStop(
    seq: _int(json['seq']),
    docId: _str(json['docid']),
    receiverName: _str(json['reciept_name']),
    address: _str(json['odraddress']),
    lat: _double(json['poslat']),
    lon: _double(json['poslon']),
    tel: _str(json['tel']),
    cod: _double(json['cod']) ?? 0,
    qty: _int(json['qty']),
    memo: _str(json['memo']),
    statusOnline: _str(json['status_online']),
  );

  bool get isDelivered => statusOnline.trim() == '1';

  bool get hasPoint => hasPosition(lat, lon);

  /// ใบนี้ต้องเอาเข้าเส้นทางไหม — ยังไม่ส่งและรู้ว่าบ้านอยู่ไหน
  bool get isRoutable => !isDelivered && hasPoint;
}

/// แผน 1 รอบรถ
class RoutePlan {
  final String truckSendId;
  final String truckId;
  final String driverId;
  final String driverName;
  final String branchName;
  final String branchAddress;

  /// พิกัดคลัง เป็นทั้งจุดออกและจุดกลับของเส้นทาง
  final double? depotLat;
  final double? depotLon;

  final String datePlan;
  final String departTime;
  final List<RouteStop> stops;

  const RoutePlan({
    required this.truckSendId,
    this.truckId = '',
    this.driverId = '',
    this.driverName = '',
    this.branchName = '',
    this.branchAddress = '',
    this.depotLat,
    this.depotLon,
    this.datePlan = '',
    this.departTime = '',
    this.stops = const [],
  });

  factory RoutePlan.fromJson(Map<String, dynamic> json) => RoutePlan(
    truckSendId: _str(json['trucksendid']),
    truckId: _str(json['truckid']),
    driverId: _str(json['driverid']),
    driverName: _str(json['driver_name']),
    branchName: _str(json['branchname']),
    branchAddress: _str(json['branch_add']),
    depotLat: _double(json['lat_branch']),
    depotLon: _double(json['lon_branch']),
    datePlan: _str(json['date_plan']),
    departTime: _str(json['depart_time']),
    stops: [
      for (final item in (json['stops'] as List? ?? const []))
        if (item is Map) RouteStop.fromJson(Map<String, dynamic>.from(item)),
    ],
  );

  bool get hasDepot => hasPosition(depotLat, depotLon);

  /// ใบที่ยังไม่ได้ส่ง ทั้งที่มีพิกัดและไม่มี
  List<RouteStop> get pending => stops.where((s) => !s.isDelivered).toList();

  /// ใบที่ยังไม่ได้ส่งแต่ไม่มีพิกัด จัดเส้นทางให้ไม่ได้ ต้องบอกคนขับแยกไว้
  List<RouteStop> get withoutPoint =>
      pending.where((s) => !s.hasPoint).toList();

  List<RouteStop> get delivered => stops.where((s) => s.isDelivered).toList();
}

/// จุดจอด 1 ที่ อาจมีหลายใบถ้าส่งที่เดียวกัน
///
/// ร้านเดียวกันสั่งสองใบไม่ใช่การจอดสองครั้ง ถ้านับแยกจะได้ระยะทางที่ดูดีเกินจริง
/// (ระยะระหว่างสองใบเป็นศูนย์) และคนขับจะเห็นรายการซ้ำที่เดิมสองแถว
class RouteStopGroup {
  final double lat;
  final double lon;
  final List<RouteStop> stops;

  const RouteStopGroup({
    required this.lat,
    required this.lon,
    required this.stops,
  });

  RouteStop get first => stops.first;

  int get billCount => stops.length;

  double get cod => stops.fold(0, (sum, s) => sum + s.cod);

  int get qty => stops.fold(0, (sum, s) => sum + s.qty);
}

/// รวมใบที่พิกัดเดียวกันเป็นจุดจอดเดียว
///
/// ปัดทศนิยม 5 ตำแหน่งก่อนเทียบ (~1 เมตร) เพราะพิกัดที่มาจากคนละครั้งของ
/// ที่เดียวกันมักต่างกันท้าย ๆ ทศนิยม
List<RouteStopGroup> groupStopsByPoint(List<RouteStop> stops) {
  final groups = <String, List<RouteStop>>{};

  for (final stop in stops) {
    if (!stop.hasPoint) continue;
    final key =
        '${stop.lat!.toStringAsFixed(5)},${stop.lon!.toStringAsFixed(5)}';
    groups.putIfAbsent(key, () => []).add(stop);
  }

  return [
    for (final entry in groups.entries)
      RouteStopGroup(
        lat: entry.value.first.lat!,
        lon: entry.value.first.lon!,
        stops: entry.value,
      ),
  ];
}

/// ระยะระหว่างสองพิกัดเป็นเมตร (haversine)
double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000.0;

  double toRad(double deg) => deg * math.pi / 180;

  final dLat = toRad(lat2 - lat1);
  final dLon = toRad(lon2 - lon1);

  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRad(lat1)) *
          math.cos(toRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);

  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// วิธีเรียงจุดส่ง
///
/// "สั้นที่สุด" คือของที่ควรใช้จริง อีกสามตัวมีไว้เพราะคนขับแต่ละคนมีวิธีของ
/// ตัวเอง บางคนไปไกลสุดก่อนแล้ววิ่งเก็บขากลับ (รถเบาลงเรื่อย ๆ ตอนใกล้คลัง)
/// บางคนเก็บใกล้ ๆ ให้จบก่อนรถติด ให้เลือกเองแล้วเห็นระยะเทียบกันไปเลย
enum RouteStrategy {
  /// เพื่อนบ้านใกล้สุดแล้วเกลาด้วย 2-opt — ระยะรวมน้อยสุด
  shortest('สั้นที่สุด'),

  /// เรียงตามระยะห่างจากคลัง ใกล้ไปไกล
  nearestFirst('ใกล้ก่อน'),

  /// เรียงตามระยะห่างจากคลัง ไกลไปใกล้
  farthestFirst('ไกลก่อน'),

  /// ตามที่ระบบวางมาใน `seq` ไม่จัดใหม่
  original('ลำดับเดิม');

  final String label;

  const RouteStrategy(this.label);
}

/// ผลการจัดเส้นทาง
class PlannedRoute {
  /// จุดจอดเรียงตามลำดับที่ควรวิ่ง
  final List<RouteStopGroup> order;

  /// ระยะจากจุดก่อนหน้าถึงจุดนั้น ๆ ยาวเท่ากับ [order] ตัวแรกคือจากคลัง
  final List<double> legMeters;

  /// ระยะกลับคลังจากจุดสุดท้าย
  final double returnMeters;

  /// ระยะรวมของลำดับเดิมที่ระบบวางมา ใช้เทียบว่าจัดใหม่แล้วดีขึ้นแค่ไหน
  final double originalMeters;

  const PlannedRoute({
    required this.order,
    required this.legMeters,
    required this.returnMeters,
    required this.originalMeters,
  });

  double get totalMeters =>
      legMeters.fold(0.0, (sum, m) => sum + m) + returnMeters;

  /// ต่างจากลำดับเดิมกี่เปอร์เซ็นต์ ติดลบ = สั้นลง บวก = ยาวขึ้น
  ///
  /// มีค่าบวกได้จริงเมื่อคนขับเลือก "ไกลก่อน" หรือ "ใกล้ก่อน" ซึ่งอาจวิ่งไกลกว่า
  /// ลำดับเดิม ต้องบอกตามตรง ไม่ใช่ซ่อนไว้
  double get changePercent {
    if (originalMeters <= 0) return 0;
    return (totalMeters - originalMeters) / originalMeters * 100;
  }

  /// สั้นลงกว่าลำดับเดิมกี่เปอร์เซ็นต์ ยาวกว่าหรือเท่าเดิมคืน 0
  double get savedPercent {
    final change = changePercent;
    return change >= 0 ? 0 : -change;
  }

  bool get isEmpty => order.isEmpty;
}

/// จัดลำดับจุดจอดให้วิ่งจากคลัง วนส่งให้ครบ แล้วกลับคลัง
///
/// สองขั้น: เพื่อนบ้านใกล้สุดเพื่อให้ได้ลำดับตั้งต้นเร็ว ๆ แล้ว 2-opt สลับ
/// เส้นที่ไขว้กันออกจนไม่ดีขึ้นอีก ของจริงระดับ 20-30 จุดจบในไม่กี่มิลลิวินาที
/// จึงไม่ต้องยกไป isolate
///
/// [stops] ที่ไม่มีพิกัดหรือส่งไปแล้วถูกคัดออกให้เอง
///
/// [strategy] เลือกวิธีเรียง ค่าตั้งต้นคือสั้นที่สุด ไม่ว่าจะเลือกแบบไหน
/// [PlannedRoute.originalMeters] ยังเป็นระยะของลำดับเดิมเสมอ จะได้เทียบกันได้
PlannedRoute planRoute({
  required double depotLat,
  required double depotLon,
  required List<RouteStop> stops,
  RouteStrategy strategy = RouteStrategy.shortest,
}) {
  final groups = groupStopsByPoint(stops.where((s) => s.isRoutable).toList());

  if (groups.isEmpty) {
    return const PlannedRoute(
      order: [],
      legMeters: [],
      returnMeters: 0,
      originalMeters: 0,
    );
  }

  // ลำดับเดิมตาม seq ที่ระบบวางมา เก็บระยะไว้เทียบก่อนจะจัดใหม่
  final original = [...groups]
    ..sort((a, b) => a.first.seq.compareTo(b.first.seq));
  final originalMeters = _tourMeters(depotLat, depotLon, original);

  final route = _orderBy(strategy, depotLat, depotLon, groups, original);

  final legs = <double>[];
  var fromLat = depotLat;
  var fromLon = depotLon;
  for (final group in route) {
    legs.add(distanceMeters(fromLat, fromLon, group.lat, group.lon));
    fromLat = group.lat;
    fromLon = group.lon;
  }

  return PlannedRoute(
    order: route,
    legMeters: legs,
    returnMeters: distanceMeters(fromLat, fromLon, depotLat, depotLon),
    originalMeters: originalMeters,
  );
}

/// เรียงจุดจอดตามวิธีที่เลือก
///
/// สามแบบหลังเป็นการเรียงตรง ๆ ไม่ได้เกลาต่อ เพราะจุดประสงค์คือให้ได้ลำดับ
/// ตามที่คนขับสั่งจริง ๆ ถ้าไปเกลาให้อีกจะไม่ใช่ "ไกลก่อน" ตามที่เขาเลือกแล้ว
List<RouteStopGroup> _orderBy(
  RouteStrategy strategy,
  double depotLat,
  double depotLon,
  List<RouteStopGroup> groups,
  List<RouteStopGroup> bySeq,
) {
  double fromDepot(RouteStopGroup g) =>
      distanceMeters(depotLat, depotLon, g.lat, g.lon);

  switch (strategy) {
    case RouteStrategy.shortest:
      final route = _nearestNeighbour(depotLat, depotLon, groups);
      _improveWith2opt(depotLat, depotLon, route);
      return route;

    case RouteStrategy.nearestFirst:
      return [...groups]..sort((a, b) => fromDepot(a).compareTo(fromDepot(b)));

    case RouteStrategy.farthestFirst:
      return [...groups]..sort((a, b) => fromDepot(b).compareTo(fromDepot(a)));

    case RouteStrategy.original:
      return [...bySeq];
  }
}

/// ออกจากคลังแล้วไปจุดที่ใกล้ที่สุดที่ยังไม่ได้ไป ทำจนครบ
List<RouteStopGroup> _nearestNeighbour(
  double depotLat,
  double depotLon,
  List<RouteStopGroup> groups,
) {
  final remaining = [...groups];
  final route = <RouteStopGroup>[];

  var lat = depotLat;
  var lon = depotLon;

  while (remaining.isNotEmpty) {
    var bestIndex = 0;
    var bestDistance = double.infinity;

    for (var i = 0; i < remaining.length; i++) {
      final d = distanceMeters(lat, lon, remaining[i].lat, remaining[i].lon);
      if (d < bestDistance) {
        bestDistance = d;
        bestIndex = i;
      }
    }

    final next = remaining.removeAt(bestIndex);
    route.add(next);
    lat = next.lat;
    lon = next.lon;
  }

  return route;
}

/// สลับช่วงของเส้นทางที่ไขว้กันออก ทำซ้ำจนไม่สั้นลงอีก
///
/// จำกัดรอบไว้ 50 เพราะเป็นงานที่ทำระหว่างผู้ใช้รอดูหน้าจอ ไม่ใช่งานเบื้องหลัง
/// ของจริงหยุดเองภายในไม่กี่รอบอยู่แล้ว
void _improveWith2opt(
  double depotLat,
  double depotLon,
  List<RouteStopGroup> route,
) {
  if (route.length < 4) return;

  var improved = true;
  var rounds = 0;

  while (improved && rounds < 50) {
    improved = false;
    rounds++;

    for (var i = 0; i < route.length - 1; i++) {
      for (var k = i + 1; k < route.length; k++) {
        final before = _tourMeters(depotLat, depotLon, route);

        final candidate = [
          ...route.sublist(0, i),
          ...route.sublist(i, k + 1).reversed,
          ...route.sublist(k + 1),
        ];

        if (_tourMeters(depotLat, depotLon, candidate) < before - 0.5) {
          route
            ..clear()
            ..addAll(candidate);
          improved = true;
        }
      }
    }
  }
}

/// ระยะรวมของเส้นทาง คลัง → ทุกจุด → กลับคลัง
double _tourMeters(
  double depotLat,
  double depotLon,
  List<RouteStopGroup> route,
) {
  if (route.isEmpty) return 0;

  var total = 0.0;
  var lat = depotLat;
  var lon = depotLon;

  for (final group in route) {
    total += distanceMeters(lat, lon, group.lat, group.lon);
    lat = group.lat;
    lon = group.lon;
  }

  return total + distanceMeters(lat, lon, depotLat, depotLon);
}

/// ระยะทางแบบที่คนอ่าน ต่ำกว่า 1 กม. บอกเป็นเมตร
String distanceLabel(double meters) {
  if (meters < 1000) return '${meters.round()} ม.';
  return '${(meters / 1000).toStringAsFixed(1)} กม.';
}

String _str(dynamic value) => value?.toString().trim() ?? '';

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(_str(value)) ?? 0;
}

double? _double(dynamic value) {
  if (value is num) return value.toDouble();
  final text = _str(value);
  if (text.isEmpty) return null;
  return double.tryParse(text);
}
