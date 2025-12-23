import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:claim/page/claim/claim_api.dart' as claim_api;

class UpdateService {
  static Future<bool> launchExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      return success;
    } catch (e) {
      debugPrint('Failed to launch URL: $e');
      return false;
    }
  }

  static Future<bool> checkForUpdates(BuildContext context) async {
    const int maxRetries = 3;
    const Duration initialDelay = Duration(seconds: 1);

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final response = await http.get(
          Uri.parse('https://anoxelazy.github.io/TPL/update.json?t=$timestamp'),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final updateData = jsonDecode(response.body);

          final latestVersion = updateData['latest_version'] ?? '';
          final forceUpdate = updateData['force_update'] ?? false;
          final apkUrl = updateData['apk_url'] ?? '';
          final message = updateData['message'] ?? '';

          final packageInfo = await PackageInfo.fromPlatform();
          final currentVersion = packageInfo.version;

          await sendVersionToGoogleSheet();

          if (latestVersion.isNotEmpty &&
              _isVersionNewer(latestVersion, currentVersion)) {
            if (context.mounted) {
              await showDialog(
                context: context,
                barrierDismissible: !forceUpdate,
                builder: (BuildContext context) {
                  return WillPopScope(
                    onWillPop: () async => !forceUpdate,
                    child: AlertDialog(
                      title: const Text('อัปเดตแอป'),
                      content: Text(
                        message.isNotEmpty
                            ? message
                            : 'มีเวอร์ชันใหม่ กรุณาอัปเดตถ้ากดอัพเดทไม่ได้กรุณาใส่ล็อกอิน Email ใน Browser ก่อนทำการอัพเดท',
                      ),
                      actions: [
                        if (!forceUpdate)
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('ภายหลัง'),
                          ),
                        TextButton(
                          onPressed: () async {
                            if (apkUrl.isEmpty) return;

                            final uri = Uri.parse(apkUrl);

                            final success = await launchExternalUrl(apkUrl);
                            if (!success) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('ไม่สามารถเปิดลิงก์อัปเดตได้'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }

                            Navigator.of(context).pop();
                          },
                          child: const Text('อัปเดต'),
                        ),
                      ],
                    ),
                  );
                },
              );
            }
            return forceUpdate;
          }
        }
        break;
      } on TimeoutException catch (e) {
        debugPrint('Update check timeout (attempt ${attempt + 1}/$maxRetries): $e');
        if (attempt < maxRetries - 1) {
          await Future.delayed(initialDelay * (1 << attempt));
          continue;
        }
        rethrow;
      } on SocketException catch (e) {
        debugPrint('Network error (attempt ${attempt + 1}/$maxRetries): $e');
        if (attempt < maxRetries - 1) {
          await Future.delayed(initialDelay * (1 << attempt));
          continue;
        }
        rethrow;
      } catch (e) {
        debugPrint('Update check error (attempt ${attempt + 1}/$maxRetries): $e');
        if (attempt < maxRetries - 1) {
          await Future.delayed(initialDelay * (1 << attempt));
          continue;
        }
        rethrow;
      }
    }
    return false;
  }

  static Future<void> sendVersionToGoogleSheet() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final prefs = await SharedPreferences.getInstance();
      final driverID = prefs.getString('driverID') ?? '';
      final fullname = prefs.getString('fullname') ?? '';

      final versionData = {
        'version': packageInfo.version,
        'version_string': '${packageInfo.version}+${packageInfo.buildNumber}',
        'buildNumber': packageInfo.buildNumber,
        'appName': packageInfo.appName,
        'packageName': packageInfo.packageName,
        'driverID': driverID,
        'fullname': fullname,
        'platform': Platform.operatingSystem,
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'version_check',
      };

      final sheetEndpoint = 'https://script.google.com/macros/s/AKfycbxdGLxrCcnAi2eWhO5s4RHIVWqMRxbX7kfQJKoHWd2Y35RUwzraogdkrfueUmOZ14Jd/exec';
      final sheetKey = '1407f066-e252-49aa-9099-a3f0942f319c';

      final uri = Uri.parse('$sheetEndpoint?key=$sheetKey');
      final body = jsonEncode(versionData);
      final response = await claim_api.postJsonPreserveRedirect(uri, body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Version data sent to Google Sheets successfully');
      } else {
        debugPrint('Failed to send version data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending version data to Google Sheets: $e');
    }
  }

  static bool _isVersionNewer(String latest, String current) {
    List<int> latestParts = latest.split('.').map(int.parse).toList();
    List<int> currentParts = current.split('.').map(int.parse).toList();

    for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return latestParts.length > currentParts.length;
  }
}
