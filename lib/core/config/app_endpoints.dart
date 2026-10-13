import '../../app/app_config.dart';

/// Endpoint and host helpers. The environment (prod or staging) comes from
/// [AppConfig.current], so there is one place that decides the base URL.
class AppEndpoints {
  AppEndpoints._();

  static String get primaryHost => AppConfig.current.host;
  static String get apiBaseUrl => AppConfig.current.apiBaseUrl;
  static String get webBaseUrl => AppConfig.current.webBaseUrl;
  static const String ebooksApiBaseUrl =
      'https://api-ebooks.loholearning.co.ke';
  static const String secondaryHost = 'loholearning.co.ke';

  static List<String> get trustedHosts => [
        primaryHost,
        secondaryHost,
        'api-ebooks.loholearning.co.ke',
      ];

  static bool isTrustedUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return false;
    return trustedHosts.contains(uri.host);
  }

  static bool isTrustedUpdateUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return false;
    }
    return uri.host == primaryHost || uri.host.endsWith('.$primaryHost');
  }
}
