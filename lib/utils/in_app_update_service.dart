import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

/// Result enum for update operations
enum AppUpdateResult {
  updateAvailable,
  updateNotAvailable,
  updateError,
  userCancelled,
  flexibleUpdateStarted,
}

/// Callback type for update status
typedef UpdateCallback = void Function(AppUpdateResult result, String? message);

/// Service class for handling in-app updates using in_app_update package
class InAppUpdateService {
  static final InAppUpdateService _instance = InAppUpdateService._internal();
  factory InAppUpdateService() => _instance;
  InAppUpdateService._internal();

  AppUpdateInfo? _updateInfo;
  bool _isCheckingForUpdate = false;

  /// Check for app updates and start flexible update if available
  /// 
  /// [onUpdateResult] - Optional callback to handle update result
  /// [context] - BuildContext for showing dialogs (optional, used for snackbar)
  /// 
  /// Returns [AppUpdateResult] indicating the outcome
  Future<AppUpdateResult> checkForUpdateAndUpdate({
    UpdateCallback? onUpdateResult,
    BuildContext? context,
  }) async {
    // Prevent multiple simultaneous update checks
    if (_isCheckingForUpdate) {
      _log('Update check already in progress, skipping...');
      return AppUpdateResult.updateError;
    }

    _isCheckingForUpdate = true;

    try {
      _log('Checking for app updates...');

      // Check if update is available
      final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();
      _updateInfo = updateInfo;

      _log('Update info received: ${updateInfo.updateAvailability}');

      // Check if update is available for download
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        _log('Update available! Starting flexible update...');

        // Notify callback
        onUpdateResult?.call(AppUpdateResult.updateAvailable, 
            'Update available');

        // Start flexible update (user can continue using the app)
        final AppUpdateResult result = await _startFlexibleUpdate(
          updateInfo: updateInfo,
          onUpdateResult: onUpdateResult,
        );

        _isCheckingForUpdate = false;
        return result;
      } else if (updateInfo.updateAvailability == 
                  UpdateAvailability.updateNotAvailable) {
        _log('No update available');
        
        onUpdateResult?.call(AppUpdateResult.updateNotAvailable, 
            'App is up to date');
        
        _isCheckingForUpdate = false;
        return AppUpdateResult.updateNotAvailable;
      } else {
        _log('Update availability: ${updateInfo.updateAvailability}');
        _isCheckingForUpdate = false;
        return AppUpdateResult.updateNotAvailable;
      }
    } catch (e, stackTrace) {
      _log('Error checking for update: $e\n$stackTrace', isError: true);
      
      final errorMessage = 'Failed to check for updates: $e';
      onUpdateResult?.call(AppUpdateResult.updateError, errorMessage);
      
      _isCheckingForUpdate = false;
      return AppUpdateResult.updateError;
    }
  }

  /// Start flexible update - allows user to continue using app while update downloads
  Future<AppUpdateResult> _startFlexibleUpdate({
    required AppUpdateInfo updateInfo,
    UpdateCallback? onUpdateResult,
  }) async {
    try {
      _log('Starting flexible update...');

      // Start flexible update
      await InAppUpdate.startFlexibleUpdate();

      _log('Flexible update started successfully');
      onUpdateResult?.call(AppUpdateResult.flexibleUpdateStarted, 
          'Update started. It will be installed when you restart the app.');

      return AppUpdateResult.flexibleUpdateStarted;
    } catch (e, stackTrace) {
      _log('Error starting flexible update: $e\n$stackTrace', isError: true);
      
      final errorMessage = 'Failed to start update: $e';
      onUpdateResult?.call(AppUpdateResult.updateError, errorMessage);
      
      return AppUpdateResult.updateError;
    }
  }

  /// Complete flexible update - should be called when app resumes
  /// 
  /// Call this in your widget's onResume lifecycle method
  Future<void> checkUpdateOnResume({
    UpdateCallback? onUpdateResult,
    BuildContext? context,
  }) async {
    try {
      if (_updateInfo == null) {
        _log('No update info available, skipping resume check');
        return;
      }

      _log('Checking update status on resume...');

      final AppUpdateInfo result = await InAppUpdate.checkForUpdate();

      if (result.updateAvailability == UpdateAvailability.updateAvailable) {
        _log('Update ready to install - calling completeUpdate');
        await InAppUpdate.completeFlexibleUpdate();
        
        _log('Flexible update completed');
        onUpdateResult?.call(
          AppUpdateResult.flexibleUpdateStarted, 
          'Update installed successfully!',
        );
      }
    } catch (e, stackTrace) {
      _log('Error completing update on resume: $e\n$stackTrace', isError: true);
    }
  }

  void _log(String message, {bool isError = false}) {
    if (isError) {
      developer.log(message, name: 'InAppUpdate', level: 900);
    } else {
      developer.log(message, name: 'InAppUpdate');
    }
  }
  bool get isCheckingForUpdate => _isCheckingForUpdate;
}

Future<void> checkForAppUpdate({
  bool showUpdateDialog = true,
  BuildContext? context,
}) async {
  final updateService = InAppUpdateService();
  
  await updateService.checkForUpdateAndUpdate(
    onUpdateResult: (result, message) {
      // Log the result
      developer.log(
        'Update result: $result, Message: $message',
        name: 'AppUpdate',
      );
    },
    context: context,
  );
}

/// Helper to be called in your home widget's resume lifecycle
/// 
/// Example:
/// ```dart
/// class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
///   @override
///   void initState() {
///     super.initState();
///     WidgetsBinding.instance.addObserver(this);
///   }
///
///   @override
///   void dispose() {
///     WidgetsBinding.instance.removeObserver(this);
///     super.dispose();
///   }
///
///   @override
///   void didChangeAppLifecycleState(AppLifecycleState state) {
///     if (state == AppLifecycleState.resumed) {
///       checkForUpdateOnResume();
///     }
///   }
/// }
/// ```
Future<void> checkForUpdateOnResume({
  BuildContext? context,
}) async {
  final updateService = InAppUpdateService();
  await updateService.checkUpdateOnResume(context: context);
}
