import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claim/utils/dio_service.dart';

const String kProfileJsonUrl =
    'https://raw.githubusercontent.com/anoxelazy/API_json/main/profile.json';

const String _kProfileCacheKey = 'profile_avatars_json';

class ProfileAvatar {
  final String id;
  final String name;
  final String url;

  const ProfileAvatar({
    required this.id,
    required this.name,
    required this.url,
  });
}

/// โหลดรายการรูปโปรไฟล์ ถ้าโหลดไม่ได้จะใช้ก้อนที่เคยโหลดสำเร็จแทน
Future<List<ProfileAvatar>> fetchProfileAvatars() async {
  SharedPreferences? prefs;

  try {
    prefs = await SharedPreferences.getInstance();

    final response = await dio.get(
      kProfileJsonUrl,
      options: Options(
        headers: {'Accept': 'application/json'},
        receiveTimeout: const Duration(seconds: 20),
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final body = response.data is String
        ? response.data as String
        : jsonEncode(response.data);

    final parsed = _parseAvatars(body);
    if (parsed.isEmpty) throw Exception('รูปแบบไฟล์ไม่ถูกต้อง');

    await prefs.setString(_kProfileCacheKey, body);
    return parsed;
  } catch (e) {
    debugPrint('profile.json error: $e');

    final cached = prefs?.getString(_kProfileCacheKey);
    final parsed = cached == null
        ? const <ProfileAvatar>[]
        : _parseAvatars(cached);
    if (parsed.isEmpty) throw Exception('โหลดรูปโปรไฟล์ไม่สำเร็จ');
    return parsed;
  }
}

/// รับได้ทั้ง "id": "url" และ "id": {"name": ..., "url": ...}
List<ProfileAvatar> _parseAvatars(String body) {
  try {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return const [];

    dynamic decoded = jsonDecode(trimmed);
    if (decoded is Map && decoded['avatars'] is Map) {
      decoded = decoded['avatars'];
    }
    if (decoded is! Map) return const [];

    final result = <ProfileAvatar>[];
    for (final entry in decoded.entries) {
      final id = entry.key.toString().trim();
      final value = entry.value;

      final String url;
      final String name;
      if (value is Map) {
        url = _str(value['url']);
        final label = _str(value['name']);
        name = label.isEmpty ? id : label;
      } else {
        url = _str(value);
        name = id;
      }

      if (id.isEmpty || url.isEmpty) continue;
      result.add(ProfileAvatar(id: id, name: name, url: url));
    }

    return result;
  } catch (e) {
    debugPrint('profile.json parse error: $e');
    return const [];
  }
}

String _str(dynamic value) {
  if (value == null) return '';
  final text = value.toString().trim();
  return text == 'null' ? '' : text;
}
