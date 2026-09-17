import 'dart:async';

import 'package:flutter/material.dart';

import 'package:claim/page/itcase/itcase_api.dart';
import 'package:claim/page/itcase/itcase_job_card.dart';
import 'package:claim/page/itcase/itcase_job_detail_page.dart';
import 'package:claim/page/itcase/itcase_status_page.dart';
import 'package:claim/utils/app_colors.dart';

/// เคสที่ยังไม่ปิด โผล่ท้ายหน้าหลักต่อจากตารางเมนู
///
/// คนแจ้งเคสแล้วมักเปิดแอปมาดูว่าทีม IT ขยับหรือยัง ถ้าต้องกดเข้าไปสองชั้น
/// (แจ้งเคส → ปุ่มรายการมุมบนขวา) กว่าจะเจอ ส่วนใหญ่จะไปถามในไลน์แทน
/// เอาการ์ดมาวางตรงนี้เลย เปิดแอปปุ๊บเห็นปั๊บว่าเรื่องไปถึงไหน
///
/// ปิดงานแล้ว (CF) ไม่ต้องโชว์ เรื่องจบแล้วไม่ใช่ของค้าง หน้าหลักมีที่จำกัด
/// ต้องเก็บไว้ให้ของที่ยังต้องตามเท่านั้น
class ItCaseOpenCases extends StatefulWidget {
  const ItCaseOpenCases({super.key});

  @override
  State<ItCaseOpenCases> createState() => _ItCaseOpenCasesState();
}

class _ItCaseOpenCasesState extends State<ItCaseOpenCases>
    with WidgetsBindingObserver {
  /// โชว์บนหน้าหลักได้กี่ใบ ที่เหลือกดดูทั้งหมดเอา
  ///
  /// อยู่ท้ายสุดแล้วก็จริง แต่ปล่อยให้ยาวไม่จำกัดหน้าหลักจะกลายเป็นหน้ารายการ
  /// เคสไปเลย เลื่อนหาอะไรท้าย ๆ ไม่เจอ ที่เหลือไปดูในหน้าของมันเอง
  static const int _maxCards = 3;

  /// เว้นอย่างน้อยเท่านี้ถึงจะยอมดึงใหม่
  ///
  /// สลับแอปไปมาถี่ ๆ ไม่ควรกลายเป็นการยิง API รัวทุกครั้งที่กลับเข้ามา
  static const Duration _minGap = Duration(seconds: 30);

  /// นั่งค้างอยู่หน้าหลัก ดึงใหม่ทุกกี่วินาที
  ///
  /// เท่ากับหน้ารายการกับหน้ารายละเอียด % บนการ์ดใบเดียวกันจะได้ขยับพร้อมกัน
  /// ไม่ใช่หน้าหลักตามหลังอยู่ครึ่งรอบแล้วคนสงสัยว่าเลขไหนถูก
  static const Duration _pollGap = Duration(seconds: 45);

  Timer? _poll;
  DateTime? _lastLoad;

  List<ItCaseJob> _open = const [];
  List<ItCaseStatus> _statuses = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _startPolling();
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// กลับเข้าแอปมาแล้ว % บนการ์ดเป็นของเก่า ดึงใหม่เงียบ ๆ ทับให้เลย
  ///
  /// ออกไปอยู่เบื้องหลังก็หยุดยิง ไม่มีใครดูอยู่แล้วยังกินเน็ตกับแบตอยู่
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshIfStale();
      _startPolling();
      return;
    }

    _poll?.cancel();
    _poll = null;
  }

  /// ตั้งรอบดึงซ้ำเงียบ ๆ ระหว่างที่หน้าหลักเปิดค้างอยู่
  ///
  /// ไม่หยุดตอนไม่มีเคสค้าง เพราะเคสใบใหม่เกิดจากหน้าแจ้งเคสที่เปิดทับหน้านี้
  /// อยู่ กลับออกมาแล้วไม่มีใครบอกการ์ดว่ามีของใหม่ รอบนี้แหละที่ไปเจอ
  void _startPolling() {
    _poll?.cancel();

    _poll = Timer.periodic(_pollGap, (_) {
      // มีหน้าอื่นทับอยู่ (เช่นหน้ารายละเอียดที่ดึงของตัวเองอยู่แล้ว)
      // ยิงไปก็ไม่มีใครเห็น รอจนกลับมาหน้าหลักก่อน
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;

      _refreshIfStale();
    });
  }

  /// ดึงใหม่เงียบ ๆ เว้นแต่เพิ่งดึงไปไม่นาน
  void _refreshIfStale() {
    final last = _lastLoad;
    if (last != null && DateTime.now().difference(last) < _minGap) return;

    _load();
  }

  /// โหลดเงียบ ๆ พังก็แค่ไม่โชว์
  ///
  /// นี่เป็นของแถมบนหน้าหลัก ไม่ใช่เนื้อหาหลัก ขึ้นกล่องแดงว่าโหลดเคสไม่ได้
  /// จะไปกวนคนที่เข้ามาใช้เมนูอื่นซึ่งไม่เคยแจ้งเคสเลยด้วยซ้ำ
  Future<void> _load() async {
    // จดเวลาไว้ก่อนยิง ไม่ใช่หลังได้ผล ระหว่างรออยู่จะได้ไม่มีใครยิงซ้ำเข้ามา
    _lastLoad = DateTime.now();

    try {
      final jobs = await fetchCaseJobs();
      final statuses = await _statusList();
      if (!mounted) return;

      final open = jobs.where((e) => !e.isClosed).toList();

      // เคสที่รอเราตรวจแล้วกดปิดขึ้นก่อน ที่เหลือคงลำดับใหม่สุดขึ้นก่อนตามเดิม
      // หน้าหลักโชว์ได้แค่ไม่กี่ใบ ใบที่รอมือเราต้องไม่ใช่ใบที่ถูกตัดทิ้ง
      final waiting = open.where((e) => e.needsConfirm);
      final rest = open.where((e) => !e.needsConfirm);

      setState(() {
        _open = [...waiting, ...rest];
        _statuses = statuses;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _open = const []);
    }
  }

  /// ตารางแปลรหัสสถานะ ไม่มีก็ยังโชว์การ์ดได้ แค่เห็นเป็นรหัสดิบ
  Future<List<ItCaseStatus>> _statusList() async {
    try {
      return await fetchCaseStatuses();
    } catch (_) {
      return const [];
    }
  }

  /// ไปหน้ารายละเอียด กลับมาแล้วดึงใหม่ เผื่อเพิ่งกดปิดงานไป
  Future<void> _open1(ItCaseJob job) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItCaseJobDetailPage(job: job, statuses: _statuses),
      ),
    );

    if (!mounted) return;
    _load();
  }

  Future<void> _openAll() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ItCaseStatusPage()));

    if (!mounted) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    // ไม่มีเคสค้างก็ไม่ต้องกินที่บนหน้าหลักเลย ไม่ใช่ขึ้นกล่องว่าง
    if (_open.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final shown = _open.take(_maxCards).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pending_actions,
                size: 17,
                color: AppColors.caseIcon,
              ),
              const SizedBox(width: 6),
              Text(
                'เคสที่ยังไม่ปิด',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 6),
              // ตัวเลขคือจำนวนที่ค้างทั้งหมด ไม่ใช่จำนวนการ์ดที่วางอยู่ข้างล่าง
              // เห็นเลข 7 แต่มีสามใบ ก็รู้เองว่าที่เหลือไปดูต่อได้ที่ปุ่มขวามือ
              _Count(value: _open.length),
              const Spacer(),
              _AllButton(onTap: _openAll),
            ],
          ),
          const SizedBox(height: 10),

          for (var i = 0; i < shown.length; i++) ...[
            ItCaseJobCard(
              job: shown[i],
              statuses: _statuses,
              onTap: shown[i].id.isEmpty ? null : () => _open1(shown[i]),
            ),
            // ใบสุดท้ายไม่ต้องเว้นท้าย ไม่งั้นจะมีช่องว่างลอยก่อนจบหน้า
            if (i != shown.length - 1) const SizedBox(height: AppSizes.gap),
          ],
        ],
      ),
    );
  }
}

/// ตัวเลขจำนวนเคสค้างข้างหัวข้อ
class _Count extends StatelessWidget {
  final int value;

  const _Count({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.caseBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$value',
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: AppColors.caseIcon,
        ),
      ),
    );
  }
}

/// ลิงก์มุมขวาบนของกลุ่ม พาไปหน้ารายการเคสทั้งหมด
///
/// อยู่บรรทัดเดียวกับหัวข้อ ไม่ใช่แถวท้ายกลุ่ม เพราะการ์ดที่วางอยู่ข้างล่างมี
/// ได้หลายใบ ปุ่มที่ต่อท้ายใบสุดท้ายจะเลื่อนตำแหน่งไปมาตามจำนวนเคส
/// อยู่ข้างหัวข้อแล้วมันนิ่ง หาเจอที่เดิมทุกครั้ง
class _AllButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AllButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.caseIcon,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ดูทั้งหมด',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          Icon(Icons.chevron_right, size: 16),
        ],
      ),
    );
  }
}
