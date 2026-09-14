import 'package:flutter/foundation.dart';

/// จับเวลาแต่ละขั้นตอนตอนเปิดแอป ให้รู้ว่าช้าตรงไหนจริง ๆ ไม่ต้องเดา
///
/// พิมพ์ออก console เฉพาะตอน debug ดูได้ด้วย `flutter run` แล้วมองหาบรรทัด
/// ที่ขึ้นต้นด้วย `boot:` ตัวเลขเป็นมิลลิวินาทีนับจากเริ่ม main()
///
/// ไม่เขียนลง AppLogger เพราะ logger เขียนผ่าน SharedPreferences ซึ่งเป็น I/O
/// การวัดเวลาบูตไม่ควรเพิ่มงาน I/O ให้การบูตเสียเอง
class BootTiming {
  BootTiming._();

  static final Stopwatch _watch = Stopwatch();
  static int _previous = 0;

  /// เริ่มจับเวลา เรียกบรรทัดแรกสุดของ main()
  static void start() {
    if (!kDebugMode) return;
    _watch.start();
    _previous = 0;
  }

  /// บันทึกว่าขั้นตอน [step] จบแล้ว พิมพ์ทั้งเวลาที่ใช้และเวลาสะสม
  static void mark(String step) {
    if (!kDebugMode || !_watch.isRunning) return;

    final total = _watch.elapsedMilliseconds;
    final spent = total - _previous;
    _previous = total;

    debugPrint('boot: $step +${spent}ms (รวม ${total}ms)');
  }
}
