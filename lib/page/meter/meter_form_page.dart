import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/permission_service.dart';
import 'package:claim/widgets/app_card.dart';
import 'package:claim/page/meter/meter_api.dart';
import 'package:claim/page/meter/meter_controller.dart';
import 'package:claim/page/meter/meter_result_page.dart';
import 'package:claim/page/meter/meter_widgets.dart';

/// หน้าบันทึกรายได้ชดเชยค่าน้ำมัน
///
/// ต้องมีสิทธิ์ module [meterModule] จึงเข้าใช้งานได้
class MeterPage extends StatefulWidget {
  const MeterPage({super.key});

  @override
  State<MeterPage> createState() => _MeterPageState();
}

class _MeterPageState extends State<MeterPage> {
  final MeterController _c = MeterController();

  final TextEditingController _driverField = TextEditingController();
  final TextEditingController _truckField = TextEditingController();
  final TextEditingController _startField = TextEditingController();
  final TextEditingController _endField = TextEditingController();

  // ผูก focus ไว้เพื่อเด้ง cursor ไปช่องต่อไปให้เองหลังสแกน QR ติด
  final FocusNode _driverFocus = FocusNode();
  final FocusNode _truckFocus = FocusNode();
  final FocusNode _meterFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _c.addListener(_onControllerChanged);
    _c.loadSession();
  }

  @override
  void dispose() {
    _c.removeListener(_onControllerChanged);
    _c.dispose();
    _driverField.dispose();
    _truckField.dispose();
    _startField.dispose();
    _endField.dispose();
    _driverFocus.dispose();
    _truckFocus.dispose();
    _meterFocus.dispose();
    super.dispose();
  }

  /// ข้อมูลเดิมที่โหลดมาต้องเด้งกลับเข้าช่องกรอกให้ผู้ใช้เห็น
  /// เทียบก่อนเขียนทับ ไม่งั้น cursor จะกระโดดทุกครั้งที่พิมพ์
  void _onControllerChanged() {
    _syncField(_startField, _c.startMeter);
    _syncField(_endField, _c.endMeter);
    if (mounted) setState(() {});
  }

  void _syncField(TextEditingController field, int value) {
    if (parseMeterInput(field.text) == value) return;
    field.text = value == 0 ? '' : formatThousands(value);
  }

  // ------------------------------------------------------------------- actions

  Future<void> _pick(MeterSideKind side) async {
    if (_c.driverId.isEmpty) {
      _snack('กรุณากรอกรหัสคนขับก่อนถ่ายรูป', error: true);
      return;
    }

    final file = await pickMeterImage(context);
    if (file == null || !mounted) return;

    final problem = await _c.attachImage(side, file);
    if (!mounted || problem == null) return;

    if (problem is MeterGpsError) {
      _snack(problem.message, error: true);
      return;
    }
    if (problem is MeterApiException) {
      _snack(problem.message, error: true);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final problem = _c.validate();
    if (problem != null) {
      if (problem.asDialog) {
        await _alert(problem.message);
      } else {
        _snack(problem.message);
      }
      return;
    }

    // ช่วงเช้าจบที่ dialog ช่วงเย็นถึงจะไปหน้าสรุปผล
    final goToResult = _c.phase == MeterPhase.evening;

    try {
      final result = await _c.save();
      if (!mounted) return;

      if (goToResult) {
        await _openResult(result);
      } else {
        await _alert(
          'บันทึกไมล์ต้นสำเร็จแล้ว',
          title: 'บันทึกสำเร็จ',
          detail: 'ตอนเลิกงานให้กลับมาบันทึกเลขไมล์ปลายวันด้วยรหัสเดิม',
          icon: Icons.check_circle_outline,
        );
        if (!mounted) return;
        await _c.checkExisting();
      }
    } on MeterApiException catch (e) {
      if (!mounted) return;
      await _alert(e.message, title: 'บันทึกไม่สำเร็จ');
    }
  }

  /// ข้อมูลครบแล้วยังขอผลย้อนหลังได้ /InputMeter เป็นที่เดียวที่คืนตัวเลขเงิน
  Future<void> _viewResult() async {
    try {
      final result = await _c.save();
      if (!mounted) return;
      await _openResult(result);
    } on MeterApiException catch (e) {
      if (!mounted) return;
      await _alert(e.message, title: 'ดูผลไม่สำเร็จ');
    }
  }

  Future<void> _openResult(MeterResult result) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => MeterResultPage(result: result)));
    if (!mounted) return;
    // กลับมาแล้วเช็คสถานะใหม่ เผื่อฝั่งเซิร์ฟเวอร์เปลี่ยนไปแล้ว
    await _c.checkExisting();
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: error ? 5 : 3),
        backgroundColor: error ? AppColors.danger : null,
      ),
    );
  }

  Future<void> _alert(
    String message, {
    String title = 'แจ้งเตือน',
    String? detail,
    IconData icon = Icons.info_outline,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(icon, size: 34),
        title: Text(title, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (detail != null) ...[
              const SizedBox(height: 10),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ตกลง'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    if (!PermissionService.I.canAccess(meterModule)) {
      return const _NoPermissionView();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('บันทึกรายได้ชดเชยค่าน้ำมัน'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(26),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                'วันที่ ${DateFormat('d MMMM y', 'th').format(DateTime.now())}'
                '${_c.recorderName.isEmpty ? '' : ' · ${_c.recorderName}'}',
                // พื้นหลังตรงนี้เป็นแถบสีของ AppBar ไม่ใช่พื้นขาวของหน้า
                // ต้องใช้สีตัวหนังสือของ AppBar ไม่งั้นจมหายไปกับพื้น
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color:
                      Theme.of(
                        context,
                      ).appBarTheme.foregroundColor?.withValues(alpha: 0.92) ??
                      Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
      // แตะที่ว่างเพื่อปิดคีย์บอร์ด ฟอร์มนี้มีช่องตัวเลขเยอะ
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: [
              _StepIndicator(phase: _c.phase),
              const SizedBox(height: AppSizes.gap),
              _identityCard(),
              const SizedBox(height: AppSizes.gap),
              _startCard(),
              const SizedBox(height: AppSizes.gap),
              _endCard(),
            ],
          ),
        ),
      ),
      // ปุ่มบันทึกติดขอบล่างเสมอ ไม่ต้องเลื่อนหาปุ่ม
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _identityCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.local_shipping_outlined,
            text: 'รถและคนขับ',
          ),
          const SizedBox(height: 14),
          ScannableField(
            controller: _driverField,
            focusNode: _driverFocus,
            nextFocusNode: _truckFocus,
            label: 'รหัสคนขับ',
            icon: Icons.person_outline,
            onChanged: (value) => _c.onIdentityChanged(driver: value),
          ),
          const SizedBox(height: 12),
          ScannableField(
            controller: _truckField,
            focusNode: _truckFocus,
            nextFocusNode: _meterFocus,
            label: 'หมายเลขรถ',
            icon: Icons.directions_bus_outlined,
            onChanged: (value) => _c.onIdentityChanged(truck: value),
          ),
          const SizedBox(height: 12),
          _checkStatus(),
        ],
      ),
    );
  }

  /// สถานะการตรวจสอบข้อมูลเดิม อยู่ใต้ช่องกรอกที่เป็นต้นเหตุ
  Widget _checkStatus() {
    final scheme = Theme.of(context).colorScheme;

    if (_c.checking) {
      return const Row(
        children: [
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text(
            'กำลังตรวจสอบข้อมูลของวันนี้...',
            style: TextStyle(fontSize: 13),
          ),
        ],
      );
    }

    final error = _c.checkError;
    if (error != null) {
      return _StatusLine(
        icon: Icons.error_outline,
        color: AppColors.danger,
        text: error,
        // token หมดอายุกดลองใหม่ก็ไม่ผ่าน ต้องไป login ใหม่เท่านั้น
        action: _c.sessionExpired
            ? null
            : TextButton(
                onPressed: _c.checkExisting,
                child: const Text('ลองใหม่'),
              ),
      );
    }

    if (_c.driverId.isEmpty || _c.truckId.isEmpty) {
      return Text(
        'กรอกให้ครบทั้งสองช่อง ระบบจะดึงข้อมูลของวันนี้ให้เอง',
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      );
    }

    if (_c.existing == null) {
      return const _StatusLine(
        icon: Icons.fiber_new_outlined,
        color: AppColors.stageOrigin,
        text: 'วันนี้ยังไม่มีข้อมูล เริ่มบันทึกไมล์ต้นวันได้เลย',
      );
    }

    return const _StatusLine(
      icon: Icons.cloud_done_outlined,
      color: AppColors.success,
      text: 'พบข้อมูลของวันนี้ ดึงมาแสดงให้แล้ว',
    );
  }

  Widget _startCard() {
    // บันทึกไปแล้วให้เห็นเป็นสรุป อ่านง่ายกว่าช่องกรอกสีเทา
    if (_c.startLocked) {
      return AppCard(
        child: MeterSavedTile(
          label: 'ไมล์ต้นวัน',
          meter: _c.startMeter,
          imageUrl: _c.startImage.url,
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(icon: Icons.wb_twilight, text: 'ไมล์ต้นวัน'),
          const SizedBox(height: 14),
          MeterNumberField(
            controller: _startField,
            focusNode: _meterFocus,
            label: 'เลขไมล์ต้นวัน',
            onChanged: _c.setStartMeter,
          ),
          const SizedBox(height: 14),
          MeterImageSlot(
            label: 'รูปหน้าปัดไมล์ต้นวัน',
            localFile: _c.startImage.localFile,
            imageUrl: _c.startImage.url,
            uploading: _c.startImage.uploading,

            onPick: () => _pick(MeterSideKind.start),
          ),
        ],
      ),
    );
  }

  Widget _endCard() {
    // ช่วงเช้ายังไม่ต้องกรอกไมล์ปลาย ซ่อนไว้ไม่ให้กรอกสลับกัน
    if (_c.phase == MeterPhase.morning) return const SizedBox.shrink();

    if (_c.endLocked) {
      return AppCard(
        child: MeterSavedTile(
          label: 'ไมล์ปลายวัน',
          meter: _c.endMeter,
          imageUrl: _c.endImage.url,
        ),
      );
    }

    final distance = _c.previewDistance;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.nights_stay_outlined,
            text: 'ไมล์ปลายวัน',
          ),
          const SizedBox(height: 14),
          MeterNumberField(
            controller: _endField,
            label: 'เลขไมล์ปลายวัน',
            onChanged: _c.setEndMeter,
          ),
          if (distance > 0) ...[
            const SizedBox(height: 12),
            // ระยะทางไว้ให้ผู้ใช้ตรวจเองว่ากรอกไม่ผิดหลัก
            // เงินชดเชยทุกตัวคำนวณที่เซิร์ฟเวอร์
            _DistanceChip(distance: distance),
          ],
          const SizedBox(height: 14),
          MeterImageSlot(
            label: 'รูปหน้าปัดไมล์ปลายวัน',
            localFile: _c.endImage.localFile,
            imageUrl: _c.endImage.url,
            uploading: _c.endImage.uploading,

            onPick: () => _pick(MeterSideKind.end),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    final scheme = Theme.of(context).colorScheme;
    final isComplete = _c.phase == MeterPhase.complete;
    final busy = _c.busy;

    final String hint;
    if (_c.uploading) {
      hint = 'กำลังอัปโหลดรูป กดบันทึกได้เมื่ออัปโหลดเสร็จ';
    } else if (isComplete) {
      hint = 'บันทึกครบทั้งสองช่วงแล้ว';
    } else if (_c.phase == MeterPhase.evening) {
      hint = 'เหลือแค่ไมล์ปลายวัน';
    } else {
      hint = 'ขั้นตอนนี้บันทึกเฉพาะไมล์ต้นวัน';
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hint,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: busy ? null : (isComplete ? _viewResult : _save),
                  icon: _c.saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          isComplete
                              ? Icons.receipt_long_outlined
                              : Icons.save_outlined,
                        ),
                  label: Text(
                    _buttonLabel(isComplete),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

  String _buttonLabel(bool isComplete) {
    if (_c.saving) return isComplete ? 'กำลังโหลด...' : 'กำลังบันทึก...';
    if (isComplete) return 'ดูรายละเอียดการชดเชยน้ำมัน';
    if (_c.phase == MeterPhase.evening) return 'บันทึกไมล์ปลายวัน';
    return 'บันทึกไมล์ต้นวัน';
  }
}

/// บอกว่าตอนนี้อยู่ขั้นไหนของวัน คนใช้จะรู้ว่าต้องทำอะไรโดยไม่ต้องอ่านยาว
class _StepIndicator extends StatelessWidget {
  final MeterPhase phase;

  const _StepIndicator({required this.phase});

  @override
  Widget build(BuildContext context) {
    final startDone = phase != MeterPhase.morning;
    final endDone = phase == MeterPhase.complete;

    return Row(
      children: [
        Expanded(
          child: _Step(
            index: 1,
            label: 'ไมล์ต้นวัน',
            done: startDone,
            active: phase == MeterPhase.morning,
          ),
        ),
        Container(
          width: 24,
          height: 2,
          color: startDone
              ? AppColors.success
              : Theme.of(context).colorScheme.outlineVariant,
        ),
        Expanded(
          child: _Step(
            index: 2,
            label: 'ไมล์ปลายวัน',
            done: endDone,
            active: phase == MeterPhase.evening,
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final int index;
  final String label;
  final bool done;
  final bool active;

  const _Step({
    required this.index,
    required this.label,
    required this.done,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Color color;
    if (done) {
      color = AppColors.success;
    } else if (active) {
      color = scheme.primary;
    } else {
      color = scheme.outline;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done || active ? color : Colors.transparent,
            border: Border.all(color: color, width: 1.5),
          ),
          child: done
              ? const Icon(Icons.check, size: 15, color: Colors.white)
              : Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: active ? Colors.white : color,
                  ),
                ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: active || done ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

class _CardTitle extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CardTitle({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 19, color: scheme.primary),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final Widget? action;

  const _StatusLine({
    required this.icon,
    required this.color,
    required this.text,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
        if (action != null) action!,
      ],
    );
  }
}

class _DistanceChip extends StatelessWidget {
  final int distance;

  const _DistanceChip({required this.distance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.stageOrigin.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.route_outlined,
            size: 17,
            color: AppColors.stageOrigin,
          ),
          const SizedBox(width: 8),
          Text(
            'ระยะทางวันนี้ ${formatThousands(distance)} กม.',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.stageOrigin,
            ),
          ),
        ],
      ),
    );
  }
}

/// ไม่มีสิทธิ์ module meter บอกให้ไปขอสิทธิ์ ไม่ใช่ปล่อยหน้าว่าง
class _NoPermissionView extends StatelessWidget {
  const _NoPermissionView();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('บันทึกรายได้ชดเชยค่าน้ำมัน')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 56, color: scheme.outline),
              const SizedBox(height: 16),
              const Text(
                'ยังไม่มีสิทธิ์ใช้งานเมนูนี้',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'การบันทึกรายได้ชดเชยค่าน้ำมันต้องเปิดสิทธิ์ให้ก่อน '
                'กรุณาติดต่อผู้ดูแลระบบเพื่อขอเปิดสิทธิ์',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
