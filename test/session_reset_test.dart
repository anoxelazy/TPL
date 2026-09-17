import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/page/tracking/models.dart';
import 'package:claim/page/tracking/tracking_cache.dart';
import 'package:claim/utils/announcement_service.dart';
import 'package:claim/utils/mobile_api.dart';
import 'package:claim/utils/rank_service.dart';
import 'package:claim/utils/session_reset.dart';

/// ผลค้นหาพัสดุแบบย่อ พอให้ cache มีของอยู่จริง
TrackingResult get _result => TrackingResult.fromJson(const {
  'tp_tracking': 'A1234567',
  'cus_tracking': 'TK9999',
  'all_status': [
    {'status_name': 'ส่งถึงแล้ว'},
  ],
});

/// จำลองเครื่องที่มีคนล็อกอินค้างอยู่ พร้อมของที่แต่ละ service เก็บไว้
Future<void> signedIn() async {
  SharedPreferences.setMockInitialValues({
    'token': 'token-ของคนแรก',
    'fullname': 'สมชาย ใจดี',
    'driverID': '80770',
    'username': 'somchai',
    'mobile_api_token': 'pm-token-ของคนแรก',
    'mobile_api_emp_no': '80770',
    'user_rank_json': '{"ranks":{"80770":{"rank":1}}}',
  });

  await MobileSession.I.init();
  await RankService.I.init();
  TrackingCache.I.save(code: 'A1234567', result: _result);
}

void main() {
  group('logout แล้วต้องไม่เหลือของคนก่อนหน้า', () {
    test('เลขที่ค้นในหน้าเช็คสถานะหายไป', () async {
      await signedIn();
      expect(TrackingCache.I.hasData, isTrue, reason: 'ตั้งต้นต้องมีของอยู่');

      await forgetSignedInUser();

      expect(TrackingCache.I.hasData, isFalse);
      expect(TrackingCache.I.code, isNull, reason: 'เลขต้องไม่ค้างให้คนถัดไป');
      expect(TrackingCache.I.result, isNull);
      expect(TrackingCache.I.fetchedAt, isNull);
    });

    test('token ของระบบ PM หายทั้งในหน่วยความจำและในเครื่อง', () async {
      await signedIn();
      expect(
        MobileSession.I.authOptions(),
        isNotNull,
        reason: 'ตั้งต้นมี token',
      );

      await forgetSignedInUser();

      expect(
        MobileSession.I.authOptions(),
        isNull,
        reason: 'คนถัดไปต้องยิง API ของ PM ด้วยสิทธิ์ของคนก่อนไม่ได้',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('mobile_api_token'), isNull);
    });

    test('คีย์ที่ผูกกับคนล็อกอินถูกลบครบทุกตัว', () async {
      await signedIn();
      await forgetSignedInUser();

      final prefs = await SharedPreferences.getInstance();
      for (final key in kSignedInPrefsKeys) {
        expect(prefs.getString(key), isNull, reason: 'คีย์ $key ต้องหาย');
      }
    });

    test('อันดับกับตารางอันดับหายไปด้วย', () async {
      await signedIn();
      expect(RankService.I.rank.value, isNotNull, reason: 'ตั้งต้นติดอันดับ 1');

      await forgetSignedInUser();

      expect(RankService.I.rank.value, isNull);
      expect(RankService.I.board.value, isNull);
      expect(RankService.I.currentEmpId, isEmpty);
    });

    test('เรียกซ้ำตอนไม่มีใครล็อกอินก็ไม่ระเบิด', () async {
      SharedPreferences.setMockInitialValues({});

      await forgetSignedInUser();
      await forgetSignedInUser();

      expect(TrackingCache.I.hasData, isFalse);
    });

    tearDown(() {
      TrackingCache.I.clear();
      RankService.I.forgetCurrentUser();
      AnnouncementService.I.forgetCurrentUser();
    });
  });
}
