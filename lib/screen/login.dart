import 'dart:async';

import 'package:flutter/material.dart';
import 'package:claim/page/home.dart';
import 'package:claim/utils/announcement_service.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:claim/utils/app_logger.dart';
import 'package:claim/utils/permission_service.dart';
import 'package:claim/utils/profile_avatar_service.dart';
import 'package:claim/utils/rank_service.dart';
import 'package:claim/utils/role_service.dart';
import 'package:claim/utils/dio_service.dart';
import 'package:claim/utils/mobile_api.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    // ไม่เช็คอัปเดตที่นี่ MyApp ยิงให้ตั้งแต่เฟรมแรกอยู่แล้ว เรียกซ้ำที่นี่
    // เท่ากับโหลด update.json สองรอบและเสี่ยงได้ dialog แจ้งอัปเดตซ้อนกัน
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    await PermissionService.I.loadFromPrefs();

    if (token != null && token.isNotEmpty) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } else {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Image(
                image: AssetImage('assets/images/TPL1.png'),
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 24),
              Text(
                'กำลังเริ่มต้นแอปพลิเคชัน...',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController emailController;
  late final TextEditingController passwordController;
  final ValueNotifier<bool> isPasswordVisibleNotifier = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);

  static const InputDecoration _emailDecoration = InputDecoration(
    labelText: 'ชื่อ หรือ รหัสพนักงาน',
    border: OutlineInputBorder(),
  );

  static const InputDecoration _passwordDecoration = InputDecoration(
    labelText: 'รหัสผ่าน',
    border: OutlineInputBorder(),
  );

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController();
    passwordController = TextEditingController();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    isPasswordVisibleNotifier.dispose();
    isLoadingNotifier.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    await AppLogger.I.log('login_clicked');
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      await AppLogger.I.log(
        'login_validation_failed',
        data: {'reason': 'empty_fields'},
      );
      _showError("กรุณาใส่รหัสพนักงานและรหัสผ่าน");
      return;
    }

    isLoadingNotifier.value = true;

    final packageInfo = await PackageInfo.fromPlatform();

    final body = {
      "username": emailController.text,
      "password": passwordController.text,
      "typeApp": "New",
      "versionNo": packageInfo.version,
      "app_name": "mobile สินค้าเสียหายสูญหาย",
    };

    try {
      final response = await dio
          .post(
            '/Login',
            data: body,
            options: Options(headers: {"Accept": "application/json"}),
          )
          .timeout(const Duration(seconds: 10));

      await AppLogger.I.log(
        'login_response',
        data: {'status': response.statusCode},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final token = data["token"];
        final fullname = data["fullname"];
        final driverID = data["driverID"];
        await AppLogger.I.log(
          'login_success',
          data: {'fullname': fullname, 'driverID': driverID},
        );

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", token);
        await prefs.setString("fullname", fullname);
        await prefs.setString("driverID", driverID);
        // เก็บชื่อผู้ใช้ที่กรอกเข้ามา ใช้ทักทายบนหน้าหลัก
        await prefs.setString("username", emailController.text.trim());

        await PermissionService.I.saveFromLoginResponse(data);
        // รูปโปรไฟล์เก็บแยกตามรหัสพนักงาน ต้องโหลดของคนที่เพิ่ง login
        // ตัว init ตอนเปิดแอปยังไม่รู้ว่าใครจะเข้ามา
        await ProfileAvatarService.I.init();
        // สิทธิ์แจ้งซ่อมอยู่คนละระบบ ต้องเอา driverID ไปถาม Supabase ต่ออีกที
        await RoleService.I.init();
        await RankService.I.init();

        // Mobile API (ระบบ PM) ออก token ของตัวเอง แลกด้วยรหัสชุดเดียวกัน
        // ตรงนี้เลย ผู้ใช้จะได้ไม่ต้องกรอกรหัสซ้ำตอนเข้าเมนู PM
        //
        // ล้มเหลวไม่ทำให้ล็อกอินล้มตาม แค่เมนูที่ใช้ API ตัวนั้นจะใช้ไม่ได้
        // แล้วบอกให้เข้าสู่ระบบใหม่ ดีกว่ากันไม่ให้เข้าแอปทั้งแอป
        await MobileSession.I.signIn(
          username: emailController.text.trim(),
          password: passwordController.text,
        );

        debugPrint("Login successful, token: $token");
        await AppLogger.I.log('login_token_display', data: {'token': token});

        if (!mounted) return;

        // แทนหน้า login ไปเลย ไม่เหลือไว้ใน stack ให้กด back ย้อนมาได้
        final navigator = Navigator.of(context);
        navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
        );

        // ประกาศเด้งตรงนี้ ไม่ต้องรอเปิดแอปรอบหน้า
        //
        // ตอนเปิดแอปยังไม่มี token ตัวเช็คเลยข้ามไป คนที่เพิ่งล็อกอินจะพลาด
        // ประกาศไปทั้งรอบถ้าไม่ยิงซ้ำที่นี่ ใช้ context ของ navigator
        // เพราะหน้า login ถูกแทนที่ไปแล้ว context ของมันใช้ต่อไม่ได้
        unawaited(AnnouncementService.I.showIfAny(navigator.context));
        return;
      } else {
        await AppLogger.I.log(
          'login_failed',
          data: {
            'status': response.statusCode,
            'body': response.data.toString(),
          },
        );
        _showError("เข้าสู่ระบบล้มเหลวโปรดใส่ชื่อกับรหัสตามระบบโปรแกรมTPS");
      }
    } on DioException catch (e) {
      await AppLogger.I.log(
        'login_error',
        data: {'type': e.type.toString(), 'error': e.toString()},
      );
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        _showError(
          "การเชื่อมต่อใช้เวลานานเกินไป กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ตและลองใหม่อีกครั้ง",
        );
      } else {
        _showError(
          "ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้ ชื่อหรือรหัสผ่านไม่ถูกต้อง หรืออาจมีปัญหาที่อินเทอร์เน็ตของคุณ ",
        );
      }
    } catch (e) {
      await AppLogger.I.log('login_exception', data: {'error': e.toString()});
      _showError("เกิดข้อผิดพลาดในการเข้าสู่ระบบ กรุณาลองใหม่อีกครั้ง");
    }

    isLoadingNotifier.value = false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'ปิด',
          textColor: Theme.of(context).colorScheme.onError,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      // หน้านี้ไม่มี AppBar ต้องกัน status bar เอง ไม่งั้นตอนคีย์บอร์ดขึ้น
      // เนื้อหาจะเลื่อนไปมุดใต้นาฬิกาของเครื่อง
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Image(
                    image: AssetImage('assets/images/tpicon.png'),
                    width: 200,
                    height: 200,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _emailDecoration,
                  ),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<bool>(
                    valueListenable: isPasswordVisibleNotifier,
                    builder: (context, isPasswordVisible, _) {
                      return TextField(
                        controller: passwordController,
                        obscureText: !isPasswordVisible,
                        decoration: _passwordDecoration.copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              isPasswordVisibleNotifier.value =
                                  !isPasswordVisible;
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: isLoadingNotifier,
                      builder: (context, isLoading, _) {
                        return ElevatedButton(
                          onPressed: isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                          ),
                          child: isLoading
                              // ต้องล็อกขนาดเป็นสี่เหลี่ยมจัตุรัส ไม่งั้นตัวหมุน
                              // จะยืดเต็มความกว้างปุ่มจนกลายเป็นวงรีแบน
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                )
                              : Text(
                                  'เข้าสู่ระบบ',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
