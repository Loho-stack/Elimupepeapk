import 'dart:io' show HttpDate;
import 'dart:math';

import 'package:dio/dio.dart';

/// 429 handling: wait (honouring `Retry-After`, else exponential with
/// jitter) and retry, at most [maxRetries] times, and only for idempotent
/// methods unless the request sets `extra: {'retryable': true}`.
class BackoffInterceptor extends Interceptor {
  BackoffInterceptor({
    required this.dio,
    this.maxRetries = 2,
    this.maxDelay = const Duration(seconds: 30),
    Future<void> Function(Duration)? delay,
    Random? random,
    DateTime Function()? now,
  })  : _delay = delay ?? Future<void>.delayed,
        _random = random ?? Random(),
        _now = now ?? DateTime.now;

  final Dio dio;
  final int maxRetries;
  final Duration maxDelay;
  final Future<void> Function(Duration) _delay;
  final Random _random;
  final DateTime Function() _now;

  static const _countKey = 'backoffCount';
  static const _idempotent = {'GET', 'HEAD', 'PUT', 'DELETE', 'OPTIONS'};

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final o = err.requestOptions;
    final count = (o.extra[_countKey] as int?) ?? 0;
    final allowed = _idempotent.contains(o.method.toUpperCase()) ||
        o.extra['retryable'] == true;
    if (err.response?.statusCode != 429 || !allowed || count >= maxRetries) {
      return handler.next(err);
    }

    await _delay(delayFor(err.response, count));
    try {
      final r = await dio.fetch<dynamic>(
          o.copyWith(extra: {...o.extra, _countKey: count + 1}));
      handler.resolve(r);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Duration delayFor(Response<dynamic>? response, int attempt) {
    final header = response?.headers.value('retry-after');
    if (header != null) {
      Duration? d;
      final secs = int.tryParse(header.trim());
      if (secs != null) {
        d = Duration(seconds: secs);
      } else {
        final at = _httpDate(header);
        if (at != null) d = at.difference(_now());
      }
      if (d != null) {
        if (d.isNegative) d = Duration.zero;
        return d > maxDelay ? maxDelay : d;
      }
    }
    final base = 500 * pow(2, attempt).toInt();
    final jitter = _random.nextInt(250);
    final d = Duration(milliseconds: base + jitter);
    return d > maxDelay ? maxDelay : d;
  }

  static DateTime? _httpDate(String v) {
    try {
      return HttpDate.parse(v);
    } catch (_) {
      return null;
    }
  }
}
