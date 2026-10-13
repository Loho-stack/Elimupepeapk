import 'package:dio/dio.dart';

/// `GET /api/app/v1/app/config?build=N` (E-16), the start-up call of the App
/// API v1. Public; a bearer token, when present, adds the caller's own
/// subscription state. Only whitelisted values come back (no secrets).
///
/// Contract (openapi.yaml, a6a0afaa): `{success, data:{server_time,
/// app:{min_supported_build, latest_build, latest_version, force_update,
/// store_url}, flags:{msafara:{...}}, subscription:{required, active,
/// covered_by}|null, support:{email, phone, faq_url, contact_url},
/// webview_origin}}`. 30 requests a minute.
class RemoteAppConfig {
  const RemoteAppConfig({
    required this.minSupportedBuild,
    required this.latestBuild,
    required this.latestVersion,
    required this.forceUpdate,
    required this.storeUrl,
    this.supportEmail,
    this.supportPhone,
    this.faqUrl,
    this.contactUrl,
    this.msafaraEnabled,
  });

  final int minSupportedBuild;
  final int latestBuild;
  final String latestVersion;

  /// The server already compared `?build=` with `min_supported_build`.
  final bool forceUpdate;
  final String storeUrl;
  final String? supportEmail;
  final String? supportPhone;
  final String? faqUrl;
  final String? contactUrl;
  final bool? msafaraEnabled;

  bool updateAvailable(int currentBuild) => latestBuild > currentBuild;
  bool mustUpdate(int currentBuild) =>
      forceUpdate || currentBuild < minSupportedBuild;

  factory RemoteAppConfig.fromJson(Map<String, dynamic> body) {
    final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? {};
    final app = (data['app'] as Map?)?.cast<String, dynamic>() ?? {};
    final support = (data['support'] as Map?)?.cast<String, dynamic>() ?? {};
    final flags = (data['flags'] as Map?)?.cast<String, dynamic>() ?? {};
    final msafara = (flags['msafara'] as Map?)?.cast<String, dynamic>();
    return RemoteAppConfig(
      minSupportedBuild: _int(app['min_supported_build']),
      latestBuild: _int(app['latest_build']),
      latestVersion: '${app['latest_version'] ?? ''}',
      forceUpdate: app['force_update'] == true,
      storeUrl: '${app['store_url'] ?? ''}',
      supportEmail: support['email'] as String?,
      supportPhone: support['phone'] as String?,
      faqUrl: support['faq_url'] as String?,
      contactUrl: support['contact_url'] as String?,
      msafaraEnabled: msafara?['enabled'] as bool?,
    );
  }

  static int _int(Object? v) =>
      v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
}

class RemoteAppConfigService {
  RemoteAppConfigService(this._appV1);

  /// The shared App API v1 client.
  final Dio _appV1;

  Future<RemoteAppConfig?> fetch({required int build}) async {
    try {
      final r = await _appV1.get<Map<String, dynamic>>(
        '/app/config',
        queryParameters: {'build': build},
      );
      final body = r.data;
      if (r.statusCode != 200 || body == null) return null;
      return RemoteAppConfig.fromJson(body);
    } on DioException {
      // 404 before cut-over, offline, rate limit: carry on without it.
      return null;
    }
  }
}
