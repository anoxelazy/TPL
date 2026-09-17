import 'package:flutter/material.dart';

import 'package:claim/utils/mobile_api.dart';

/// ตัวทดสอบว่าเว็บคุยกับ Mobile API ได้จริงไหม ไม่ใช่แอปตัวจริง
///
/// จงใจไม่แตะโค้ดหน้าแจ้งเคสที่มีอยู่ เพราะไฟล์พวกนั้นยัง import `dart:io`
/// ซึ่งเว็บไม่มี ตัวนี้เรียก endpoint ตรง ๆ เพื่อตอบคำถามเดียวคือ
/// "เบราว์เซอร์ล็อกอินแล้วดึงรายการเคสได้หรือเปล่า"
///
/// ผ่านแล้วค่อยไปแก้ dart:io ออกจาก 3 ไฟล์แล้วยกของจริงมาใช้
///
/// รันด้วย `flutter run -d chrome -t lib/main_web.dart`
void main() {
  runApp(const _ProbeApp());
}

class _ProbeApp extends StatelessWidget {
  const _ProbeApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ทดสอบเว็บ – แจ้งเคส IT',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B21B6)),
      useMaterial3: true,
    ),
    home: const _ProbePage(),
  );
}

class _ProbePage extends StatefulWidget {
  const _ProbePage();

  @override
  State<_ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<_ProbePage> {
  final _user = TextEditingController();
  final _pass = TextEditingController();

  bool _busy = false;
  String _log = 'ยังไม่ได้ทดสอบ';

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  /// ล็อกอินแล้วยิง joblist ต่อทันที เขียนผลดิบลงจอทั้งหมด
  ///
  /// ไม่แปลง ไม่จัดรูปแบบ อยากเห็นว่าเซิร์ฟเวอร์ตอบอะไรกลับมาจริง ๆ
  /// รวมถึงชื่อช่องใน json ที่เดาไว้ในแอปมือถือว่าตรงของจริงไหม
  Future<void> _run() async {
    setState(() {
      _busy = true;
      _log = 'กำลังล็อกอิน...';
    });

    final ok = await MobileSession.I.signIn(
      username: _user.text.trim(),
      password: _pass.text,
    );

    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _log =
            'ล็อกอินไม่ผ่าน\n\n'
            'ถ้าชื่อผู้ใช้กับรหัสถูก แต่ยังไม่ผ่าน แปลว่าเบราว์เซอร์ถูกบล็อก\n'
            'ให้เปิด DevTools แท็บ Console ดูว่ามีข้อความ CORS หรือ '
            'mixed content ขึ้นไหม';
      });
      return;
    }

    setState(
      () => _log =
          'ล็อกอินผ่าน (empNo: ${MobileSession.I.empNo})\n'
          'กำลังดึงรายการเคส...',
    );

    try {
      final response = await mobileDio.get(
        '/api/ITRepair/joblist',
        options: MobileSession.I.authOptions(),
      );

      if (!mounted) return;
      setState(() {
        _busy = false;
        _log =
            'สำเร็จ HTTP ${response.statusCode}\n\n'
            '--- response ดิบ ---\n${response.data}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _log = 'ดึงรายการเคสไม่สำเร็จ\n\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ทดสอบเว็บ – แจ้งเคส IT'),
        backgroundColor: const Color(0xFF5B21B6),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'ล็อกอินด้วยชื่อผู้ใช้/รหัสผ่านชุดเดียวกับในแอปมือถือ',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _user,
                decoration: const InputDecoration(
                  labelText: 'ชื่อผู้ใช้',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass,
                obscureText: true,
                onSubmitted: (_) => _busy ? null : _run(),
                decoration: const InputDecoration(
                  labelText: 'รหัสผ่าน',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 46,
                child: FilledButton(
                  onPressed: _busy ? null : _run,
                  child: Text(
                    _busy ? 'กำลังทดสอบ...' : 'ล็อกอินและดึงรายการเคส',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  _log,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
