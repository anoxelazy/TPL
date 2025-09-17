import 'package:flutter/material.dart';
import 'package:flutter_application_1/page/menu/menu.dart';
import 'package:flutter_application_1/page/claim/claim.dart';
import 'package:flutter_application_1/page/profile/profile.dart';
import 'package:flutter_application_1/screen/login.dart';
import 'package:url_launcher/url_launcher.dart'; // เพิ่มตรงนี้
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_application_1/page/claim/claim_history_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/page/logs/logs_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  String? _userId;

  final List<Widget> _pages = [
    const MenuPage(),
    const ClaimPage(),
    const ProfilePage(),
  ];

  final List<String> _titles = [
    'TP logistics',
    'Claim',
    'โปรไฟล์',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // void _logout() {
  //   Navigator.pushReplacement(
  //     context,
  //     MaterialPageRoute(builder: (context) => const LoginPage()),
  //   );
  // }

  Future<void> _navigateFromDrawer(int index) async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String version = packageInfo.version;
      debugPrint('App version: ' + version);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Version: ' + version)),
      );
    } catch (e) {
      debugPrint('Failed to get app version: ' + e.toString());
    }
    setState(() {
      _selectedIndex = index;
    });
    _scaffoldKey.currentState?.closeDrawer();
  }

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userId = prefs.getString('driverID') ?? '';
      });
    } catch (e) {
      debugPrint('Load user id failed: ' + e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      drawer: NavigationDrawer(onSelect: _navigateFromDrawer, onLogout: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }, onOpenClaimHistory: () {
        _scaffoldKey.currentState?.closeDrawer();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClaimHistoryPage(userId: _userId ?? ''),
          ),
        );
      }),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Menu',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.archive),
            label: 'Claim',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'โปรไฟล์',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        onTap: _onItemTapped,
      ),
    );
  }
}

class NavigationDrawer extends StatelessWidget {
  final Function(int) onSelect;
  final VoidCallback onLogout;
  final VoidCallback onOpenClaimHistory;

  const NavigationDrawer({super.key, required this.onSelect, required this.onLogout, required this.onOpenClaimHistory});

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'เมนูหลัก',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final String version = snapshot.hasData ? snapshot.data!.version : '-';
                    return Text(
                      'Version: ' + version,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600),
                    );
                  },
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: Text('Menu',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            onTap: () => onSelect(0),
          ),
          ListTile(
            leading: const Icon(Icons.archive),
            title: Text('Claim',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            onTap: () => onSelect(1),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: Text('โปรไฟล์',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            onTap: () => onSelect(2),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: Text('ประวัติการเคลม',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            onTap: onOpenClaimHistory,
          ),
          ListTile(
            leading: const Icon(Icons.event_note),
            title: Text('บันทึกการทำงาน',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LogsPage()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.link),
            title: Text('เว็บแจ้งปัญหาไอที',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            onTap: () => _launchURL('https://internal.thaiparcels.com:1150/'),
          ),
          // ListTile(
          //   leading: const Icon(Icons.logout),
          //   title: const Text('ออกจากระบบ'),
          //   onTap: onLogout,
          // ),
        ],
      ),
    );
  }
}
