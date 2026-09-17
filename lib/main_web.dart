import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:claim/page/itcase/itcase_form_page.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/mobile_api.dart';
import 'package:claim/utils/theme.dart';

/// เว็บแอปเฉพาะระบบแจ้งเคส IT
///
/// เป็นคนละ entry point กับ main.dart เพราะแอปมือถือมีเมนูที่ใช้บนเว็บไม่ได้
/// (กล้อง สแกนบาร์โค้ด อัปเดตในแอป แจ้งเตือน) และคุยกับ API หลักซึ่งเป็น
/// http:// ล้วน ๆ ที่เบราว์เซอร์บล็อกเพราะหน้าเว็บเสิร์ฟผ่าน https
///
/// ระบบแจ้งเคสใช้ Mobile API ตัวใหม่อย่างเดียว ซึ่งเป็น https ใบรับรองถูกต้อง
/// เปิด CORS ให้แล้ว และมีหน้าล็อกอินของตัวเอง จึงยกมาทั้งชุดได้เลย
///
/// Dart คอมไพล์เฉพาะไฟล์ที่ entry point เรียกถึง ไฟล์ของเคลม/มิเตอร์/สแกน/PM
/// จึงไม่ถูกลากเข้ามาในก้อนเว็บ
///
/// รัน: flutter run -d chrome -t lib/main_web.dart
/// build: flutter build web -t lib/main_web.dart --base-href /TPL/
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // วันที่ภาษาไทยใช้ทั้งการ์ดเคสและหน้ารายละเอียด ไม่โหลดก่อนจะโยนตอนวาด
  await initializeDateFormatting('th', null);
  await MobileSession.I.init();

  runApp(const ItCaseWebApp());
}

class ItCaseWebApp extends StatelessWidget {
  const ItCaseWebApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'แจ้งเคส IT',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.getLightTheme(),
    home: const _Gate(),
  );
}

/// มี token อยู่แล้วเข้าหน้าแจ้งเคสเลย ไม่มีก็ให้ล็อกอินก่อน
///
/// token เก็บใน shared_preferences ซึ่งบนเว็บคือ localStorage ปิดแท็บแล้ว
/// เปิดใหม่จึงไม่ต้องล็อกอินซ้ำ
class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  bool _signedIn = MobileSession.I.isReady;

  @override
  Widget build(BuildContext context) => _signedIn
      ? ItCaseFormPage(onSignOut: _signOut)
      : _LoginPage(onDone: () => setState(() => _signedIn = true));

  Future<void> _signOut() async {
    await MobileSession.I.clear();
    if (!mounted) return;
    setState(() => _signedIn = false);
  }
}

/// หน้าล็อกอินของเว็บ ใช้บัญชีเดียวกับแอปมือถือ
///
/// ไม่ได้ยกหน้าล็อกอินของแอปมาใช้ เพราะอันนั้นล็อกอินที่ API หลักซึ่งเป็น
/// http:// เบราว์เซอร์บล็อกแน่นอน อันนี้ยิงที่ Mobile API ตรง ๆ
class _LoginPage extends StatefulWidget {
  final VoidCallback onDone;

  const _LoginPage({required this.onDone});

  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage> {
  final _user = TextEditingController();
  final _pass = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _user.text.trim();
    if (username.isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'กรอกชื่อผู้ใช้และรหัสผ่านก่อน');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final ok = await MobileSession.I.signIn(
      username: username,
      password: _pass.text,
    );

    if (!mounted) return;
    if (ok) {
      widget.onDone();
      return;
    }

    setState(() {
      _busy = false;
      _error = 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง';
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            // จอคอมกว้างกว่ามือถือมาก ปล่อยให้ช่องกรอกยาวเต็มจอแล้วอ่านยาก
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.support_agent,
                  size: 56,
                  color: AppColors.caseIcon,
                ),
                const SizedBox(height: 12),
                const Text(
                  'แจ้งเคสถึงทีม IT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.caseIcon,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ใช้บัญชีเดียวกับแอปในมือถือ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _user,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อผู้ใช้',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  onSubmitted: (_) => _busy ? null : _submit(),
                  decoration: const InputDecoration(
                    labelText: 'รหัสผ่าน',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: scheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 46,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.caseIcon,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_busy ? 'กำลังเข้าสู่ระบบ...' : 'เข้าสู่ระบบ'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
