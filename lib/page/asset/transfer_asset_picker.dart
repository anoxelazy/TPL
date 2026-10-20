/// เลือกทรัพย์สินหลายชิ้นใส่ใบโอนย้าย
///
/// ต่างจาก [pickAssetBranch] / [pickAssetEmployee] ตรงที่เลือกได้หลายชิ้นและ
/// ของที่เลือกไปแล้วต้องยังเห็นอยู่แม้จะพิมพ์ค้นคำอื่น — คนที่ย้ายของสิบชิ้น
/// มักค้นทีละคำ (`notebook` แล้ว `printer`) ถ้าของที่เลือกไว้หายไปตอนเปลี่ยนคำค้น
/// เขาจะไม่รู้ว่าเลือกอะไรไปแล้วบ้าง
///
/// คืน null เมื่อปิดไปเฉย ๆ คืนลิสต์ใหม่เมื่อกดยืนยัน
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:claim/page/asset/asset_api.dart';
import 'package:claim/page/asset/asset_models.dart';
import 'package:claim/utils/mobile_api.dart';
import 'package:claim/widgets/state_views.dart';

Future<List<Asset>?> pickTransferAssets(
  BuildContext context, {
  List<Asset> selected = const [],
}) {
  return showModalBottomSheet<List<Asset>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AssetMultiPicker(selected: selected),
  );
}

class _AssetMultiPicker extends StatefulWidget {
  final List<Asset> selected;

  const _AssetMultiPicker({required this.selected});

  @override
  State<_AssetMultiPicker> createState() => _AssetMultiPickerState();
}

class _AssetMultiPickerState extends State<_AssetMultiPicker> {
  static const _debounce = Duration(milliseconds: 350);

  final _search = TextEditingController();

  Timer? _timer;
  int _round = 0;

  /// เก็บเป็น Map เพื่อกันเลือกชิ้นเดียวซ้ำ และคงลำดับที่เลือกไว้
  late final Map<String, Asset> _picked = {
    for (final asset in widget.selected) asset.id: asset,
  };

  List<Asset> _results = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onTyped(String _) {
    _timer?.cancel();
    setState(() => _loading = true);
    _timer = Timer(_debounce, _run);
  }

  Future<void> _run() async {
    final round = ++_round;

    try {
      final result = await fetchAssets(
        AssetQuery(keyword: _search.text.trim(), pageSize: 30),
      );
      if (!mounted || round != _round) return;

      setState(() {
        _results = result.items;
        _loading = false;
        _error = null;
      });
    } on MobileApiException catch (e) {
      if (!mounted || round != _round) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _toggle(Asset asset) {
    setState(() {
      if (_picked.containsKey(asset.id)) {
        _picked.remove(asset.id);
      } else {
        _picked[asset.id] = asset;
      }
    });
  }

  /// ของที่เลือกไว้แล้วแต่ไม่อยู่ในผลค้นรอบนี้ เอามาต่อท้ายให้ยังเห็น
  List<Asset> get _extraPicked {
    final shown = _results.map((e) => e.id).toSet();
    return _picked.values.where((e) => !shown.contains(e.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);

    return Padding(
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
                    child: Text(
                      'เลือกทรัพย์สิน',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'ปิด',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                controller: _search,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onTyped,
                decoration: InputDecoration(
                  hintText: 'รหัส ชื่อ หรือ Serial ของทรัพย์สิน',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'ล้าง',
                          onPressed: () {
                            _search.clear();
                            _onTyped('');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
            ),
            Expanded(child: _list()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_picked.values.toList()),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: Text(
                    _picked.isEmpty
                        ? 'ยังไม่ได้เลือก'
                        : 'ใช้ ${_picked.length} ชิ้นนี้',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    if (_loading) return const ListLoadingView();

    final error = _error;
    if (error != null) {
      return ErrorStateView(message: error, onRetry: _run);
    }

    final extra = _extraPicked;
    if (_results.isEmpty && extra.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 48),
        child: EmptyStateView(
          message: 'ไม่พบทรัพย์สินที่ตรงกับที่ค้น',
          icon: Icons.inventory_2_outlined,
        ),
      );
    }

    return ListView(
      children: [
        for (final asset in _results) _row(asset),
        if (extra.isNotEmpty) ...[
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'เลือกไว้แล้วจากการค้นครั้งก่อน',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final asset in extra) _row(asset),
        ],
      ],
    );
  }

  Widget _row(Asset asset) {
    final scheme = Theme.of(context).colorScheme;
    final on = _picked.containsKey(asset.id);

    return CheckboxListTile(
      value: on,
      onChanged: (_) => _toggle(asset),
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        asset.name.isEmpty ? asset.id : asset.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          asset.id,
          if (asset.statusLabel.isNotEmpty) asset.statusLabel,
          if (asset.siteId.isNotEmpty) asset.siteId,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
