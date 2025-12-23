import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:claim/page/claim/claim.dart';
import 'package:flutter/material.dart';
import 'package:claim/page/home.dart';
// ignore: unused_import
import 'package:claim/page/profile/profile.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:claim/utils/app_logger.dart';
import 'package:claim/utils/update_service.dart';

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
    // Start version tracking in background (non-blocking)
    UpdateService.sendVersionToGoogleSheet();

    // Check for updates (may block on force update)
    bool shouldBlock = await UpdateService.checkForUpdates(context);
    if (shouldBlock) return; // Block further execution if force update

    // Get user preferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    // Navigate based on authentication status
    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
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
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Image(
                image: AssetImage('assets/images/tpicon.png'),
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
  final ValueNotifier<bool> isPasswordVisibleNotifier = ValueNotifier<bool>(false);
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
      await AppLogger.I.log('login_validation_failed', data: {
        'reason': 'empty_fields',
      });
      _showError("กรุณาใส่รหัสพนักงานและรหัสผ่าน");
      return;
    }

    isLoadingNotifier.value = true;

    final url = Uri.parse("http://147.50.36.66:1152/Login");
    final body = {
      "username": emailController.text,
      "password": passwordController.text,
      "typeApp": "New",
    };

    try {
      final response = await http
          .post(
            url,
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      await AppLogger.I.log('login_response', data: {
        'status': response.statusCode,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data["token"];
        final fullname = data["fullname"];
        final driverID = data["driverID"];
        await AppLogger.I.log('login_success', data: {
          'fullname': fullname,
          'driverID': driverID,
        });

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", token);
        await prefs.setString("fullname", fullname);
        await prefs.setString("driverID", driverID);

        // Show token in a dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('เข้าสู่ระบบสำเร็จ'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ชื่อ: $fullname'),
                    Text('รหัสพนักงาน: $driverID'),
                    const SizedBox(height: 10),
                    const Text('Token:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SelectableText(
                      token,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const ClaimPage()),
                      );
                    },
                    child: const Text('ตกลง'),
                  ),
                ],
              );
            },
          );
        }

        debugPrint("Login successful, token: $token");
        await AppLogger.I.log('login_token_display', data: {'token': token});

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        await AppLogger.I.log('login_failed', data: {
          'status': response.statusCode,
          'body': response.body,
        });
        _showError(
          "เข้าสู่ระบบล้มเหลวโปรดใส่ชื่อกับรหัสตามระบบโปรแกรมTPS",
        );
      }
    } on TimeoutException catch (e) {
      await AppLogger.I.log('login_timeout', data: {
        'error': e.toString(),
      });
      _showError("การเชื่อมต่อใช้เวลานานเกินไป กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ตและลองใหม่อีกครั้ง");
    } on SocketException catch (e) {
      await AppLogger.I.log('login_network_error', data: {
        'error': e.toString(),
      });
      _showError("ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้ กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต");
    } catch (e) {
      await AppLogger.I.log('login_exception', data: {
        'error': e.toString(),
      });
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
      body: GestureDetector(
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
                            isPasswordVisibleNotifier.value = !isPasswordVisible;
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
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        ),
                        child: isLoading
                            ? CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary)
                            : Text(
                                'เข้าสู่ระบบ',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Theme.of(context).colorScheme.onPrimary,
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
    );
  }
}
