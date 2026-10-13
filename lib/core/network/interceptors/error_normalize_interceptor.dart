import 'package:dio/dio.dart';

import '../api_exception.dart';

/// Turns common failures into short user-facing messages on
/// `DioException.message` (existing screens already show it). Keeps the
/// original response and error so callers can still inspect them.
class ErrorNormalizeInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    String? message;
    if (err.error is SessionExpiredException || status == 401) {
      message = 'Session expired. Please log in again.';
    } else if (status == 404) {
      message = 'The requested resource was not found on the server.';
    } else if (status == 429) {
      message = 'Too many requests. Please wait a moment and try again.';
    } else if (err.error is OfflineException) {
      message = 'No internet connection.';
    }
    handler.next(message == null ? err : err.copyWith(message: message));
  }
}
