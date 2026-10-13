import 'package:flutter/services.dart' show appFlavor;

/// Build-time configuration. Everything comes from `--dart-define`, nothing
/// is read from the device, and no secret lives here.
///
///   flutter run --flavor prod    --dart-define=ENV=prod
///   flutter run --flavor staging --dart-define=ENV=staging
///
/// Phase 2A (App API v1) features are off by default because the server keeps
/// every `/api/app/v1` path answering 404 until cut-over. Turn them on per
/// environment once it is deployed:
///
///   --dart-define=APP_API_V1=true          all three flags below
///   --dart-define=A11Y_REMOTE_SYNC=true    sync accessibility settings
///   --dart-define=TOKEN_REFRESH=true       refresh tokens (also needs the
///                                          App API v1 login, see AuthFlow)
///   --dart-define=APP_API_V1_LOGIN=true    log in through /auth/*/login
///   --dart-define=APP_CONFIG=true          start-up config (GET /app/config)
///                                          replaces the missing /v1/app/version
enum AppEnv { prod, staging }

class AppConfig {
  const AppConfig({
    required this.env,
    this.a11yRemoteSync = false,
    this.tokenRefresh = false,
    this.appApiV1Login = false,
    this.appConfigEndpoint = false,
  });

  final AppEnv env;
  final bool a11yRemoteSync;
  final bool tokenRefresh;
  final bool appApiV1Login;
  final bool appConfigEndpoint;

  static const _env = String.fromEnvironment('ENV', defaultValue: 'prod');
  static const _all = bool.fromEnvironment('APP_API_V1');
  static const _sync = bool.fromEnvironment('A11Y_REMOTE_SYNC');
  static const _refresh = bool.fromEnvironment('TOKEN_REFRESH');
  static const _login = bool.fromEnvironment('APP_API_V1_LOGIN');
  static const _config = bool.fromEnvironment('APP_CONFIG');

  /// The configuration of this build. Throws at start-up if the Android
  /// flavour and `--dart-define=ENV` disagree, so a prod app can never talk
  /// to staging (or the other way round) by a typo in the build command.
  static final AppConfig current = resolve(
    envDefine: _env,
    flavor: appFlavor,
    a11yRemoteSync: _all || _sync,
    tokenRefresh: _all || _refresh,
    appApiV1Login: _all || _login,
    appConfigEndpoint: _all || _config,
  );

  static AppConfig resolve({
    required String envDefine,
    String? flavor,
    bool a11yRemoteSync = false,
    bool tokenRefresh = false,
    bool appApiV1Login = false,
    bool appConfigEndpoint = false,
  }) {
    AppEnv? parse(String? v) => switch (v) {
          'prod' => AppEnv.prod,
          'staging' => AppEnv.staging,
          _ => null,
        };
    final fromDefine = parse(envDefine);
    if (fromDefine == null) {
      throw StateError('ENV must be prod or staging, got "$envDefine"');
    }
    final fromFlavor = parse(flavor);
    if (flavor != null && flavor.isNotEmpty && fromFlavor == null) {
      throw StateError('Unknown flavor "$flavor"');
    }
    if (fromFlavor != null && fromFlavor != fromDefine) {
      throw StateError(
          'Flavor "$flavor" does not match ENV=$envDefine. Build with '
          '--flavor $flavor --dart-define=ENV=$flavor.');
    }
    return AppConfig(
      env: fromDefine,
      a11yRemoteSync: a11yRemoteSync,
      tokenRefresh: tokenRefresh,
      appApiV1Login: appApiV1Login,
      appConfigEndpoint: appConfigEndpoint,
    );
  }

  bool get isStaging => env == AppEnv.staging;

  String get host => isStaging
      ? 'staging.loholearning.co.ke'
      : 'elimupepe.loholearning.co.ke';

  String get webBaseUrl => 'https://$host';
  String get apiBaseUrl => 'https://$host/api';
  String get appApiBaseUrl => 'https://$host/api/app/v1';
}
