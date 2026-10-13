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
enum AppEnv { prod, staging }

class AppConfig {
  const AppConfig({
    required this.env,
    this.a11yRemoteSync = false,
    this.tokenRefresh = false,
    this.appApiV1Login = false,
  });

  final AppEnv env;
  final bool a11yRemoteSync;
  final bool tokenRefresh;
  final bool appApiV1Login;

  static const _env = String.fromEnvironment('ENV', defaultValue: 'prod');
  static const _all = bool.fromEnvironment('APP_API_V1');
  static const _sync = bool.fromEnvironment('A11Y_REMOTE_SYNC');
  static const _refresh = bool.fromEnvironment('TOKEN_REFRESH');
  static const _login = bool.fromEnvironment('APP_API_V1_LOGIN');

  static const AppConfig current = AppConfig(
    env: _env == 'staging' ? AppEnv.staging : AppEnv.prod,
    a11yRemoteSync: _all || _sync,
    tokenRefresh: _all || _refresh,
    appApiV1Login: _all || _login,
  );

  bool get isStaging => env == AppEnv.staging;

  String get host => isStaging
      ? 'staging.loholearning.co.ke'
      : 'elimupepe.loholearning.co.ke';

  String get webBaseUrl => 'https://$host';
  String get apiBaseUrl => 'https://$host/api';
  String get appApiBaseUrl => 'https://$host/api/app/v1';
}
