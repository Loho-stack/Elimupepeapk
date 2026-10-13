import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal key-value surface over secure storage, so tests can use memory.
abstract class SecureKv {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<Map<String, String>> readAll();
  Future<void> deleteAll();
}

class FlutterSecureKv implements SecureKv {
  const FlutterSecureKv([this._s = const FlutterSecureStorage()]);
  final FlutterSecureStorage _s;

  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
  @override
  Future<Map<String, String>> readAll() => _s.readAll();
  @override
  Future<void> deleteAll() => _s.deleteAll();
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    this.refreshToken,
    this.accessExpiresAt,
    this.refreshExpiresAt,
  });

  final String accessToken;

  /// Only present for App API v1 logins. Legacy tokens have none.
  final String? refreshToken;
  final DateTime? accessExpiresAt;
  final DateTime? refreshExpiresAt;

  bool get canRefresh => refreshToken != null && refreshToken!.isNotEmpty;
}

/// Where tokens live: flutter_secure_storage only, never SharedPreferences,
/// never logged. `toString` is deliberately not overridden on [AuthTokens]
/// callers; do not interpolate tokens into strings.
class TokenStore {
  TokenStore(this._kv);
  final SecureKv _kv;

  static const accessKey = 'access_token';
  static const refreshKey = 'refresh_token';
  static const accessExpiresKey = 'access_expires_at';
  static const refreshExpiresKey = 'refresh_expires_at';

  /// Pre-hardening keys. Read only as a fallback and removed by
  /// `LegacyMigration`.
  static const legacyKeys = ['auth_token', 'passport_token'];

  Future<String?> accessToken() async {
    final t = await _kv.read(accessKey);
    if (t != null && t.isNotEmpty) return t;
    for (final k in legacyKeys) {
      final legacy = await _kv.read(k);
      if (legacy != null && legacy.isNotEmpty) return legacy;
    }
    return null;
  }

  Future<AuthTokens?> read() async {
    final access = await accessToken();
    if (access == null) return null;
    return AuthTokens(
      accessToken: access,
      refreshToken: await _kv.read(refreshKey),
      accessExpiresAt: _date(await _kv.read(accessExpiresKey)),
      refreshExpiresAt: _date(await _kv.read(refreshExpiresKey)),
    );
  }

  Future<void> save(AuthTokens t) async {
    await _kv.write(accessKey, t.accessToken);
    await _write(refreshKey, t.refreshToken);
    await _write(accessExpiresKey, t.accessExpiresAt?.toIso8601String());
    await _write(refreshExpiresKey, t.refreshExpiresAt?.toIso8601String());
  }

  Future<bool> get hasSession async => (await accessToken()) != null;

  Future<void> clear() async {
    for (final k in [
      accessKey,
      refreshKey,
      accessExpiresKey,
      refreshExpiresKey,
      ...legacyKeys,
    ]) {
      await _kv.delete(k);
    }
  }

  Future<void> _write(String key, String? value) =>
      value == null ? _kv.delete(key) : _kv.write(key, value);

  static DateTime? _date(String? v) => v == null ? null : DateTime.tryParse(v);
}
