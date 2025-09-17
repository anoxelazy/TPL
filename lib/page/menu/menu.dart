import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/page/menu/webviewpage.dart';
import 'package:flutter_application_1/page/pm/pm.dart';
import 'package:flutter_application_1/page/claim/claim.dart';
import 'package:flutter_application_1/page/qr_pay.dart/qr.dart';
import 'package:url_launcher/url_launcher.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late Timer _timer;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> menuItems = [
    {'title': 'PM', 'icon': Icons.computer, 'page': const PMPage()},
    {'title': 'Claim', 'icon': Icons.receipt_long, 'page': const ClaimPage()},
    {
      'title': 'เว็บ',
      'icon': Icons.public,
      'page': WebViewPage(url: 'https://internal.thaiparcels.com:1150/'),
    },
    {
      'title': 'Tracking',
      'icon': Icons.local_shipping,
      'page': WebViewPage(url: 'https://tptrack.info/ecom/dtrack.php'),
    },
    {'title': 'QR', 'icon': Icons.qr_code, 'page': const QrPage()},
  ];

  List<Map<String, dynamic>> filteredMenuItems = [];

  @override
  void initState() {
    super.initState();
    filteredMenuItems = menuItems;

    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (_currentPage < 2) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });

    _searchController.addListener(() {
      final query = _searchController.text.toLowerCase();
      setState(() {
        filteredMenuItems = menuItems
            .where((item) => item['title'].toLowerCase().contains(query))
            .toList();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: SizedBox(
              height: 180,
              child: PageView.builder(
                controller: _pageController,
                itemCount: 3,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final images = [
                    'assets/images/TP1.png',
                    'assets/images/TP2.png',
                    'assets/images/TP3.png',
                  ];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      images[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหาเมนู...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GridView.count(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: filteredMenuItems.map((item) {
                  return _buildMenuCardWithLabel(
                    context,
                    icon: item['icon'],
                    title: item['title'],
                    page: item['page'],
                    url: item['url'],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCardWithLabel(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget page,
    String? url,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: Colors.black),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> openWeb(String url) async {
    final Uri uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      print('ไม่สามารถเปิดเว็บไซต์ได้');
    }
  }
}
