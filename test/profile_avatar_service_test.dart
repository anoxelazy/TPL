import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/page/profile/profile_avatar_api.dart';
import 'package:claim/utils/profile_avatar_service.dart';

const ProfileAvatar _catAvatar = ProfileAvatar(
  id: 'cat',
  name: 'แมว',
  url: 'http://x/cat.png',
);

const ProfileAvatar _dogAvatar = ProfileAvatar(
  id: 'dog',
  name: 'หมา',
  url: 'http://x/dog.png',
);

ProfileAvatarService get service => ProfileAvatarService.I;

/// จำลองการ login ของพนักงานคนหนึ่ง
Future<void> loginAs(String driverId, {Map<String, Object> extra = const {}}) {
  SharedPreferences.setMockInitialValues({'driverID': driverId, ...extra});
  return service.init();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service.forgetCurrentUser();
  });

  group('เก็บรูปแยกตามรหัสพนักงาน', () {
    test('login เดิมกลับมาได้รูปเดิมคืน', () async {
      await loginAs('EMP001');
      await service.select(_catAvatar);
      expect(service.imageUrl.value, _catAvatar.url);

      // logout: เอาออกจากหน้าจอ แต่ของที่เก็บไว้ยังอยู่
      service.forgetCurrentUser();
      expect(service.imageUrl.value, isNull);

      // login คนเดิมกลับมา
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('driverID', 'EMP001');
      await service.init();

      expect(service.imageUrl.value, _catAvatar.url);
      expect(service.selectedId, 'cat');
    });

    test('คนละคนไม่เห็นรูปของกันและกัน', () async {
      await loginAs('EMP001');
      await service.select(_catAvatar);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('driverID', 'EMP002');
      await service.init();

      // คนใหม่ยังไม่เคยเลือก ต้องได้รูปเริ่มต้น
      expect(service.imageUrl.value, isNull);
      expect(service.selectedId, isNull);

      await service.select(_dogAvatar);
      expect(service.imageUrl.value, _dogAvatar.url);

      // กลับไปคนแรก รูปของเขาต้องยังอยู่ ไม่ถูกคนที่สองทับ
      await prefs.setString('driverID', 'EMP001');
      await service.init();
      expect(service.imageUrl.value, _catAvatar.url);
    });

    test('กด "ใช้รูปเริ่มต้น" ลบของคนนั้นถาวร', () async {
      await loginAs('EMP001');
      await service.select(_catAvatar);

      await service.clear();
      expect(service.imageUrl.value, isNull);

      await service.init();
      expect(service.imageUrl.value, isNull);
    });

    test('ยังไม่ login เลือกรูปไม่ได้ และไม่พัง', () async {
      SharedPreferences.setMockInitialValues({});
      await service.init();

      await service.select(_catAvatar);

      expect(service.imageUrl.value, isNull);
      expect(service.selectedId, isNull);
    });

    test('driverID ว่างถือว่ายังไม่ login', () async {
      await loginAs('');
      expect(service.selectedId, isNull);
    });
  });

  group('ย้ายข้อมูลจาก key แบบเก่า', () {
    test('คนที่เคยเลือกรูปไว้ก่อนอัปเดตไม่เสียรูป', () async {
      // ก่อนอัปเดตเก็บรวมกันไม่แยกคน
      await loginAs(
        'EMP001',
        extra: {
          'profile_avatar_id': 'cat',
          'profile_avatar_url': _catAvatar.url,
        },
      );

      expect(service.selectedId, 'cat');
      expect(service.imageUrl.value, _catAvatar.url);

      // ย้ายแล้วต้องลบ key เก่าทิ้ง ไม่ให้ไปโผล่ให้คนอื่น
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('profile_avatar_id'), isNull);
      expect(prefs.getString('profile_avatar_url'), isNull);
      expect(prefs.getString('profile_avatar_id_EMP001'), 'cat');
    });

    test('คนที่มีรูปของตัวเองอยู่แล้วไม่ถูกของเก่าทับ', () async {
      await loginAs(
        'EMP001',
        extra: {
          'profile_avatar_id': 'cat',
          'profile_avatar_url': _catAvatar.url,
          'profile_avatar_id_EMP001': 'dog',
          'profile_avatar_url_EMP001': _dogAvatar.url,
        },
      );

      expect(service.selectedId, 'dog');
      expect(service.imageUrl.value, _dogAvatar.url);
    });

    test('ย้ายแล้วคนถัดไปที่ login ไม่ได้รูปติดมาด้วย', () async {
      await loginAs(
        'EMP001',
        extra: {
          'profile_avatar_id': 'cat',
          'profile_avatar_url': _catAvatar.url,
        },
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('driverID', 'EMP002');
      await service.init();

      expect(service.imageUrl.value, isNull);
    });
  });

  group('syncWith ตาม profile.json', () {
    test('url ของ id เดิมเปลี่ยน ให้ตามค่าใหม่', () async {
      await loginAs('EMP001');
      await service.select(_catAvatar);

      const moved = ProfileAvatar(
        id: 'cat',
        name: 'แมว',
        url: 'http://x/cat-v2.png',
      );
      await service.syncWith(const [moved]);

      expect(service.imageUrl.value, 'http://x/cat-v2.png');
    });

    test('id ที่เลือกไว้หายไปจากไฟล์ ให้ถอยไปใช้รูปเริ่มต้น', () async {
      await loginAs('EMP001');
      await service.select(_catAvatar);

      await service.syncWith(const [_dogAvatar]);

      expect(service.imageUrl.value, isNull);
      expect(service.selectedId, isNull);
    });

    test('ยังไม่ได้เลือกรูป syncWith ไม่ทำอะไร', () async {
      await loginAs('EMP001');

      await service.syncWith(const [_catAvatar]);

      expect(service.imageUrl.value, isNull);
    });
  });
}
