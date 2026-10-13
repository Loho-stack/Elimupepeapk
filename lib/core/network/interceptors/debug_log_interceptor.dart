import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Debug-only request log: `METHOD /path -> status 123ms`. Never prints
/// headers, query strings (a webview token travels in one), request or
/// response bodies, or tokens. Release builds log nothing.
class DebugLogInterceptor extends Interceptor {
  DebugLogInterceptor({bool? enabled, void Function(String)? sink})
      : enabled = enabled ?? kDebugMode,
        _sink = sink ?? ((m) => debugPrint(m));

  final bool enabled;
  final void Function(String) _sink;
  static const _startKey = 'logStart';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      options.extra[_startKey] = DateTime.now().millisecondsSinceEpoch;
    }
    handler.next(options);
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    _log(response.requestOptions, '${response.statusCode}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log(err.requestOptions,
        err.response?.statusCode?.toString() ?? err.type.name);
    handler.next(err);
  }

  void _log(RequestOptions o, String result) {
    if (!enabled) return;
    final start = o.extra[_startKey] as int?;
    final ms = start == null
        ? ''
        : ' ${DateTime.now().millisecondsSinceEpoch - start}ms';
    _sink('${o.method} ${o.uri.path} -> $result$ms');
  }
}
