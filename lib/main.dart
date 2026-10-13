import 'dart:async';
import 'dart:ui';

import 'package:elimupepe/app/app_config.dart';
import 'package:elimupepe/app/app_services.dart';
import 'package:elimupepe/features/auth/welcome_screen.dart';
import 'package:elimupepe/core/services/analytics_service.dart';
import 'package:elimupepe/core/theme/app_page_transitions.dart';
import 'package:elimupepe/core/theme/app_theme.dart';
import 'package:elimupepe/features/auth/auth_gate.dart';
import 'package:elimupepe/firebase_options.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// A 401 that could not be refreshed (or an account that was disabled):
/// wipe the device and go back to the welcome flow.
Future<void> _onSessionExpired() async {
  await AppServices.instance.endSession();
  appNavigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const WelcomeScreen()),
    (route) => false,
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runZonedGuarded(
    () {
      runApp(const AppBootstrapper());
    },
    (error, stackTrace) {
      _recordCrashSafely(error, stackTrace);
    },
  );
}

void _recordCrashSafely(Object error, StackTrace stackTrace) {
  try {
    if (Firebase.apps.isNotEmpty) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        fatal: true,
      );
    }
  } catch (_) {
    // Never let crash reporting crash the app.
  }
}

class AppBootstrapper extends StatefulWidget {
  const AppBootstrapper({super.key});

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // Staging has no registered Firebase app yet (see
      // android/app/src/staging/README.md): collect nothing from it.
      final collect = !kDebugMode && !AppConfig.current.isStaging;
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        collect,
      );
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(
        collect,
      );
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(collect);
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (e, stackTrace) {
      if (kDebugMode) debugPrint('Firebase initialization failed');
      _recordCrashSafely(e, stackTrace);
    }

    // Remove what older versions stored (saved passwords, PII in
    // SharedPreferences) before any screen reads it.
    try {
      await AppServices.instance.runStartup();
    } catch (_) {}
    AppServices.instance.sessionExpired.addListener(_onSessionExpired);

    if (mounted) {
      setState(() {
        _isReady = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: AppColors.surfaceGray,
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.brandGreen),
            ),
          ),
        ),
      );
    }

    return const SecureElimupepeApp();
  }
}

class SecureElimupepeApp extends StatelessWidget {
  const SecureElimupepeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final analyticsObserver = AnalyticsService.instance.navigatorObserver;

    return MaterialApp(
      title: 'Elimu Pepe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.brandGreen,
          primary: AppColors.brandGreen,
          secondary: AppColors.lightGreen,
        ),
        pageTransitionsTheme: AppPageTransitions.theme,
        scaffoldBackgroundColor: AppColors.surfaceGray,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.brandGreen,
          foregroundColor: AppColors.textLight,
        ),
      ),
      navigatorKey: appNavigatorKey,
      navigatorObservers: [if (analyticsObserver != null) analyticsObserver],
      home: const AuthGate(),
    );
  }
}
