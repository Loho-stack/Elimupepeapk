import 'package:dio/dio.dart';

import 'api_error.dart';

/// The `{success, data, meta?}` envelope of App API v1, already checked.
class Envelope {
  const Envelope({required this.data, this.meta, this.replayed = false});

  final Object? data;
  final Map<String, dynamic>? meta;

  /// The server answered from its Idempotency-Key store (`Idempotent-Replayed: true`).
  final bool replayed;

  Map<String, dynamic> get object {
    final d = data;
    if (d is Map) return Map<String, dynamic>.from(d);
    throw const FormatException('data should be an object');
  }

  List<Map<String, dynamic>> get rows {
    final d = data;
    if (d is List) {
      return [
        for (final item in d)
          item is Map ? Map<String, dynamic>.from(item) : throw const FormatException('data should be a list of objects'),
      ];
    }
    throw const FormatException('data should be a list');
  }
}

/// Runs one request on the app API Dio and returns the envelope, or throws an
/// [AppApiError]. Repositories use this and never see a `DioException`.
class ApiCall {
  ApiCall(this._dio);
  final Dio _dio;

  Future<Envelope> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<Envelope> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<Envelope> delete(String path, {Object? body}) =>
      _send('DELETE', path, body: body);

  /// POST with an Idempotency-Key. Marked retryable so the 429 back-off may
  /// replay it: the key makes that safe. [retry] false hands a 429 straight
  /// back (reading pings, which are better skipped than delayed).
  Future<Envelope> post(String path, {Object? body, String? idempotencyKey, bool retry = true}) =>
      _send('POST', path, body: body, idempotencyKey: idempotencyKey, retry: retry);

  Future<Envelope> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    String? idempotencyKey,
    bool retry = true,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          headers: {if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey},
          extra: {if (idempotencyKey != null && retry) 'retryable': true},
        ),
      );
      final raw = response.data;
      if (raw is! Map || raw['success'] != true) {
        throw const FormatException('not an App API envelope');
      }
      final meta = raw['meta'];
      return Envelope(
        data: raw['data'],
        meta: meta is Map ? Map<String, dynamic>.from(meta) : null,
        replayed: response.headers.value('idempotent-replayed') == 'true',
      );
    } catch (e) {
      throw AppApiError.from(e);
    }
  }
}

/// Parses with [parse], turning a bad shape into a `ParseError`.
T parsed<T>(T Function() parse) {
  try {
    return parse();
  } catch (e) {
    throw AppApiError.from(e is AppApiError ? e : const FormatException('shape'));
  }
}
