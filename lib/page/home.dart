import 'package:flutter/material.dart';
import 'package:claim/page/dashboard/dashboard_page.dart';
import 'package:claim/page/profile/profile.dart';
import 'package:claim/utils/permission_service.dart';

class TabConfig {
  final String? module;
  final String title;
  final IconData icon;
  final Widget Function() pageBuilder;

  TabConfig({
    required this.module,
    required this.title,
    required this.icon,
    required this.pageBuilder,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  List<Widget> _pages = [];
  List<TabConfig> _tabs = [];

  @override
  void initState() {
    super.initState();
    _loadPermissionsAndBuildTabs();
  }

  Future<void> _loadPermissionsAndBuildTabs() async {
    if (mounted) setState(() => _buildTabs());
  }

  void _buildTabs() {
    final allTabs = <TabConfig>[
      TabConfig(
        module: null,
        title: 'หน้าหลัก',
        icon: Icons.home,
        pageBuilder: () => const DashboardPage(),
      ),
      TabConfig(
        module: null,
        title: 'โปรไฟล์',
        icon: Icons.person,
        pageBuilder: () => const ProfilePage(),
      ),
    ];

    final visible = allTabs
        .where(
          (t) => t.module == null || PermissionService.I.canAccess(t.module!),
        )
        .toList();

    _tabs = visible.isNotEmpty ? visible : [allTabs.last];
    _pages = _tabs.map<Widget>((t) => t.pageBuilder()).toList();
    if (_selectedIndex >= _tabs.length) _selectedIndex = 0;
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_tabs.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                'ไม่มีสิทธิ์เข้าใช้งาน',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      // ไม่มี AppBar แล้ว ต้องกัน status bar เอง (bottom ปล่อยให้ Scaffold
      // จัดการ เพราะมี bottomNavigationBar อยู่แล้ว)
      body: SafeArea(bottom: false, child: _pages[_selectedIndex]),
      bottomNavigationBar: BottomNavigationBar(
        items: _tabs
            .map(
              (t) =>
                  BottomNavigationBarItem(icon: Icon(t.icon), label: t.title),
            )
            .toList(),
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        backgroundColor: Theme.of(context).colorScheme.surface,
        onTap: _onItemTapped,
      ),
    );
  }
}
