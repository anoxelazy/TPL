import 'package:flutter/material.dart';
import 'package:flutter_application_1/page/menu/menu.dart';
import 'package:flutter_application_1/page/claim/claim.dart';
import 'package:flutter_application_1/page/profile/profile.dart';
import 'package:flutter_application_1/screen/login.dart';
import 'package:url_launcher/url_launcher.dart'; // เพิ่มตรงนี้

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

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

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  void _navigateFromDrawer(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      drawer: NavigationDrawer(onSelect: _navigateFromDrawer, onLogout: _logout),
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

  const NavigationDrawer({super.key, required this.onSelect, required this.onLogout});

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
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.green),
            child: Text(
              'เมนูหลัก',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Menu'),
            onTap: () => onSelect(0),
          ),
          ListTile(
            leading: const Icon(Icons.archive),
            title: const Text('Claim'),
            onTap: () => onSelect(1),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('โปรไฟล์'),
            onTap: () => onSelect(2),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('เว็บแจ้งปัญหาไอที'),
            onTap: () => _launchURL('https://internal.thaiparcels.com:1150/'),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('ออกจากระบบ'),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}
