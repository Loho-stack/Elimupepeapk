import 'package:flutter/foundation.dart';

import '../core/auth/token_store.dart';
import '../core/network/api_client.dart';
import 'app_config.dart';

/// Process-wide wiring for the pieces that legacy services reach through
/// singletons (AuthService, LearnerDashboardApiService, ...). New code
/// should receive these through constructors or Provider instead.
class AppServices {
  AppServices._(this.config, this.tokenStore, this.apiClient);

  static AppServices? _instance;

  static AppServices get instance =>
      _instance ??= AppServices.create(AppConfig.current);

  /// Builds the production graph. Tests replace it with [override].
  factory AppServices.create(AppConfig config, {TokenStore? tokenStore}) {
    final store = tokenStore ?? TokenStore(const FlutterSecureKv());
    late final AppServices services;
    final client = ApiClient(
      config: config,
      tokenStore: store,
      onSessionExpired: () => services.sessionExpired.value++,
    );
    services = AppServices._(config, store, client);
    return services;
  }

  @visibleForTesting
  static void override(AppServices? services) => _instance = services;

  final AppConfig config;
  final TokenStore tokenStore;
  final ApiClient apiClient;

  /// Incremented each time a 401 could not be refreshed. The router listens
  /// and sends the user to the login screen.
  final ValueNotifier<int> sessionExpired = ValueNotifier<int>(0);
}
