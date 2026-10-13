import 'package:dio/dio.dart';

import 'a11y_settings.dart';

/// A pull result. [notModified] means the server answered 304 for our ETag.
class A11yPull {
  const A11yPull({
    required this.settings,
    this.updatedAt,
    this.etag,
    this.notModified = false,
  });

  const A11yPull.notModified()
      : settings = null,
        updatedAt = null,
        etag = null,
        notModified = true;

  final A11ySettings? settings;

  /// Null until the account has saved settings once (server `updated_at`).
  final DateTime? updatedAt;
  final String? etag;
  final bool notModified;
}

/// The account is not allowed to use this endpoint (parent/teacher, 403).
class A11ySyncForbidden implements Exception {
  const A11ySyncForbidden();
}

/// Server sync for accessibility settings. [LocalOnlySync] is used until
/// the App API v1 is deployed; [RemoteA11ySync] switches on with
/// `AppConfig.a11yRemoteSync`.
abstract class A11ySync {
  bool get enabled;
  Future<A11yPull> pull({String? etag});

  /// Sends a partial change and returns the full stored settings.
  Future<A11ySettings> push(Map<String, dynamic> changes);
}

class LocalOnlySync implements A11ySync {
  const LocalOnlySync();

  @override
  bool get enabled => false;

  @override
  Future<A11yPull> pull({String? etag}) async => const A11yPull.notModified();

  @override
  Future<A11ySettings> push(Map<String, dynamic> changes) =>
      throw UnsupportedError('Accessibility sync is off');
}

/// `GET/PUT /api/app/v1/me/accessibility` (E-12, E-13).
///
/// Contract (openapi.yaml, tag App API v1, a6a0afaa):
/// - 200 `{success:true, data:{settings:{...}, updated_at}}`, `updated_at`
///   null until first save; GET sends an ETag and honours If-None-Match (304).
/// - PUT takes any subset of the keys; unknown keys are ignored server side.
/// - 401 unauthenticated, 403 not a student, 422 invalid, 429 rate limit.
///
/// The Dio passed in must be the shared ApiClient Dio built for the App API
/// v1 root, which already adds the bearer token and handles 401 and 429.
class RemoteA11ySync implements A11ySync {
  RemoteA11ySync(this._dio);

  final Dio _dio;

  static const path = '/me/accessibility';

  @override
  bool get enabled => true;

  @override
  Future<A11yPull> pull({String? etag}) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        path,
        options: Options(
          headers: {if (etag != null) 'If-None-Match': etag},
          validateStatus: (s) =>
              s != null && (s == 304 || (s >= 200 && s < 300)),
        ),
      );
      if (r.statusCode == 304) return const A11yPull.notModified();
      final (settings, updatedAt) = _parse(r.data);
      return A11yPull(
        settings: settings,
        updatedAt: updatedAt,
        etag: r.headers.value('etag'),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) throw const A11ySyncForbidden();
      rethrow;
    }
  }

  @override
  Future<A11ySettings> push(Map<String, dynamic> changes) async {
    try {
      final r = await _dio.put<Map<String, dynamic>>(path, data: changes);
      return _parse(r.data).$1;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) throw const A11ySyncForbidden();
      rethrow;
    }
  }

  (A11ySettings, DateTime?) _parse(Map<String, dynamic>? body) {
    final data = (body?['data'] as Map?)?.cast<String, dynamic>();
    final settings = A11ySettings.fromJson(
        (data?['settings'] as Map?)?.cast<String, dynamic>());
    final updated = data?['updated_at'];
    return (settings, updated is String ? DateTime.tryParse(updated) : null);
  }
}
