import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:claim/page/plan/longdo_address_api.dart';
import 'package:claim/page/plan/route_plan_models.dart';
import 'package:claim/page/plan/route_road_api.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/map_keys.dart';

/// จำนวนจุดแวะที่กูเกิลแมปรับได้ต่อหนึ่งลิงก์
///
/// ใช้กับปุ่มนำทางเท่านั้น แมปในแอปวาดได้ครบทุกจุดไม่มีเพดาน
const int kMapMaxWaypoints = 9;

/// ลิงก์เปิดเส้นทางทั้งรอบในกูเกิลแมป
///
/// **ไม่สั่งให้เริ่มนำทางเอง** (ไม่ใส่ `dir_action=navigate`) เปิดมาค้างที่หน้า
/// เส้นทางให้คนขับดูก่อนว่าจะไปทางไหน แวะกี่จุด ใช้เวลาเท่าไหร่ แล้วค่อยกด
/// เริ่มเองตอนพร้อมออกรถ ถ้าเด้งเข้าโหมดนำทางทันทีตั้งแต่ยังจอดอยู่ท้ายคลัง
/// เสียงบอกทางจะเริ่มพูดทั้งที่คนขับยังจัดของอยู่
///
/// **จุดเริ่มเป็นตำแหน่งปัจจุบันของรถ** ไม่ได้ล็อกไว้ที่คลัง เพราะกดตอนไหนก็ได้
/// ทั้งตอนออกจากคลังและตอนอยู่กลางทางแล้ว ถ้าบังคับให้เริ่มจากคลัง แมปจะพาวน
/// กลับไปตั้งต้นใหม่
///
/// ปลายทางเป็นจุดสุดท้ายในลำดับ ที่เหลือเป็นจุดแวะ ไม่ได้ให้วิ่งกลับคลังต่อ
/// เพราะคนขับรู้ทางกลับอยู่แล้ว เอาช่องจุดแวะที่มีจำกัดไปใช้กับลูกค้าดีกว่า
Uri buildMapsRouteUrl({required List<RouteStopGroup> order}) {
  if (order.isEmpty) {
    return Uri.parse('https://www.google.com/maps/dir/?api=1');
  }

  // ปลายทาง 1 จุด ที่เหลือเป็นจุดแวะ กูเกิลนับเพดานเฉพาะจุดแวะ
  final points = order.take(kMapMaxWaypoints + 1).toList();
  final destination = points.removeLast();
  final waypoints = points.map((g) => '${g.lat},${g.lon}').join('|');

  return Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&destination=${destination.lat},${destination.lon}'
    '&travelmode=driving'
    '${waypoints.isEmpty ? '' : '&waypoints=$waypoints'}',
  );
}

/// ลิงก์เปิดเส้นทางไปจุดเดียวในกูเกิลแมป
///
/// ไม่สั่งเริ่มนำทางเองเหมือนกัน คนขับกดเริ่มเองในแมป
/// และไม่ใส่จุดเริ่ม กูเกิลแมปจะใช้ตำแหน่งปัจจุบันของรถให้เอง
Uri buildMapsStopUrl({required double lat, required double lon}) => Uri.parse(
  'https://www.google.com/maps/dir/?api=1'
  '&destination=$lat,$lon'
  '&travelmode=driving',
);

/// แผนที่เส้นทางในแอป
///
/// ใช้ flutter_map กับแผนที่ OpenStreetMap ไม่ได้ฝังกูเกิลแมป เพราะ
/// (1) กูเกิลบล็อกการเปิดแมปใน WebView — ของเดิมจึงขึ้น "หน้าเว็บไม่พร้อมใช้งาน"
/// (2) `google_maps_flutter` ต้องมี API key ที่ผูกบัญชีคิดเงิน และตั้งค่าแยก
///     ทั้ง Android/iOS ส่วน OSM เปิดใช้ได้เลยไม่มีค่าใช้จ่าย
///
/// ภาพแผนที่ใช้ของ Longdo เมื่อมี key ([kLongdoTileUrl]) ชื่อถนนและสถานที่
/// เป็นภาษาไทย ไม่มี key ค่อยใช้ OSM ซึ่งห้ามแอปที่คนใช้เยอะดึงเป็นหลัก
///
/// เส้นทางบนแมปขอจาก ORS/OSRM (ถนนจริง) ขอไม่ได้ก็ลากเส้นตรงระหว่างจุดแทน
/// แล้วบอกผู้ใช้ว่าเป็นเส้นตรง จะได้ไม่เข้าใจผิดว่าให้วิ่งทะลุตึก
///
/// คืนวิธีเรียงที่เลือกไว้ตอนปิดหน้า หน้ารายการจะได้เรียงตามกันโดยไม่ต้องเลือกซ้ำ
class RouteMapPage extends StatefulWidget {
  final RoutePlan plan;
  final RouteStrategy strategy;

  const RouteMapPage({super.key, required this.plan, required this.strategy});

  @override
  State<RouteMapPage> createState() => _RouteMapPageState();
}

class _RouteMapPageState extends State<RouteMapPage> {
  late RouteStrategy _strategy = widget.strategy;

  /// เส้นทางของทุกวิธี คิดครั้งเดียวตอนเปิดหน้า สลับวิธีแล้วไม่ต้องคิดใหม่
  late final Map<RouteStrategy, PlannedRoute> _routes = {
    for (final strategy in RouteStrategy.values)
      strategy: planRoute(
        depotLat: widget.plan.depotLat!,
        depotLon: widget.plan.depotLon!,
        stops: widget.plan.stops,
        strategy: strategy,
      ),
  };

  /// เส้นทางตามถนนจาก OSRM ว่างแปลว่ายังไม่ได้ หรือขอไม่สำเร็จ
  List<LatLng> _road = const [];
  bool _loadingRoad = true;

  /// เลขรอบของคำขอเส้นทาง กันผลของวิธีเก่ามาทับวิธีที่เพิ่งกดเลือก
  ///
  /// สลับวิธีเร็ว ๆ สองสามที คำขอเก่าอาจตอบกลับมาทีหลัง ถ้าไม่กันไว้จะได้เส้นทาง
  /// ของวิธีที่ไม่ได้เลือกวาดค้างอยู่บนแมป
  int _roadRequest = 0;

  /// ที่อยู่จาก Longdo ของจุดที่ระบบไม่ได้ส่งที่อยู่มา key คือ `lat,lon`
  final Map<String, String> _lookedUpAddresses = {};

  PlannedRoute get _route => _routes[_strategy]!;

  LatLng get _depot => LatLng(widget.plan.depotLat!, widget.plan.depotLon!);

  /// ลำดับจุดที่รถต้องวิ่ง ออกจากคลังและจบที่คลัง
  List<LatLng> get _waypoints => [
    _depot,
    for (final group in _route.order) LatLng(group.lat, group.lon),
    _depot,
  ];

  @override
  void initState() {
    super.initState();
    _start();
  }

  /// รอคีย์แผนที่ก่อนค่อยขอเส้นทางกับที่อยู่
  ///
  /// ปกติคีย์มาถึงตั้งแต่เปิดแอป ([MapKeys.ensureLoaded] ใน main) รอบนี้เลยไม่ได้
  /// รอจริง ที่ต้องรอคือการเปิดแอปครั้งแรกของเครื่องที่ยังไม่มีคีย์ใน cache
  /// ไม่รอก็จะขอเส้นทางจาก OSRM และไม่หาที่อยู่ ทั้งที่อีกอึดใจคีย์ก็มา
  Future<void> _start() async {
    await MapKeys.ensureLoaded();
    if (!mounted) return;
    // แผนที่วาดไปก่อนด้วย OSM แล้ว ได้คีย์ Longdo มาก็ต้องวาดใหม่
    setState(() {});
    _loadRoad();
    _loadMissingAddresses();
  }

  /// หาที่อยู่ให้จุดที่ช่องที่อยู่ว่าง ยิงทีละจุดไม่ยิงพร้อมกัน
  ///
  /// ทุกวิธีเรียงใช้จุดชุดเดียวกัน หาจากวิธีที่เปิดมาครั้งเดียวพอ
  Future<void> _loadMissingAddresses() async {
    if (MapKeys.longdo.isEmpty) return;

    for (final group in _route.order) {
      if (group.first.address.trim().isNotEmpty) continue;

      final key = '${group.lat},${group.lon}';
      if (_lookedUpAddresses.containsKey(key)) continue;

      final address = await fetchAddress(lat: group.lat, lon: group.lon);
      if (!mounted) return;
      if (address.isNotEmpty) _lookedUpAddresses[key] = address;
    }
  }

  /// ที่อยู่ที่จะแสดงของจุดนี้ ไม่มีจากระบบก็ใช้ที่หาจาก Longdo
  String _addressOf(RouteStopGroup group) {
    final address = group.first.address.trim();
    if (address.isNotEmpty) return address;
    return _lookedUpAddresses['${group.lat},${group.lon}'] ?? '';
  }

  Future<void> _loadRoad() async {
    final request = ++_roadRequest;
    setState(() => _loadingRoad = true);

    final road = await fetchRoadRoute(_waypoints);
    if (!mounted || request != _roadRequest) return;

    setState(() {
      _road = road;
      _loadingRoad = false;
    });
  }

  void _selectStrategy(RouteStrategy strategy) {
    if (strategy == _strategy) return;
    setState(() {
      _strategy = strategy;
      _road = const [];
    });
    _loadRoad();
  }

  /// ส่งเส้นทางทั้งรอบไปกูเกิลแมป คนขับกดเริ่มเองที่นั่น
  Future<void> _openWholeRoute() =>
      _open(buildMapsRouteUrl(order: _route.order));

  Future<void> _openStop(int index) {
    final group = _route.order[index];
    return _open(buildMapsStopUrl(lat: group.lat, lon: group.lon));
  }

  Future<void> _open(Uri url) async {
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!mounted || opened) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('เปิดแอปกูเกิลแมปไม่ได้')));
  }

  /// เลือกส่งเข้าแมปทีละจุด
  ///
  /// ของจริงคนขับไม่ได้นำทางรวดเดียวจบเสมอ บางทีของจุดแรกยังไม่พร้อม
  /// หรือกลับมากดต่อกลางทางแล้วต้องไปจุดที่ 5
  Future<void> _pickStopToNavigate() async {
    final index = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'ส่งเข้าแมปทีละจุด',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            for (var i = 0; i < _route.order.length; i++)
              ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  child: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
                ),
                title: Text(
                  _route.order[i].first.receiverName.isEmpty
                      ? _route.order[i].first.docId
                      : _route.order[i].first.receiverName,
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  _addressOf(_route.order[i]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () => Navigator.pop(sheetContext, i),
              ),
          ],
        ),
      ),
    );

    if (index == null) return;
    await _openStop(index);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // ได้เส้นถนนมาก็วาดตามถนน ไม่ได้ก็ลากตรงระหว่างจุดไปก่อน
    final line = _road.isNotEmpty ? _road : _waypoints;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // ส่งวิธีที่เลือกกลับไปให้หน้ารายการเรียงตามกัน
        Navigator.of(context).pop(_strategy);
      },
      child: Scaffold(
        appBar: AppBar(title: Text('เส้นทาง ${widget.plan.truckId}')),
        bottomNavigationBar: _route.isEmpty ? null : _startBar(),
        body: Column(
          children: [
            _strategyPicker(),
            Expanded(
              child: FlutterMap(
                // สลับวิธีแล้วต้องซูมใหม่ให้พอดีจุดชุดใหม่ ไม่งั้นแมปค้างที่เดิม
                key: ValueKey(_strategy),
                options: MapOptions(
                  initialCameraFit: CameraFit.coordinates(
                    coordinates: _waypoints,
                    padding: const EdgeInsets.all(48),
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: MapKeys.longdo.isEmpty
                        ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                        : kLongdoTileUrl,
                    additionalOptions: {'key': MapKeys.longdo},
                    // OSM ขอให้บอกว่าแอปไหนเรียกใช้ ไม่ใส่เสี่ยงโดนบล็อก
                    userAgentPackageName: 'com.thaiparcels.claim',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: line,
                        strokeWidth: 4,
                        color: scheme.primary.withValues(alpha: 0.85),
                      ),
                    ],
                  ),
                  MarkerLayer(markers: _markers()),
                ],
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  /// เลือกวิธีเรียงได้จากบนแมปเลย พร้อมระยะรวมของแต่ละวิธี
  ///
  /// อยู่บนหน้านี้ด้วยเพราะคนเปิดแมปมาแล้วเห็นเส้นทางจริงถึงจะรู้ว่าชอบแบบไหน
  /// ถ้าต้องถอยกลับไปเลือกที่หน้ารายการแล้วเข้ามาใหม่ทุกครั้งจะไม่มีใครลองเทียบ
  Widget _strategyPicker() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final strategy in RouteStrategy.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: _strategy == strategy,
                  onSelected: (_) => _selectStrategy(strategy),
                  label: Text(
                    '${strategy.label} · '
                    '${distanceLabel(_routes[strategy]!.totalMeters)}',
                  ),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _strategy == strategy
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: _strategy == strategy
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// แถบปุ่มนำทางติดขอบล่าง
  ///
  /// ปุ่มหลักคือนำทางรวดเดียวทั้งรอบ ส่วนปุ่มรองไว้เลือกไปทีละจุด
  Widget _startBar() {
    final scheme = Theme.of(context).colorScheme;
    final overflow = _route.order.length > kMapMaxWaypoints + 1;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _openWholeRoute,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.map_outlined),
                      label: Text(
                        'ส่ง ${_route.order.length} จุดเข้ากูเกิลแมป',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'ส่งเข้าแมปทีละจุด',
                    onPressed: _pickStopToNavigate,
                    icon: const Icon(Icons.list),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  overflow
                      ? 'เริ่มจากตำแหน่งปัจจุบัน กดเริ่มเองในแมป · '
                            'กูเกิลแมปรับได้ ${kMapMaxWaypoints + 1} จุดแรก '
                            'ที่เหลือส่งทีละจุด'
                      : 'เริ่มจากตำแหน่งปัจจุบัน แล้วกดเริ่มเองในแมปตอนพร้อมออกรถ',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Marker> _markers() {
    return [
      Marker(
        point: _depot,
        width: 34,
        height: 34,
        child: _pin(Icons.warehouse, AppColors.stockIcon),
      ),
      for (var i = 0; i < _route.order.length; i++)
        Marker(
          point: LatLng(_route.order[i].lat, _route.order[i].lon),
          width: 30,
          height: 30,
          child: _numberPin(i + 1),
        ),
    ];
  }

  Widget _pin(IconData icon, Color color) => Container(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
    ),
    child: Icon(icon, size: 18, color: Colors.white),
  );

  /// หมุดจุดส่ง เลขบนหมุดตรงกับลำดับในรายการ
  Widget _numberPin(int number) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        '$number',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  /// แถบล่าง: สถานะเส้นทาง กับเครดิตแผนที่ (OSM บังคับให้แสดง)
  Widget _footer() {
    final scheme = Theme.of(context).colorScheme;

    final status = _loadingRoad
        ? 'กำลังดึงเส้นทางตามถนน...'
        : _road.isEmpty
        ? 'ดึงเส้นทางตามถนนไม่ได้ เส้นที่เห็นเป็นเส้นตรงระหว่างจุด'
        : '${_route.order.length} จุดส่ง · ${distanceLabel(_route.totalMeters)}';

    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status, style: TextStyle(fontSize: 12, color: scheme.onSurface)),
          const SizedBox(height: 2),
          Text(
            [
              MapKeys.longdo.isEmpty
                  ? 'แผนที่จาก OpenStreetMap'
                  : 'แผนที่จาก Longdo Map',
              if (MapKeys.ors.isNotEmpty) 'เส้นทางจาก openrouteservice',
            ].join(' · '),
            style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
