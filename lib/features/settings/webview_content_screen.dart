import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:elimupepe/core/theme/app_theme.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:elimupepe/core/config/app_endpoints.dart';
import 'package:elimupepe/app/app_services.dart';
import 'package:elimupepe/features/parental_control/parental_gate.dart';
import 'package:elimupepe/core/utils/error_feedback.dart';
import 'package:flutter/services.dart' show rootBundle;

class WebViewContentScreen extends StatefulWidget {
  final String title;
  final String url;

  const WebViewContentScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<WebViewContentScreen> createState() => _WebViewContentScreenState();
}

class _WebViewContentScreenState extends State<WebViewContentScreen>
    with SingleTickerProviderStateMixin {
  static final List<String> _trustedHosts = [
    AppEndpoints.primaryHost,
    AppEndpoints.secondaryHost,
  ];

  late final WebViewController _controller;
  late final AnimationController _loaderPulseController;
  late final Animation<double> _loaderPulse;
  late String _pageTitle;
  bool _isLoading = true;
  bool _hasShownLoadError = false;
  bool _isUsingFallback = false;
  bool _allowRoutePop = false;
  int _progress = 0;
  String? _loadError;
  static String? _cachedOfflineHtml;

  @override
  void initState() {
    super.initState();
    _pageTitle = widget.title;
    _loaderPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _loaderPulse = CurvedAnimation(
      parent: _loaderPulseController,
      curve: Curves.easeInOut,
    );
    late final PlatformWebViewControllerCreationParams creationParams;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      creationParams = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      creationParams = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(
      creationParams,
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _progress = progress;
              _isLoading = progress < 100;
            });
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasShownLoadError = false;
                _loadError = null;
                _progress = 0;
              });
            }
          },
          onPageFinished: (url) async {
            await _syncPageTitle();
            final uri = Uri.parse(url);
            if (_shouldApplyReadabilityFix(uri)) {
              await _applyReadabilityFix();
            }
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasShownLoadError = false;
                _loadError = null;
                _progress = 100;
              });
            }
          },
          onWebResourceError: (error) {
            _handleWebResourceError(error);
          },
          onNavigationRequest: (NavigationRequest request) async {
            final uri = Uri.parse(request.url);
            final host = uri.host.toLowerCase();

            // Allow internal navigation without gate
            if (_trustedHosts.contains(host)) {
              return NavigationDecision.navigate;
            }

            // For any other navigation (external links), we MUST show a parental gate
            // and potentially block it if it's not a safe domain.
            final passed = await showParentalGate(context);
            if (passed) {
              return NavigationDecision.navigate;
            }

            return NavigationDecision.prevent;
          },
        ),
      );
    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
    _loadUrl(widget.url);
  }

  @override
  void dispose() {
    _loaderPulseController.dispose();
    super.dispose();
  }

  Future<void> _handleWebResourceError(WebResourceError error) async {
    if (!mounted) return;
    if (error.isForMainFrame != true) {
      return;
    }
    if (ErrorFeedback.isNetworkError(error.description) &&
        !_isUsingFallback) {
      await _loadOfflineFallback();
      return;
    }
    if (_hasShownLoadError) return;
    setState(() {
      _isLoading = false;
      _loadError = ErrorFeedback.userMessage(
        error.description,
        fallback: 'Please check your network connection and try again.',
      );
    });
    _hasShownLoadError = true;
  }

  @override
  void didUpdateWidget(covariant WebViewContentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _pageTitle = widget.title;
      _loadUrl(widget.url);
    } else if (oldWidget.title != widget.title &&
        _pageTitle == oldWidget.title) {
      _pageTitle = widget.title;
    }
  }

  Future<void> _loadUrl(String rawUrl) async {
    final uri = Uri.parse(rawUrl);
    final headers = await _buildHeadersForUrl(uri);
    await _controller.loadRequest(uri, headers: headers);
  }

  Future<void> _loadOfflineFallback() async {
    if (_isUsingFallback || !mounted) {
      return;
    }

    try {
      final brandedHtml = await _getOfflineHtml();
      _isUsingFallback = true;
      setState(() {
        _isLoading = false;
        _hasShownLoadError = false;
        _loadError = null;
        _progress = 100;
      });
      await _controller.loadHtmlString(
        brandedHtml,
        baseUrl: 'https://offline.elimupepe.local/',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = ErrorFeedback.userMessage(
          e,
          fallback: 'Please check your network connection and try again.',
        );
      });
      _hasShownLoadError = true;
    }
  }

  Future<String> _getOfflineHtml() async {
    final cached = _cachedOfflineHtml;
    if (cached != null) {
      return cached;
    }

    final rawHtml = await rootBundle.loadString('assets/offline/offline.html');
    final logoBytes = await rootBundle.load('assets/images/elimu.png');
    final logoBase64 = base64Encode(logoBytes.buffer.asUint8List());
    final html = rawHtml.replaceAll('{{PAGE_TITLE}}', _pageTitle);
    final brandedHtml = html.replaceAll(
      '{{APP_LOGO}}',
      'data:image/png;base64,$logoBase64',
    );
    _cachedOfflineHtml = brandedHtml;
    return brandedHtml;
  }

  Future<Map<String, String>> _buildHeadersForUrl(Uri uri) async {
    if (!_trustedHosts.contains(uri.host.toLowerCase())) {
      return const {};
    }

    // Replaced by SsoWebView (no bearer header to webviews) in a later commit.
    final token = await AppServices.instance.tokenStore.accessToken();

    if (token == null || token.isEmpty) {
      return const {};
    }

    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json, text/html, */*',
    };
  }

  Future<void> _syncPageTitle() async {
    try {
      final title = await _controller.getTitle();
      if (!mounted || title == null || title.trim().isEmpty) {
        return;
      }

      setState(() {
        _pageTitle = title.trim();
      });
    } catch (_) {
      // Keep the original title if the webview cannot expose one.
    }
  }

  bool _shouldApplyReadabilityFix(Uri uri) {
    return _trustedHosts.contains(uri.host.toLowerCase());
  }

  Future<void> _applyReadabilityFix() async {
    const script = '''
      (() => {
        const isNearWhite = (rgb) => rgb && rgb[0] >= 235 && rgb[1] >= 235 && rgb[2] >= 235;
        const parseColor = (value) => {
          if (!value) return null;
          const match = value.match(/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)/i);
          if (!match) return null;
          return [Number(match[1]), Number(match[2]), Number(match[3])];
        };
        const effectiveBackground = (element) => {
          let current = element;
          while (current) {
            const style = window.getComputedStyle(current);
            const color = parseColor(style.backgroundColor);
            if (color && style.backgroundColor !== 'rgba(0, 0, 0, 0)' && style.backgroundColor !== 'transparent') {
              return color;
            }
            current = current.parentElement;
          }
          return [255, 255, 255];
        };

        const elements = [document.body, ...document.querySelectorAll('body *')].filter(Boolean);
        for (const element of elements) {
          const style = window.getComputedStyle(element);
          const textColor = parseColor(style.color);
          const fillColor = parseColor(style.webkitTextFillColor);
          const background = effectiveBackground(element);
          const whiteText = isNearWhite(textColor) || isNearWhite(fillColor);

          if (whiteText && isNearWhite(background)) {
            element.style.setProperty('color', '#1F2937', 'important');
            element.style.setProperty('-webkit-text-fill-color', '#1F2937', 'important');
          }
        }
      })();
    ''';

    try {
      await _controller.runJavaScript(script);
    } catch (_) {
      // Ignore script injection failures for pages that block custom JS.
    }
  }

  Future<void> _retryLoad() async {
    if (!mounted) return;
    setState(() {
      _isUsingFallback = false;
      _loadError = null;
      _isLoading = true;
      _progress = 0;
    });
    await _loadUrl(widget.url);
  }

  Future<void> _handleBackNavigation() async {
    try {
      if (await _controller.canGoBack()) {
        await _controller.goBack();
        return;
      }
    } catch (_) {
      // If the history check fails, fall back to closing the screen.
    }

    _requestClose();
  }

  void _closeWebView() {
    _requestClose();
  }

  void _requestClose() {
    if (!mounted) {
      return;
    }

    if (_allowRoutePop) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _allowRoutePop = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowRoutePop,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBackNavigation();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.lightGreen,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _closeWebView,
          ),
          title: Text(_pageTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          bottom: _isLoading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    value: _progress > 0 && _progress < 100
                        ? _progress / 100
                        : null,
                    backgroundColor: Colors.white.withValues(alpha: 0.24),
                    valueColor: const AlwaysStoppedAnimation(
                      AppColors.brandGreen,
                    ),
                  ),
                )
              : null,
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              Container(
                color: Colors.white.withValues(alpha: 0.55),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _loaderPulse,
                    builder: (context, child) {
                      final pulse = 0.95 + (_loaderPulse.value * 0.08);
                      final glow = 0.05 + (_loaderPulse.value * 0.09);

                      return Transform.scale(
                        scale: pulse,
                        child: Container(
                          width: 132,
                          height: 132,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.lightGreen.withValues(alpha: glow),
                                Colors.white.withValues(alpha: 0.02),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.brandGreen.withValues(
                                  alpha: 0.12 + (_loaderPulse.value * 0.08),
                                ),
                                blurRadius: 22,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: SizedBox(
                            width: 120,
                            height: 120,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  strokeWidth: 6,
                                  color: AppColors.lightGreen,
                                  value: _progress > 0 && _progress < 100
                                      ? _progress / 100
                                      : null,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: AppColors.brandGreen.withValues(
                                        alpha: 0.16,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.08,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    transitionBuilder: (child, animation) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: ScaleTransition(
                                          scale: Tween<double>(
                                            begin: 0.95,
                                            end: 1.0,
                                          ).animate(animation),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: Text(
                                      '${_progress.clamp(0, 100)}%',
                                      key: ValueKey<int>(_progress),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.3,
                                        color: AppColors.brandGreen,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            Positioned(
              top: 12,
              right: 12,
              child: SafeArea(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _closeWebView,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_loadError != null)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withValues(alpha: 0.92),
                  child: ErrorFeedback.buildInlineError(
                    context: context,
                    title: 'Could not load page',
                    error: _loadError,
                    onRetry: _retryLoad,
                    fallback:
                        'Please check your network connection and try again.',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
