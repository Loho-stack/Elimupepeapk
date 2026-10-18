import 'dart:async';
import 'dart:ui';

import 'package:elimupepe/app/app.dart';
import 'package:elimupepe/app/app_config.dart';
import 'package:elimupepe/app/app_services.dart';
import 'package:elimupepe/core/theme/app_theme.dart';
import 'package:elimupepe/features/quest/quest_pdf_cache.dart';
import 'package:elimupepe/firebase_options.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';

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

    // Elimu Quest book PDFs older than 7 days leave the cache. Not awaited: it must not delay start-up.
    unawaited(QuestPdfCache.cleanStale());

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

    return const ElimuPepeApp();
  }
}
