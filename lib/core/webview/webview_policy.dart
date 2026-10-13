/// What a webview may load, and what must leave the app.
///
/// The list follows docs/api/STUDENT_RESOURCE_MAP.md: our own hosts, plus the
/// third parties that our pages embed or redirect to (Dals, Esoma, PhET, the
/// e-Limu games, YouTube and Vimeo players, Google and Office document
/// viewers). H5P and SCORM are served from our own origin.
enum NavDecision {
  /// Load it in the webview.
  allow,

  /// Open it in the system browser (or phone/mail app).
  external,

  /// Refuse it silently.
  block,
}

class WebviewPolicy {
  const WebviewPolicy({required this.ownHost});

  /// The environment's host, `elimupepe.loholearning.co.ke` or
  /// `staging.loholearning.co.ke`.
  final String ownHost;

  /// Our organisation's domain and everything below it
  /// (leaderboard.loholearning.co.ke, the environment hosts, ...).
  static const String orgDomain = 'loholearning.co.ke';

  /// Third-party hosts our pages use. Exact match unless it starts with `.`
  /// (then any subdomain too).
  static const List<String> thirdPartyHosts = [
    // Dals Learning
    'dalslearning.co.ke',
    '.dalslearning.co.ke',
    // Esoma Kids
    'www.esomakids.com',
    'esomakids.com',
    // Virtual labs
    'phet.colorado.edu',
    // e-Limu games
    'api.e-limu.org',
    '.e-limu.org',
    // Video players
    'www.youtube.com',
    'www.youtube-nocookie.com',
    'youtube.com',
    'player.vimeo.com',
    'vimeo.com',
    // Terms and privacy policy pages (public, no sign-in)
    'loho-stack.github.io',
    // Document viewers used by lesson pages
    'docs.google.com',
    'view.officeapps.live.com',
  ];

  /// Schemes handed to the phone's own apps.
  static const Set<String> externalSchemes = {'mailto', 'tel', 'sms'};

  static const Set<String> downloadExtensions = {
    'pdf', 'zip', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'csv', 'epub',
  };

  bool isOwnHost(String host) {
    final h = host.toLowerCase();
    return h == ownHost.toLowerCase() ||
        h == orgDomain ||
        h.endsWith('.$orgDomain');
  }

  bool isAllowedHost(String host) {
    final h = host.toLowerCase();
    if (isOwnHost(h)) return true;
    for (final t in thirdPartyHosts) {
      if (t.startsWith('.')) {
        if (h.endsWith(t)) return true;
      } else if (h == t) {
        return true;
      }
    }
    return false;
  }

  /// Decides a navigation. [isMainFrame] is false for iframes, which may
  /// only load allowed hosts: an iframe to anything else is blocked, never
  /// opened in the browser.
  NavDecision decide(Uri uri, {required bool isMainFrame}) {
    final scheme = uri.scheme.toLowerCase();

    if (scheme == 'about' && uri.toString() == 'about:blank') {
      return NavDecision.allow;
    }
    if (externalSchemes.contains(scheme)) {
      return isMainFrame ? NavDecision.external : NavDecision.block;
    }
    if (scheme != 'https') {
      // http, javascript, data, file, intent, content, blob, ...
      return NavDecision.block;
    }
    if (uri.host.isEmpty) return NavDecision.block;
    if (isAllowedHost(uri.host)) return NavDecision.allow;
    return isMainFrame ? NavDecision.external : NavDecision.block;
  }

  /// Whether a main-frame request looks like a file download rather than a
  /// page (by extension or an export path).
  bool looksLikeDownload(Uri uri) {
    final path = uri.path.toLowerCase();
    final dot = path.lastIndexOf('.');
    if (dot != -1 && downloadExtensions.contains(path.substring(dot + 1))) {
      return true;
    }
    return path.endsWith('/export') || path.contains('/download');
  }

  /// A relative path that is safe to pass as `intended` to the server (it
  /// does not validate it, S-18): starts with a single slash, no scheme, no
  /// host, no backslash, no control characters, no `..`.
  static bool isSafeIntendedPath(String path) {
    if (!path.startsWith('/') || path.startsWith('//')) return false;
    if (path.contains('\\') || path.contains('..')) return false;
    if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(path)) return false;
    final uri = Uri.tryParse(path);
    return uri != null && !uri.hasScheme && uri.host.isEmpty;
  }
}
