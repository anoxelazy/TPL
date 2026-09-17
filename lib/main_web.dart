import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/page/dashboard/it_case_banner.dart';
import 'package:claim/page/dashboard/it_case_open_cards.dart';
import 'package:claim/page/itcase/itcase_appbar.dart';
import 'package:claim/page/itcase/itcase_status_page.dart';
import 'package:claim/page/repair/repair_page.dart';
import 'package:claim/utils/app_colors.dart';
import 'package:claim/utils/mobile_api.dart';
import 'package:claim/utils/role_service.dart';
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
  await _syncEmpId();
  await RoleService.I.init();

  runApp(const ItCaseWebApp());
}

class ItCaseWebApp extends StatelessWidget {
  const ItCaseWebApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'แจ้งเคส IT',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.getLightTheme(),
    // จอคอมกว้างกว่ามือถือหลายเท่า ปล่อยให้เนื้อหายืดเต็มจอ 24 นิ้วแล้วสายตา
    // ต้องกวาดไปมาทั้งจอกว่าจะอ่านจบบรรทัด บีบให้เท่าแท็บเล็ตแล้วจัดกลาง
    // ครอบที่ builder ทีเดียว ทุกหน้าที่ push ต่อไปได้ความกว้างเท่ากันหมด
    builder: (context, child) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: child,
      ),
    ),
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
      ? _HomePage(onSignOut: _signOut)
      : _LoginPage(onDone: () => setState(() => _signedIn = true));

  Future<void> _signOut() async {
    await MobileSession.I.clear();
    // ล้างรหัสพนักงานด้วย ไม่งั้นคนถัดไปที่ล็อกอินจะได้สิทธิ์ของคนก่อนหน้า
    // จนกว่า RoleService จะถามใหม่เสร็จ
    await _syncEmpId();
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

/// หน้าแรกหลังล็อกอินบนเว็บ
///
/// เดิมเข้ามาเจอฟอร์มแจ้งเคสเลย ซึ่งใช้ได้บนมือถือที่กดเข้ามาจากเมนู
/// "แจ้งเคส" โดยตั้งใจอยู่แล้ว แต่บนเว็บมันคือหน้าแรกหลังล็อกอิน คนเปิดมาเจอ
/// ฟอร์มเปล่า ๆ จะนึกว่าเว็บมีแค่นี้ ทั้งที่ยังมีรายการเคสกับความคืบหน้าอยู่
///
/// เอาของชุดเดียวกับหน้าหลักในแอปมือถือมาวาง คือแถบแจ้งเคสกับการ์ดเคสที่ยัง
/// ไม่ปิด ไม่ได้ทำหน้าใหม่ให้ต้องดูแลสองที่
class _HomePage extends StatelessWidget {
  final VoidCallback onSignOut;

  const _HomePage({required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: itCaseAppBar(
        title: 'แจ้งเคส IT',
        actions: [
          IconButton(
            tooltip: 'ขั้นตอนการดำเนินงาน',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ItCaseStatusPage())),
            icon: const Icon(Icons.list_alt),
          ),
          IconButton(
            tooltip: 'ออกจากระบบ',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const ItCaseBanner(),
          const SizedBox(height: AppSizes.gap),
          _MenuBanner(
            icon: Icons.build_circle_outlined,
            color: AppColors.repairIcon,
            background: AppColors.repairBg,
            title: 'แจ้งซ่อม',
            subtitle: 'เครื่องเสีย อุปกรณ์ใช้งานไม่ได้',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const RepairPage())),
          ),
          // ไม่มีเคสค้าง การ์ดชุดนี้จะไม่กินที่เลย เหลือแถบเมนูสองอัน
          const ItCaseOpenCases(),
        ],
      ),
    );
  }
}

/// ให้ระบบอื่นรู้ว่าใครล็อกอินอยู่ ผ่านรหัสพนักงานที่ Mobile API ส่งกลับมา
///
/// บนมือถือ `driverID` ถูกเขียนตอนล็อกอินที่ API หลัก แต่เว็บไม่ได้ผ่านทางนั้น
/// ถ้าไม่เขียนเอง [RoleService] จะหาไม่เจอว่าใครล็อกอินอยู่ แล้วถือเป็น USER
/// ทุกคน เมนูของทีม IT ในหน้าแจ้งซ่อมจะไม่ขึ้นเลยแม้แต่กับคนที่เป็น IT จริง
///
/// ตัวสิทธิ์จริงยังไปถามที่ Supabase เหมือนเดิม ตรงนี้แค่บอกว่าจะถามของใคร
Future<void> _syncEmpId() async {
  final empNo = MobileSession.I.empNo;
  final prefs = await SharedPreferences.getInstance();

  if (empNo == null || empNo.isEmpty) {
    await prefs.remove('driverID');
    return;
  }

  await prefs.setString('driverID', empNo);
}

/// แถบเมนูเต็มความกว้างบนหน้าแรกของเว็บ
///
/// หน้าตาเดียวกับแถบแจ้งเคสบนหน้าหลักของแอปมือถือ แต่รับสีกับข้อความมาจาก
/// ข้างนอก เว็บมีเมนูน้อยจนไม่คุ้มจะทำเป็นตารางไอคอนแบบในแอป วางเป็นแถวยาว
/// อ่านง่ายกว่าบนจอคอม
class _MenuBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuBanner({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppSizes.cardRadius);

    return Material(
      color: scheme.surface,
      borderRadius: radius,
      // แถบสีด้านซ้ายต้องโดนตัดตามมุมโค้ง ไม่งั้นมุมจะแหลมโผล่ออกมา
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: color.withValues(alpha: 0.28),
              width: AppSizes.cardBorder,
            ),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                color.withValues(alpha: 0.13),
                color.withValues(alpha: 0.03),
              ],
            ),
          ),
          child: Row(
            children: [
              Container(width: 5, height: 78, color: color),
              const SizedBox(width: 13),
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 26, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}
