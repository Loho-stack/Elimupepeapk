import 'package:dio/dio.dart';

import '../../app/app_config.dart';
import '../auth/token_store.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/backoff_interceptor.dart';
import 'interceptors/connectivity_interceptor.dart';
import 'interceptors/debug_log_interceptor.dart';
import 'interceptors/error_normalize_interceptor.dart';
import 'interceptors/unauthorized_interceptor.dart';
import 'token_refresher.dart';

/// The one place that builds Dio clients. Base URLs come from [AppConfig]
/// (`--dart-define=ENV`). Every client gets the same stack, in this order:
/// connectivity, auth header, 401 handling, 429 backoff, debug log.
class ApiClient {
  ApiClient({
    required this.config,
    required this.tokenStore,
    required this.onSessionExpired,
    ConnectivityChecker? connectivity,
    TokenRefresher? refresher,
    bool? debugLog,
    HttpClientAdapter? adapter,
  }) {
    final plain = _plain(config.appApiBaseUrl, adapter);
    this.refresher = refresher ??
        (config.tokenRefresh ? ServerRefresh(tokenStore, plain) : const NoRefresh());
    final checker = connectivity ?? PlatformConnectivity();
    api = _build(config.apiBaseUrl, checker, debugLog, adapter);
    appV1 = _build(config.appApiBaseUrl, checker, debugLog, adapter);
  }

  final AppConfig config;
  final TokenStore tokenStore;
  final void Function() onSessionExpired;
  late final TokenRefresher refresher;

  /// `https://<host>/api`: legacy student, teacher, parent and loho-coins
  /// routes used by the current app.
  late final Dio api;

  /// `https://<host>/api/app/v1`: Phase 2A routes (flagged off until
  /// deployed).
  late final Dio appV1;

  static const _timeout = Duration(seconds: 30);

  static Dio _plain(String baseUrl, HttpClientAdapter? adapter) {
    final d = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
      sendTimeout: _timeout,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));
    if (adapter != null) d.httpClientAdapter = adapter;
    return d;
  }

  Dio _build(String baseUrl, ConnectivityChecker checker, bool? debugLog,
      HttpClientAdapter? adapter) {
    final dio = _plain(baseUrl, adapter);
    dio.interceptors.addAll([
      ConnectivityInterceptor(checker),
      AuthInterceptor(
        store: tokenStore,
        refresher: refresher,
        ownHosts: {config.host},
      ),
      UnauthorizedInterceptor(
        dio: dio,
        store: tokenStore,
        refresher: refresher,
        onSessionExpired: onSessionExpired,
      ),
      BackoffInterceptor(dio: dio),
      ErrorNormalizeInterceptor(),
      DebugLogInterceptor(enabled: debugLog),
    ]);
    return dio;
  }

  /// The ebooks host has no auth and is a different deployment; it still
  /// gets connectivity, backoff and the safe debug log.
  Dio ebooks(String baseUrl) {
    final dio = _plain(baseUrl, null);
    dio.interceptors.addAll([
      ConnectivityInterceptor(PlatformConnectivity()),
      BackoffInterceptor(dio: dio),
      DebugLogInterceptor(),
    ]);
    return dio;
  }
}
