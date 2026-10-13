import 'package:dio/dio.dart';

import '../../app/app_config.dart';
import 'webview_policy.dart';

class SsoException implements Exception {
  const SsoException(this.kind);
  final SsoFailure kind;
  @override
  String toString() => 'SsoException(${kind.name})';
}

enum SsoFailure { offline, unauthorized, unavailable, invalidPath }

/// Produces a URL that opens [path] already signed in. A new single-use
/// token is requested on every call: never cache or reuse the result.
abstract class SsoTokenService {
  Future<Uri> link(String path);
}

/// The deployed flow (release-2026-10-13c):
/// 1. `POST /api/student/generate-webview-token` with the bearer token
///    returns `{success, token}`: 64 random characters, valid 10 minutes,
///    redeemed once.
/// 2. The webview opens `GET /api/webview-auth?token=...&intended=<path>`;
///    the server logs the learner in and redirects to `intended`. A used or
///    expired token gives an HTML 403 page, so the caller asks again.
///
/// The token is only ever placed inside the returned [Uri]. It is never
/// logged, never stored and never shown. The deprecated password-taking
/// `/student/webview-token` is not used.
class LegacySsoTokenService implements SsoTokenService {
  LegacySsoTokenService({required Dio api, required AppConfig config})
      : _api = api,
        _config = config;

  final Dio _api;
  final AppConfig _config;

  @override
  Future<Uri> link(String path) async {
    if (!WebviewPolicy.isSafeIntendedPath(path)) {
      throw const SsoException(SsoFailure.invalidPath);
    }
    final Response<dynamic> r;
    try {
      r = await _api.post<dynamic>('/student/generate-webview-token');
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        throw const SsoException(SsoFailure.unauthorized);
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        throw const SsoException(SsoFailure.offline);
      }
      throw const SsoException(SsoFailure.unavailable);
    }

    final body = r.data;
    final token = body is Map ? body['token'] : null;
    if (token is! String || token.isEmpty) {
      throw const SsoException(SsoFailure.unavailable);
    }
    return Uri.parse('${_config.apiBaseUrl}/webview-auth').replace(
      queryParameters: {'token': token, 'intended': path},
    );
  }
}
