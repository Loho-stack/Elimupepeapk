import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:elimupepe/core/auth/token_store.dart';
import 'package:elimupepe/core/network/interceptors/connectivity_interceptor.dart';

/// In-memory secure storage.
class MemoryKv implements SecureKv {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> delete(String key) async => data.remove(key);
  @override
  Future<Map<String, String>> readAll() async => {...data};
  @override
  Future<void> deleteAll() async => data.clear();
}

class FakeConnectivity implements ConnectivityChecker {
  FakeConnectivity([this.online = true]);
  bool online;
  @override
  Future<bool> isOnline() async => online;
}

typedef Responder = ResponseBody Function(RequestOptions o);

/// Dio adapter that answers from a function and records every request.
class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this.handler);
  Responder handler;
  final seen = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  /// Authorization header values seen, in order.
  List<String?> get authHeaders =>
      seen.map((o) => o.headers['Authorization'] as String?).toList();
}

ResponseBody jsonBody(Object body,
        {int status = 200, Map<String, List<String>>? headers}) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: ['application/json'],
      ...?headers,
    });

ResponseBody status(int code, {Map<String, List<String>>? headers}) =>
    ResponseBody.fromString('{}', code, headers: {
      Headers.contentTypeHeader: ['application/json'],
      ...?headers,
    });

/// A body shaped like the App API v1 AppTokens schema.
Map<String, dynamic> tokensEnvelope({
  String access = 'access-2',
  String refresh = 'refresh-2',
  String expiresAt = '2099-01-01T00:00:00+03:00',
  String refreshExpiresAt = '2099-04-01T00:00:00+03:00',
}) =>
    {
      'success': true,
      'data': {
        'access_token': access,
        'refresh_token': refresh,
        'token_type': 'Bearer',
        'expires_in': 2592000,
        'expires_at': expiresAt,
        'refresh_expires_at': refreshExpiresAt,
      },
    };
