import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:claim/page/itcase/itcase_api.dart';
import 'package:claim/page/itcase/itcase_appbar.dart';
import 'package:claim/page/itcase/itcase_close_dialog.dart';
import 'package:claim/page/itcase/itcase_image.dart';
import 'package:claim/page/itcase/itcase_job_card.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/mobile_api.dart';
import 'package:claim/widgets/app_card.dart';
import 'package:claim/widgets/state_views.dart';

/// รายละเอียดการดำเนินงานของเคสหนึ่งใบ
///
/// เรียงตามป๊อปอัปในเว็บของระบบเดียวกัน คือข้อมูลการแจ้งก่อน แล้วค่อยเป็นฝั่ง
/// ที่ทีม IT ทำ ไม่ใช่เส้นเวลาหลายขั้น เพราะ `jobdetails` ตอบมาใบเดียว
///
/// หัวหน้าจอวาดจากข้อมูลที่หน้ารายการมีอยู่แล้ว ไม่ต้องรอเน็ตก่อนเห็นว่าเปิด
/// เคสไหนอยู่ ที่เหลือเติมเข้ามาเมื่อโหลดเสร็จ
class ItCaseJobDetailPage extends StatefulWidget {
  final ItCaseJob job;

  /// ตารางอ้างอิงที่หน้ารายการโหลดไว้แล้ว ส่งต่อมาแปลรหัสเป็นข้อความ
  ///
  /// ว่างได้เมื่อเข้ามาจากป๊อปอัปตอนแจ้งเคสสำเร็จ ตรงนั้นไม่มีตารางสถานะอยู่
  /// ในมือ หน้านี้จะโหลดเองให้ ไม่ใช่โชว์รหัสดิบอย่าง `OP` ให้ผู้แจ้งอ่าน
  final List<ItCaseStatus> statuses;
  final List<ItCaseSolveType> types;

  const ItCaseJobDetailPage({
    super.key,
    required this.job,
    this.statuses = const [],
    this.types = const [],
  });

  @override
  State<ItCaseJobDetailPage> createState() => _ItCaseJobDetailPageState();
}

class _ItCaseJobDetailPageState extends State<ItCaseJobDetailPage>
    with WidgetsBindingObserver {
  /// ห่างจากรอบก่อนน้อยกว่านี้ถือว่าเพิ่งดึงไป ไม่ต้องยิงซ้ำ
  ///
  /// กันคนที่สลับไปไลน์แล้วสลับกลับมารัว ๆ ยิง API ทุกครั้งที่สลับ
  static const Duration _minGap = Duration(seconds: 30);

  /// ระยะห่างของรอบดึงซ้ำเงียบ ๆ ระหว่างเปิดหน้านี้ค้างไว้
  ///
  /// สถานะเปลี่ยนตอนเจ้าหน้าที่ IT กดในเว็บ ซึ่งเกิดในสเกลสิบนาทีขึ้นไป
  /// ยิงถี่กว่านี้ได้ผลเท่าเดิมแต่กินแบตกับเน็ตของผู้ใช้ฟรี ๆ
  static const Duration _pollGap = Duration(seconds: 45);

  ItCaseJobDetail? _detail;
  bool _loading = true;
  String? _error;

  /// กำลังส่งคำยืนยันปิดงาน ระหว่างนี้ปุ่มต้องกดซ้ำไม่ได้
  bool _closing = false;

  /// ตารางสถานะที่ใช้จริง เริ่มจากที่หน้ารายการส่งมา ไม่มีก็โหลดเองทีหลัง
  late List<ItCaseStatus> _statuses = widget.statuses;

  /// เวลาที่ยิงรอบล่าสุด ใช้กันยิงถี่ ไม่ใช่เวลาที่ได้ข้อมูลมา
  DateTime? _lastLoad;

  /// เวลาที่ได้ข้อมูลชุดที่โชว์อยู่มาจริง ๆ เอาไปบอกใต้แถบความคืบหน้า
  DateTime? _updatedAt;

  Timer? _poll;

  /// เคสปิดแล้วหรือยัง ปิดแล้วไม่ต้องดึงซ้ำ ไม่มีอะไรให้รออีก
  bool get _isClosed =>
      (_detail?.stage ?? widget.job.stage) == ItCaseStage.done;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _loadStatuses();
    _startPolling();
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// กลับเข้าแอปมาแล้วเลขบนจอเป็นของเก่า ดึงใหม่เงียบ ๆ ทับให้เลย
  ///
  /// คนมักสลับไปถามทีม IT ในไลน์แล้วสลับกลับมาดูว่าขยับหรือยัง
  /// ออกจากหน้าจอไปแล้วก็หยุดรอบอัตโนมัติไว้ก่อน ไม่ต้องยิงตอนไม่มีคนดู
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

  void _refreshIfStale() {
    final last = _lastLoad;
    if (last != null && DateTime.now().difference(last) < _minGap) return;

    _load(quiet: true);
  }

  /// ตั้งรอบดึงซ้ำเงียบ ๆ ระหว่างที่หน้านี้เปิดค้างอยู่
  ///
  /// คนที่เพิ่งแจ้งเคสแล้วเปิดค้างรอจะเห็นแถบขยับเอง โดยไม่ต้องดึงลงรีเฟรช
  void _startPolling() {
    _poll?.cancel();
    if (_isClosed) return;

    _poll = Timer.periodic(_pollGap, (timer) {
      // เคสเพิ่งเดินไปถึงปิดงานระหว่างรอบ เลิกดึงตั้งแต่ตรงนี้
      if (_isClosed) {
        timer.cancel();
        _poll = null;
        return;
      }
      _load(quiet: true);
    });
  }

  /// ตารางแปลรหัสสถานะ โหลดเฉพาะตอนที่ไม่มีใครส่งมาให้
  ///
  /// ล่มก็ไม่ต้องขึ้น error ทั้งหน้า หัวเรื่องโชว์รหัสดิบแทนได้ เนื้อหาข้างล่าง
  /// ไม่ได้พึ่งตารางนี้เลย
  Future<void> _loadStatuses() async {
    if (_statuses.isNotEmpty) return;

    try {
      final statuses = await fetchCaseStatuses();
      if (!mounted || statuses.isEmpty) return;
      setState(() => _statuses = statuses);
    } catch (_) {
      // เงียบไว้ตั้งใจ ดูหมายเหตุข้างบน
    }
  }

  /// ดึงรายละเอียดของเคสใบนี้
  ///
  /// [quiet] คือรอบที่ผู้ใช้ไม่ได้สั่งเอง ทั้งดึงลงรีเฟรช ทั้งตอนกลับเข้าแอป
  /// ทั้งรอบอัตโนมัติ รอบพวกนี้พังแล้วต้องคงของเดิมบนจอไว้ ไม่ใช่ล้างทิ้งเป็น
  /// หน้า error ทั้งที่ผู้ใช้กำลังอ่านอยู่ดี ๆ เน็ตสะดุดวินาทีเดียวไม่ใช่เหตุ
  /// ให้ข้อมูลที่ได้มาแล้วหายไป
  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    _lastLoad = DateTime.now();

    try {
      final detail = await fetchCaseJobDetail(widget.job.id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _updatedAt = DateTime.now();
        _error = null;
        _loading = false;
      });
    } on MobileApiException catch (e) {
      if (!mounted || _keepOnScreen(quiet)) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || _keepOnScreen(quiet)) return;
      setState(() {
        _error = 'โหลดรายละเอียดไม่สำเร็จ กรุณาลองใหม่';
        _loading = false;
      });
    }
  }

  /// รอบเบื้องหลังที่พังทั้งที่มีข้อมูลอยู่แล้ว ปล่อยผ่านไปเงียบ ๆ

  /// ถามผลการตรวจงานแล้วส่งไป ใช้ป๊อปอัปตัวเดียวกับปุ่มบนการ์ด
  ///
  /// เก็บคะแนนกับความเห็นตอนนี้เพราะเป็นจังหวะเดียวที่ผู้แจ้งเพิ่งเห็นผลงาน
  /// สด ๆ ถามทีหลังคนก็ลืมแล้วว่างานเป็นยังไง
  Future<void> _confirmClose() async {
    setState(() => _closing = true);

    try {
      final sent = await runItCaseCloseFlow(context, widget.job.id);
      if (!sent || !mounted) return;

      // ดึงใหม่เพื่อให้สถานะกับ % บนหน้าจอเดินไปที่ปลายทางจริง ๆ
      await _load(quiet: true);
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  bool _keepOnScreen(bool quiet) => quiet && _detail != null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: itCaseAppBar(title: 'รายละเอียดเคส'),
      body: RefreshIndicator(
        onRefresh: () => _load(quiet: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSizes.pagePadding,
          children: [
            _head(scheme),
            const SizedBox(height: AppSizes.gap),
            ..._body(),
          ],
        ),
      ),
    );
  }

  /// เลขเอกสารกับสถานะล่าสุด ใช้ของจากหน้ารายการไปก่อนจนกว่าจะโหลดเสร็จ
  Widget _head(ColorScheme scheme) {
    final detail = _detail;

    final id = detail?.id.isNotEmpty == true ? detail!.id : widget.job.id;
    final stage = detail?.stage ?? widget.job.stage;
    final percent = detail?.progress ?? widget.job.progress;
    final status = detail?.statusTextFrom(_statuses) ?? '';
    final color = itCaseStageColor(stage, scheme);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            id.isEmpty ? 'ไม่มีเลขเอกสาร' : id,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.caseIcon,
            ),
          ),
          const SizedBox(height: 8),

          // สถานะเป็นแถบเต็มความกว้าง ไม่ใช่ป้ายเล็กแบบบนการ์ดในรายการ
          // หน้านี้เปิดมาเพื่อดูอันนี้โดยเฉพาะ ไม่ต้องประหยัดที่
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color),
            ),
            child: Text(
              status.isNotEmpty ? status : widget.job.statusTextFrom(_statuses),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ItCaseProgressBar(percent: percent, color: color),

          // บอกเวลาที่ข้อมูลชุดนี้มาถึง ไม่งั้นแถบที่ไม่ขยับหลายชั่วโมงจะทำให้
          // ผู้แจ้งสงสัยว่าแอปค้างหรือทีม IT ไม่ทำงานกันแน่
          if (_updatedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'อัปเดตเมื่อ ${DateFormat('HH:mm').format(_updatedAt!)}',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _body() {
    if (_loading) return const [SizedBox(height: 40), LoadingStateView()];

    final error = _error;
    if (error != null) {
      return [
        const SizedBox(height: 20),
        ErrorStateView(message: error, onRetry: _load),
      ];
    }

    final detail = _detail;
    if (detail == null) {
      return const [
        SizedBox(height: 30),
        EmptyStateView(
          icon: Icons.description_outlined,
          message: 'ไม่พบรายละเอียดของเคสนี้',
        ),
      ];
    }

    final type = detail.typeTextFrom(widget.types);
    final program = detail.programTextFrom(widget.types);
    final created = detail.createdAt;

    return [
      _Section(
        title: 'ข้อมูลการแจ้ง',
        children: [
          if (created != null)
            _Field(
              label: 'วันที่แจ้ง',
              value: DateFormat('d MMM y HH:mm', 'th').format(created),
            ),
          if (detail.informer.isNotEmpty)
            _Field(label: 'ผู้แจ้ง', value: detail.informer),
          if (type.isNotEmpty) _Field(label: 'ประเภทปัญหา', value: type),
          _Field(
            label: 'ระบบหรือโปรแกรมที่เป็นปัญหา',
            // เว็บโชว์ "ไม่ระบุ" ไม่ใช่ปล่อยว่าง เคสส่วนใหญ่ไม่ได้ผูกโปรแกรม
            value: program.isEmpty ? 'ไม่ระบุ' : program,
          ),
          if (detail.description.isNotEmpty)
            _Field(
              label: 'รายละเอียด',
              value: detail.description,
              strong: true,
            ),
          // ปกติ job_description เป็นตัวเดียวกับรายละเอียดข้างบนแล้ว
          // ส่งมาไม่เหมือนกันเมื่อไหร่ค่อยโชว์เพิ่ม ไม่ใช่โชว์ซ้ำสองบรรทัด
          if (detail.jobDescription.isNotEmpty &&
              detail.jobDescription != detail.description)
            _Field(
              label: 'รายละเอียดงาน',
              value: detail.jobDescription,
              strong: true,
            ),
          if (detail.image.isNotEmpty)
            _Field(label: 'ภาพประกอบ', image: detail.image),
          // ยังไม่ได้ให้คะแนนก็ไม่ต้องขึ้นดาวว่างห้าดวงให้ดูเหมือนได้ศูนย์
          if (detail.rating > 0)
            _Field(label: 'คะแนนที่ให้', rating: detail.rating),
        ],
      ),

      // ฝั่งที่ทีม IT ทำ ยังไม่มีใครลงมือก็ไม่ต้องขึ้นการ์ดเปล่า
      if (detail.solveNote.isNotEmpty ||
          detail.solveImage.isNotEmpty ||
          detail.officer.isNotEmpty) ...[
        const SizedBox(height: AppSizes.gap),
        _Section(
          title: 'การดำเนินงาน',
          children: [
            if (detail.solveNote.isNotEmpty)
              _Field(
                label: 'รายละเอียดการแก้ไข',
                value: detail.solveNote,
                strong: true,
                // เขียวเพราะเป็นฝั่งที่แก้ให้แล้ว คนละฝั่งกับปัญหาที่แจ้งมา
                accent: AppColors.success,
              ),
            if (detail.solveImage.isNotEmpty)
              _Field(label: 'รูปภาพปิดงาน', image: detail.solveImage),
            if (detail.officer.isNotEmpty)
              _Field(label: 'ผู้รับงาน', value: detail.officer),
          ],
        ),
      ],

      // ทีม IT แก้เสร็จแล้ว รอผู้แจ้งตรวจ ปุ่มขึ้นเฉพาะตอนนี้เท่านั้น
      // ปิดไปแล้ว (CF) หรือยังทำไม่เสร็จ ก็ไม่มีอะไรให้ยืนยัน
      if (detail.statusId.toUpperCase() == kItCaseWaitConfirmStatusId) ...[
        const SizedBox(height: 18),
        _CloseButton(busy: _closing, onPressed: _confirmClose),
      ],
    ];
  }
}

/// การ์ดหนึ่งกลุ่มพร้อมหัวข้อ
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.caseIcon,
            ),
          ),
          Divider(height: 16, color: scheme.outlineVariant),
          ...children,
        ],
      ),
    );
  }
}

/// หนึ่งช่องข้อมูล ชื่อช่องอยู่บน ค่าอยู่ล่าง แบบเดียวกับฟอร์มในเว็บ
///
/// ใส่ [image] แทน [value] เมื่อค่าเป็นรูป
/// หนึ่งช่องข้อมูล ชื่อช่องอยู่บน ค่าอยู่ล่าง แบบเดียวกับฟอร์มในเว็บ
///
/// ใส่ [image] แทน [value] เมื่อค่าเป็นรูป หรือ [rating] เมื่อค่าเป็นดาว
///
/// [strong] ใช้กับสองช่องที่เป็นเนื้อเรื่องจริง ๆ ของเคส คือปัญหาที่แจ้งกับ
/// สิ่งที่ทีม IT ทำให้ ที่เหลือเป็นข้อมูลประกอบ (วันที่ ชื่อคน ประเภท) ซึ่งถ้า
/// ตัวหนังสือเท่ากันหมด คนจะกวาดตาแล้วไม่รู้ว่าต้องอ่านบรรทัดไหน
class _Field extends StatelessWidget {
  final String label;
  final String? value;
  final String? image;
  final int? rating;

  final bool strong;

  /// สีแถบซ้ายตอน [strong] ปล่อยว่างจะใช้สีประจำหน้าแจ้งเคส
  final Color? accent;

  const _Field({
    required this.label,
    this.value,
    this.image,
    this.rating,
    this.strong = false,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          _value(scheme),
        ],
      ),
    );
  }

  Widget _value(ColorScheme scheme) {
    final source = image;
    if (source != null) return ItCaseImage(source: source);

    final score = rating;
    if (score != null) return _Stars(score: score);

    final text = value ?? '';
    if (!strong) {
      return Text(
        text,
        style: TextStyle(fontSize: 14, height: 1.4, color: scheme.onSurface),
      );
    }

    final color = accent ?? AppColors.caseIcon;

    // แถบสีต้องโดนตัดตามมุมโค้ง จึงต้องครอบด้วย ClipRRect ไม่ใช่ใส่ Border
    // ด้านเดียวใน BoxDecoration ที่มี borderRadius (Flutter ไม่ยอมให้ทำ)
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: color),
            Expanded(
              child: Container(
                color: color.withValues(alpha: 0.07),
                padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                child: Text(
                  text.isEmpty ? '-' : text,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ดาว 1-5 ดวงที่ผู้แจ้งให้ไว้
class _Stars extends StatelessWidget {
  final int score;

  const _Stars({required this.score});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= score ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 22,
            color: i <= score ? AppColors.pending : scheme.outlineVariant,
          ),
        const SizedBox(width: 6),
        Text(
          '$score/5',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// ปุ่มยืนยันปิดงาน ขึ้นเฉพาะตอนที่ทีม IT แก้เสร็จแล้วรอผู้แจ้งตรวจ
///
/// เต็มความกว้างและเป็นสีเขียวเพราะเป็นงานเดียวที่หน้านี้ให้ทำ ถ้าทำเป็นปุ่ม
/// เล็ก ๆ ปนกับเนื้อหา คนจะเลื่อนผ่านแล้วเคสค้างอยู่ที่ "รอตรวจรับ" ทั้งที่
/// เรื่องจบไปแล้ว
class _CloseButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onPressed;

  const _CloseButton({required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        // กดค้างไว้ระหว่างส่งไม่ได้ ไม่งั้นยิงซ้ำสองรอบ
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
        ),
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.task_alt),
        label: Text(busy ? 'กำลังปิดงาน...' : 'ตรวจสอบแล้ว ปิดงาน'),
      ),
    );
  }
}
