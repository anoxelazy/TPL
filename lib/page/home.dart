import 'package:claim/page/logs/logs_page.dart';
import 'package:flutter/material.dart';
import 'package:claim/page/menu/menu.dart';
import 'package:claim/page/claim/claim.dart';
import 'package:claim/page/profile/profile.dart';
import 'package:claim/screen/login.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  String? _userId;
  final ValueNotifier<bool> _isDialogOpen = ValueNotifier<bool>(false);
  final ValueNotifier<int> _unsentClaimsCount = ValueNotifier<int>(0);
  late final List<Widget> _pages;

  final List<String> _titles = [
    // 'TP Logistics',
    'บันทึกสินค้าเสียหาย/สูญหาย',
    'โปรไฟล์',
  ];

  final List<Map<String, dynamic>> claims = [];

  Future<bool> _confirmNavigation() async {
    if (!_hasPendingClaims()) return true;
    
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('มีรายการที่ยังไม่ได้ส่ง'),
          content: const Text('คุณมีรายการที่ยังไม่ได้ส่ง คุณต้องการออกจากหน้านี้หรือไม่?'),
          actions: <Widget>[
            TextButton(
              child: const Text('ยกเลิก'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('ออกจากหน้า'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    ) ?? false;
  }

  void _onItemTapped(int index) async {
    if (_selectedIndex == index) return;

    if (_isDialogOpen.value) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('ยังมีการแก้ไขอยู่'),
            content: const Text('มีหน้าต่างแก้ไขเปิดอยู่ คุณต้องการออกจากการแก้ไขหรือไม่?'),
            actions: [
              TextButton(
                child: const Text('กลับไปแก้ต่อ'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: const Text('ออกจากหน้า'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      ) ?? false;

      if (!leave) return; // stay in dialog

      Navigator.of(context, rootNavigator: true).popUntil((route) => route is PageRoute);
      _isDialogOpen.value = false;
    }

    if (index == 1 && _hasPendingClaims()) {
      final shouldContinue = await _showPendingClaimsDialog();
      if (!shouldContinue) {
        return;
      }
    } else if (_selectedIndex == 0 && _hasPendingClaims()) {
      final shouldNavigate = await _confirmNavigation();
      if (!shouldNavigate) {
        return;
      }
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  bool _hasPendingClaims() {
    return _unsentClaimsCount.value > 0;
  }

  Future<bool> _showPendingClaimsDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('มีรายการเคลมที่ยังไม่ได้ส่ง'),
          content: const Text('คุณมีรายการเคลมที่ยังไม่ได้ส่งไปยังระบบ คุณต้องการดำเนินการต่อหรือไม่?'),
          actions: <Widget>[
            TextButton(
              child: const Text('ยกเลิก'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('ดำเนินการต่อ'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    ) ?? false;
  }

  // void _logout() {
  //   Navigator.pushReplacement(
  //     context,
  //     MaterialPageRoute(builder: (context) => const LoginPage()),
  //   );
  // }

  Future<void> _navigateFromDrawer(int index) async {
    if (_isDialogOpen.value) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('ยังมีการแก้ไขอยู่'),
            content: const Text('มีหน้าต่างแก้ไขเปิดอยู่ คุณต้องการออกจากการแก้ไขหรือไม่?'),
            actions: [
              TextButton(
                child: const Text('กลับไปแก้ต่อ'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: const Text('ออกจากหน้า'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      ) ?? false;

      if (!leave) return;
      Navigator.of(context, rootNavigator: true).popUntil((route) => route is PageRoute);
      _isDialogOpen.value = false;
    }
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
    _pages = [
      ClaimPage(dialogOpenNotifier: _isDialogOpen, unsentCountNotifier: _unsentClaimsCount),
      const ProfilePage(),
    ];
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
    return WillPopScope(
      onWillPop: () async {
        if (_unsentClaimsCount.value > 0) {
          final leave = await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('มีรายการที่ยังไม่ได้ส่ง'),
                content: Text('มีรายการ ${_unsentClaimsCount.value} รายการที่ยังไม่ได้ส่ง คุณต้องการออกจากแอปหรือไม่?'),
                actions: [
                  TextButton(
                    child: const Text('ยกเลิก'),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  TextButton(
                    child: const Text('ออกจากแอป'),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              );
            },
          ) ?? false;
          return leave;
        }
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(_titles[_selectedIndex]),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          centerTitle: true,
          automaticallyImplyLeading: false,
      ),
      // drawer: NavigationDrawer(onSelect: _navigateFromDrawer, onLogout: () {
      //   Navigator.pushReplacement(
      //     context,
      //     MaterialPageRoute(builder: (context) => const LoginPage()),
      //   );
      // }),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          // BottomNavigationBarItem(
          //   icon: Icon(Icons.home),
          //   label: 'Menu',
          // ),
          BottomNavigationBarItem(
            icon: Icon(Icons.archive),
            label: 'Damage/Lost',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        backgroundColor: Theme.of(context).colorScheme.surface,
        onTap: _onItemTapped,
      ),
      ),
    );
  }
}

// class NavigationDrawer extends StatelessWidget {
//   final Function(int) onSelect;
//   final VoidCallback onLogout;

//   const NavigationDrawer({super.key, required this.onSelect, required this.onLogout});

//   Future<void> _launchURL(String url) async {
//     final Uri uri = Uri.parse(url);
//     if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
//       throw 'Could not launch $url';
//     }
//   }

  // @override
  // Widget build(BuildContext context) {
    // return Drawer(
    //   child: ListView(
    //     padding: EdgeInsets.zero,
    //     children: [
    //       DrawerHeader(
    //         decoration: BoxDecoration(
    //           color: Theme.of(context).colorScheme.primary,
    //         ),
    //         child: Column(
    //           crossAxisAlignment: CrossAxisAlignment.start,
    //           mainAxisAlignment: MainAxisAlignment.end,
    //           children: [
    //             Text(
    //               'เมนูหลัก',
    //               style: Theme.of(context)
    //                   .textTheme
    //                   .titleLarge
    //                   ?.copyWith(
    //                     color: Theme.of(context).colorScheme.onPrimary,
    //                     fontWeight: FontWeight.w700,
    //                   ),
    //             ),
    //             const SizedBox(height: 6),
    //             FutureBuilder<PackageInfo>(
    //               future: PackageInfo.fromPlatform(),
    //               builder: (context, snapshot) {
    //                 final String version = snapshot.hasData ? snapshot.data!.version : '-';
    //                 return Text(
    //                   'Version: ' + version,
    //                   style: Theme.of(context)
    //                       .textTheme
    //                       .labelLarge
    //                       ?.copyWith(
    //                         color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
    //                         fontWeight: FontWeight.w600,
    //                       ),
    //                 );
    //               },
    //             ),
    //           ],
    //         ),
    //       ),
    //       ListTile(
    //         leading: const Icon(Icons.home),
    //         title: Text('Menu',
    //             style: Theme.of(context)
    //                 .textTheme
    //                 .bodyLarge
    //                 ?.copyWith(fontWeight: FontWeight.w700)),
    //         onTap: () => onSelect(0),
    //       ),
    //       ListTile(
    //         leading: const Icon(Icons.archive),
    //         title: Text('บันทึกข้อมูล',
    //             style: Theme.of(context)
    //                 .textTheme
    //                 .bodyLarge
    //                 ?.copyWith(fontWeight: FontWeight.w700)),
    //         onTap: () => onSelect(1),
    //       ),
    //       ListTile(
    //         leading: const Icon(Icons.person),
    //         title: Text('Profile',
    //             style: Theme.of(context)
    //                 .textTheme
    //                 .bodyLarge
    //                 ?.copyWith(fontWeight: FontWeight.w700)),
    //         onTap: () => onSelect(2),
    //       ),
    //       ListTile(
    //         leading: const Icon(Icons.event_note),
    //         title: Text('บันทึกการทำงาน',
    //             style: Theme.of(context)
    //                 .textTheme
    //                 .bodyLarge
    //                 ?.copyWith(fontWeight: FontWeight.w700)),
    //         onTap: () {
    //           Navigator.of(context).push(
    //             MaterialPageRoute(builder: (_) => const LogsPage()),
    //           );
    //         },
    //       ),
    //       const Divider(),
    //       ListTile(
    //         leading: const Icon(Icons.link),
    //         title: Text('เว็บแจ้งปัญหาไอที',
    //             style: Theme.of(context)
    //                 .textTheme
    //                 .bodyLarge
    //                 ?.copyWith(fontWeight: FontWeight.w700)),
    //         onTap: () => _launchURL('https://internal.thaiparcels.com:1150/'),
    //       ),
    //       ListTile(
    //         leading: const Icon(Icons.logout),
    //         title: const Text('ออกจากระบบ'),
    //         onTap: onLogout,
    //       ),
    //     ],
    //   ),
    // );
//   }
// }