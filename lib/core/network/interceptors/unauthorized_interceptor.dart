import 'package:dio/dio.dart';

import '../../auth/token_store.dart';
import '../api_exception.dart';
import '../token_refresher.dart';

/// 401 handling. If a refresh is possible, refresh once (shared between
/// concurrent requests) and replay the request. Otherwise the session is
/// over: tokens are cleared and [onSessionExpired] sends the user to login.
///
/// A 401 only counts when the request carried our token; a wrong password
/// on a login call (no token) must not log anyone out.
class UnauthorizedInterceptor extends Interceptor {
  UnauthorizedInterceptor({
    required this.dio,
    required this.store,
    required this.refresher,
    required this.onSessionExpired,
  });

  final Dio dio;
  final TokenStore store;
  final TokenRefresher refresher;
  final void Function() onSessionExpired;

  static const _retriedKey = 'authRetried';

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final o = err.requestOptions;
    final sentToken = o.headers['Authorization'] != null;
    if (err.response?.statusCode != 401 ||
        o.extra['noAuth'] == true ||
        !sentToken) {
      return handler.next(err);
    }

    if (o.extra[_retriedKey] != true && await refresher.canRefresh()) {
      switch (await refresher.refresh()) {
        case RefreshOutcome.refreshed:
          try {
            final retry = await dio.fetch<dynamic>(
              o.copyWith(
                extra: {...o.extra, _retriedKey: true},
                headers: {...o.headers}..remove('Authorization'),
              ),
            );
            return handler.resolve(retry);
          } on DioException catch (e) {
            return handler.next(e);
          }
        case RefreshOutcome.unavailable:
          return handler.next(err);
        case RefreshOutcome.rejected:
          break;
      }
    }

    await _expire();
    handler.next(err.copyWith(error: const SessionExpiredException()));
  }

  bool _expiring = false;

  Future<void> _expire() async {
    if (_expiring) return;
    _expiring = true;
    try {
      await store.clear();
      onSessionExpired();
    } finally {
      _expiring = false;
    }
  }
}
