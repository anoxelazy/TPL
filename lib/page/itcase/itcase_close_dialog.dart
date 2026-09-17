import 'package:flutter/material.dart';

import 'package:claim/page/itcase/itcase_api.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/mobile_api.dart';

/// สิ่งที่ผู้แจ้งเลือกในป๊อปอัปตรวจงาน
typedef ItCaseCloseChoice = ({String status, int rating, String note});

/// เปิดป๊อปอัปตรวจงาน ส่งผลไปเซิร์ฟเวอร์ แล้วบอกผลด้วย snackbar
///
/// รวมไว้ที่เดียวเพราะมีสามที่ที่กดปิดงานได้ (การ์ดบนหน้าหลัก การ์ดในหน้า
/// รายการ และหน้ารายละเอียด) ถ้าแยกกันเขียน คำถาม เงื่อนไข และข้อความบอกผล
/// จะเริ่มไม่ตรงกันทีละนิดจนกลายเป็นคนละเรื่อง
///
/// เลือกเสร็จส่งเลย ไม่มีป๊อปอัปถามซ้ำอีกชั้น การเลือกในป๊อปอัปนี้คือการยืนยัน
/// อยู่แล้ว
///
/// คืน true เมื่อส่งสำเร็จ คนเรียกเอาไปดึงข้อมูลใหม่ให้สถานะบนจอตรงกับของจริง
/// ยกเลิกหรือส่งไม่สำเร็จคืน false
Future<bool> runItCaseCloseFlow(BuildContext context, String jobId) async {
  final messenger = ScaffoldMessenger.of(context);

  final choice = await showDialog<ItCaseCloseChoice>(
    context: context,
    builder: (_) => const _CloseDialog(),
  );
  if (choice == null) return false;

  final closing = choice.status == kItCaseClosedStatusId;

  try {
    await updateCaseJobStatus(
      jobId,
      status: choice.status,
      rating: choice.rating,
      note: choice.note,
    );

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          closing
              ? 'ปิดงานเรียบร้อย ขอบคุณครับ'
              : 'ส่งเรื่องกลับให้ทีม IT ดูอีกครั้งแล้ว',
        ),
      ),
    );
    return true;
  } on MobileApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          closing
              ? 'ปิดงานไม่สำเร็จ กรุณาลองใหม่'
              : 'ส่งไม่สำเร็จ กรุณาลองใหม่',
        ),
      ),
    );
  }

  return false;
}

/// ป๊อปอัปถามผลการตรวจงาน
///
/// สองทางเลือกวางคู่กันตั้งแต่แรก ไม่ซ่อนทางเลือกที่สองไว้หลังปุ่มเล็ก ๆ
/// เพราะงานที่ยังไม่เรียบร้อยแล้วผู้แจ้งหาทางตีกลับไม่เจอ สุดท้ายจะกดปิดไปทั้ง
/// อย่างนั้น แล้วไปบ่นในไลน์แทน ซึ่งทีม IT ไม่มีทางรู้จากระบบเลย
class _CloseDialog extends StatefulWidget {
  const _CloseDialog();

  @override
  State<_CloseDialog> createState() => _CloseDialogState();
}

class _CloseDialogState extends State<_CloseDialog> {
  final TextEditingController _note = TextEditingController();

  /// ยังไม่เลือกเป็น null ไม่ใช่ตั้งค่าเริ่มต้นเป็นปิดงาน
  ///
  /// ตั้งไว้ให้แล้วคนจะกดยืนยันรวดเดียวโดยไม่ได้อ่านว่ามีอีกทางเลือกอยู่
  String? _status;

  int _rating = 0;

  bool get _isClosing => _status == kItCaseClosedStatusId;
  bool get _isRedo => _status == kItCaseRedoStatusId;

  /// ครบพอจะส่งได้หรือยัง
  ///
  /// ปิดงานต้องมีดาว ส่วนตีกลับต้องมีเหตุผล ทีม IT ที่ได้งานคืนโดยไม่รู้ว่า
  /// ยังติดตรงไหน ก็ได้แต่เดาแล้วส่งกลับมาใหม่วนอยู่อย่างนั้น
  bool get _canSend {
    if (_isClosing) return _rating > 0;
    if (_isRedo) return _note.text.trim().isNotEmpty;
    return false;
  }

  /// สิ่งที่ยังขาดอยู่ ครบแล้วเป็น null
  ///
  /// เลือกทางไหนก็ยังไม่ต้องบอกอะไร ป๊อปอัปเพิ่งเปิดมาเปล่า ๆ คนยังไม่ได้ทำ
  /// อะไรผิด เตือนตั้งแต่ยังไม่เริ่มก็เหมือนดุไว้ก่อน
  String? get _hint {
    if (_status == null) return null;
    if (_isClosing && _rating == 0) return 'ให้ดาวก่อนถึงจะปิดงานได้';
    if (_isRedo && _note.text.trim().isEmpty) {
      return 'บอกด้วยว่ายังติดตรงไหน ทีม IT จะได้ไม่ต้องเดา';
    }
    return null;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _choose(String status) {
    setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text(
        'ตรวจงานที่ทีม IT แก้ให้',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 18, 20, 18),

      // เลือกแล้วป๊อปอัปจะสูงขึ้นเพราะมีดาวกับช่องพิมพ์โผล่มา ให้ค่อย ๆ ยืด
      // ไม่ใช่กระตุกเปลี่ยนขนาดทันทีจนคนอ่านหลุดว่ากำลังดูอะไรอยู่
      content: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _choice(
                scheme,
                status: kItCaseClosedStatusId,
                icon: Icons.task_alt,
                color: AppColors.success,
                title: 'ตรวจสอบเรียบร้อยแล้ว',
                subtitle: 'ปิดเคสนี้ เรื่องจบ',
              ),
              const SizedBox(height: 8),
              _choice(
                scheme,
                status: kItCaseRedoStatusId,
                icon: Icons.replay,
                color: AppColors.pending,
                title: 'แจ้งดำเนินการอีกครั้ง',
                subtitle: 'ยังไม่เรียบร้อย ส่งกลับให้ทีม IT',
              ),

              // ดาวเป็นของการปิดงาน งานที่ตีกลับยังไม่จบ ให้คะแนนตอนนี้ก็ยัง
              // ไม่รู้ว่าสุดท้ายจะออกมาดีหรือไม่ดี
              if (_isClosing) ...[
                const SizedBox(height: 14),
                Text(
                  'ให้คะแนนการบริการ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                _stars(scheme),
              ],

              if (_status != null) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  maxLength: 200,
                  maxLines: 2,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    hintText: _isRedo
                        ? 'ยังติดตรงไหน บอกทีม IT ด้วย'
                        : 'ความเห็นเพิ่มเติม (ไม่บังคับ)',
                    hintStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ],

              // บอกสิ่งที่ยังขาดตรงนี้แทนที่จะไปเปลี่ยนข้อความบนปุ่ม
              // ปุ่มที่เปลี่ยนคำไปมาจะกว้างไม่เท่ากันในแต่ละจังหวะ ดูเหมือน
              // ป๊อปอัปขยับเองตลอดเวลา
              if (_hint != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _hint!,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.3,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),

      // สองปุ่มกว้างเท่ากันคนละครึ่ง ไม่ว่าคำบนปุ่มจะสั้นยาวแค่ไหน
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  foregroundColor: scheme.onSurfaceVariant,
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                child: const Text('ยังก่อน'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _canSend
                    ? () => Navigator.of(context).pop((
                        status: _status!,
                        rating: _isClosing ? _rating : 0,
                        note: _note.text,
                      ))
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  backgroundColor: _isRedo
                      ? AppColors.pending
                      : AppColors.success,
                  foregroundColor: Colors.white,
                ),
                child: Text(_isRedo ? 'ส่งกลับ' : 'ปิดงาน'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// ดาวห้าดวงเรียงกลาง ระยะห่างเท่ากันทุกช่อง
  ///
  /// ไม่ใช้ IconButton เพราะมันมีระยะเผื่อของตัวเองที่ทำให้ดวงริมสองข้าง
  /// ดูไม่อยู่กึ่งกลางกับของอื่นในป๊อปอัป
  Widget _stars(ColorScheme scheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          InkResponse(
            onTap: () => setState(() => _rating = i),
            radius: 22,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Icon(
                i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 30,
                color: i <= _rating ? AppColors.pending : scheme.outlineVariant,
              ),
            ),
          ),
      ],
    );
  }

  /// หนึ่งทางเลือก แตะทั้งแถวได้ ไม่ใช่ต้องจิ้มวงกลมเล็ก ๆ ข้างหน้า
  Widget _choice(
    ColorScheme scheme, {
    required String status,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    final selected = _status == status;

    return InkWell(
      onTap: () => _choose(status),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected ? color.withValues(alpha: 0.10) : null,
          // ความหนาเท่ากันทั้งสองสถานะ ต่างกันแค่สี เส้นที่หนาขึ้นตอนเลือก
          // จะดันกล่องให้สูงกว่าอีกใบนิดหนึ่ง มองเห็นเป็นการขยับทุกครั้งที่สลับ
          border: Border.all(
            color: selected ? color : scheme.outlineVariant,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: selected ? color : scheme.outline),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selected ? color : scheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.3,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
