import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:claim/utils/claim_store.dart';

/// แจ้งเตือนบนโทรศัพท์ก่อนที่ระบบจะล้างฟอร์มสินค้าเสียหาย/สูญหายตอนเที่ยงคืน
///
/// ฟอร์มมีอายุแค่ภายในวันที่สร้าง ([ClaimStore.purgeExpired] ลบทิ้งตอนเที่ยงคืน)
/// ถ้าผู้ใช้ยังมีรายการที่ไม่ได้ส่งค้างอยู่ จะได้แจ้งเตือนล่วงหน้าเพื่อส่งให้ทัน
class ClaimReminderService {
  ClaimReminderService._();

  static final ClaimReminderService I = ClaimReminderService._();

  /// เวลาที่ต้องการให้แจ้งเตือน (นาฬิกา 24 ชม.)
  static const int reminderHour = 20;

  /// ไม่แจ้งเตือนทันทีที่ผู้ใช้เพิ่งปิดแอป เว้นระยะไว้ก่อน
  static const Duration _minLeadTime = Duration(minutes: 15);

  /// แอปใช้งานในไทย ผูก timezone ไว้ตรง ๆ ไม่ต้องพึ่ง tz ของเครื่อง
  /// เพราะถ้าเครื่องตั้ง timezone อื่นเวลาล้างข้อมูลก็ยังยึดเวลาไทย
  static const String _timeZone = 'Asia/Bangkok';

  static const int _notificationId = 1001;
  static const String _channelId = 'claim_purge_reminder';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  /// รองรับแค่มือถือ บนเดสก์ท็อป/เว็บให้เงียบไปเลย
  bool get _supported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// เตรียม plugin, ช่องแจ้งเตือน และขอสิทธิ์ เรียกซ้ำได้
  Future<void> init() async {
    if (!_supported || _ready) return;

    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(_timeZone));

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings: settings);

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            'เตือนก่อนล้างข้อมูล',
            description:
                'เตือนให้ส่งรายการที่ค้างก่อนระบบล้างข้อมูลตอนเที่ยงคืน',
            importance: Importance.high,
          ),
        );
        // Android 13+ ต้องขอสิทธิ์ก่อนถึงจะแจ้งเตือนได้
        await android.requestNotificationsPermission();
      }

      _ready = true;
    } catch (e) {
      debugPrint('ClaimReminder: init failed: $e');
    }
  }

  /// ตั้ง/ยกเลิกการแจ้งเตือนตามจำนวนรายการที่ค้างอยู่ตอนนี้
  ///
  /// เรียกตอนเปิดแอปและตอนแอปถูกพักไป เพราะรายการเปลี่ยนได้เฉพาะขณะแอปทำงาน
  /// จำนวนที่ใส่ในข้อความจึงตรงกับความจริงตอนแจ้งเตือนเสมอ
  Future<void> refresh() async {
    if (!_supported) return;
    await init();
    if (!_ready) return;

    try {
      // ตั้งใหม่ทุกครั้ง กันข้อความค้างจำนวนเก่า
      await _plugin.cancel(id: _notificationId);

      // รายการอาจยังโหลดไม่เสร็จ ตอนเปิดแอปเราไม่รอมันก่อนวาดจอแรกแล้ว
      await ClaimStore.I.init();
      final int unsent = ClaimStore.I.unsentCount;
      if (unsent <= 0) return;

      final DateTime? fireAt = resolveFireTime(DateTime.now());
      if (fireAt == null) return;

      await _plugin.zonedSchedule(
        id: _notificationId,
        scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
        title: 'มีรายการค้างยังไม่ได้ส่ง $unsent รายการ',
        body:
            'ระบบจะล้างข้อมูลทั้งหมดตอนเที่ยงคืน '
            'กรุณาเปิดแอปแล้วส่งให้ครบก่อนหมดวัน',
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      debugPrint('ClaimReminder: scheduled $unsent unsent at $fireAt');
    } catch (e) {
      debugPrint('ClaimReminder: refresh failed: $e');
    }
  }

  /// ยกเลิกการแจ้งเตือนที่ตั้งไว้ (ใช้ตอน logout)
  Future<void> cancel() async {
    if (!_supported || !_ready) return;
    try {
      await _plugin.cancel(id: _notificationId);
    } catch (e) {
      debugPrint('ClaimReminder: cancel failed: $e');
    }
  }

  /// หาเวลาที่ควรแจ้งเตือน คืน null เมื่อเตือนไม่ทันก่อนเที่ยงคืน
  ///
  /// ใช้ [reminderHour] ของวันนี้ถ้ายังมาไม่ถึง แต่ถ้าเลยเวลานั้นมาแล้ว
  /// (เช่นกะดึกที่มาเพิ่มรายการตอน 21:00) จะเลื่อนเป็น now + [_minLeadTime]
  /// เพื่อให้ยังเตือนทันก่อนข้อมูลถูกล้าง
  @visibleForTesting
  DateTime? resolveFireTime(DateTime now) {
    final DateTime preferred = DateTime(
      now.year,
      now.month,
      now.day,
      reminderHour,
    );
    final DateTime midnight = DateTime(now.year, now.month, now.day + 1);

    final DateTime fireAt = preferred.isAfter(now)
        ? preferred
        : now.add(_minLeadTime);
    return fireAt.isBefore(midnight) ? fireAt : null;
  }

  NotificationDetails get _details => const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'เตือนก่อนล้างข้อมูล',
      channelDescription:
          'เตือนให้ส่งรายการที่ค้างก่อนระบบล้างข้อมูลตอนเที่ยงคืน',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
    ),
    iOS: DarwinNotificationDetails(),
  );
}
