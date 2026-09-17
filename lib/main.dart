import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:claim/screen/login.dart';
import 'package:claim/utils/boot_timing.dart';
import 'package:claim/utils/mobile_api.dart';
import 'package:claim/utils/theme.dart';
import 'package:claim/utils/update_service.dart';
import 'package:claim/utils/dio_service.dart';
import 'package:claim/utils/claim_store.dart';
import 'package:claim/utils/announcement_service.dart';
import 'package:claim/utils/claim_reminder_service.dart';
import 'package:claim/page/repair/repair_watch_service.dart';
import 'package:claim/utils/profile_avatar_service.dart';
import 'package:claim/utils/rank_service.dart';
import 'package:claim/utils/role_service.dart';
import 'package:claim/utils/supabase_config.dart';
import 'package:claim/widgets/offline_banner.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  BootTiming.start();
  WidgetsFlutterBinding.ensureInitialized();
  BootTiming.mark('binding');

  await initDio();
  BootTiming.mark('dio');
  await Future.wait([
    initializeDateFormatting('th', null),
    ProfileAvatarService.I.init(),
    RoleService.I.init(),
    MobileSession.I.init(),
  ]);
  BootTiming.mark('prefs services');

  unawaited(SupabaseConfig.refresh());

  unawaited(RankService.I.init());

  unawaited(ClaimStore.I.init());
  ClaimStore.I.startAutoPurge();

  runApp(const MyApp());
  BootTiming.mark('runApp');
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ClaimReminderService.I.refresh();
      RepairWatchService.I.check();
      _checkForUpdatesOnResume();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkForUpdatesOnResume();
      ClaimStore.I.purgeExpired();
      ClaimStore.I.startAutoPurge();
      ClaimReminderService.I.refresh();
      RepairWatchService.I.check();
    }
    if (state == AppLifecycleState.paused) {
      ClaimReminderService.I.refresh();
    }
  }

  Future<void> _checkForUpdatesOnResume() async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final blocked = await UpdateService.checkForUpdates(context);

    if (blocked || !context.mounted) return;
    await AnnouncementService.I.showIfAny(context);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AppTheme.getLightTheme(),
      darkTheme: AppTheme.getDarkTheme(),
      builder: (context, child) {
        final scheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.statusBarStyleFor(scheme.surface).copyWith(
            systemNavigationBarColor: scheme.surface,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: Stack(
            alignment: Alignment.bottomLeft,
            children: [
              child!,
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: OfflineBanner(),
              ),
            ],
          ),
        );
      },
      home: const SplashPage(),
    );
  }
}
