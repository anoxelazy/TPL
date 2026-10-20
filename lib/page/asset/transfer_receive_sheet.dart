/// รับของเข้าปลายทาง ทีละชิ้น
///
/// API รับทีละชิ้น (`POST /transfer/{no}/receive` รับ `asset_id` เดียว) แต่คน
/// ที่ยืนแกะกล่องอยู่มีของตรงหน้าหลายชิ้น แผ่นนี้จึงให้ติ๊กผลของทุกชิ้นก่อน
/// แล้วค่อยยิงทีละชิ้นตอนกดบันทึก
///
/// **ยิงทีละชิ้นแล้วชิ้นหนึ่งพัง ชิ้นก่อนหน้าที่สำเร็จไปแล้วไม่ถูกย้อน** —
/// เซิร์ฟเวอร์ไม่มี endpoint รับเป็นชุด จึงไม่มี transaction ครอบให้ แผ่นนี้
/// เลยรายงานว่าชิ้นไหนผ่านชิ้นไหนไม่ผ่าน แล้วให้คนกดลองใหม่เฉพาะที่ค้าง
///
/// คืน `true` เมื่อมีอย่างน้อยหนึ่งชิ้นบันทึกสำเร็จ
library;

import 'package:flutter/material.dart';

import 'package:claim/page/asset/transfer_api.dart';
import 'package:claim/page/asset/transfer_models.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/mobile_api.dart';

Future<bool?> showTransferReceiveSheet(
  BuildContext context, {
  required AssetTransferDoc doc,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    builder: (_) => _ReceiveSheet(doc: doc),
  );
}

class _ReceiveSheet extends StatefulWidget {
  final AssetTransferDoc doc;

  const _ReceiveSheet({required this.doc});

  @override
  State<_ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends State<_ReceiveSheet> {
  /// ผลที่เลือกไว้ของแต่ละชิ้น ยังไม่ได้ยิง
  final _outcomes = <String, String>{};
  final _notes = <String, TextEditingController>{};

  /// ชิ้นที่บันทึกสำเร็จไปแล้วในรอบนี้ ไม่ต้องยิงซ้ำถ้ากดบันทึกอีกที
  final _done = <String>{};

  /// ชิ้นที่ยิงแล้วไม่ผ่าน พร้อมเหตุผล
  final _failed = <String, String>{};

  bool _saving = false;

  List<AssetTransferLine> get _lines => widget.doc.pendingLines;

  @override
  void initState() {
    super.initState();
    // ตั้งต้นว่ารับปกติทุกชิ้น เพราะเป็นผลที่เกิดบ่อยสุด คนที่ของครบดีจะได้
    // กดบันทึกทีเดียวจบ ส่วนคนที่มีปัญหาค่อยไปเปลี่ยนเฉพาะชิ้นที่มีปัญหา
    for (final line in _lines) {
      _outcomes[line.assetId] = kReceiveOk;
    }
  }

  @override
  void dispose() {
    for (final controller in _notes.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _noteOf(String assetId) =>
      _notes.putIfAbsent(assetId, TextEditingController.new);

  /// ชิ้นที่เลือกผลที่มีปัญหาไว้ ต้องบังคับให้เขียนหมายเหตุ
  bool _needsNote(AssetTransferLine line) =>
      transferOutcomeIsProblem(_outcomes[line.assetId] ?? '');

  String? get _blocker {
    for (final line in _lines) {
      if (_done.contains(line.assetId)) continue;
      if (_needsNote(line) && _noteOf(line.assetId).text.trim().isEmpty) {
        return 'ชิ้นที่ไม่ได้รับตามปกติต้องเขียนหมายเหตุว่าเกิดอะไรขึ้น';
      }
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;

    final blocker = _blocker;
    if (blocker != null) {
      _toast(blocker);
      return;
    }

    setState(() {
      _saving = true;
      _failed.clear();
    });

    for (final line in _lines) {
      if (_done.contains(line.assetId)) continue;

      final outcome = _outcomes[line.assetId] ?? kReceiveOk;
      try {
        await receiveTransferLine(
          widget.doc.transferNo,
          assetId: line.assetId,
          outcome: outcome,
          note: _noteOf(line.assetId).text,
          // รับปกติแปลว่าสภาพดี ใส่ให้เลยตามตัวอย่างใน cheat sheet ไม่ต้องให้
          // คนกรอกซ้ำ ผลอื่นเว้นไว้ เพราะยังไม่รู้รหัสสภาพที่ backend ใช้ และ
          // หมายเหตุบังคับของชิ้นที่มีปัญหาก็อธิบายสภาพไว้แล้ว
          conditionIn: outcome == kReceiveOk ? kTransferConditionGood : '',
        );
        if (!mounted) return;
        setState(() => _done.add(line.assetId));
      } on MobileApiException catch (e) {
        if (!mounted) return;
        setState(() => _failed[line.assetId] = e.message);
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (_failed.isEmpty) {
      Navigator.of(context).pop(true);
      return;
    }
    _toast('บันทึกไม่ผ่าน ${_failed.length} ชิ้น ดูรายละเอียดในรายการ');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _close() => Navigator.of(context).pop(_done.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final remaining = _lines.where((e) => !_done.contains(e.assetId)).length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _close();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SizedBox(
          height: media.size.height * 0.85,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'รับของเข้า',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.doc.transferNo} · เหลือ $remaining ชิ้น',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'ปิด',
                      onPressed: _saving ? null : _close,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (_saving) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _lines.length,
                  separatorBuilder: (_, _) => const Divider(height: 20),
                  itemBuilder: (context, index) => _lineCard(_lines[index]),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: FilledButton.icon(
                    onPressed: _saving || remaining == 0 ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      _saving
                          ? 'กำลังบันทึก...'
                          : remaining == 0
                          ? 'บันทึกครบแล้ว'
                          : 'บันทึกการรับ $remaining ชิ้น',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lineCard(AssetTransferLine line) {
    final scheme = Theme.of(context).colorScheme;
    final saved = _done.contains(line.assetId);
    final failure = _failed[line.assetId];

    return Opacity(
      opacity: saved ? 0.55 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (saved)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AppColors.success,
                  ),
                ),
              Expanded(
                child: Text(
                  line.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [
              line.assetId,
              if (line.serialNo.isNotEmpty) 'S/N ${line.serialNo}',
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          if (failure != null) ...[
            const SizedBox(height: 6),
            Text(
              failure,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ],
          if (!saved) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in kReceiveOutcomes.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    labelStyle: const TextStyle(fontSize: 12),
                    visualDensity: VisualDensity.compact,
                    selected: _outcomes[line.assetId] == entry.key,
                    onSelected: _saving
                        ? null
                        : (_) => setState(
                            () => _outcomes[line.assetId] = entry.key,
                          ),
                  ),
              ],
            ),
            if (_needsNote(line)) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _noteOf(line.assetId),
                enabled: !_saving,
                maxLength: kTransferNoteMax,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'เกิดอะไรขึ้น',
                  hintText: 'เช่น กล่องบุบ หน้าจอมีรอยร้าว',
                  counterText: '',
                  isDense: true,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
