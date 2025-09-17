import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogEntry {
  final DateTime timestamp;
  final String action;
  final Map<String, dynamic>? data;

  LogEntry({required this.timestamp, required this.action, this.data});

  Map<String, dynamic> toJson() => {
        'ts': timestamp.toIso8601String(),
        'action': action,
        'data': data,
      };

  static LogEntry fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: DateTime.tryParse(json['ts'] ?? '') ?? DateTime.now(),
      action: json['action'] ?? 'unknown',
      data: (json['data'] as Map?)?.cast<String, dynamic>(),
    );
  }
}

class AppLogger {
  AppLogger._internal();
  static final AppLogger _instance = AppLogger._internal();
  static AppLogger get I => _instance;

  static const String _prefsKey = 'app_logs';
  static const int _maxEntries = 500;

  final List<LogEntry> _entries = <LogEntry>[];
  bool _initialized = false;

  Future<void> _ensureLoaded() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey) ?? <String>[];
      _entries
        ..clear()
        ..addAll(list.map((e) => LogEntry.fromJson(jsonDecode(e))));
      _initialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('Logger load failed: $e');
      }
      _initialized = true;
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _entries
          .take(_maxEntries)
          .map((e) => jsonEncode(e.toJson()))
          .toList(growable: false);
      await prefs.setStringList(_prefsKey, list);
    } catch (e) {
      if (kDebugMode) {
        print('Logger persist failed: $e');
      }
    }
  }

  Future<void> log(String action, {Map<String, dynamic>? data}) async {
    await _ensureLoaded();
    _entries.insert(0, LogEntry(timestamp: DateTime.now(), action: action, data: data));
    if (_entries.length > _maxEntries) {
      _entries.removeRange(_maxEntries, _entries.length);
    }
    await _persist();
  }

  Future<List<LogEntry>> list() async {
    await _ensureLoaded();
    return List<LogEntry>.unmodifiable(_entries);
  }

  Future<void> clear() async {
    await _ensureLoaded();
    _entries.clear();
    await _persist();
  }
}


