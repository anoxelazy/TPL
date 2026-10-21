import 'dart:convert';
import 'dart:io';

import 'package:claim/page/claim/image_utils.dart';
import 'package:claim/utils/claim_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory root;
  late Directory scratch;

  /// สร้างไฟล์รูปปลอมไว้นอกโฟลเดอร์ถาวร (เลียนแบบ cache ของ image_picker)
  File fakeImage(String name) {
    final file = File(p.join(scratch.path, name));
    file.writeAsBytesSync(List<int>.filled(64, 7));
    return file;
  }

  Map<String, dynamic> claimData(List<File> images) => {
    'docNumber': 'A1-0001',
    'type': 'เสียหาย',
    'carCode': 'CAR-9',
    'timestamp': DateTime(2026, 7, 31, 10, 30),
    'images': images,
    'empID': '67057',
    'remarkType': 'กล่องบุบ',
    'isSent': false,
    'fromFrontStore': true,
  };

  // SQLite ของจริงต้องมีปลั๊กอินมือถือ เทสต์บนเครื่องพัฒนาใช้แบบ FFI แทน
  setUpAll(() {
    sqfliteFfiInit();
    ClaimStore.debugDatabaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    root = Directory.systemTemp.createTempSync('claim_store_root');
    scratch = Directory.systemTemp.createTempSync('claim_store_cache');
    await ClaimStore.I.debugUseDirectory(root);
  });

  tearDown(() async {
    // ปิดฐานข้อมูลก่อนลบโฟลเดอร์ Windows ไม่ยอมลบไฟล์ที่ยังเปิดอยู่
    await ClaimStore.I.debugUseDirectory(root);
    if (root.existsSync()) root.deleteSync(recursive: true);
    if (scratch.existsSync()) scratch.deleteSync(recursive: true);
  });

  test('เก็บรายการและรูปไว้ในเครื่อง แล้วโหลดคืนได้หลังเปิดแอปใหม่', () async {
    final source = fakeImage('shot1.jpg');
    final claim = await ClaimStore.I.prepareClaim(claimData([source]));
    ClaimStore.I.addClaim(claim);
    await ClaimStore.I.flush();

    // รูปถูกคัดลอกออกจาก cache ไปโฟลเดอร์ถาวรของรายการนี้
    final stored = (claim['images'] as List).cast<File>().single;
    expect(stored.existsSync(), isTrue);
    expect(stored.path, isNot(source.path));
    expect(p.basename(stored.parent.path), claim['id']);
    expect(File(p.join(root.path, 'claims.db')).existsSync(), isTrue);

    // จำลองเปิดแอปใหม่: ล้าง memory แล้วโหลดจากดิสก์
    await ClaimStore.I.debugUseDirectory(root);
    expect(ClaimStore.I.count, 0);
    await ClaimStore.I.init();

    expect(ClaimStore.I.count, 1);
    expect(ClaimStore.I.unsentCount, 1);
    final loaded = ClaimStore.I.claims.single;
    expect(loaded['docNumber'], 'A1-0001');
    expect(loaded['carCode'], 'CAR-9');
    expect(loaded['type'], 'เสียหาย');
    expect(loaded['remarkType'], 'กล่องบุบ');
    expect(loaded['fromFrontStore'], isTrue);
    expect(loaded['timestamp'], DateTime(2026, 7, 31, 10, 30));
    expect((loaded['images'] as List).cast<File>().single.path, stored.path);
  });

  test('markAsSent ถูกบันทึกลงดิสก์', () async {
    ClaimStore.I.addClaim(
      await ClaimStore.I.prepareClaim(claimData([fakeImage('shot1.jpg')])),
    );
    ClaimStore.I.markAsSent(0);
    await ClaimStore.I.flush();

    await ClaimStore.I.debugUseDirectory(root);
    await ClaimStore.I.init();

    expect(ClaimStore.I.count, 1);
    expect(ClaimStore.I.claims.single['isSent'], isTrue);
    expect(ClaimStore.I.unsentCount, 0);
  });

  group('ตัวเลขแถบสรุป ส่งสำเร็จ / รอส่ง / ไม่สำเร็จ', () {
    // รอให้เขียนลงดิสก์เสร็จก่อน tearDown ด้านนอกลบโฟลเดอร์ทิ้ง ไม่งั้น
    // การเขียนที่ค้างจะไปเขียนลงโฟลเดอร์ของเทสต์ถัดไปแล้วชนกันเป็นบางที
    tearDown(() => ClaimStore.I.flush());

    Future<void> addThree() async {
      for (var i = 0; i < 3; i++) {
        ClaimStore.I.addClaim(
          await ClaimStore.I.prepareClaim(claimData([fakeImage('s$i.jpg')])),
        );
      }
    }

    test('นับแยกสามกลุ่มตามสถานะ', () async {
      await addThree();
      ClaimStore.I.markAsSent(0);
      ClaimStore.I.markSendFailed(1);

      expect(ClaimStore.I.sentCount, 1);
      expect(ClaimStore.I.failedCount, 1);
      expect(ClaimStore.I.pendingCount, 1);
    });

    test('ส่งไม่สำเร็จถูกจำไว้ข้ามการเปิดแอป', () async {
      await addThree();
      ClaimStore.I.markSendFailed(2);
      await ClaimStore.I.flush();

      await ClaimStore.I.debugUseDirectory(root);
      await ClaimStore.I.init();

      expect(ClaimStore.I.failedCount, 1);
      expect(ClaimStore.I.claims[2]['sendFailed'], isTrue);
    });

    test('ส่งใหม่สำเร็จแล้วไม่นับเป็นไม่สำเร็จอีก', () async {
      await addThree();
      ClaimStore.I.markSendFailed(0);
      ClaimStore.I.markAsSent(0);

      expect(ClaimStore.I.failedCount, 0);
      expect(ClaimStore.I.sentCount, 1);
    });

    test(
      'รายการที่ส่งสำเร็จแล้ว กดส่งซ้ำไม่ผ่าน ยังนับเป็นส่งสำเร็จ',
      () async {
        await addThree();
        ClaimStore.I.markAsSent(0);
        ClaimStore.I.markSendFailed(0);

        expect(ClaimStore.I.sentCount, 1);
        expect(ClaimStore.I.failedCount, 0);
      },
    );

    test('ขึ้นวันใหม่ ตัวเลขทั้งหมดกลับเป็นศูนย์', () async {
      await addThree();
      ClaimStore.I.markAsSent(0);
      ClaimStore.I.markSendFailed(1);

      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await ClaimStore.I.purgeExpired(now: tomorrow);

      expect(ClaimStore.I.sentCount, 0);
      expect(ClaimStore.I.pendingCount, 0);
      expect(ClaimStore.I.failedCount, 0);
    });
  });

  test('แก้ไขรายการแล้วลบรูปออก ไฟล์ที่ไม่ใช้ถูกลบตาม', () async {
    final claim = await ClaimStore.I.prepareClaim(
      claimData([fakeImage('a.jpg'), fakeImage('b.jpg')]),
    );
    ClaimStore.I.addClaim(claim);
    await ClaimStore.I.flush();

    final images = (claim['images'] as List).cast<File>();
    expect(images.length, 2);
    final kept = images.first;
    final dropped = images.last;

    // แก้ไขรายการเดิม (ส่ง id เดิม) โดยเหลือรูปเดียว
    final edited = await ClaimStore.I.prepareClaim(
      claimData([kept]),
      id: claim['id'] as String,
    );
    ClaimStore.I.updateClaim(0, edited);
    await ClaimStore.I.flush();

    expect(kept.existsSync(), isTrue, reason: 'รูปที่ยังใช้ต้องไม่ถูกลบ');
    expect(
      dropped.existsSync(),
      isFalse,
      reason: 'รูปที่ลบออกต้องหายไปจากเครื่อง',
    );

    await ClaimStore.I.debugUseDirectory(root);
    await ClaimStore.I.init();
    expect((ClaimStore.I.claims.single['images'] as List).length, 1);
  });

  test('ลบรายการแล้วโฟลเดอร์รูปถูกลบด้วย', () async {
    final claim = await ClaimStore.I.prepareClaim(
      claimData([fakeImage('a.jpg')]),
    );
    ClaimStore.I.addClaim(claim);
    await ClaimStore.I.flush();
    final dir = (claim['images'] as List).cast<File>().single.parent;

    ClaimStore.I.removeClaim(0);
    await ClaimStore.I.flush();
    // การลบไฟล์ทำแบบ async หลังบันทึก รอให้ระบบไฟล์ตามทัน
    for (var i = 0; i < 20 && dir.existsSync(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(dir.existsSync(), isFalse);
    await ClaimStore.I.debugUseDirectory(root);
    await ClaimStore.I.init();
    expect(ClaimStore.I.count, 0);
  });

  test('รูปที่หายจากเครื่องถูกข้ามไป แต่ข้อมูลฟอร์มยังอยู่', () async {
    final claim = await ClaimStore.I.prepareClaim(
      claimData([fakeImage('a.jpg')]),
    );
    ClaimStore.I.addClaim(claim);
    await ClaimStore.I.flush();

    (claim['images'] as List).cast<File>().single.deleteSync();

    await ClaimStore.I.debugUseDirectory(root);
    await ClaimStore.I.init();

    expect(ClaimStore.I.count, 1);
    expect((ClaimStore.I.claims.single['images'] as List), isEmpty);
    expect(ClaimStore.I.claims.single['docNumber'], 'A1-0001');
  });

  test('โฟลเดอร์รูปที่ไม่มีรายการอ้างถึงถูกลบตอนเปิดแอป', () async {
    // จำลองกรณีแอปถูก kill หลังคัดลอกรูปแต่ยังไม่ได้บันทึกรายการ
    await ClaimStore.I.prepareClaim(claimData([fakeImage('a.jpg')]));
    final orphanBase = Directory(p.join(root.path, 'claim_images'));
    expect(orphanBase.listSync().length, 1);

    await ClaimStore.I.debugUseDirectory(root);
    await ClaimStore.I.init();

    expect(orphanBase.listSync(), isEmpty);
  });

  test(
    'เก็บ thumbnail ของรูปที่ยังใช้อยู่ไว้ แต่ลบ thumbnail ที่กำพร้า',
    () async {
      final claim = await ClaimStore.I.prepareClaim(
        claimData([fakeImage('a.jpg'), fakeImage('b.jpg')]),
      );
      ClaimStore.I.addClaim(claim);
      final images = (claim['images'] as List).cast<File>();
      final kept = images.first;
      final dropped = images.last;

      // จำลอง thumbnail ที่ FastImagePreview สร้างไว้ข้างไฟล์ต้นฉบับ
      final keptThumb = File('${kept.path}$thumbnailSuffix')
        ..writeAsBytesSync([1, 2, 3]);
      final droppedThumb = File('${dropped.path}$thumbnailSuffix')
        ..writeAsBytesSync([1, 2, 3]);

      ClaimStore.I.updateClaim(
        0,
        await ClaimStore.I.prepareClaim(
          claimData([kept]),
          id: claim['id'] as String,
        ),
      );
      await ClaimStore.I.flush();

      expect(keptThumb.existsSync(), isTrue);
      expect(droppedThumb.existsSync(), isFalse);
    },
  );

  test('นามสกุล thumbnail ของสองไฟล์ต้องตรงกัน', () {
    // ถ้าไม่ตรง ClaimStore จะลบ thumbnail ของรูปที่ยังใช้อยู่ทิ้งทุกครั้งที่แก้ไข
    expect(thumbnailSuffix, ClaimStore.thumbSuffix);
  });

  group('อายุของฟอร์ม 1 วัน', () {
    test('รายการของเมื่อวานถูกลบตอนเปิดแอป พร้อมรูปในเครื่อง', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final claim = await ClaimStore.I.prepareClaim({
        ...claimData([fakeImage('a.jpg')]),
        'createdAt': yesterday,
      });
      ClaimStore.I.addClaim(claim);
      await ClaimStore.I.flush();
      final dir = (claim['images'] as List).cast<File>().single.parent;

      await ClaimStore.I.debugUseDirectory(root);
      await ClaimStore.I.init();

      expect(ClaimStore.I.count, 0);
      expect(ClaimStore.I.lastPurgedCount, 1);
      expect(dir.existsSync(), isFalse);
    });

    test('รายการของวันนี้ไม่ถูกลบ', () async {
      ClaimStore.I.addClaim(
        await ClaimStore.I.prepareClaim(claimData([fakeImage('a.jpg')])),
      );
      await ClaimStore.I.flush();

      expect(await ClaimStore.I.purgeExpired(), 0);

      await ClaimStore.I.debugUseDirectory(root);
      await ClaimStore.I.init();
      expect(ClaimStore.I.count, 1);
    });

    test('ข้ามเที่ยงคืนแล้วรายการของวันนี้หมดอายุ', () async {
      final claim = await ClaimStore.I.prepareClaim(
        claimData([fakeImage('a.jpg')]),
      );
      ClaimStore.I.addClaim(claim);
      final before = ClaimStore.I.revision.value;

      // จำลองเวลาเที่ยงคืนของวันถัดไป
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final removed = await ClaimStore.I.purgeExpired(
        now: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
      );

      expect(removed, 1);
      expect(ClaimStore.I.count, 0);
      expect(
        ClaimStore.I.revision.value,
        greaterThan(before),
        reason: 'หน้าจอต้องรู้ว่ารายการถูกลบเพื่อ refresh ตัวเอง',
      );
    });

    test('การแก้ไขรายการไม่ต่ออายุให้ฟอร์ม', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final claim = await ClaimStore.I.prepareClaim({
        ...claimData([fakeImage('a.jpg')]),
        'createdAt': yesterday,
      });
      ClaimStore.I.addClaim(claim);

      // แก้ไขวันนี้ โดย claim map ที่ส่งเข้ามาไม่มี createdAt (เหมือน UI จริง)
      final edited = await ClaimStore.I.prepareClaim(
        claimData((claim['images'] as List).cast<File>()),
        id: claim['id'] as String,
      );
      ClaimStore.I.updateClaim(0, edited);

      expect(edited['createdAt'], yesterday);
      expect(await ClaimStore.I.purgeExpired(), 1);
    });

    test('ข้อมูลเก่าที่ไม่มี createdAt ใช้วันที่ของรายการคิดอายุ', () async {
      // เขียน claims.json แบบเวอร์ชันก่อนที่ยังไม่มีฟิลด์ createdAt
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      File(p.join(root.path, 'claims.json')).writeAsStringSync(
        jsonEncode({
          'version': 1,
          'claims': [
            {
              'id': 'claim_legacy',
              'docNumber': 'A1-OLD',
              'type': 'เสียหาย',
              'carCode': 'CAR-1',
              'timestamp': yesterday.toIso8601String(),
              'images': <String>[],
              'empID': '67057',
              'isSent': false,
            },
          ],
        }),
      );

      await ClaimStore.I.init();

      expect(ClaimStore.I.count, 0);
      expect(ClaimStore.I.lastPurgedCount, 1);
    });
  });

  group('ย้ายจาก claims.json เดิมเข้า SQLite', () {
    void writeLegacy(List<Map<String, dynamic>> claims) {
      File(
        p.join(root.path, 'claims.json'),
      ).writeAsStringSync(jsonEncode({'version': 1, 'claims': claims}));
    }

    Map<String, dynamic> legacy(String id, {bool sent = false}) => {
      'id': id,
      'docNumber': 'DOC-$id',
      'type': 'สูญหาย',
      'carCode': 'CAR-$id',
      'timestamp': DateTime.now().toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
      'images': <String>[],
      'empID': '67057',
      'isSent': sent,
      'uploadedLinks': ['https://x/$id'],
    };

    test('รายการค้างในเครื่องย้ายมาครบ ลำดับและสถานะเหมือนเดิม', () async {
      writeLegacy([legacy('a'), legacy('b', sent: true)]);

      await ClaimStore.I.init();

      expect(ClaimStore.I.claims.map((c) => c['id']), ['a', 'b']);
      expect(ClaimStore.I.claims[0]['docNumber'], 'DOC-a');
      expect(ClaimStore.I.claims[0]['type'], 'สูญหาย');
      expect(ClaimStore.I.claims[1]['isSent'], isTrue);
      expect(ClaimStore.I.claims[1]['uploadedLinks'], ['https://x/b']);
    });

    test('ย้ายแล้วไฟล์เก่าถูกเปลี่ยนชื่อ เปิดแอปรอบถัดไปไม่ย้ายซ้ำ', () async {
      writeLegacy([legacy('a')]);
      await ClaimStore.I.init();

      expect(File(p.join(root.path, 'claims.json')).existsSync(), isFalse);
      expect(
        File(p.join(root.path, 'claims.json.migrated')).existsSync(),
        isTrue,
      );

      await ClaimStore.I.debugUseDirectory(root);
      await ClaimStore.I.init();
      expect(ClaimStore.I.count, 1);
    });

    test('ฐานข้อมูลมีรายการอยู่แล้ว ไม่เอาของเก่ามาซ้อน', () async {
      ClaimStore.I.addClaim(
        await ClaimStore.I.prepareClaim(claimData([fakeImage('n.jpg')])),
      );
      await ClaimStore.I.flush();
      await ClaimStore.I.debugUseDirectory(root);

      writeLegacy([legacy('old')]);
      await ClaimStore.I.init();

      expect(ClaimStore.I.count, 1);
      expect(ClaimStore.I.claims.single['docNumber'], 'A1-0001');
    });
  });

  test('clear ลบทั้งรายการและรูปทั้งหมด', () async {
    ClaimStore.I.addClaim(
      await ClaimStore.I.prepareClaim(claimData([fakeImage('a.jpg')])),
    );
    await ClaimStore.I.flush();

    await ClaimStore.I.clear();

    expect(ClaimStore.I.count, 0);
    expect(Directory(p.join(root.path, 'claim_images')).existsSync(), isFalse);

    await ClaimStore.I.debugUseDirectory(root);
    await ClaimStore.I.init();
    expect(ClaimStore.I.count, 0);
  });
}
