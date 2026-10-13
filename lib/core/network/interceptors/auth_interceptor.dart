import 'package:dio/dio.dart';

import '../../auth/token_store.dart';
import '../token_refresher.dart';

/// Adds `Authorization: Bearer` for requests to our own API host only.
/// Requests marked `extra: {'noAuth': true}` (login, refresh) get none.
///
/// With refresh available it also refreshes ahead of time when the access
/// token has less than [refreshWindow] left (30 day tokens, so a learner who
/// opens the app weekly never hits a 401).
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.store,
    required this.refresher,
    required this.ownHosts,
    this.refreshWindow = const Duration(days: 7),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final TokenStore store;
  final TokenRefresher refresher;
  final Set<String> ownHosts;
  final Duration refreshWindow;
  final DateTime Function() _now;

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra['noAuth'] == true ||
        !ownHosts.contains(options.uri.host)) {
      return handler.next(options);
    }
    final tokens = await store.read();
    if (tokens == null) return handler.next(options);

    final exp = tokens.accessExpiresAt;
    if (exp != null &&
        exp.difference(_now()) < refreshWindow &&
        await refresher.canRefresh()) {
      await refresher.refresh();
    }

    final token = await store.accessToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }
}
