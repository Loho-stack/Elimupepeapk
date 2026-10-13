import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/a11y/a11y_controller.dart';
import '../core/a11y/a11y_host.dart';
import '../core/a11y/a11y_store.dart';
import '../core/a11y/a11y_sync.dart';
import '../core/a11y/speech_service.dart';
import '../core/design/clay.dart';
import '../core/services/analytics_service.dart';
import '../core/theme/app_page_transitions.dart';
import '../core/theme/app_theme.dart';
import 'app_services.dart';
import 'router/app_router.dart';
import 'session_controller.dart';

/// Root of the app: accessibility settings, session and router.
class ElimuPepeApp extends StatefulWidget {
  const ElimuPepeApp({super.key});

  @override
  State<ElimuPepeApp> createState() => _ElimuPepeAppState();
}

class _ElimuPepeAppState extends State<ElimuPepeApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final SessionController _session = SessionController();
  late final A11yController _a11y;
  late final SpeechService _speech = FlutterTtsService();
  late final GoRouter _router;
  bool _wasSignedIn = false;

  @override
  void initState() {
    super.initState();
    final services = AppServices.instance;

    // Accessibility sync talks to /api/app/v1/me/accessibility only when the
    // flag is on (the server answers 404 there until cut-over).
    _a11y = A11yController(
      store: SharedPreferencesA11yStore(),
      sync: services.config.a11yRemoteSync
          ? RemoteA11ySync(services.apiClient.appV1)
          : const LocalOnlySync(),
      canSync: () => _session.isSignedIn && _session.role == AppRole.student,
    )..load();

    final observer = AnalyticsService.instance.navigatorObserver;
    _router = buildRouter(
      session: _session,
      navigatorKey: _navigatorKey,
      observers: [if (observer != null) observer],
    );

    services.sessionExpired.addListener(_session.expire);
    _session.addListener(_onSessionChanged);
    _session.refresh();
  }

  void _onSessionChanged() {
    final signedIn = _session.isSignedIn;
    if (signedIn && !_wasSignedIn) {
      _a11y.onSignedIn();
    } else if (!signedIn && _wasSignedIn) {
      _a11y.onSignedOut();
    }
    _wasSignedIn = signedIn;
  }

  @override
  void dispose() {
    AppServices.instance.sessionExpired.removeListener(_session.expire);
    _session.removeListener(_onSessionChanged);
    _router.dispose();
    _session.dispose();
    _a11y.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _session),
        ChangeNotifierProvider.value(value: _a11y),
        Provider<SpeechService>.value(value: _speech),
      ],
      child: Consumer<A11yController>(
        builder: (context, a11y, _) => MaterialApp.router(
          title: 'Elimu Pepe',
          debugShowCheckedModeBanner: false,
          routerConfig: _router,
          theme: legacyCompatTheme(a11y.settings.toThemeOptions()),
          builder: (context, child) =>
              A11yHost(navigatorKey: _navigatorKey, child: child!),
        ),
      ),
    );
  }
}

/// The Clay theme plus the two settings older screens still depend on (green
/// app bars and the slide page transition). Remove when Phase 4 has rebuilt
/// those screens.
ThemeData legacyCompatTheme(ClayThemeOptions options) {
  final base = ClayTheme.build(options);
  return base.copyWith(
    pageTransitionsTheme: AppPageTransitions.theme,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.brandGreen,
      foregroundColor: AppColors.textLight,
    ),
  );
}
