import 'dart:async';

import 'package:flutter/material.dart';

import 'package:claim/page/itcase/itcase_api.dart';
import 'package:claim/page/itcase/itcase_appbar.dart';
import 'package:claim/page/itcase/itcase_job_card.dart';
import 'package:claim/page/itcase/itcase_job_detail_page.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/mobile_api.dart';
import 'package:claim/widgets/state_views.dart';

/// เคสที่ผู้ใช้คนนี้เคยแจ้งไว้ พร้อมสถานะล่าสุด กดเข้าไปดูความคืบหน้าต่อได้
///
/// `repairstatuslist` กับ `repairsolvetype` ไม่ได้เอามาโชว์เป็นหน้าของตัวเอง
/// ทั้งสองอันคือตารางอ้างอิงไว้แปลรหัสที่ติดมากับเคส (`IN` เป็น "อยู่ระหว่าง
/// ดำเนินการ", `S002` เป็น "โปรแกรม") โหลดพร้อมกันตรงนี้ทีเดียวแล้วส่งต่อให้
/// การ์ดกับหน้ารายละเอียดใช้ ไม่ต้องยิงซ้ำ
class ItCaseStatusPage extends StatefulWidget {
  const ItCaseStatusPage({super.key});

  @override
  State<ItCaseStatusPage> createState() => _ItCaseStatusPageState();
}

class _ItCaseStatusPageState extends State<ItCaseStatusPage>
    with WidgetsBindingObserver {
  /// ห่างจากรอบก่อนน้อยกว่านี้ถือว่าเพิ่งดึงไป ไม่ต้องยิงซ้ำ
  ///
  /// รอบเต็มยิงสามเส้น ยิ่งต้องกันคนที่สลับแอปไปมาไม่ให้ยิงทุกครั้ง
  static const Duration _minGap = Duration(seconds: 30);

  /// ระยะห่างของรอบดึงซ้ำเงียบ ๆ ระหว่างเปิดหน้านี้ค้างไว้
  ///
  /// เท่ากับหน้ารายละเอียด สถานะเปลี่ยนตอนเจ้าหน้าที่ IT กดในเว็บ ซึ่งเกิดใน
  /// สเกลสิบนาทีขึ้นไป ยิงถี่กว่านี้ได้ผลเท่าเดิมแต่กินแบตกับเน็ตฟรี ๆ
  static const Duration _pollGap = Duration(seconds: 45);

  List<ItCaseJob> _jobs = const [];
  List<ItCaseStatus> _statuses = const [];
  List<ItCaseSolveType> _types = const [];

  bool _loading = true;
  String? _error;

  /// เวลาที่ยิงรอบล่าสุด ใช้กันยิงถี่
  DateTime? _lastLoad;

  Timer? _poll;

  final TextEditingController _search = TextEditingController();

  /// คำค้นล่าสุด กรองเฉพาะฝั่งแอปจากรายการที่โหลดมาแล้ว ไม่ได้ยิงถาม API ใหม่
  ///
  /// เคสของคนคนเดียวมีไม่กี่สิบใบ กรองในมือถือเร็วกว่ารอเน็ตอยู่แล้ว
  /// และยังค้นได้ตอนเน็ตหลุดด้วย
  String _query = '';

  /// ยังมีเคสที่ยังไม่ปิดอยู่ไหม ปิดหมดแล้วก็ไม่มีอะไรให้รอ เลิกดึงได้
  ///
  /// ดูจากรายการเต็ม ไม่ใช่ที่กรองแล้ว การพิมพ์ค้นหาไม่ควรไปหยุดรอบดึงข้อมูล
  bool get _hasOpenCase => _jobs.any((job) => job.stage != ItCaseStage.done);

  /// รายการที่จะโชว์จริงหลังกรองด้วยคำค้น
  List<ItCaseJob> get _visible {
    final keyword = _query.trim().toLowerCase();
    if (keyword.isEmpty) return _jobs;

    return _jobs.where((job) => _matches(job, keyword)).toList();
  }

  /// ข้อความสถานะต้องเทียบแยก เพราะแถวอาจมีแต่รหัส (`IN`) ส่วนคำเต็มที่ผู้ใช้
  /// เห็นบนป้าย ("อยู่ระหว่างดำเนินการ") มาจากตารางอ้างอิงที่หน้านี้ถืออยู่
  /// ไม่เทียบตรงนี้ คนที่พิมพ์คำที่ตัวเองเห็นบนจอจะหาไม่เจอ
  bool _matches(ItCaseJob job, String keyword) =>
      job.searchIndex.contains(keyword) ||
      job.statusTextFrom(_statuses).toLowerCase().contains(keyword);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _search.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// กลับเข้าแอปมาแล้วรายการบนจอเป็นของเก่า ดึงใหม่เงียบ ๆ ทับให้เลย
  ///
  /// ออกจากแอปไปก็หยุดรอบอัตโนมัติไว้ก่อน ไม่ต้องยิงตอนไม่มีคนดู
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _refreshIfStale();
      _startPolling();
      return;
    }

    _poll?.cancel();
    _poll = null;
  }

  /// ดึงใหม่เงียบ ๆ เว้นแต่เพิ่งดึงไปไม่นาน
  void _refreshIfStale() {
    final last = _lastLoad;
    if (last != null && DateTime.now().difference(last) < _minGap) return;

    _load(quiet: true);
  }

  /// ตั้งรอบดึงซ้ำเงียบ ๆ ระหว่างที่หน้านี้เปิดค้างอยู่
  ///
  /// คนที่นั่งดูหน้านี้รออยู่จะเห็นแถบ % ขยับเอง ไม่ต้องดึงลงรีเฟรชเป็นระยะ
  /// เพื่อถามว่าขยับหรือยัง
  void _startPolling() {
    _poll?.cancel();
    if (!_hasOpenCase) return;

    _poll = Timer.periodic(_pollGap, (timer) {
      // เคสปิดครบทุกใบระหว่างรอบ เลิกดึงตั้งแต่ตรงนี้
      if (!_hasOpenCase) {
        timer.cancel();
        _poll = null;
        return;
      }

      // มีหน้าอื่นทับอยู่ (เช่นหน้ารายละเอียดที่ดึงของตัวเองอยู่แล้ว)
      // ยิงไปก็ไม่มีใครเห็น รอจนกลับมาหน้านี้ก่อน
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;

      _refreshJobs();
    });
  }

  /// รอบอัตโนมัติ ยิงแค่รายการเคส ไม่ลากตารางอ้างอิงมาด้วย
  ///
  /// `repairstatuslist` กับ `repairsolvetype` เป็นตารางคงที่ โหลดรอบแรกครั้งเดียว
  /// พอ รอบระหว่างนั่งดูจึงเหลือเส้นเดียว ถูกกว่ารอบเต็มสามเท่า
  ///
  /// ล้มเหลวก็เงียบ คงรายการเดิมไว้ ผู้ใช้ไม่ได้สั่งรอบนี้เอง ไม่ต้องรายงาน
  Future<void> _refreshJobs() async {
    _lastLoad = DateTime.now();

    try {
      final jobs = await fetchCaseJobs();
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _error = null;
      });
    } catch (_) {
      // เงียบไว้ตั้งใจ ดูหมายเหตุข้างบน
    }
  }

  /// [quiet] สำหรับรอบที่ผู้ใช้ไม่ได้สั่งเอง ทั้งดึงลงรีเฟรชและตอนกลับเข้าแอป
  /// ไม่ต้องขึ้นวงกลมกลางจอทับของเดิม RefreshIndicator มีวงหมุนของตัวเองอยู่แล้ว
  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    _lastLoad = DateTime.now();

    // ยิงพร้อมกันทั้งสามตัว สองตัวหลังเป็นตารางอ้างอิง
    final jobs = _guard(fetchCaseJobs());
    final statuses = _guard(fetchCaseStatuses());
    final types = _guard(fetchSolveTypes());

    final jobsResult = await jobs;
    final statusesResult = await statuses;
    final typesResult = await types;

    if (!mounted) return;
    setState(() {
      final rows = jobsResult.data;
      if (rows != null) {
        _jobs = rows;
        _error = null;
      } else if (!quiet || _jobs.isEmpty) {
        // รอบเบื้องหลังที่พังทั้งที่มีรายการอยู่แล้ว คงของเดิมไว้
        // เน็ตสะดุดตอนสลับกลับเข้าแอปไม่ใช่เหตุให้รายการที่อ่านอยู่หายไป
        _jobs = const [];
        _error = jobsResult.error;
      }

      // ตารางอ้างอิงล่มไม่ต้องขึ้น error ทั้งหน้า การ์ดโชว์รหัสดิบแทนได้
      // เสียแค่ความสวย ไม่ได้เสียข้อมูล
      _statuses = statusesResult.data ?? _statuses;
      _types = typesResult.data ?? _types;
      _loading = false;
    });

    // รายการเพิ่งเปลี่ยน รอบอัตโนมัติจึงต้องประเมินใหม่ว่ายังต้องดึงต่อไหม
    _startPolling();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: itCaseAppBar(title: 'ขั้นตอนการดำเนินงาน'),
      body: Column(
        children: [
          // ช่องค้นหาอยู่นอก RefreshIndicator จึงไม่เลื่อนหายไปกับรายการ
          // คนที่พิมพ์ค้นแล้วเลื่อนดูผลจะได้แก้คำค้นได้โดยไม่ต้องเลื่อนขึ้นมาใหม่
          if (_showSearch) _searchField(scheme),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(quiet: true),
              child: _body(),
            ),
          ),
        ],
      ),
    );
  }

  /// โชว์ช่องค้นหาเฉพาะตอนที่มีของให้ค้นจริง ๆ
  ///
  /// จอที่ยังโหลดอยู่ จอที่พัง และคนที่ยังไม่เคยแจ้งเคสสักใบ เห็นช่องค้นหา
  /// ไปก็ไม่มีอะไรให้ทำ
  bool get _showSearch => !_loading && _error == null && _jobs.isNotEmpty;

  Widget _searchField(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.gap,
        AppSizes.gap,
        AppSizes.gap,
        0,
      ),
      child: TextField(
        controller: _search,
        textInputAction: TextInputAction.search,
        onChanged: (value) => setState(() => _query = value),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'ค้นหาเลขเคส อาการ สถานะ ผู้รับงาน',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'ล้างคำค้น',
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                    FocusScope.of(context).unfocus();
                  },
                  icon: const Icon(Icons.close, size: 20),
                ),
          filled: true,
          fillColor: scheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingStateView();

    final error = _error;
    if (error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSizes.pagePadding,
        children: [
          const SizedBox(height: 60),
          ErrorStateView(message: error, onRetry: _load),
        ],
      );
    }

    if (_jobs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          EmptyStateView(
            icon: Icons.inbox_outlined,
            message: 'ยังไม่เคยแจ้งเคสไว้\nเคสที่แจ้งแล้วจะมาอยู่ตรงนี้',
          ),
        ],
      );
    }

    final jobs = _visible;
    if (jobs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSizes.pagePadding,
        children: [
          const SizedBox(height: 60),
          EmptyStateView(
            icon: Icons.search_off,
            message: 'ไม่พบเคสที่ตรงกับ "${_query.trim()}"',
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSizes.pagePadding,
      itemCount: jobs.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.gap),
      itemBuilder: (context, index) {
        final job = jobs[index];

        return ItCaseJobCard(
          job: job,
          statuses: _statuses,
          // ไม่มีเลขเคสก็เปิดรายละเอียดไม่ได้ endpoint ต้องใช้เลขนี้
          onTap: job.id.isEmpty ? null : () => _openDetail(job),
        );
      },
    );
  }

  /// เปิดรายละเอียดการดำเนินงานของเคสใบนั้น
  ///
  /// ส่งตารางอ้างอิงที่โหลดไว้แล้วไปด้วย หน้าปลายทางจะได้ไม่ต้องยิงซ้ำ
  ///
  /// กลับออกมาแล้วดึงรายการใหม่เงียบ ๆ หน้ารายละเอียดเพิ่งเห็นสถานะล่าสุด
  /// การ์ดในรายการไม่ควรค้างเป็นของเก่ากว่าหน้าที่ผู้ใช้เพิ่งออกมา
  Future<void> _openDetail(ItCaseJob job) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ItCaseJobDetailPage(job: job, statuses: _statuses, types: _types),
      ),
    );

    if (!mounted) return;
    _refreshIfStale();
  }
}

/// ยิง request แล้วห่อผลเป็นคู่ ข้อมูลหรือข้อความผิดพลาด
///
/// ต้องเรียกให้ครบทุกตัวก่อนค่อย await ทีละอัน ตัวฟังก์ชันเริ่มทำงานทันทีที่
/// ถูกเรียกและไปติดที่ await ข้างใน จึงมีคนรับ error ตั้งแต่วินาทีแรก
/// ถ้าปล่อย Future เปล่า ๆ ไว้แล้วค่อย await ทีหลัง ตัวที่พังก่อนจะกลายเป็น
/// unhandled error
Future<({List<T>? data, String? error})> _guard<T>(
  Future<List<T>> request,
) async {
  try {
    return (data: await request, error: null);
  } on MobileApiException catch (e) {
    return (data: null, error: e.message);
  } catch (_) {
    return (data: null, error: 'โหลดข้อมูลไม่สำเร็จ กรุณาลองใหม่');
  }
}
