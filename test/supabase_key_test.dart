import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/utils/supabase_config.dart';

/// แทนที่ตัวยิงเน็ตจริง เทสต์จะได้คุมได้ว่าลิงก์ตอบอะไรกลับมา
///
/// [body] เป็น null = ต่อไม่ติด เหมือนตอนผู้ใช้ไม่มีเน็ต
class _FakeLink implements HttpClientAdapter {
  final String? body;
  final int status;

  _FakeLink(this.body, {this.status = 200});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final content = body;
    if (content == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'ไม่มีเน็ต',
      );
    }

    return ResponseBody.fromString(
      content,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// ตั้งค่าลิงก์กับ cache แล้วสั่งโหลด
Future<bool> load({String? link, String? cached, int status = 200}) {
  SupabaseConfig.loaderDio = Dio()
    ..httpClientAdapter = _FakeLink(link, status: status);
  SharedPreferences.setMockInitialValues({
    if (cached != null) 'supabase_anon_key': cached,
  });
  return SupabaseConfig.ensureKey();
}

String json(String key) => '{"SUPABASE_ANON_KEY": "$key"}';

void main() {
  setUp(SupabaseConfig.resetForTest);

  test('ลิงก์คีย์ชี้ไปไฟล์ที่ตกลงกันไว้', () {
    expect(
      kSupabaseKeyUrl,
      'https://raw.githubusercontent.com/anoxelazy/API_json/main/key_sapu.json',
    );
  });

  group('ดึงคีย์จากลิงก์', () {
    test('ได้คีย์จาก json ตามชื่อฟิลด์ที่ใช้จริง', () async {
      final ok = await load(link: json('sb_publishable_fromlink'));

      expect(ok, isTrue);
      expect(SupabaseConfig.anonKey, 'sb_publishable_fromlink');
      expect(SupabaseConfig.isConfigured, isTrue);
    });

    test('ได้คีย์แล้วเก็บลง cache ไว้ใช้รอบหน้า', () async {
      await load(link: json('sb_publishable_saveme'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('supabase_anon_key'), 'sb_publishable_saveme');
    });

    test('เขียนชื่อฟิลด์เป็น anonKey หรือ key ก็ยังอ่านออก', () async {
      await load(link: '{"anonKey": "sb_publishable_a"}');
      expect(SupabaseConfig.anonKey, 'sb_publishable_a');

      SupabaseConfig.resetForTest();
      await load(link: '{"key": "sb_publishable_b"}');
      expect(SupabaseConfig.anonKey, 'sb_publishable_b');
    });

    test('ลิงก์ตอบคีย์เปล่า ๆ ไม่ใช่ json ก็ยังใช้ได้', () async {
      await load(link: 'sb_publishable_plain');
      expect(SupabaseConfig.anonKey, 'sb_publishable_plain');
    });

    test('json พังหรือไม่มีฟิลด์ที่ต้องการ ถือว่าไม่มีคีย์', () async {
      expect(await load(link: '{"อะไรไม่รู้": "x"}'), isFalse);
      expect(SupabaseConfig.anonKey, isEmpty);
    });
  });

  group('ตอนลิงก์ล่มหรือเน็ตไม่มี', () {
    test('มีคีย์ที่ cache ไว้ ใช้ต่อได้', () async {
      final ok = await load(link: null, cached: 'sb_publishable_cached');

      expect(ok, isTrue);
      expect(SupabaseConfig.anonKey, 'sb_publishable_cached');
    });

    test('ไม่มีทั้ง cache และเน็ต คืน false ไม่ระเบิด', () async {
      expect(await load(link: null), isFalse);
      expect(SupabaseConfig.isConfigured, isFalse);
    });

    test('ลิงก์ตอบ 404 แต่มี cache ก็ยังไปต่อได้', () async {
      final ok = await load(
        link: 'not found',
        status: 404,
        cached: 'sb_publishable_cached',
      );

      expect(ok, isTrue);
      expect(SupabaseConfig.anonKey, 'sb_publishable_cached');
    });

    test('คีย์ในลิงก์ใหม่กว่า cache ให้ตัวใหม่ชนะ', () async {
      await load(
        link: json('sb_publishable_new'),
        cached: 'sb_publishable_old',
      );

      expect(SupabaseConfig.anonKey, 'sb_publishable_new');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('supabase_anon_key'), 'sb_publishable_new');
    });
  });

  group('กันคีย์ผิดตัว', () {
    test('secret key ในลิงก์ ไม่ถูกหยิบมาใช้', () async {
      final ok = await load(link: json('sb_secret_dQKDJW'));

      expect(ok, isFalse, reason: 'secret key ห้ามหลุดมาถึงเครื่องผู้ใช้');
      expect(SupabaseConfig.anonKey, isEmpty);
    });

    test('secret key ที่ค้างอยู่ใน cache ก็ไม่เอา', () async {
      expect(await load(link: null, cached: 'sb_secret_dQKDJW'), isFalse);
      expect(SupabaseConfig.anonKey, isEmpty);
    });

    test('service_role ก็ไม่เอา', () async {
      expect(await load(link: json('eyJhbG.service_role.xx')), isFalse);
      expect(SupabaseConfig.anonKey, isEmpty);
    });

    test('คีย์มีแต่ช่องว่าง ถือว่าไม่มีคีย์', () async {
      expect(await load(link: json('   ')), isFalse);
      expect(SupabaseConfig.anonKey, isEmpty);
    });
  });

  group('เรียกซ้ำ', () {
    test('ได้คีย์แล้วเรียกอีกไม่ไปโหลดใหม่', () async {
      await load(link: json('sb_publishable_first'));

      SupabaseConfig.loaderDio = Dio()
        ..httpClientAdapter = _FakeLink(json('sb_publishable_second'));

      expect(await SupabaseConfig.ensureKey(), isTrue);
      expect(SupabaseConfig.anonKey, 'sb_publishable_first');
    });

    test('ยิงพร้อมกันหลายที่ ได้ผลตรงกันทุกตัว', () async {
      SupabaseConfig.loaderDio = Dio()
        ..httpClientAdapter = _FakeLink(json('sb_publishable_shared'));
      SharedPreferences.setMockInitialValues({});

      final results = await Future.wait([
        SupabaseConfig.ensureKey(),
        SupabaseConfig.ensureKey(),
        SupabaseConfig.ensureKey(),
      ]);

      expect(results, everyElement(isTrue));
      expect(SupabaseConfig.anonKey, 'sb_publishable_shared');
    });
  });

  group('supabaseDio', () {
    test('ชี้ไปโปรเจกต์ที่ถูกต้อง', () {
      expect(supabaseDio.options.baseUrl, SupabaseConfig.baseUrl);
      expect(SupabaseConfig.baseUrl, startsWith('https://'));
    });

    test('apikey ใส่ตอนยิง ไม่ได้ตั้งค้างไว้ใน BaseOptions', () {
      // ตั้งค้างไม่ได้ เพราะคีย์มาทีหลังตอนโหลดจากลิงก์เสร็จ
      expect(supabaseDio.options.headers.containsKey('apikey'), isFalse);
      expect(supabaseDio.options.headers.containsKey('Authorization'), isFalse);
      expect(supabaseDio.interceptors, isNotEmpty);
    });
  });
}
