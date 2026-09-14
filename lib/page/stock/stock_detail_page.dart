import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:claim/page/stock/shipment_progress.dart';
import 'package:claim/page/stock/stock_api.dart';
import 'package:claim/page/stock/status_post_api.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/widgets/app_card.dart';
import 'package:claim/widgets/info_row.dart';

/// หน้ารายละเอียดบิลในคลัง ใช้พักสถานะสินค้า
class StockDetailPage extends StatefulWidget {
  final BillStockItem item;

  const StockDetailPage({super.key, required this.item});

  @override
  State<StockDetailPage> createState() => _StockDetailPageState();
}

class _StockDetailPageState extends State<StockDetailPage> {
  List<HoldReason> _reasons = [];
  HoldReason? _reason;
  bool _isLoadingReasons = true;
  String? _reasonError;
  bool _isSending = false;

  /// พักสำเร็จในรอบนี้แล้ว กันกดซ้ำในช่วงที่ยังไม่ได้ออกจากหน้า
  bool _justParked = false;

  BillStockItem get _item => widget.item;

  bool get _alreadyParked => _item.isParked || _justParked;

  bool get _canSend => !_isSending && !_alreadyParked && _reason != null;

  @override
  void initState() {
    super.initState();
    _loadReasons();
  }

  Future<void> _loadReasons() async {
    setState(() {
      _isLoadingReasons = true;
      _reasonError = null;
    });

    try {
      final reasons = await fetchHoldReasons();
      if (!mounted) return;
      setState(() {
        _reasons = reasons;
        _isLoadingReasons = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingReasons = false;
        _reasonError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _park() async {
    final reason = _reason;
    // เช็คซ้ำที่นี่ด้วย ไม่พึ่งแต่ปุ่มที่ปิดไว้ เผื่อถูกเรียกจากทางอื่น
    if (reason == null || _isSending || _alreadyParked) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันพักสถานะ'),
        content: Text(
          'บิล ${_item.billCode}\n'
          'เหตุผล: ${reason.reasonName}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSending = true);

    try {
      await postBillStatus(
        a1: _item.billCode,
        statusCode: kParkStatusCode,
        reasonCode: reason.id,
      );
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _justParked = true;
      });
      _showMessage('พักสถานะเรียบร้อย');
      // ส่งค่ากลับให้หน้ารายการโหลดข้อมูลใหม่
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('พักสถานะสินค้า')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _billCard(context),
          if (_item.hasCustomerInfo) ...[
            const SizedBox(height: 12),
            _customerCard(context),
          ],
          const SizedBox(height: 12),
          _parkCard(context),
        ],
      ),
    );
  }

  Widget _billCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _item.billCode,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'สถานะสินค้า: ',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                TextSpan(
                  text: _item.jobStatusId ?? '-',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ShipmentProgress(stage: _item.stage),
          const SizedBox(height: 14),
          // ชื่อลูกค้าย้ายไปอยู่การ์ดข้อมูลลูกค้าแล้ว ไม่ต้องซ้ำที่นี่
          InfoRow(icon: Icons.inventory_2_outlined, value: _item.quantity),
          InfoRow(icon: Icons.schedule, value: _item.dateText),
          InfoRow(icon: Icons.notes_outlined, value: _item.remark),
        ],
      ),
    );
  }

  /// ข้อมูลลูกค้าของบิลนี้ เอาเท่าที่ต้องใช้ตอนพักสถานะ: ชื่อ เบอร์ ที่อยู่
  ///
  /// แสดงเฉพาะฟิลด์ที่ API ส่งมาจริง ([InfoRow] ซ่อนตัวเองเมื่อไม่มีค่า)
  /// เพราะ Bill_Stock ส่งฟิลด์ไม่เท่ากันในแต่ละแถว
  Widget _customerCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'ข้อมูลลูกค้า',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_item.customer != null)
            Text(
              _item.customer!,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          if (_item.customer != null) const SizedBox(height: 8),
          _phoneRow(context),
          InfoRow(icon: Icons.place_outlined, value: _item.address),
        ],
      ),
    );
  }

  /// เบอร์โทรกดโทรออกได้เลย พนักงานคลังต้องโทรหาลูกค้าบ่อย
  Widget _phoneRow(BuildContext context) {
    final phone = _item.phone;
    if (phone == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    // เบอร์ที่ส่งมามีขีดหรือเว้นวรรคปนได้ ต้องเหลือแต่ตัวเลขก่อนโทร
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.phone_outlined, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(phone, style: const TextStyle(fontSize: 14))),
          if (digits.isNotEmpty)
            TextButton.icon(
              onPressed: () => _call(digits),
              icon: const Icon(Icons.call, size: 16),
              label: const Text('โทร'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
        ],
      ),
    );
  }

  Future<void> _call(String digits) async {
    final uri = Uri(scheme: 'tel', path: digits);
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      _showMessage('โทรออกไม่ได้ กรุณาโทรด้วยตัวเอง');
    }
  }

  Widget _parkCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _alreadyParked
                    ? Icons.pause_circle_filled
                    : Icons.pause_circle_outline,
                size: 20,
                color: AppColors.pending,
              ),
              const SizedBox(width: 8),
              Text(
                _alreadyParked ? 'พักสถานะแล้ว' : 'พักสถานะ',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _alreadyParked
                ? 'รายการนี้พักสถานะอยู่แล้ว พักซ้ำไม่ได้'
                : 'ใช้เมื่อสินค้าค้างในคลัง ยังไม่เข้าคิวจัดส่ง',
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),
          // พักแล้วไม่ต้องมีช่องเหตุผลกับปุ่มให้กด ซ่อนไปเลยชัดกว่าปุ่มสีเทา
          if (!_alreadyParked) ...[
            const SizedBox(height: 16),
            _reasonField(context),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _canSend ? _park : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.pause_circle_outline),
              label: Text(_isSending ? 'กำลังบันทึก...' : 'บันทึกพักสถานะ'),
            ),
            if (_reason == null && !_isLoadingReasons && _reasonError == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'เลือกเหตุผลก่อนจึงจะบันทึกได้',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// รายการเหตุผลมาจาก /api/GetHoldReason ไม่ได้ hardcode ไว้ในแอป
  Widget _reasonField(BuildContext context) {
    if (_isLoadingReasons) {
      return const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('กำลังโหลดเหตุผล...', style: TextStyle(fontSize: 14)),
        ],
      );
    }

    if (_reasonError != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              _reasonError!,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _loadReasons,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('ลองใหม่'),
          ),
        ],
      );
    }

    return DropdownButtonFormField<HoldReason>(
      initialValue: _reason,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'เหตุผลที่พัก'),
      hint: const Text('เลือกเหตุผล'),
      items: [
        for (final reason in _reasons)
          DropdownMenuItem(
            value: reason,
            child: Text(reason.reasonName, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: _isSending ? null : (value) => setState(() => _reason = value),
    );
  }
}
