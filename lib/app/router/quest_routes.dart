import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/services/remote_app_config.dart';
import '../../core/webview/sso_webview.dart';
import '../../features/quest/profile_page.dart';
import '../../features/quest/quest_gate.dart';
import '../../features/quest/quest_session.dart';
import '../../features/quest/terms_page.dart';
import '../app_services.dart';
import '../menu/student_menu.dart';

/// The website's Elimu Quest, for when the native flow is off (remote config, or the API answers 404).
const questWebPath = '/msafara';

/// The Elimu Quest tab with the App API v1 flag off: the website's Msafara, never `/my-quizzes`.
class QuestWebRoute extends StatelessWidget {
  const QuestWebRoute({super.key});

  @override
  Widget build(BuildContext context) => SsoWebViewScreen(
        title: 'Elimu Quest',
        path: questWebPath,
        onRootBack: () => StatefulNavigationShell.of(context).goBranch(StudentMenu.homeBranch),
      );
}

/// Owns the [MsafaraSession] for the life of the tab and hands it to the pushed screens through `extra`.
class QuestRoute extends StatefulWidget {
  const QuestRoute({super.key, required this.services});
  final AppServices services;

  @override
  State<QuestRoute> createState() => _QuestRouteState();
}

class _QuestRouteState extends State<QuestRoute> {
  late final MsafaraSession _session = MsafaraSession(
    widget.services.repositories.msafara,
    langStore: QuestLangStore(),
    remoteEnabled: _remoteEnabled,
  );

  @override
  void initState() {
    super.initState();
    _session.start(deviceLanguage: WidgetsBinding.instance.platformDispatcher.locale.languageCode);
  }

  /// `flags.msafara.enabled` of the start-up config. Unknown (offline, 404) counts as enabled: the
  /// `state` call decides then.
  Future<bool?> _remoteEnabled() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final cfg = await RemoteAppConfigService(widget.services.apiClient.appV1)
          .fetch(build: int.tryParse(info.buildNumber) ?? 0);
      return cfg?.msafaraEnabled;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => QuestGate(
        session: _session,
        onReserve: () => context.push('/student/quest/terms', extra: _session),
        onProfile: () => context.push('/student/quest/profile', extra: _session),
        activeBuilder: (context) => _ActiveStub(session: _session),
        fallbackBuilder: (context) => const QuestWebRoute(),
      );
}

/// Replaced by the Elimu Quest home.
class _ActiveStub extends StatelessWidget {
  const _ActiveStub({required this.session});
  final MsafaraSession session;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(session.strings.t('title'))),
        body: Center(child: Text(session.state?.calendar.today.town ?? '')),
      );
}

/// A pushed terms screen. After the terms the learner goes on to the profile if that is what is missing.
class QuestTermsRoute extends StatelessWidget {
  const QuestTermsRoute({super.key, required this.session});
  final MsafaraSession session;

  @override
  Widget build(BuildContext context) => TermsPage(
        session: session,
        onDone: () {
          if (session.state?.seat == 'profile') {
            context.pushReplacement('/student/quest/profile', extra: session);
          } else if (context.canPop()) {
            context.pop();
          }
        },
      );
}

class QuestProfileRoute extends StatelessWidget {
  const QuestProfileRoute({super.key, required this.session});
  final MsafaraSession session;

  @override
  Widget build(BuildContext context) => ProfilePage(
        session: session,
        onDone: () {
          if (context.canPop()) context.pop();
        },
      );
}
