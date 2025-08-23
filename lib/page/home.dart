import 'package:flutter/material.dart';
import 'package:flutter_application_1/page/claim.dart';
import 'package:flutter_application_1/page/pm.dart';
import 'package:flutter_application_1/page/profile.dart';
import 'package:flutter_application_1/screen/login.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const PMPage(),
    const ClaimPage(),
    const ProfilePage(),
    Center(child: Text('หน้าหลัก', style: TextStyle(fontSize: 20))),
    Center(child: Text('ค้นหา', style: TextStyle(fontSize: 20))),
    Center(child: Text('โปรไฟล์', style: TextStyle(fontSize: 20))),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TP logistics'),
        backgroundColor: Colors.green,
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.logout),
          //   onPressed: _logout,
          //   tooltip: 'ออกจากระบบ',
          // ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.computer),
            label: 'PM',
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
