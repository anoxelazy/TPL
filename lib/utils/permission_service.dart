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

  // In-memory cache
  Map<String, dynamic>? _permissionsData;
  String? _branchId;

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

  /// Clear permissions and branch ID (on logout)
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_permissionsKey);
    await prefs.remove(_branchIdKey);
    _permissionsData = null;
    _branchId = null;
  }
}
