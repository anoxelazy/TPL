import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionService {
  PermissionService._internal();

  static final PermissionService _instance = PermissionService._internal();

  factory PermissionService() => _instance;

  static PermissionService get I => _instance;

  // Keys for SharedPreferences
  static const String _permissionsKey = 'permissions';
  static const String _branchIdKey = 'branch_id';
  static const String _branchLatKey = 'branch_lat';
  static const String _branchLonKey = 'branch_lon';
  static const String _branchDistanceKey = 'branch_distance';

  // In-memory cache
  Map<String, dynamic>? _permissionsData;
  String? _branchId;
  double? _branchLat;
  double? _branchLon;
  double? _branchDistance;

  /// ค่าตัวเลขจาก JSON อาจมาเป็น num หรือ String ก็ได้
  static double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  Future<void> _saveDouble(
    SharedPreferences prefs,
    String key,
    double? value,
  ) async {
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setDouble(key, value);
    }
  }

  /// Save permissions and branch ID from login response
  Future<void> saveFromLoginResponse(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final permissions = data['Permissions'];
    final branchId = data['BranchID'];

    if (permissions != null) {
      await prefs.setString(_permissionsKey, jsonEncode(permissions));
      _permissionsData = permissions as Map<String, dynamic>;
    }

    if (branchId != null) {
      await prefs.setString(_branchIdKey, branchId);
      _branchId = branchId as String;
    }

    // พิกัดสาขา + รัศมีที่อนุญาต (เมตร) ถ้า response ไม่ส่งมาให้ล้างค่าเก่า
    // ไม่งั้นผู้ใช้ที่ login สาขาใหม่จะโดนเช็คด้วยพิกัดของสาขาเดิม
    _branchLat = _toDouble(data['BranchLat']);
    _branchLon = _toDouble(data['BranchLon']);
    _branchDistance = _toDouble(data['branch_distance']);
    await _saveDouble(prefs, _branchLatKey, _branchLat);
    await _saveDouble(prefs, _branchLonKey, _branchLon);
    await _saveDouble(prefs, _branchDistanceKey, _branchDistance);
  }

  /// Load permissions and branch ID from SharedPreferences
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final permissionsJson = prefs.getString(_permissionsKey);
    final branchId = prefs.getString(_branchIdKey);

    if (permissionsJson != null) {
      _permissionsData = jsonDecode(permissionsJson) as Map<String, dynamic>;
    }

    if (branchId != null) {
      _branchId = branchId;
    }

    _branchLat = prefs.getDouble(_branchLatKey);
    _branchLon = prefs.getDouble(_branchLonKey);
    _branchDistance = prefs.getDouble(_branchDistanceKey);
  }

  /// Check if a module is enabled
  bool canAccess(String module) {
    final modules = _permissionsData?['Modules'] as Map<String, dynamic>?;
    final moduleData = modules?[module] as Map<String, dynamic>?;
    return moduleData?['Enabled'] == true;
  }

  /// Check if a specific action is allowed for a module
  bool canDo(String module, String action) {
    final modules = _permissionsData?['Modules'] as Map<String, dynamic>?;
    final moduleData = modules?[module] as Map<String, dynamic>?;
    final actions = moduleData?['Actions'] as List<dynamic>?;
    return actions != null && actions.contains(action);
  }

  /// Get branch ID
  String? getBranchId() => _branchId;

  /// พิกัดสาขา null เมื่อ backend ไม่ส่งมาหรือเป็น 0,0 (ค่าแทน "ไม่มีพิกัด")
  ({double lat, double lon})? getBranchLocation() {
    final lat = _branchLat;
    final lon = _branchLon;
    if (lat == null || lon == null) return null;
    if (lat == 0 && lon == 0) return null;
    return (lat: lat, lon: lon);
  }

  /// ระยะสูงสุดจากสาขาที่บันทึกไมล์ได้ (เมตร) null = ไม่จำกัด
  double? getBranchDistance() {
    final d = _branchDistance;
    return (d == null || d <= 0) ? null : d;
  }

  /// Clear permissions and branch ID (on logout)
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_permissionsKey);
    await prefs.remove(_branchIdKey);
    await prefs.remove(_branchLatKey);
    await prefs.remove(_branchLonKey);
    await prefs.remove(_branchDistanceKey);
    _permissionsData = null;
    _branchId = null;
    _branchLat = null;
    _branchLon = null;
    _branchDistance = null;
  }
}
