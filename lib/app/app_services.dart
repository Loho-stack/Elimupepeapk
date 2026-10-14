import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/auth/legacy_migration.dart';
import '../core/auth/remembered_login.dart';
import '../core/auth/session_cleaner.dart';
import '../core/auth/token_store.dart';
import '../core/auth/user_profile_store.dart';
import '../core/services/webview_session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/api_client.dart';
import '../data/repositories/app_repositories.dart';
import '../core/network/interceptors/connectivity_interceptor.dart';
import 'app_config.dart';

/// Process-wide wiring for the pieces that legacy services reach through
/// singletons (AuthService, LearnerDashboardApiService, ...). New code
/// should receive these through constructors or Provider instead.
class AppServices {
  AppServices._(this.config, this.tokenStore, this.apiClient, this.kv)
      : profile = UserProfileStore(kv),
        remembered = RememberedLogin(kv) {
    cleaner = SessionCleaner(
      kv: kv,
      prefs: SharedPreferences.getInstance,
      clearWebview: WebViewSessionService.clear,
    );
  }

  static AppServices? _instance;

  static AppServices get instance =>
      _instance ??= AppServices.create(AppConfig.current);

  /// Builds the production graph. Tests replace it with [override].
  factory AppServices.create(
    AppConfig config, {
    SecureKv? kv,
    HttpClientAdapter? adapter,
    ConnectivityChecker? connectivity,
  }) {
    final secure = kv ?? const FlutterSecureKv();
    final store = TokenStore(secure);
    late final AppServices services;
    final client = ApiClient(
      config: config,
      tokenStore: store,
      onSessionExpired: () => services.sessionExpired.value++,
      adapter: adapter,
      connectivity: connectivity,
    );
    services = AppServices._(config, store, client, secure);
    return services;
  }

  @visibleForTesting
  static void override(AppServices? services) => _instance = services;

  final AppConfig config;
  final TokenStore tokenStore;
  final ApiClient apiClient;
  final SecureKv kv;

  /// Repositories of App API v1 on the one [ApiClient]. Only used when [AppConfig.appApiV1] is on.
  late final AppRepositories repositories = AppRepositories.fromClient(apiClient);

  /// Display name and avatar URL only (see UserProfileStore).
  final UserProfileStore profile;

  /// "Remember me": the Student ID only, opt-in.
  final RememberedLogin remembered;

  /// Logout, account deletion and expired sessions all call this.
  late final SessionCleaner cleaner;

  /// Run once before the first screen: removes what older versions stored
  /// (saved passwords, PII in SharedPreferences) and moves tokens.
  Future<void> runStartup() async {
    final prefs = await SharedPreferences.getInstance();
    await LegacyMigration(kv: kv, prefs: prefs).run();
  }

  /// Wipes the signed-in learner's data from this device.
  Future<void> endSession({bool keepRemembered = true}) async {
    await cleaner.clear(keepRemembered: keepRemembered);
    await profile.clear();
  }

  /// Incremented each time a 401 could not be refreshed. The router listens
  /// and sends the user to the login screen.
  final ValueNotifier<int> sessionExpired = ValueNotifier<int>(0);
}
