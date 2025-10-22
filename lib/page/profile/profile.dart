import 'package:flutter/material.dart';
import 'package:claim/screen/login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String fullName = "";
  String driverID = "";
  String appVersion = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    if (token == null) {

      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginPage()));
      return;
    }

    // Load app version
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version;
    } catch (e) {
      appVersion = "ไม่พบเวอร์ชัน";
    }

    setState(() {
      fullName = prefs.getString("fullname") ?? "ไม่มีชื่อ";
      driverID = prefs.getString("driverID") ?? "ไม่มีรหัส";
      isLoading = false;
    });
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    await prefs.remove("fullname");
    await prefs.remove("driverID");

    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   automaticallyImplyLeading: false,
      //   centerTitle: false,
      //   titleSpacing: 16,
      //   backgroundColor: Theme.of(context).colorScheme.surface,
      //   title: Text(
      //     "โปรไฟล์ของฉัน",
      //     style: Theme.of(context).textTheme.titleLarge?.copyWith(
      //       color: Theme.of(context).colorScheme.onSurface,
      //     ),
      //   ),
      // ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: const AssetImage(
                        "assets/images/profile.png"), 
                  ),
                  const SizedBox(height: 20),
                  Text(
                    fullName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "รหัสพนักงาน: $driverID",
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "เวอร์ชันแอป: $appVersion",
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                  ),

                  const SizedBox(height: 10),
                  Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    color: Theme.of(context).colorScheme.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: Icon(Icons.logout,
                          color: Theme.of(context).colorScheme.error),
                      title: Text(
                        "ออกจากระบบ",
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                      onTap: _logout,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (driverID.isNotEmpty && driverID != "ไม่มีรหัส") ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            "QR Code รหัสพนักงาน",
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          QrImageView(
                            data: driverID,
                            version: QrVersions.auto,
                            size: 200.0,
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            foregroundColor: Theme.of(context).colorScheme.onSurface,
                            errorCorrectionLevel: QrErrorCorrectLevel.M,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            driverID,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
    );
  }
}
