import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:claim/page/plan/route_map_page.dart';
import 'package:claim/page/plan/route_plan_api.dart';
import 'package:claim/page/plan/route_plan_models.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/widgets/app_card.dart';
import 'package:claim/widgets/state_views.dart';

/// หน้าแผนเดินรถ: เอาพิกัดบ้านลูกค้ามาจัดลำดับว่าควรวิ่งจุดไหนก่อน
///
/// ช่วงทดสอบเปิดให้เฉพาะรหัสใน `kRoutePlanTesters` และอ่านข้อมูลจากไฟล์ JSON
/// ไม่ใช่จากแผนจริง เพราะ `GetBillList` ยังไม่ส่งพิกัดมาให้
class RoutePlanPage extends StatefulWidget {
  const RoutePlanPage({super.key});

  @override
  State<RoutePlanPage> createState() => _RoutePlanPageState();
}

class _RoutePlanPageState extends State<RoutePlanPage> {
  List<RoutePlan> _plans = const [];
  bool _loading = true;
  String? _error;

  /// วิธีเรียงที่เลือกอยู่ ใช้ร่วมกันทุกแผนในหน้านี้
  ///
  /// คนขับคนหนึ่งมีนิสัยการวิ่งแบบเดียว ไม่ได้เปลี่ยนวิธีรายรอบ แยกเก็บทีละแผน
  /// จะกลายเป็นต้องกดซ้ำทุกแผนโดยไม่ได้อะไรเพิ่ม
  RouteStrategy _strategy = RouteStrategy.shortest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final plans = await fetchMyRoutePlans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'อ่านไฟล์แผนเดินรถไม่สำเร็จ: $e';
        _loading = false;
      });
    }
  }

  /// เริ่มนำทางไปจุดนั้นเลยจากในรายการ
  ///
  /// มีปุ่มนี้ทุกแถวเพราะคนขับที่ลงของเสร็จจะกดจุดถัดไปจากรายการเลย
  /// ไม่ได้ย้อนกลับไปเปิดแมปก่อนทุกครั้ง
  Future<void> _navigate(RouteStopGroup group) async {
    final url = buildMapsStopUrl(lat: group.lat, lon: group.lon);
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!mounted || opened) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('เปิดแอปกูเกิลแมปไม่ได้')));
  }

  /// เปิดแผนที่เส้นทางในแอป
  ///
  /// เลือกวิธีเรียงบนแมปได้ด้วย กลับมาแล้วรายการเรียงตามที่เลือกไว้บนนั้น
  /// ไม่ใช่เด้งกลับเป็นของเดิมจนคนงงว่าที่เพิ่งเลือกไปหายไปไหน
  Future<void> _openMap(RoutePlan plan) async {
    final picked = await Navigator.of(context).push<RouteStrategy>(
      MaterialPageRoute(
        builder: (_) => RouteMapPage(plan: plan, strategy: _strategy),
      ),
    );

    if (picked == null || !mounted) return;
    setState(() => _strategy = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('แผนเดินรถ (ทดสอบ)')),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const ListLoadingView();

    final error = _error;
    if (error != null) {
      return ErrorStateView(message: error, onRetry: _load);
    }

    if (_plans.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            EmptyStateView(
              message: 'ไม่มีแผนเดินรถของคุณในไฟล์ทดสอบ',
              icon: Icons.alt_route,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: AppSizes.pagePadding,
        itemCount: _plans.length,
        separatorBuilder: (_, _) => const SizedBox(height: 20),
        itemBuilder: (context, index) => _planSection(_plans[index]),
      ),
    );
  }

  Widget _planSection(RoutePlan plan) {
    // คลังไม่มีพิกัดก็จัดเส้นทางไม่ได้ ไม่รู้ว่าจะออกจากไหน
    if (!plan.hasDepot) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _planHeader(plan),
            const SizedBox(height: 8),
            Text(
              'แผนนี้ไม่มีพิกัดคลัง (lat_branch/lon_branch) จัดเส้นทางให้ไม่ได้',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
      );
    }

    // หน้านี้คิดเฉพาะวิธีที่เลือกอยู่ ไม่ต้องคิดครบทุกวิธีเหมือนหน้าแมป
    // เพราะที่นี่ไม่มีปุ่มให้สลับแล้ว (ย้ายไปอยู่บนแมปที่เห็นเส้นทางจริง)
    final route = planRoute(
      depotLat: plan.depotLat!,
      depotLon: plan.depotLon!,
      stops: plan.stops,
      strategy: _strategy,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _planHeader(plan),
              const SizedBox(height: 12),
              _summary(plan, route),
              if (!route.isEmpty) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _openMap(plan),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: const Icon(Icons.map_outlined, size: 20),
                  label: const Text('ดูเส้นทางบนแผนที่'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSizes.gap),
        if (route.isEmpty)
          AppCard(
            child: Text(
              'ไม่มีใบที่จัดเส้นทางได้ (ส่งครบแล้ว หรือไม่มีพิกัดลูกค้าเลย)',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ..._routeStops(plan, route),
        if (plan.withoutPoint.isNotEmpty) ...[
          const SizedBox(height: AppSizes.gap),
          _withoutPointCard(plan),
        ],
      ],
    );
  }

  Widget _planHeader(RoutePlan plan) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 20,
              color: scheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'รถ ${plan.truckId}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              plan.truckSendId,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${plan.branchName} · ออก ${plan.departTime} น. · ${plan.datePlan}',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _summary(RoutePlan plan, PlannedRoute route) {
    final scheme = Theme.of(context).colorScheme;
    final billCount = route.order.fold(0, (sum, g) => sum + g.billCount);

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _stat('จุดจอด', '${route.order.length}'),
        _stat('ใบส่ง', '$billCount'),
        _stat('ระยะรวม', distanceLabel(route.totalMeters)),
        // ปุ่มสลับวิธีอยู่บนหน้าแมป หน้านี้จึงต้องบอกว่าที่เรียงอยู่คือแบบไหน
        // ไม่งั้นเปลี่ยนวิธีบนแมปแล้วกลับมา จะไม่รู้ว่าลำดับที่เห็นมาจากอะไร
        _stat('เรียงแบบ', _strategy.label),
        // เทียบกับลำดับที่ระบบวางมาเสมอ ไม่ว่าจะเลือกวิธีไหน เลือกแบบที่วิ่งไกล
        // กว่าเดิมก็ต้องเห็นว่าไกลกว่า ไม่ใช่ซ่อนไว้แล้วให้ไปเซอร์ไพรส์เอาหน้างาน
        if (route.savedPercent > 0)
          _stat(
            'สั้นลงจากลำดับเดิม',
            '${route.savedPercent.toStringAsFixed(0)}%',
            color: AppColors.success,
          )
        else if (route.changePercent > 0)
          _stat(
            'ยาวกว่าลำดับเดิม',
            '${route.changePercent.toStringAsFixed(0)}%',
            color: AppColors.pending,
          ),
        if (plan.delivered.isNotEmpty)
          _stat(
            'ส่งแล้ว',
            '${plan.delivered.length} ใบ',
            color: scheme.onSurfaceVariant,
          ),
      ],
    );
  }

  Widget _stat(String label, String value, {Color? color}) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color ?? scheme.onSurface,
          ),
        ),
      ],
    );
  }

  /// รายการจุดจอดตามลำดับที่ควรวิ่ง
  ///
  /// ตัวเลขหน้าแถวคือลำดับใหม่ ไม่ใช่ `seq` ที่ระบบวางมา ของเดิมโชว์ไว้ท้ายแถว
  /// ให้คนขับที่ชินกับลำดับเก่ายังเทียบได้
  List<Widget> _routeStops(RoutePlan plan, PlannedRoute route) {
    final scheme = Theme.of(context).colorScheme;
    final widgets = <Widget>[];

    for (var i = 0; i < route.order.length; i++) {
      final group = route.order[i];
      final stop = group.first;

      widgets.add(
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.receiverName.isEmpty
                          ? stop.docId
                          : stop.receiverName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stop.address,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        'ห่างจากจุดก่อนหน้า ${distanceLabel(route.legMeters[i])}',
                        if (group.billCount > 1) '${group.billCount} ใบที่นี่',
                        if (group.cod > 0)
                          'เก็บ ${group.cod.toStringAsFixed(0)} บาท',
                      ].join(' · '),
                      style: TextStyle(fontSize: 11, color: scheme.primary),
                    ),
                    if (stop.memo.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          stop.memo,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'เดิม #${stop.seq}',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  IconButton.filledTonal(
                    tooltip: 'เปิดเส้นทางไปจุดนี้ในกูเกิลแมป',
                    onPressed: () => _navigate(group),
                    icon: const Icon(Icons.navigation_outlined, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      widgets.add(const SizedBox(height: AppSizes.gap));
    }

    widgets.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          'กลับคลัง ${plan.branchName} อีก ${distanceLabel(route.returnMeters)}',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ),
    );

    return widgets;
  }

  /// ใบที่ยังไม่ได้ส่งแต่ไม่มีพิกัด จัดเส้นทางให้ไม่ได้ แต่ห้ามทำหาย
  Widget _withoutPointCard(RoutePlan plan) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.wrong_location_outlined,
                size: 18,
                color: AppColors.pending,
              ),
              const SizedBox(width: 8),
              Text(
                'ไม่มีพิกัด ${plan.withoutPoint.length} ใบ',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'ใบพวกนี้ไม่ได้อยู่ในเส้นทาง ต้องดูที่อยู่แล้วแวะเอง',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          for (final stop in plan.withoutPoint)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${stop.docId} · ${stop.receiverName}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    stop.address,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
