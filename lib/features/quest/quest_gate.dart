import 'package:flutter/material.dart';

import '../../core/design/clay.dart';
import '../../data/models/msafara.dart';
import '../student/widgets/load_view.dart';
import 'countdown_page.dart';
import 'profile_page.dart';
import 'quest_session.dart';
import 'quest_widgets.dart';
import 'terms_page.dart';

/// `/student/quest`: shows the screen for `state.stage`. Nothing else decides where the learner is.
class QuestGate extends StatelessWidget {
  const QuestGate({
    super.key,
    required this.session,
    required this.onReserve,
    required this.onProfile,
    required this.activeBuilder,
    required this.fallbackBuilder,
  });

  final MsafaraSession session;

  /// Countdown "Reserve your seat": opens the terms.
  final VoidCallback onReserve;

  /// Countdown "Choose grade and county".
  final VoidCallback onProfile;

  /// Elimu Quest home.
  final WidgetBuilder activeBuilder;

  /// The website's Elimu Quest in the SSO webview (`/msafara`).
  final WidgetBuilder fallbackBuilder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (session.useWebFallback) return fallbackBuilder(context);
        final s = session.strings;
        final state = session.state;

        if (state == null) {
          return QuestScaffold(
            title: s.t('title'),
            body: session.error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(ClaySpace.s4),
                      child: ErrorView(error: session.error!, onRetry: session.refresh, busy: session.loading),
                    ),
                  )
                : Semantics(
                    label: s.t('gate.checking'),
                    liveRegion: true,
                    child: const Padding(
                      padding: EdgeInsets.all(ClaySpace.s4),
                      child: Column(children: [ClaySkeleton(height: 96), SizedBox(height: 12), ClaySkeleton(height: 96)]),
                    ),
                  ),
          );
        }

        return switch (state.stage) {
          QuestStage.countdown => QuestScaffold(
              title: s.t('title'),
              body: CountdownPage(session: session, onReserve: onReserve, onProfile: onProfile),
            ),
          QuestStage.terms => QuestScaffold(
              title: s.t('title'),
              body: TermsPage(session: session, showBar: false),
            ),
          QuestStage.profile => QuestScaffold(
              title: s.t('title'),
              body: ProfilePage(session: session, showBar: false),
            ),
          QuestStage.active => activeBuilder(context),
          QuestStage.hidden || QuestStage.disabled => QuestScaffold(
              title: s.t('title'),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(ClaySpace.s4),
                  child: ClayEmptyState(
                    title: s.t('closed.title'),
                    message: s.t('closed.text'),
                    icon: ClayIcons.msafara,
                    actionLabel: s.t('states.retry'),
                    onAction: session.refresh,
                  ),
                ),
              ),
            ),
        };
      },
    );
  }
}
