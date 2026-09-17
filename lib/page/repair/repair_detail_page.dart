import 'package:flutter/material.dart';

import 'package:claim/page/repair/repair_appbar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/page/repair/repair_api.dart';
import 'package:claim/page/repair/repair_style.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/role_service.dart';
import 'package:claim/widgets/app_card.dart';

/// รายละเอียดใบแจ้งซ่อม 1 ใบ ทุกคนดูได้ แต่ปุ่มเปลี่ยนสถานะเห็นเฉพาะ IT
class RepairDetailPage extends StatefulWidget {
  final RepairTicket ticket;

  const RepairDetailPage({super.key, required this.ticket});

  @override
  State<RepairDetailPage> createState() => _RepairDetailPageState();
}

class _RepairDetailPageState extends State<RepairDetailPage> {
  late RepairTicket _ticket = widget.ticket;
  bool _busy = false;

  /// มีการแก้อะไรไปแล้ว ใช้บอกหน้ารายการว่าต้องโหลดใหม่
  bool _changed = false;

  bool get _isIt => RoleService.I.isIt;

  Future<String> _myName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
            .getString('fullname')
            ?.replaceAll(RegExp(r'\s+'), ' ')
            .trim() ??
        '';
  }

  Future<void> _apply({RepairStatus? status, String? technicianName}) async {
    final id = _ticket.id;
    if (id == null || _busy) return;

    setState(() => _busy = true);

    try {
      await updateRepair(
        id: id,
        status: status,
        technicianName: technicianName,
      );

      // เซิร์ฟเวอร์ไม่ได้คืนแถวที่อัปเดตมา ดึงใหม่ให้ตรงกับของจริง
      // โดยเฉพาะ completed_at ที่เซิร์ฟเวอร์เป็นคนเซ็ต
      final fresh = await fetchRepairs(sn: _ticket.sn);
      if (!mounted) return;

      setState(() {
        _busy = false;
        _changed = true;
        for (final t in fresh) {
          if (t.id == id) _ticket = t;
        }
      });
      _message('บันทึกแล้ว');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _message(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _accept() async {
    final name = await _myName();
    await _apply(
      status: RepairStatus.inProgress,
      technicianName: name.isEmpty ? null : name,
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: repairAppBar(title: 'รายละเอียดใบแจ้งซ่อม'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _headCard(scheme),
            const SizedBox(height: AppSizes.gap),
            _infoCard(scheme),
            if (_isIt) ...[
              const SizedBox(height: AppSizes.gap),
              _actionCard(scheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _headCard(ColorScheme scheme) {
    final color = repairStatusColor(_ticket.status, scheme);

    return AppCard(
      color: repairCardColor(_ticket.status, scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _ticket.deviceName.isEmpty ? '-' : _ticket.deviceName,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              RepairStatusChip(status: _ticket.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _ticket.issueDescription.isEmpty ? '-' : _ticket.issueDescription,
            style: TextStyle(fontSize: 14, color: scheme.onSurface),
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: switch (_ticket.status) {
              RepairStatus.pending => 0.15,
              RepairStatus.inProgress => 0.6,
              RepairStatus.completed => 1,
            },
            minHeight: 6,
            borderRadius: BorderRadius.circular(6),
            color: color,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }

  Widget _infoCard(ColorScheme scheme) {
    final created = _ticket.createdAt;
    final completed = _ticket.completedAt;
    final fmt = DateFormat('d MMM y HH:mm', 'th');

    return AppCard(
      child: Column(
        children: [
          _row(scheme, 'S/N', _ticket.sn),
          _row(scheme, 'รหัสทรัพย์สิน', _ticket.assetCode),
          _row(scheme, 'สาขา', _ticket.branch),
          _row(scheme, 'ผู้แจ้ง', _ticket.requesterName),
          _row(scheme, 'ช่างที่รับงาน', _ticket.technicianName),
          _row(scheme, 'ผู้อนุมัติ', _ticket.approverName),
          _row(scheme, 'บันทึกเพิ่มเติม', _ticket.note),
          _row(
            scheme,
            'วันที่แจ้ง',
            created == null ? '' : fmt.format(created),
          ),
          _row(
            scheme,
            'วันที่ปิดงาน',
            completed == null ? '' : fmt.format(completed),
          ),
        ],
      ),
    );
  }

  Widget _row(ColorScheme scheme, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(ColorScheme scheme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.build_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'งานของ IT',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_ticket.status == RepairStatus.pending)
            _button(
              icon: Icons.play_arrow,
              label: 'รับเคสนี้',
              onPressed: _accept,
            ),
          if (_ticket.status == RepairStatus.inProgress) ...[
            _button(
              icon: Icons.check_circle_outline,
              label: 'ปิดงาน',
              onPressed: () => _apply(status: RepairStatus.completed),
            ),
            const SizedBox(height: 8),
            _button(
              icon: Icons.undo,
              label: 'ย้อนกลับเป็นรอรับเรื่อง',
              filled: false,
              onPressed: () => _apply(status: RepairStatus.pending),
            ),
          ],
          if (_ticket.status == RepairStatus.completed)
            _button(
              icon: Icons.replay,
              label: 'เปิดงานใหม่',
              filled: false,
              onPressed: () => _apply(status: RepairStatus.inProgress),
            ),
        ],
      ),
    );
  }

  Widget _button({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool filled = true,
  }) {
    final child = Text(label);
    final onTap = _busy ? null : onPressed;

    return SizedBox(
      width: double.infinity,
      child: filled
          ? FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon),
              label: child,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon),
              label: child,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),
    );
  }
}
