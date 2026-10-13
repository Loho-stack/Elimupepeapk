import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// A failed main-frame load.
class WebLoadError {
  const WebLoadError({required this.isMainFrame, required this.isNetwork});
  final bool isMainFrame;

  /// No connection, DNS failure, timeout.
  final bool isNetwork;
}

/// Everything the engine reports back to the screen.
class WebEngineEvents {
  WebEngineEvents({
    required this.onNavigationRequest,
    required this.onProgress,
    required this.onPageStarted,
    required this.onPageFinished,
    required this.onUrlChange,
    required this.onError,
    required this.onHttpError,
    required this.onScriptMessage,
    required this.onShowFullscreen,
    required this.onHideFullscreen,
  });

  /// Return true to let the navigation happen.
  final bool Function(Uri uri, bool isMainFrame) onNavigationRequest;
  final void Function(int progress) onProgress;
  final void Function(Uri? url) onPageStarted;
  final void Function(Uri? url) onPageFinished;
  final void Function(Uri? url) onUrlChange;
  final void Function(WebLoadError error) onError;

  /// A main-frame HTTP status of 400 or more.
  final void Function(Uri? url, int status) onHttpError;

  /// A message from the page-side bridge (`target=_blank` and
  /// `window.open` URLs).
  final void Function(String message) onScriptMessage;
  final void Function(Widget fullscreen) onShowFullscreen;
  final void Function() onHideFullscreen;
}

/// The part of a webview that the SSO screen needs. A fake implements this in
/// tests; [FlutterWebEngine] is the real one.
abstract class WebEngine {
  Widget get view;
  Future<void> load(Uri uri);
  Future<bool> canGoBack();
  Future<void> goBack();
  Future<void> reload();
  Future<String?> title();
  Future<void> runJavaScript(String script);
}

typedef WebEngineFactory = WebEngine Function(WebEngineEvents events);

/// Page-side script: sends `target=_blank` link clicks and `window.open`
/// calls to Flutter instead of letting the webview open a window, so they
/// can go to the external browser.
const String ssoBridgeScript = r'''
(function () {
  if (window.__ssoBridgeInstalled || !window.SsoBridge) { return; }
  window.__ssoBridgeInstalled = true;
  document.addEventListener('click', function (e) {
    var a = e.target && e.target.closest ? e.target.closest('a[target="_blank"]') : null;
    if (a && a.href) {
      e.preventDefault();
      e.stopPropagation();
      window.SsoBridge.postMessage(String(a.href));
    }
  }, true);
  window.open = function (u) {
    if (u) { window.SsoBridge.postMessage(String(u)); }
    return null;
  };
})();
''';

class FlutterWebEngine implements WebEngine {
  FlutterWebEngine(WebEngineEvents events) {
    final PlatformWebViewControllerCreationParams params =
        WebViewPlatform.instance is WebKitWebViewPlatform
            ? WebKitWebViewControllerCreationParams(
                allowsInlineMediaPlayback: true,
                mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
              )
            : const PlatformWebViewControllerCreationParams();

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'SsoBridge',
        onMessageReceived: (m) => events.onScriptMessage(m.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            return events.onNavigationRequest(uri, request.isMainFrame)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onProgress: events.onProgress,
          onPageStarted: (url) {
            runJavaScript(ssoBridgeScript);
            events.onPageStarted(Uri.tryParse(url));
          },
          onPageFinished: (url) {
            runJavaScript(ssoBridgeScript);
            events.onPageFinished(Uri.tryParse(url));
          },
          onUrlChange: (change) {
            final u = change.url;
            events.onUrlChange(u == null ? null : Uri.tryParse(u));
          },
          onWebResourceError: (e) => events.onError(WebLoadError(
            isMainFrame: e.isForMainFrame ?? false,
            isNetwork: e.errorType == WebResourceErrorType.hostLookup ||
                e.errorType == WebResourceErrorType.connect ||
                e.errorType == WebResourceErrorType.timeout ||
                e.errorType == WebResourceErrorType.io,
          )),
          onHttpError: (e) {
            final status = e.response?.statusCode ?? 0;
            // Only the main document matters; sub-resources fail quietly.
            events.onHttpError(e.request?.uri, status);
          },
        ),
      );

    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
      // Our iframe items (Dals, Esoma, PhET) need third-party cookies.
      AndroidWebViewCookieManager(const PlatformWebViewCookieManagerCreationParams())
          .setAcceptThirdPartyCookies(platform, true);
      platform.setCustomWidgetCallbacks(
        onShowCustomWidget: (widget, onHide) => events.onShowFullscreen(widget),
        onHideCustomWidget: events.onHideFullscreen,
      );
    }
  }

  late final WebViewController _controller;

  @override
  Widget get view => WebViewWidget(controller: _controller);

  @override
  Future<void> load(Uri uri) => _controller.loadRequest(uri);

  @override
  Future<bool> canGoBack() => _controller.canGoBack();

  @override
  Future<void> goBack() => _controller.goBack();

  @override
  Future<void> reload() => _controller.reload();

  @override
  Future<String?> title() => _controller.getTitle();

  @override
  Future<void> runJavaScript(String script) async {
    try {
      await _controller.runJavaScript(script);
    } catch (_) {
      // The page may be navigating; the bridge is installed again on the
      // next page event.
    }
  }
}
