import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/utils/app_logger.dart';

class ClaimHistoryPage extends StatefulWidget {
  final String userId;
  const ClaimHistoryPage({super.key, required this.userId});

  @override
  State<ClaimHistoryPage> createState() => _ClaimHistoryPageState();
}

class _ClaimHistoryPageState extends State<ClaimHistoryPage> {
  List<Map<String, dynamic>> _claimHistory = [];
  final String _password = '1234';

  @override
  void initState() {
    super.initState();
    _loadClaimHistory();
  }

  Future<void> _loadClaimHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'claim_history_${widget.userId}';
    final savedClaims = prefs.getStringList(key) ?? [];
    await AppLogger.I.log('history_loaded', data: {'count': savedClaims.length});

    final now = DateTime.now();
    final filteredClaims = savedClaims.where((e) {
      try {
        final claim = jsonDecode(e) as Map<String, dynamic>;
        final timestamp = DateTime.tryParse(claim['created_at'] ?? '') ?? now;
        return now.difference(timestamp).inDays <= 30;
      } catch (_) {
        return false;
      }
    }).toList();

    setState(() {
      _claimHistory = filteredClaims.map((e) {
        final claim = jsonDecode(e) as Map<String, dynamic>;
        claim['isSent'] = claim['isSent'] ?? false;
        return claim;
      }).toList();
    });
  }

  Future<void> _saveClaimHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'claim_history_${widget.userId}';
    await prefs.setStringList(
      key,
      _claimHistory.map((e) => jsonEncode(e)).toList(),
    );
  }

  Future<void> _deleteClaim(int index) async {
    final confirmed = await _askPassword();
    if (confirmed != true) return;

    setState(() {
      _claimHistory.removeAt(index);
    });
    await _saveClaimHistory();
    await AppLogger.I.log('history_deleted_one', data: {'index': index});
  }

  Future<void> _deleteAllClaims() async {
    final confirmed = await _askPassword();
    if (confirmed != true) return;

    setState(() {
      _claimHistory.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    final key = 'claim_history_${widget.userId}';
    await prefs.remove(key);
    await AppLogger.I.log('history_deleted_all');
  }

  Future<bool?> _askPassword() async {
    final TextEditingController passwordController = TextEditingController();
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('กรุณาใส่รหัสเพื่อยืนยัน'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'รหัส'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              if (passwordController.text == _password) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('รหัสไม่ถูกต้อง')));
              }
            },
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
  }

  Future<bool> _sendClaimToAPI(Map<String, dynamic> claim) async {
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  Future<void> _sendClaim(int index) async {
    final claim = _claimHistory[index];
    await AppLogger.I.log('history_send_clicked', data: {'index': index});
    bool success = await _sendClaimToAPI(claim);

    if (success) {
      setState(() {
        _claimHistory[index]['isSent'] = true;
      });
      await _saveClaimHistory();
      await AppLogger.I.log('history_send_success', data: {'index': index});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ส่ง Claim สำเร็จ')));
    } else {
      await AppLogger.I.log('history_send_failed', data: {'index': index});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ส่ง Claim ล้มเหลว')));
    }
  }

  void _viewImages(List<String> images) {
    if (images.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('รูปภาพ Claim')),
          body: ListView.builder(
            itemCount: images.length,
            itemBuilder: (context, index) {
              final url = images[index];
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.network(url, fit: BoxFit.contain),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        title: Text(
          'ประวัติการเคลม',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'ลบทั้งหมด',
            onPressed: _claimHistory.isEmpty ? null : () => _deleteAllClaims(),
          ),
        ],
      ),
      body: _claimHistory.isEmpty
          ? const Center(child: Text('ไม่มีประวัติการเคลม'))
          : ListView.builder(
              itemCount: _claimHistory.length,
              itemBuilder: (context, index) {
                final claim = _claimHistory[index];
                final timestamp =
                    DateTime.tryParse(claim['created_at'] ?? '') ??
                    DateTime.now();
                final images = List<String>.from(claim['images'] ?? []);
                final expiryDate = timestamp.add(const Duration(days: 30));

                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[100], 
                    borderRadius: BorderRadius.circular(12), 
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.local_shipping),
                    title: Text(
                      'เลขเอกสาร: ${claim['a1_no']}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ประเภท: ${claim['claim_type']}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'รหัสรถ: ${claim['truck_no']}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'วันที่สร้าง: ${DateFormat('dd/MM/yyyy').format(timestamp)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          'หมดอายุ: ${DateFormat('dd/MM/yyyy').format(expiryDate)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          'จำนวนรูป: ${images.length}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        if (images.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.image, color: Colors.blue),
                            tooltip: 'ดูรูปภาพ',
                            onPressed: () => _viewImages(images),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'ลบรายการนี้',
                          onPressed: () => _deleteClaim(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
