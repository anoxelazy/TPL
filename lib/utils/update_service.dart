import 'dart:async';
import 'dart:convert';
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
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('https://anoxelazy.github.io/TPL/update.json?t=$timestamp'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final updateData = jsonDecode(response.body);

        final latestVersion = updateData['latest_version'] ?? '';
        final forceUpdate = updateData['force_update'] ?? false;
        final apkUrl = updateData['apk_url'] ?? '';
        final message = updateData['message'] ?? '';

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        // Send version data to Google Sheets (fire and forget - don't await)
        sendVersionToGoogleSheet();

        if (latestVersion.isNotEmpty &&
            _isVersionNewer(latestVersion, currentVersion)) {
          if (context.mounted) {
            await showDialog(
              context: context,
              barrierDismissible: !forceUpdate,
              builder: (BuildContext context) {
                return PopScope(
                  canPop: !forceUpdate,
                  child: _UpdateDialog(
                    currentVersion: currentVersion,
                    latestVersion: latestVersion,
                    message: message,
                    forceUpdate: forceUpdate,
                    apkUrl: apkUrl,
                  ),
                );
              },
            );
          }
          return forceUpdate;
        }
      }
      // No update available or check failed - return false
      return false;
    } on TimeoutException catch (e) {
      debugPrint('Update check timeout: $e');
      // Return false - app continues without blocking
      return false;
    } on SocketException catch (e) {
      debugPrint('Network error: $e');
      // Return false - app continues without blocking
      return false;
    } catch (e) {
      debugPrint('Update check error: $e');
      // Return false - app continues without blocking
      return false;
    }
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

      final sheetEndpoint = 'https://script.google.com/macros/s/AKfycbzMTA6IlcjnwwXWjO7-GA8NyfnX7rWvuqxKTnP0Vjs0iHEFZFswQsVl0CUwZeQR07up/exec';
      final sheetKey = '1407f066-e252-49aa-9099-a3f0942f319c';

      final uri = Uri.parse('$sheetEndpoint?key=$sheetKey');
      final body = jsonEncode(versionData);

      // Use timeout to prevent hanging
      await claim_api.postJsonPreserveRedirect(uri, body).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw TimeoutException('Version send timeout');
        },
      );
    } catch (e) {
      // Silently fail - version tracking is not critical
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

/// Custom Update Dialog with modern Material 3 design
class _UpdateDialog extends StatelessWidget {
  final String currentVersion;
  final String latestVersion;
  final String message;
  final bool forceUpdate;
  final String apkUrl;

  const _UpdateDialog({
    required this.currentVersion,
    required this.latestVersion,
    required this.message,
    required this.forceUpdate,
    required this.apkUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      elevation: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        colorScheme.primary,
                        colorScheme.primary.withValues(alpha: 0.8),
                      ]
                    : [
                        colorScheme.primary,
                        colorScheme.primary.withValues(alpha: 0.9),
                      ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                // App update icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    forceUpdate ? Icons.system_update_alt : Icons.update,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                // Title
                Text(
                  'อัปเดตแอปพลิเคชัน',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Version info
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'v$currentVersion → v$latestVersion',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Column(
              children: [
                Text(
                  message.isNotEmpty
                      ? message
                      : 'มีเวอร์ชันใหม่พร้อมให้ดาวน์โหลด กรุณาอัปเดตแอปเพื่อใช้งานฟีเจอร์ล่าสุด',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (forceUpdate) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: colorScheme.onErrorContainer,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'จำเป็นต้องอัปเดตก่อนใช้งาน',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Row(
              children: [
                if (!forceUpdate) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'ภายหลัง',
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: forceUpdate ? 1 : 1,
                  child: FilledButton(
                    onPressed: () async {
                      if (apkUrl.isEmpty) return;

                      final success = await UpdateService.launchExternalUrl(apkUrl);
                      if (!success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('ไม่สามารถเปิดลิงก์อัปเดตได้'),
                            backgroundColor: colorScheme.error,
                          ),
                        );
                      }

                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.download, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'อัปเดตเลย',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
