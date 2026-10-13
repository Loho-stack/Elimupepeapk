import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// What may leave the device through Analytics. Anything not listed is
/// dropped: no names, emails, phone numbers, Student IDs, tokens, titles or
/// free text. Add an event here (with its exact parameter keys) before
/// logging it.
class AnalyticsPolicy {
  AnalyticsPolicy._();

  static const Map<String, Set<String>> events = {
    'login_terms_not_agreed': {},
    'login_attempt': {'remember_me'},
    'login_failed': {'reason'},
    'login_error': {},
    'parent_login_attempt': {},
    'parent_login_failed': {'reason'},
    'book_download_start': {'book_id'},
    'book_download_success': {'book_id', 'book_category'},
    'book_download_failed': {'book_id'},
    'book_download_error': {'book_id', 'error_type'},
  };

  /// Values a `reason` parameter may take.
  static const Set<String> failureReasons = {'network', 'server', 'rejected'};

  static const int maxValueLength = 40;

  /// Returns the parameters to send, or null if the event is not allowed.
  static Map<String, Object>? sanitize(
    String name,
    Map<String, Object>? parameters,
  ) {
    final allowedKeys = events[name];
    if (allowedKeys == null) return null;
    final out = <String, Object>{};
    parameters?.forEach((key, value) {
      if (!allowedKeys.contains(key)) return;
      if (key == 'reason' && !failureReasons.contains(value)) return;
      if (value is num || value is bool) {
        out[key] = value;
      } else if (value is String) {
        out[key] = value.length > maxValueLength
            ? value.substring(0, maxValueLength)
            : value;
      }
    });
    return out;
  }
}

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._internal();
  factory AnalyticsService() => instance;
  AnalyticsService._internal();

  FirebaseAnalytics? _analytics;
  FirebaseAnalyticsObserver? _observer;

  static bool get _isSupportedPlatform {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => true,
      TargetPlatform.iOS => true,
      TargetPlatform.macOS => true,
      _ => false,
    };
  }

  FirebaseAnalytics? get analytics {
    if (!_isSupportedPlatform) return null;
    try {
      return _analytics ??= FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  NavigatorObserver? get navigatorObserver {
    final analyticsInstance = analytics;
    if (analyticsInstance == null) return null;
    return _observer ??= FirebaseAnalyticsObserver(analytics: analyticsInstance);
  }

  Future<void> setCollectionEnabled(bool enabled) async {
    final analyticsInstance = analytics;
    if (analyticsInstance == null) return;
    try {
      await analyticsInstance.setAnalyticsCollectionEnabled(enabled);
    } catch (_) {}
  }

  Future<void> logLogin({required String method}) async {
    final analyticsInstance = analytics;
    if (analyticsInstance == null) return;
    try {
      await analyticsInstance.logLogin(loginMethod: method);
    } catch (_) {}
  }

  Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    final safe = AnalyticsPolicy.sanitize(name, parameters);
    if (safe == null) {
      assert(false, 'Analytics event "$name" is not in AnalyticsPolicy');
      return;
    }
    final analyticsInstance = analytics;
    if (analyticsInstance == null) return;
    try {
      await analyticsInstance.logEvent(
        name: name,
        parameters: safe.isEmpty ? null : safe,
      );
    } catch (_) {}
  }
}
