import 'dart:convert';
import 'package:claim/page/claim/claim.dart';
import 'package:flutter/material.dart';
import 'package:claim/page/home.dart';
// ignore: unused_import
import 'package:claim/page/profile/profile.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:claim/utils/app_logger.dart';

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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

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
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isPasswordVisible = false;
  bool isLoading = false;

  Future<void> _login() async {
    await AppLogger.I.log('login_clicked');
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      await AppLogger.I.log('login_validation_failed', data: {
        'reason': 'empty_fields',
      });
      _showError("กรุณาใส่รหัสพนักงานและรหัสผ่าน");
      return;
    }

    setState(() {
      isLoading = true;
    });

    final url = Uri.parse("http://61.91.54.130:1159/Login");
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
          "เข้าสู่ระบบล้มเหลว: ${response.statusCode}\n${response.body}",
        );
      }
    } catch (e) {
      await AppLogger.I.log('login_exception', data: {
        'error': e.toString(),
      });
      _showError("เกิดข้อผิดพลาด: $e");
    }

    setState(() {
      isLoading = false;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
                Image.asset('assets/images/tpicon.png', width: 200, height: 200),
                const SizedBox(height: 20),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อ หรือ รหัสพนักงาน',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  obscureText: !isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'รหัสผ่าน',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          isPasswordVisible = !isPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
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
