import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/services/remote_app_config.dart';
import '../../core/design/clay.dart';
import '../../core/webview/sso_webview.dart';
import '../../data/models/msafara_quests.dart';
import '../../features/quest/profile_page.dart';
import '../../features/quest/quest_gate.dart';
import '../../features/quest/quest_home_page.dart';
import '../../features/quest/quest_pdf_cache.dart';
import '../../features/quest/quest_read_page.dart';
import '../../features/quest/quest_session.dart';
import '../../features/quest/quest_strings.dart';
import '../../features/quest/quest_widgets.dart';
import '../../features/quest/questions_controller.dart';
import '../../features/quest/questions_page.dart';
import '../../features/quest/terms_page.dart';
import '../../features/student/load_controller.dart';
import '../../features/student/widgets/load_view.dart';
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
        activeBuilder: (context) => QuestHomeHost(session: _session),
        fallbackBuilder: (context) => const QuestWebRoute(),
      );
}

/// Owns the home controller. After a quest screen closes the home reloads, so kilometres, locks and
/// scores are the server's.
class QuestHomeHost extends StatefulWidget {
  const QuestHomeHost({super.key, required this.session});
  final MsafaraSession session;

  @override
  State<QuestHomeHost> createState() => _QuestHomeHostState();
}

class _QuestHomeHostState extends State<QuestHomeHost> {
  late final LoadController<QuestHome> _home = LoadController(_fetch)..load();

  Future<QuestHome> _fetch() async {
    try {
      return await widget.session.repo.home();
    } catch (e) {
      // A gate 409 refreshes the state; the gate then shows the right screen.
      widget.session.handleError(e);
      rethrow;
    }
  }

  @override
  void dispose() {
    _home.dispose();
    super.dispose();
  }

  Future<void> _open(String path) async {
    await context.push(path, extra: widget.session);
    if (mounted) _home.load();
  }

  @override
  Widget build(BuildContext context) => QuestHomePage(
        session: widget.session,
        controller: _home,
        actions: QuestHomeActions(
          openQuest: (card) => _open(
            '/student/quest/${card.completed || card.unlocked ? 'questions' : 'read'}/${card.no}',
          ),
          openBonus: () => _open('/student/quest/questions/6'),
        ),
      );
}

/// The reading screen of one quest: loads the quest, then shows the book or the lesson.
class QuestReadRoute extends StatefulWidget {
  const QuestReadRoute({super.key, required this.session, required this.no});
  final MsafaraSession session;
  final int no;

  @override
  State<QuestReadRoute> createState() => _QuestReadRouteState();
}

class _QuestReadRouteState extends State<QuestReadRoute> {
  late final LoadController<QuestDetail> _detail = LoadController(_fetch)..load();
  Future<QuestPdfCache>? _cache;

  Future<QuestDetail> _fetch() async {
    try {
      return await widget.session.repo.quest(widget.no);
    } catch (e) {
      if (widget.session.handleError(e) && mounted) _close();
      rethrow;
    }
  }

  /// One cache for this screen: the session's Dio, and only the app's own hosts.
  Future<QuestPdfCache> _openCache() => _cache ??= () async {
        final services = AppServices.instance;
        return QuestPdfCache(
          dio: services.apiClient.appV1,
          allowedHosts: QuestPdfCache.hostsOf([services.config.webBaseUrl, services.config.appApiBaseUrl]),
          directory: await QuestPdfCache.defaultDirectory(),
        );
      }();

  void _close() {
    if (context.canPop()) context.pop();
  }

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session.strings;
    // The error state of LoadView draws no page of its own; this gives it a surface.
    return Material(
      color: ClayTokens.of(context).palette.page,
      child: SafeArea(child: _view(context, s)),
    );
  }

  Widget _view(BuildContext context, QuestStrings s) {
    return LoadView<QuestDetail>(
      controller: _detail,
      loadingLabel: s.t('states.loading'),
      skeleton: QuestScaffold(
        title: s.t('title'),
        body: const Padding(padding: EdgeInsets.all(ClaySpace.s4), child: ClaySkeleton(height: 120)),
      ),
      builder: (context, detail, banner) => QuestReadPage(
        session: widget.session,
        detail: detail,
        fetchPdf: detail.book == null ? null : (url) async => (await _openCache()).fetch(url),
        onAnswer: () => context.pushReplacement('/student/quest/questions/${detail.no}', extra: widget.session),
        onClose: _close,
      ),
    );
  }
}

/// The questions of one quest.
class QuestQuestionsRoute extends StatefulWidget {
  const QuestQuestionsRoute({super.key, required this.session, required this.no});
  final MsafaraSession session;
  final int no;

  @override
  State<QuestQuestionsRoute> createState() => _QuestQuestionsRouteState();
}

class _QuestQuestionsRouteState extends State<QuestQuestionsRoute> {
  late final QuestionsController _controller = QuestionsController(
    repo: widget.session.repo,
    no: widget.no,
    onGate: (e) {
      widget.session.handleError(e);
      _close();
    },
  )..load();

  void _close() {
    if (mounted && context.canPop()) context.pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      QuestionsPage(session: widget.session, controller: _controller, onClose: _close);
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
