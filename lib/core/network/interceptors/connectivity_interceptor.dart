import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import '../api_exception.dart';

abstract class ConnectivityChecker {
  Future<bool> isOnline();
}

/// Uses connectivity_plus. It reports whether a network is attached, not
/// whether the server is reachable; real failures still surface as Dio
/// connection errors.
class PlatformConnectivity implements ConnectivityChecker {
  PlatformConnectivity([Connectivity? c]) : _c = c ?? Connectivity();
  final Connectivity _c;

  @override
  Future<bool> isOnline() async {
    final r = await _c.checkConnectivity();
    return r.any((e) => e != ConnectivityResult.none);
  }
}

/// Fails fast when offline instead of waiting for the connect timeout.
class ConnectivityInterceptor extends Interceptor {
  ConnectivityInterceptor(this._checker);
  final ConnectivityChecker _checker;

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (await _checker.isOnline()) return handler.next(options);
    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: const OfflineException(),
        message: 'No network connection',
      ),
      true,
    );
  }
}
