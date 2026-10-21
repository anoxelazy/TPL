import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/utils/map_keys.dart';

/// แทนที่ตัวยิงเน็ตจริง [body] เป็น null = ต่อไม่ติด
class _FakeLink implements HttpClientAdapter {
  final String? body;

  _FakeLink(this.body);

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
    return ResponseBody.fromString(content, 200);
  }

  @override
  void close({bool force = false}) {}
}

Future<void> load({String? link, Map<String, Object> cached = const {}}) {
  MapKeys.loaderDio = Dio()..httpClientAdapter = _FakeLink(link);
  SharedPreferences.setMockInitialValues(cached);
  return MapKeys.ensureLoaded();
}

void main() {
  setUp(MapKeys.resetForTest);

  test('อ่านคีย์ทั้งสองตัวจาก json ในลิงก์', () async {
    await load(link: '{"ORS_API_KEY": "ors1", "LONGDO_API_KEY": "ld1"}');

    expect(MapKeys.ors, 'ors1');
    expect(MapKeys.longdo, 'ld1');
  });

  test('ไฟล์เดียวกับคีย์ Supabase มีฟิลด์อื่นปนอยู่ก็อ่านได้', () async {
    await load(
      link: '{"SUPABASE_ANON_KEY": "sb_publishable_x", "LONGDO_API_KEY": "ld1"}',
    );

    expect(MapKeys.longdo, 'ld1');
    // ไม่มีฟิลด์ ORS ก็ว่างไว้ แอปถอยไปใช้ OSRM เอง
    expect(MapKeys.ors, isEmpty);
  });

  test('เน็ตหลุด ใช้คีย์ที่เคยโหลดได้ครั้งก่อน', () async {
    await load(cached: {'map_key_ors': 'ors_old', 'map_key_longdo': 'ld_old'});

    expect(MapKeys.ors, 'ors_old');
    expect(MapKeys.longdo, 'ld_old');
  });

  test('ลิงก์มีคีย์ใหม่ ทับของเก่าใน cache และจำไว้ใช้ครั้งหน้า', () async {
    await load(
      link: '{"ORS_API_KEY": "ors_new", "LONGDO_API_KEY": "ld_new"}',
      cached: {'map_key_ors': 'ors_old', 'map_key_longdo': 'ld_old'},
    );

    expect(MapKeys.ors, 'ors_new');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('map_key_longdo'), 'ld_new');
  });

  test('ไฟล์พังหรือไม่ใช่ json ไม่ทำให้แอปพัง และไม่ลบคีย์เดิม', () async {
    await load(link: 'not json', cached: {'map_key_ors': 'ors_old'});

    expect(MapKeys.ors, 'ors_old');
  });

  test('รอบแรกไม่ได้คีย์สักตัว เรียกครั้งถัดไปลองใหม่', () async {
    await load();
    expect(MapKeys.longdo, isEmpty);

    await load(link: '{"LONGDO_API_KEY": "ld1"}');
    expect(MapKeys.longdo, 'ld1');
  });
}
