import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:claim/page/tracking/api.dart';
import 'package:claim/page/tracking/models.dart';
import 'package:claim/page/tracking/tracking_cache.dart';
import 'package:claim/page/tracking/tracking_style.dart';
import 'package:claim/page/tracking/tracking_timeline.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/widgets/app_card.dart';
import 'package:claim/widgets/barcode_scanner.dart';
import 'package:claim/widgets/info_row.dart';
import 'package:claim/widgets/state_views.dart';
import 'package:claim/utils/app_icons.dart';

/// จัดรูปเลขเอกสารตอนพิมพ์: ตัวพิมพ์ใหญ่ล้วน ไม่มีช่องว่าง
///
/// ⚠️ ต้องคำนวณตำแหน่งเคอร์เซอร์ใหม่เอง ห้ามใช้ `newValue.copyWith(text: ...)`
/// เฉย ๆ เพราะ selection ของเดิมจะชี้เกินความยาวข้อความที่สั้นลง แล้ว
/// Flutter จะ assert ตาย ("Range start 13 is out of text of length 11")
/// เกิดจริงตอนผู้ใช้ paste เลขที่มีช่องว่าง เช่น "HVR 0126 0909"
final TextInputFormatter trackingCodeFormatter =
    TextInputFormatter.withFunction((_, newValue) {
      final raw = newValue.text;
      final text = raw.toUpperCase().replaceAll(' ', '');
      final cursor = newValue.selection.baseOffset;

      // ขยับเคอร์เซอร์ซ้ายเท่าจำนวนช่องว่างที่ถูกตัดออกก่อนตำแหน่งมัน
      // ไม่งั้น paste กลางข้อความแล้วเคอร์เซอร์จะเลื่อนไปผิดที่
      final int offset;
      if (cursor < 0) {
        offset = text.length;
      } else {
        final head = raw.substring(0, cursor.clamp(0, raw.length));
        final removed = head.length - head.replaceAll(' ', '').length;
        offset = (cursor - removed).clamp(0, text.length);
      }

      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: offset),
      );
    });

/// สถานะของหน้าจอ
enum _ViewState { idle, loading, loaded, notFound, error }

/// หน้าเช็คสถานะพัสดุ อ่านอย่างเดียว
class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  final TextEditingController _codeController = TextEditingController();

  _ViewState _state = _ViewState.idle;
  TrackingResult? _result;
  String? _error;
  String _lastCode = '';

  /// เวลาที่ข้อมูลบนจอถูกดึงมา null เมื่อยังไม่มีผลลัพธ์
  DateTime? _fetchedAt;

  @override
  void initState() {
    super.initState();

    // กลับเข้าหน้านี้อีกครั้งแล้วต้องเห็นของเดิมทันที ไม่ต้องพิมพ์เลขซ้ำ
    final cache = TrackingCache.I;
    if (cache.hasData) {
      _lastCode = cache.code!;
      _codeController.text = cache.code!;
      _result = cache.result;
      _fetchedAt = cache.fetchedAt;
      _state = _ViewState.loaded;

      // สถานะพัสดุเปลี่ยนได้ตลอด ของที่ค้างไว้อาจเก่าไปแล้ว จึงดึงใหม่
      // เบื้องหลังโดยไม่ขึ้นวงหมุนทับข้อมูลที่ผู้ใช้กำลังอ่าน
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshQuietly());
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() => FocusScope.of(context).unfocus();

  Future<void> _search() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _state = _ViewState.error;
        _error = 'กรุณากรอกเลขเอกสาร';
        _result = null;
      });
      return;
    }

    _dismissKeyboard();
    _lastCode = code;
    await _run();
  }

  /// สแกนบาร์โค้ดบนใบพัสดุแล้วค้นหาต่อให้เลย
  ///
  /// ไม่ต้องกดปุ่มค้นหาซ้ำ เพราะคนที่ยกกล้องขึ้นสแกนย่อมอยากเห็นสถานะทันที
  Future<void> _scan() async {
    final code = await openBarcodeScannerPage(
      context,
      title: 'สแกนเลขเอกสาร',
      hint: 'วางบาร์โค้ดให้อยู่กลางจอ ระบบจะค้นหาให้อัตโนมัติ',
    );
    if (code == null || !mounted) return;

    // การเซ็ต controller.text ตรง ๆ ไม่ผ่าน inputFormatters ของ TextField
    // จึงยัดผ่าน formatter เองเพื่อให้ค่าที่สแกนมาถูกจัดรูปแบบเดียวกับที่พิมพ์
    // (บาร์โค้ดบางใบอ่านมาได้ตัวพิมพ์เล็กหรือมีช่องว่างคั่น)
    _codeController.value = trackingCodeFormatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: code,
        selection: TextSelection.collapsed(offset: code.length),
      ),
    );

    await _search();
  }

  /// ยิงด้วยเลขที่ค้นครั้งล่าสุด ใช้ร่วมกันทั้งปุ่มค้นหาและปุ่มลองใหม่
  Future<void> _run() async {
    setState(() {
      _state = _ViewState.loading;
      _error = null;
      _result = null;
    });

    try {
      final result = await fetchTracking(code: _lastCode);
      if (!mounted) return;
      TrackingCache.I.save(code: _lastCode, result: result);
      setState(() {
        _result = result;
        _fetchedAt = TrackingCache.I.fetchedAt;
        _state = _ViewState.loaded;
      });
    } on TrackingException catch (e) {
      if (!mounted) return;
      // ค้นใหม่แล้วไม่เจอ ของเก่าที่ค้างไว้ใช้ไม่ได้อีก ต้องล้างทิ้ง
      // ไม่งั้นกลับเข้าหน้ามาใหม่จะเห็นผลของเลขที่เลิกค้นไปแล้ว
      TrackingCache.I.clear();
      setState(() {
        _error = e.message;
        _fetchedAt = null;
        _state = e.notFound ? _ViewState.notFound : _ViewState.error;
      });
    } catch (_) {
      if (!mounted) return;
      TrackingCache.I.clear();
      setState(() {
        _error = 'เช็คสถานะไม่สำเร็จ กรุณาลองใหม่';
        _fetchedAt = null;
        _state = _ViewState.error;
      });
    }
  }

  /// ดึงข้อมูลใหม่เบื้องหลังโดยไม่รบกวนสิ่งที่ผู้ใช้กำลังอ่าน
  ///
  /// ไม่ขึ้นวงหมุนและไม่ล้างของเดิม ถ้าดึงไม่สำเร็จก็เงียบไว้ ปล่อยให้ดูของเก่า
  /// ต่อได้ เพราะผู้ใช้ไม่ได้สั่งให้ดึง การเด้ง error ใส่หน้าที่มีข้อมูลอยู่แล้ว
  /// จะเป็นการทำให้แย่ลงกว่าไม่ทำอะไร
  Future<void> _refreshQuietly() async {
    if (_lastCode.isEmpty) return;

    try {
      final result = await fetchTracking(code: _lastCode);
      if (!mounted) return;
      TrackingCache.I.save(code: _lastCode, result: result);
      setState(() {
        _result = result;
        _fetchedAt = TrackingCache.I.fetchedAt;
        _state = _ViewState.loaded;
      });
    } catch (_) {
      // เงียบไว้ตามที่อธิบายข้างบน
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เช็คสถานะพัสดุ')),
      body: GestureDetector(
        onTap: _dismissKeyboard,
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            _SearchBar(
              controller: _codeController,
              enabled: _state != _ViewState.loading,
              onSubmit: _search,
              onScan: _scan,
            ),
            const Divider(height: 1),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _ViewState.idle:
        return const Center(
          child: EmptyStateView(
            message: 'กรอกเลขเอกสารเพื่อเช็คสถานะ',
            icon: Icons.local_shipping_outlined,
          ),
        );

      case _ViewState.loading:
        return const LoadingStateView();

      case _ViewState.notFound:
        return Center(
          child: EmptyStateView(
            message: _error ?? 'ไม่พบข้อมูลพัสดุ',
            icon: Icons.search_off,
          ),
        );

      case _ViewState.error:
        return ErrorStateView(
          message: _error ?? 'เช็คสถานะไม่สำเร็จ',
          onRetry: _run,
        );

      case _ViewState.loaded:
        final result = _result;
        if (result == null) return const SizedBox.shrink();
        return ListView(
          padding: AppSizes.pagePadding,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            // ผลที่ค้างจากรอบก่อนหน้าตาเหมือนของใหม่เอี่ยม ต้องบอกเวลาที่ดึงมา
            // ไม่งั้นผู้ใช้ไม่มีทางรู้ว่ากำลังอ่านข้อมูลของเมื่อไร
            if (_fetchedAt != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'ข้อมูลเมื่อ ${formatTrackingTime(_fetchedAt!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            _SummaryCard(result: result),
            if (result.events.isNotEmpty) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'ประวัติสถานะ',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TrackingTimeline(events: result.events),
            ],
          ],
        );
    }
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmit;
  final VoidCallback onScan;

  const _SearchBar({
    required this.controller,
    required this.enabled,
    required this.onSubmit,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(10);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => TextField(
                controller: controller,
                enabled: enabled,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.search,
                inputFormatters: [trackingCodeFormatter],
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'เลขเอกสาร / เลขร้านค้า',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  prefixIcon: IconButton(
                    tooltip: 'สแกนบาร์โค้ด',
                    icon: const Icon(AppIcons.scan, size: 20),
                    color: scheme.primary,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    onPressed: enabled ? onScan : null,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 40,
                  ),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'ล้างค่า',
                          icon: const Icon(Icons.close, size: 16),
                          visualDensity: VisualDensity.compact,
                          onPressed: enabled ? controller.clear : null,
                        ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: radius,
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: radius,
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: radius,
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
                onSubmitted: (_) => onSubmit(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: enabled ? onSubmit : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(borderRadius: radius),
              ),
              child: const Icon(Icons.search, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final TrackingResult result;

  const _SummaryCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final code = result.currentStatusCode;
    final color = trackingStatusColor(code);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(trackingStatusIcon(code), color: color, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'สถานะปัจจุบัน',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result.currentStatus ?? 'ไม่ระบุสถานะ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InfoRow(
            icon: Icons.local_shipping_outlined,
            value: result.tpTracking,
          ),
          InfoRow(icon: Icons.storefront_outlined, value: result.cusTracking),
          InfoRow(
            icon: Icons.schedule,
            value: formatTrackingDate(result.currentStatusTime),
          ),
          InfoRow(
            icon: Icons.location_on_outlined,
            value: result.currentStatusLocation,
          ),
        ],
      ),
    );
  }
}
