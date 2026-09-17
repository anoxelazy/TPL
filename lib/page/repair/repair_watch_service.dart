import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/page/repair/repair_api.dart';
import 'package:claim/utils/claim_reminder_service.dart';
import 'package:claim/utils/supabase_config.dart';

/// แจ้งเตือนเจ้าของใบแจ้งซ่อมเมื่อ IT รับงานหรือปิดงาน
///
/// ระบบหลังบ้านยังไม่มี push แอปจึงต้องเช็คเอง โดยเทียบสถานะล่าสุดกับที่จำไว้
/// ทุกครั้งที่เปิดหรือสลับกลับเข้าแอป การแจ้งเตือนจึงเด้งตอนเปิดแอป
/// ไม่ใช่วินาทีที่ IT กดรับงาน ถ้าต้องการแบบทันทีต้องทำ FCM ฝั่งเซิร์ฟเวอร์
class RepairWatchService {
  RepairWatchService._();

  static final RepairWatchService I = RepairWatchService._();

  static const String _snapshotKey = 'repair_status_snapshot';
  static const String _channelId = 'repair_status';
  static const int _baseNotificationId = 2000;

  /// กันยิงซ้ำถี่ ๆ ตอนผู้ใช้สลับแอปไปมา
  static const Duration _minGap = Duration(seconds: 60);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  DateTime? _lastCheck;
  bool _channelReady = false;

  /// เช็คว่ามีใบของเราเปลี่ยนสถานะไหม เงียบเสมอเมื่อล้มเหลว
  ///
  /// ไม่ throw ออกไปเลยเพราะเป็นงานเสริม พังแล้วต้องไม่กระทบการเปิดแอป
  /// [tickets] ส่งมาได้เมื่อหน้าจอเพิ่งโหลดรายการไปแล้ว จะได้ไม่ยิง API ซ้ำ
  /// [force] ข้ามตัวกันยิงถี่ ใช้ตอนผู้ใช้เปิดหน้าแจ้งซ่อมเอง
  Future<void> check({List<RepairTicket>? tickets, bool force = false}) async {
    if (!await SupabaseConfig.ensureKey()) {
      debugPrint('repair watch: ยังไม่มีคีย์ Supabase');
      return;
    }

    final now = DateTime.now();
    final last = _lastCheck;
    if (!force && last != null && now.difference(last) < _minGap) {
      debugPrint('repair watch: เพิ่งเช็คไป ข้ามรอบนี้');
      return;
    }
    _lastCheck = now;

    try {
      final prefs = await SharedPreferences.getInstance();
      final me = _normalize(prefs.getString('fullname') ?? '');
      final empId = prefs.getString('driverID') ?? '';
      if (me.isEmpty || empId.isEmpty) {
        debugPrint('repair watch: ยังไม่ได้ login');
        return;
      }

      final all = tickets ?? await fetchRepairs();
      final mine = all
          .where((t) => t.id != null && _normalize(t.requesterName) == me)
          .toList();
      if (mine.isEmpty) {
        debugPrint('repair watch: ไม่มีใบที่ "$me" เป็นผู้แจ้ง');
        return;
      }

      final key = '${_snapshotKey}_$empId';
      final hasSnapshot = prefs.containsKey(key);
      final previous = _readSnapshot(prefs.getString(key));

      final changed = <RepairTicket>[
        for (final ticket in mine)
          if (previous[ticket.id.toString()] != null &&
              previous[ticket.id.toString()] != ticket.status.code)
            ticket,
      ];

      await prefs.setString(
        key,
        jsonEncode({for (final t in mine) t.id.toString(): t.status.code}),
      );

      // ครั้งแรกยังไม่มีของเดิมให้เทียบ บันทึกไว้เฉย ๆ ไม่งั้นจะเด้งรวดเดียว
      // ทุกใบที่เคยแจ้งไว้ตั้งแต่อดีต
      if (!hasSnapshot) {
        debugPrint(
          'repair watch: จำสถานะครั้งแรกของ ${mine.length} ใบ ยังไม่แจ้ง',
        );
        return;
      }

      debugPrint(
        'repair watch: เปลี่ยนสถานะ ${changed.length} ใบ จาก ${mine.length} ใบของเรา',
      );

      for (final ticket in changed) {
        await _notify(ticket);
      }
    } catch (e) {
      debugPrint('repair watch failed: $e');
    }
  }

  /// ล้างของที่จำไว้ตอน logout ไม่จำเป็น เพราะ key แยกตามรหัสพนักงานอยู่แล้ว
  /// แต่ต้องรีเซ็ตตัวกันยิงซ้ำ ไม่งั้นคนถัดไปที่ login จะโดนข้ามรอบแรก
  void forgetCurrentUser() => _lastCheck = null;

  Future<void> _notify(RepairTicket ticket) async {
    final String title;
    switch (ticket.status) {
      case RepairStatus.inProgress:
        title = 'IT รับงานซ่อมแล้ว';
      case RepairStatus.completed:
        title = 'ซ่อมเสร็จแล้ว';
      // ย้อนกลับไปรอรับเรื่องไม่ต้องกวนผู้ใช้
      case RepairStatus.pending:
        return;
    }

    final device = ticket.deviceName.isEmpty ? ticket.sn : ticket.deviceName;
    final tech = ticket.technicianName.isEmpty
        ? ''
        : ' · ช่าง ${ticket.technicianName}';

    await _ensureChannel();
    if (!_channelReady) return;

    await _plugin.show(
      // ผูก id กับใบ ใบหลายใบจะได้ไม่ทับกัน
      id: _baseNotificationId + (ticket.id! % 1000),
      title: title,
      body: '$device$tech',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'สถานะงานซ่อม',
          channelDescription: 'แจ้งเมื่อ IT รับงานหรือปิดงานซ่อมของคุณ',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// ใช้ปลั๊กอินตัวเดียวกับตัวเตือนเคลม (คลาสนี้เป็น singleton อยู่แล้ว)
  /// จึงยืม init ของที่นั่นมาใช้ ไม่ต้องขอสิทธิ์แจ้งเตือนซ้ำอีกรอบ
  Future<void> _ensureChannel() async {
    if (_channelReady) return;

    try {
      await ClaimReminderService.I.init();

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            'สถานะงานซ่อม',
            description: 'แจ้งเมื่อ IT รับงานหรือปิดงานซ่อมของคุณ',
            importance: Importance.high,
          ),
        );
      }

      _channelReady = true;
    } catch (e) {
      debugPrint('repair notification channel failed: $e');
    }
  }

  Map<String, String> _readSnapshot(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          entry.key.toString(): entry.value.toString(),
      };
    } catch (e) {
      return const {};
    }
  }

  /// ชื่อจาก API พนักงานมีช่องว่างซ้อนกันหลายตัว เทียบตรง ๆ จะไม่ตรง
  String _normalize(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
}
