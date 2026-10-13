import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/token_store.dart';

enum RefreshOutcome {
  /// New tokens are stored; retry the request.
  refreshed,

  /// The server refused (401/422) or there is nothing to refresh with:
  /// the session is over.
  rejected,

  /// Could not reach the server. The session may still be valid.
  unavailable,
}

/// Strategy for getting a new access token. Until the App API v1 is
/// deployed, [NoRefresh] is used and a 401 ends the session.
abstract class TokenRefresher {
  /// Whether a refresh can be attempted for the stored session.
  Future<bool> canRefresh();
  Future<RefreshOutcome> refresh();
}

class NoRefresh implements TokenRefresher {
  const NoRefresh();
  @override
  Future<bool> canRefresh() async => false;
  @override
  Future<RefreshOutcome> refresh() async => RefreshOutcome.rejected;
}

/// `POST /api/app/v1/auth/refresh` (E-04).
///
/// Contract (openapi.yaml, a6a0afaa): body `{refresh_token, device_token?}`;
/// 200 `{success, data:{access_token, refresh_token, token_type, expires_in,
/// expires_at, refresh_expires_at}}`. The refresh token is the credential (no
/// bearer) and works once: the old pair is revoked (rotation). 401 invalid or
/// revoked, 422 validation, 429 limited to 10/hour per IP.
///
/// Concurrent callers share one in-flight request, because a second use of
/// the same refresh token would fail after rotation.
class ServerRefresh implements TokenRefresher {
  ServerRefresh(this._store, this._dio, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final TokenStore _store;

  /// A plain Dio for the App API v1 root, without the auth/401 interceptors
  /// (the refresh call must not recurse into itself).
  final Dio _dio;
  final DateTime Function() _now;

  Future<RefreshOutcome>? _inFlight;

  @override
  Future<bool> canRefresh() async {
    final t = await _store.read();
    if (t == null || !t.canRefresh) return false;
    final exp = t.refreshExpiresAt;
    return exp == null || exp.isAfter(_now());
  }

  @override
  Future<RefreshOutcome> refresh() =>
      _inFlight ??= _run().whenComplete(() => _inFlight = null);

  Future<RefreshOutcome> _run() async {
    final current = await _store.read();
    if (current == null || !current.canRefresh) return RefreshOutcome.rejected;
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': current.refreshToken},
        options: Options(extra: const {'noAuth': true}),
      );
      final d = (r.data?['data'] as Map?)?.cast<String, dynamic>();
      final access = d?['access_token'] as String?;
      final refresh = d?['refresh_token'] as String?;
      if (access == null || access.isEmpty || refresh == null) {
        return RefreshOutcome.rejected;
      }
      await _store.save(AuthTokens(
        accessToken: access,
        refreshToken: refresh,
        accessExpiresAt: DateTime.tryParse('${d?['expires_at']}'),
        refreshExpiresAt: DateTime.tryParse('${d?['refresh_expires_at']}'),
      ));
      return RefreshOutcome.refreshed;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 422 || code == 403) {
        return RefreshOutcome.rejected;
      }
      // 404 before cut-over, 429, 5xx, no network: not authoritative.
      return RefreshOutcome.unavailable;
    } catch (_) {
      return RefreshOutcome.unavailable;
    }
  }
}
