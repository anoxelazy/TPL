import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:claim/page/tracking/api.dart';
import 'package:claim/page/tracking/models.dart';
import 'package:claim/page/tracking/tracking_cache.dart';
import 'package:claim/page/tracking/tracking_history.dart';
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

  /// เลขที่เช็คเจอแล้วในวันนี้ ใหม่สุดอยู่หน้า
  List<TrackingHistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();

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

  Future<void> _loadHistory() async {
    final entries = await TrackingHistory.load();
    if (mounted) setState(() => _history = entries);
  }

  /// เก็บเฉพาะเลขที่ค้นเจอ เลขที่พิมพ์ผิดจนหาไม่เจอไม่ควรค้างอยู่ในประวัติ
  Future<void> _remember(String code) async {
    final entries = await TrackingHistory.add(code);
    if (mounted) setState(() => _history = entries);
  }

  Future<void> _forget(String code) async {
    final entries = await TrackingHistory.remove(code);
    if (mounted) setState(() => _history = entries);
  }

  /// กดเลขในประวัติแล้วเช็คให้เลย ไม่ต้องกดปุ่มค้นหาซ้ำ
  Future<void> _searchFromHistory(String code) async {
    _codeController.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    await _search();
  }

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

  /// เปิดรายการเลขที่เช็ควันนี้ เลือกเลขไหนก็เช็คเลขนั้นต่อเลย
  Future<void> _openHistory() async {
    _dismissKeyboard();
    final code = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _HistorySheet(
        entries: _history,
        currentCode: _lastCode,
        onDelete: _forget,
      ),
    );
    if (code != null && mounted) await _searchFromHistory(code);
  }

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
      _remember(_lastCode);
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

  /// ดึงลงเพื่อรีเฟรช
  ///
  /// ต่างจาก [_refreshQuietly] ตรงที่ผู้ใช้สั่งเอง ถ้าล้มต้องบอก ไม่งั้นวงหมุน
  /// หายไปเฉย ๆ แล้วผู้ใช้จะเข้าใจว่าได้ข้อมูลล่าสุดแล้ว แต่ยังคงของเดิมไว้บนจอ
  /// ไม่สลับไปหน้า error เพราะของเดิมยังอ่านได้อยู่
  Future<void> _pullRefresh() async {
    if (_lastCode.isEmpty) return;

    try {
      final result = await fetchTracking(code: _lastCode);
      if (!mounted) return;
      TrackingCache.I.save(code: _lastCode, result: result);
      setState(() {
        _result = result;
        _fetchedAt = TrackingCache.I.fetchedAt;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e is TrackingException
          ? e.message
          : 'รีเฟรชไม่สำเร็จ กรุณาลองใหม่';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เช็คสถานะพัสดุ'),
        actions: [
          // ยังไม่ได้เช็คเลขไหนวันนี้ก็ไม่มีอะไรให้ดู ซ่อนไว้ให้หัวโล่ง
          if (_history.isNotEmpty)
            IconButton(
              tooltip: 'เช็ควันนี้',
              onPressed: _state == _ViewState.loading ? null : _openHistory,
              icon: Badge.count(
                count: _history.length,
                child: const Icon(Icons.history),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
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
        return RefreshIndicator(
          onRefresh: _pullRefresh,
          child: _buildResult(result),
        );
    }
  }

  Widget _buildResult(TrackingResult result) {
    return ListView(
      // ผลสั้นกว่าจอก็ยังต้องดึงลงได้ ไม่งั้น RefreshIndicator ไม่ทำงาน
      physics: const AlwaysScrollableScrollPhysics(),
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
          const SizedBox(height: AppSizes.gap),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('สถานะ', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 14),
                TrackingTimeline(events: result.events),
              ],
            ),
          ),
        ],
      ],
    );
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
    final radius = BorderRadius.circular(AppSizes.innerRadius);

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

/// รายการเลขที่เช็ควันนี้ กดเลขเพื่อเช็คซ้ำ ปัดซ้ายเพื่อลบ
///
/// ถือสำเนารายการไว้เอง เพราะ sheet ไม่ได้ rebuild ตามหน้าหลักตอนลบ
class _HistorySheet extends StatefulWidget {
  final List<TrackingHistoryEntry> entries;

  /// เลขที่แสดงผลอยู่บนหน้าตอนนี้ ใช้ติดป้าย "กำลังดู"
  final String currentCode;
  final ValueChanged<String> onDelete;

  const _HistorySheet({
    required this.entries,
    required this.currentCode,
    required this.onDelete,
  });

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  late final List<TrackingHistoryEntry> _entries = [...widget.entries];

  void _delete(String code) {
    widget.onDelete(code);
    setState(() => _entries.removeWhere((e) => e.code == code));
    // ลบจนหมดแล้วไม่มีอะไรให้ดู ปิดไปเลยดีกว่าค้างหน้าว่าง
    if (_entries.isEmpty) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppSizes.innerRadius),
                  ),
                  child: Icon(
                    Icons.history,
                    color: scheme.onPrimaryContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'เช็ควันนี้',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(
                                AppSizes.pillRadius,
                              ),
                            ),
                            child: Text(
                              '${_entries.length}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: scheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'แตะเพื่อเช็คซ้ำ ปัดซ้ายเพื่อลบ ล้างเองเมื่อขึ้นวันใหม่',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final entry = _entries[i];
                return _AppearIn(
                  // ไล่กันเข้ามาทีละใบ ไม่โผล่พร้อมกันทั้งก้อน
                  delay: Duration(milliseconds: 40 * i.clamp(0, 8)),
                  child: _HistoryTile(
                    entry: entry,
                    isLatest: i == 0,
                    isCurrent: entry.code == widget.currentCode,
                    onTap: () => Navigator.pop(context, entry.code),
                    onDelete: () => _delete(entry.code),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// เลข 1 ใบในรายการ "เช็ควันนี้"
class _HistoryTile extends StatelessWidget {
  final TrackingHistoryEntry entry;
  final bool isLatest;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryTile({
    required this.entry,
    required this.isLatest,
    required this.isCurrent,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppSizes.innerRadius);
    final time = entry.checkedAt;

    return Dismissible(
      key: ValueKey(entry.code),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: scheme.error, borderRadius: radius),
        child: Icon(Icons.delete_outline, color: scheme.onError),
      ),
      child: Material(
        color: isCurrent
            ? scheme.primaryContainer.withValues(alpha: 0.5)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: isCurrent ? scheme.primary : scheme.outlineVariant,
                width: isCurrent ? 1.2 : 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_shipping_outlined,
                    size: 18,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (time != null) ...[
                            Icon(
                              Icons.schedule,
                              size: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                'เช็คเมื่อ ${formatTrackingTime(time)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                          if (isCurrent)
                            const _MiniTag(label: 'กำลังดู')
                          else if (isLatest)
                            const _MiniTag(label: 'ล่าสุด'),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;

  const _MiniTag({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSizes.pillRadius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: scheme.primary,
        ),
      ),
    );
  }
}

/// ค่อย ๆ จางเข้าพร้อมเลื่อนขึ้นเล็กน้อย หน่วงตาม [delay] ให้ไล่กันเข้ามา
class _AppearIn extends StatelessWidget {
  final Duration delay;
  final Widget child;

  const _AppearIn({required this.delay, required this.child});

  static const _duration = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    final total = _duration + delay;
    final start = delay.inMilliseconds / total.inMilliseconds;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      ),
    );
  }
}

/// การ์ดสรุปบนสุด: สถานะปัจจุบันตัวใหญ่บนแถบสีของสถานะ ตามด้วยเลขอ้างอิง
///
/// เลขพัสดุกับเลขร้านค้าหน้าตาคล้ายกันมาก ถ้าไม่มีป้ายกำกับผู้ใช้แยกไม่ออก
/// ว่าเลขไหนคือเลขอะไร จึงใส่ป้ายและปุ่มคัดลอกไว้ให้เอาไปส่งต่อได้เลย
class _SummaryCard extends StatelessWidget {
  final TrackingResult result;

  const _SummaryCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final code = result.currentStatusCode;
    final color = trackingStatusColor(code, scheme);
    final time = formatTrackingDate(result.currentStatusTime);

    return AppCard(
      clipContent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: color.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(trackingStatusIcon(code), color: color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.currentStatus ?? 'ไม่ระบุสถานะ',
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      if (time != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.currentStatusLocation != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 4),
                    child: InfoRow(
                      icon: Icons.location_on_outlined,
                      value: result.currentStatusLocation,
                    ),
                  ),
                _CodeRow(label: 'เลขพัสดุ', value: result.tpTracking),
                _CodeRow(label: 'เลขลูกค้า', value: result.cusTracking),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// เลขอ้างอิง 1 บรรทัด: ป้ายซ้าย เลขขวา ปุ่มคัดลอกท้ายสุด ซ่อนเองเมื่อไม่มีค่า
class _CodeRow extends StatelessWidget {
  final String label;
  final String? value;

  const _CodeRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = value;
    if (text == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          tooltip: 'คัดลอก$label',
          icon: const Icon(Icons.copy_rounded, size: 18),
          color: scheme.onSurfaceVariant,
          visualDensity: VisualDensity.compact,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text('คัดลอก$labelแล้ว')));
          },
        ),
      ],
    );
  }
}
