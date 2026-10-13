import 'package:webview_flutter/webview_flutter.dart';

class WebViewSessionService {
  WebViewSessionService._();

  static final WebViewCookieManager _cookieManager = WebViewCookieManager();

  /// Removes everything a webview kept for the signed-in learner: cookies
  /// (including the SSO session), HTTP cache and web storage (localStorage,
  /// sessionStorage, IndexedDB). Failures are ignored so logout completes.
  static Future<void> clear() async {
    try {
      await _cookieManager.clearCookies();
    } catch (_) {}
    try {
      final controller = WebViewController();
      await controller.clearCache();
      await controller.clearLocalStorage();
    } catch (_) {}
  }
}
