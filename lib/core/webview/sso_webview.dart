import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_services.dart';
import '../../features/parental_control/parental_gate.dart';
import '../design/clay.dart';
import '../network/interceptors/connectivity_interceptor.dart';
import 'sso_token_service.dart';
import 'web_engine.dart';
import 'webview_policy.dart';

enum _Phase { fetching, page, error }

enum _ErrorKind { offline, unavailable, sessionEnded }

/// The one screen every WEBVIEW item of the student menu opens.
///
/// - Signed-in pages: [path] is a relative web path such as `/dals`. On every
///   open (and on one retry) a fresh single-use token is requested, then
///   `/api/webview-auth?token=...&intended=<path>` is loaded. No token is
///   cached, logged or shown.
/// - Public pages (terms, privacy, FAQ): pass [publicUrl]; no token is used.
/// - Only hosts allowed by [WebviewPolicy] load inside the app. Other links,
///   `target=_blank` and `window.open` go to the external browser after the
///   parental gate; iframes to other hosts are blocked.
/// - Back goes through webview history first. Fullscreen video, loading and
///   offline states are handled here.
class SsoWebViewScreen extends StatefulWidget {
  const SsoWebViewScreen({
    super.key,
    required this.title,
    this.path,
    this.publicUrl,
    this.tokenService,
    this.policy,
    this.engineFactory,
    this.connectivity,
    this.openExternal,
    this.parentalGate,
    this.onRootBack,
  }) : assert((path == null) != (publicUrl == null),
            'Pass exactly one of path or publicUrl');

  final String title;
  final String? path;
  final String? publicUrl;

  // Seams for tests; the defaults are the real implementations.
  final SsoTokenService? tokenService;
  final WebviewPolicy? policy;
  final WebEngineFactory? engineFactory;
  final ConnectivityChecker? connectivity;
  final Future<bool> Function(Uri uri)? openExternal;
  final Future<bool> Function(BuildContext context)? parentalGate;

  /// When the screen is a tab of a shell, back at the first page calls this
  /// (for example go to the Home tab) instead of popping the route.
  final VoidCallback? onRootBack;

  /// Opens [path] (relative to the site root) signed in.
  static Future<void> open(
    BuildContext context, {
    required String title,
    required String path,
  }) =>
      Navigator.of(context).push<void>(MaterialPageRoute(
        settings: const RouteSettings(name: 'sso_webview'),
        builder: (_) => SsoWebViewScreen(title: title, path: path),
      ));

  /// Opens a public page without signing in.
  static Future<void> openPublic(
    BuildContext context, {
    required String title,
    required String url,
  }) =>
      Navigator.of(context).push<void>(MaterialPageRoute(
        settings: const RouteSettings(name: 'public_webview'),
        builder: (_) => SsoWebViewScreen(title: title, publicUrl: url),
      ));

  @override
  State<SsoWebViewScreen> createState() => _SsoWebViewScreenState();
}

class _SsoWebViewScreenState extends State<SsoWebViewScreen> {
  late final WebEngine _engine;
  late final WebviewPolicy _policy;
  late final SsoTokenService _tokens;
  late final ConnectivityChecker _connectivity;

  _Phase _phase = _Phase.fetching;
  _ErrorKind _error = _ErrorKind.unavailable;
  int _progress = 0;
  String? _pageTitle;
  Widget? _fullscreen;
  bool _retriedToken = false;
  bool _externalInFlight = false;

  @override
  void initState() {
    super.initState();
    final services = AppServices.instance;
    _policy = widget.policy ?? WebviewPolicy(ownHost: services.config.host);
    _tokens = widget.tokenService ??
        LegacySsoTokenService(
            api: services.apiClient.api, config: services.config);
    _connectivity = widget.connectivity ?? PlatformConnectivity();
    final factory = widget.engineFactory ?? FlutterWebEngine.new;
    _engine = factory(_events());
    _open();
  }

  WebEngineEvents _events() => WebEngineEvents(
        onNavigationRequest: _onNavigationRequest,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageStarted: (_) {
          if (mounted && _phase == _Phase.page) {
            setState(() => _progress = 0);
          }
        },
        onPageFinished: (_) async {
          final t = await _engine.title();
          if (!mounted) return;
          setState(() {
            _progress = 100;
            if (t != null && t.trim().isNotEmpty) _pageTitle = t.trim();
          });
        },
        onUrlChange: _onUrlChange,
        onError: _onLoadError,
        onHttpError: _onHttpError,
        onScriptMessage: _onScriptMessage,
        onShowFullscreen: (w) {
          if (!mounted) return;
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
          setState(() => _fullscreen = w);
        },
        onHideFullscreen: _hideFullscreen,
      );

  void _hideFullscreen() {
    if (!mounted) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    setState(() => _fullscreen = null);
  }

  // --------------------------------------------------------------- loading

  Future<void> _open() async {
    setState(() {
      _phase = _Phase.fetching;
      _progress = 0;
    });
    try {
      final public = widget.publicUrl;
      if (public != null) {
        await _engine.load(Uri.parse(public));
      } else {
        if (!await _connectivity.isOnline()) {
          throw const SsoException(SsoFailure.offline);
        }
        // A fresh single-use token on every open; never reuse a link.
        final link = await _tokens.link(widget.path!);
        await _engine.load(link);
      }
      if (mounted) setState(() => _phase = _Phase.page);
    } on SsoException catch (e) {
      _fail(switch (e.kind) {
        SsoFailure.offline => _ErrorKind.offline,
        SsoFailure.unauthorized => _ErrorKind.sessionEnded,
        _ => _ErrorKind.unavailable,
      });
    } catch (_) {
      _fail(_ErrorKind.unavailable);
    }
  }

  void _fail(_ErrorKind kind) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.error;
      _error = kind;
    });
  }

  void _onLoadError(WebLoadError e) {
    if (!e.isMainFrame) return;
    _fail(e.isNetwork ? _ErrorKind.offline : _ErrorKind.unavailable);
  }

  void _onHttpError(Uri? url, int status) {
    if (status < 400 || url == null) return;
    // A used or expired token renders a 403 page at /webview-auth: ask for a
    // new token once, then give up with a clear message.
    if (status == 403 && url.path.endsWith('/webview-auth')) {
      if (!_retriedToken && widget.path != null) {
        _retriedToken = true;
        _open();
      } else {
        _fail(_ErrorKind.unavailable);
      }
    }
  }

  // ------------------------------------------------------------ navigation

  bool _onNavigationRequest(Uri uri, bool isMainFrame) {
    final decision = _policy.decide(uri, isMainFrame: isMainFrame);
    switch (decision) {
      case NavDecision.block:
        return false;
      case NavDecision.external:
        _openExternal(uri);
        return false;
      case NavDecision.allow:
        if (isMainFrame && _policy.looksLikeDownload(uri)) {
          // Files are handed to the phone (browser or viewer), not loaded
          // into the page.
          _openExternal(uri);
          return false;
        }
        return true;
    }
  }

  /// A main-frame URL that slipped past the delegate (for example a popup
  /// window): bring the webview back and open it outside.
  void _onUrlChange(Uri? url) {
    if (url == null) return;
    if (_policy.decide(url, isMainFrame: true) == NavDecision.allow) return;
    _engine.goBack();
    if (url.scheme == 'https') _openExternal(url);
  }

  void _onScriptMessage(String message) {
    final uri = Uri.tryParse(message.trim());
    if (uri == null) return;
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'https' ||
        WebviewPolicy.externalSchemes.contains(scheme)) {
      _openExternal(uri);
    }
  }

  Future<void> _openExternal(Uri uri) async {
    if (_externalInFlight || !mounted) return;
    _externalInFlight = true;
    try {
      // Leaving the app needs a grown-up, as before.
      final gate = widget.parentalGate ?? showParentalGate;
      if (!await gate(context)) return;
      final launch = widget.openExternal ??
          (u) => launchUrl(u, mode: LaunchMode.externalApplication);
      await launch(uri);
    } catch (_) {
      // Nothing to show: the learner stays on the page.
    } finally {
      _externalInFlight = false;
    }
  }

  // ------------------------------------------------------------------- UI

  Future<void> _onBack() async {
    if (_fullscreen != null) {
      _hideFullscreen();
      return;
    }
    if (_phase == _Phase.page && await _engine.canGoBack()) {
      await _engine.goBack();
      return;
    }
    if (!mounted) return;
    final rootBack = widget.onRootBack;
    if (rootBack != null) {
      rootBack();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ClayTokens.of(context).palette;
    final title = _pageTitle ?? widget.title;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: p.page,
        appBar: _fullscreen != null
            ? null
            : ClayAppBar(
                title: title,
                actions: [
                  if (_phase == _Phase.page)
                    ClayIconButton(
                      icon: ClayIcons.refresh,
                      label: 'Reload page',
                      onPressed: () => _engine.reload(),
                    ),
                ],
              ),
        body: Stack(
          children: [
            // The view stays mounted so history and state survive overlays.
            Positioned.fill(
              child: Offstage(
                offstage: _phase != _Phase.page,
                child: _engine.view,
              ),
            ),
            if (_phase == _Phase.page && _progress < 100)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ClayProgressBar(
                  value: _progress / 100,
                  semanticLabel: 'Loading page',
                ),
              ),
            if (_phase == _Phase.fetching) const _Opening(),
            if (_phase == _Phase.error)
              _ErrorView(kind: _error, onRetry: _retry),
            if (_fullscreen != null)
              Positioned.fill(child: ColoredBox(color: Colors.black, child: _fullscreen!)),
          ],
        ),
      ),
    );
  }

  void _retry() {
    _retriedToken = false;
    _open();
  }
}

class _Opening extends StatelessWidget {
  const _Opening();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(ClaySpace.s4),
        child: Semantics(
          liveRegion: true,
          label: 'Opening securely',
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClaySkeleton(shape: ClaySkeletonShape.title, width: 200),
              SizedBox(height: ClaySpace.s3),
              ClaySkeleton(shape: ClaySkeletonShape.art),
              SizedBox(height: ClaySpace.s3),
              ClaySkeleton(),
              SizedBox(height: ClaySpace.s2),
              ClaySkeleton(width: 240),
            ],
          ),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.kind, required this.onRetry});
  final _ErrorKind kind;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (title, message, icon, canRetry) = switch (kind) {
      _ErrorKind.offline => (
          'You are offline',
          'Check your connection and try again.',
          ClayIcons.offline,
          true
        ),
      _ErrorKind.sessionEnded => (
          'Please sign in again',
          'Your session ended. Go back and log in to continue.',
          ClayIcons.lock,
          false
        ),
      _ErrorKind.unavailable => (
          'Could not open this page',
          'Something went wrong while opening it securely. Please try again.',
          ClayIcons.warning,
          true
        ),
    };
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ClaySpace.s4),
        child: ClayEmptyState(
          title: title,
          message: message,
          icon: icon,
          actionLabel: canRetry ? 'Try again' : null,
          onAction: canRetry ? onRetry : null,
        ),
      ),
    );
  }
}
