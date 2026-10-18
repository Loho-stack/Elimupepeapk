import 'package:flutter/material.dart';

import '../../core/design/clay.dart';
import '../../data/models/msafara_checkpoint.dart';
import '../student/widgets/load_view.dart';
import 'checkpoint_controller.dart';
import 'quest_session.dart';
import 'quest_strings.dart';
import 'quest_widgets.dart';

/// The "Did you know" of a town and its checkpoint question: fact, question, answer, result, late state.
class CheckpointPage extends StatelessWidget {
  const CheckpointPage({super.key, required this.session, required this.controller, required this.onClose});
  final MsafaraSession session;
  final CheckpointController controller;

  /// Back to Elimu Quest.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([session, controller]),
      builder: (context, _) {
        final s = session.strings;
        final c = controller;
        return QuestScaffold(
          title: s.t('cp.did_you_know'),
          body: switch (c.phase) {
            CheckpointPhase.loading => Semantics(
                label: s.t('states.loading'),
                liveRegion: true,
                child: const Padding(
                  padding: EdgeInsets.all(ClaySpace.s4),
                  child: Column(children: [ClaySkeleton(height: 120), SizedBox(height: 12), ClaySkeleton(height: 160)]),
                ),
              ),
            CheckpointPhase.failed => Center(
                child: Padding(
                  padding: const EdgeInsets.all(ClaySpace.s4),
                  child: ErrorView(error: c.error!, onRetry: c.load),
                ),
              ),
            CheckpointPhase.none => Center(
                child: Padding(
                  padding: const EdgeInsets.all(ClaySpace.s4),
                  child: ClayEmptyState(
                    title: s.t('cp.band_pending'),
                    icon: ClayIcons.questions,
                    actionLabel: s.t('quest.back'),
                    onAction: onClose,
                  ),
                ),
              ),
            CheckpointPhase.ready => _Body(session: session, c: c, onClose: onClose),
          },
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.session, required this.c, required this.onClose});
  final MsafaraSession session;
  final CheckpointController c;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = session.strings;
    final cp = c.checkpoint!;
    final theme = Theme.of(context).textTheme;
    final r = c.result;

    return ListView(
      padding: const EdgeInsets.all(ClaySpace.s4),
      children: [
        QuestEntrance(child: _Postcard(s: s, cp: cp, lang: session.lang)),
        const SizedBox(height: ClaySpace.s3),
        if (cp.state == 'locked' && cp.date != null)
          ClayCard(
            tone: ClayCardTone.soft,
            child: Row(children: [
              const ExcludeSemantics(child: Icon(ClayIcons.lock)),
              const SizedBox(width: ClaySpace.s2),
              Expanded(child: Text(s.t('cp.opens_on', {'date': formatEatDate(cp.date!, session.lang)}), style: theme.bodyMedium)),
            ]),
          ),
        if (cp.state == 'closed')
          ClayCard(
            tone: ClayCardTone.rose,
            child: Semantics(liveRegion: true, child: Text(s.t('cp.closed'), style: theme.bodyMedium)),
          ),
        if (cp.bandPending)
          ClayCard(tone: ClayCardTone.soft, child: Text(s.t('cp.band_pending'), style: theme.bodyMedium))
        else ...[
          if (cp.fact != null && cp.state != 'locked') ...[
            Semantics(header: true, child: Text(s.t('cp.did_you_know'), style: theme.titleMedium)),
            const SizedBox(height: ClaySpace.s2),
            ClayCard(child: Text(cp.fact!, style: theme.bodyLarge)),
            const SizedBox(height: ClaySpace.s4),
          ],
          if (cp.state != 'locked') _Question(s: s, c: c, cp: cp, result: r, onClose: onClose),
        ],
      ],
    );
  }
}

class _Postcard extends StatelessWidget {
  const _Postcard({required this.s, required this.cp, required this.lang});
  final QuestStrings s;
  final Checkpoint cp;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final dayLabel = cp.isLaunchDay ? s.t('cp.launch_day') : s.t('cp.day', {'day': cp.day});
    return ClayCard(
      tone: ClayCardTone.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const ExcludeSemantics(child: Icon(ClayIcons.msafara, size: 24)),
            const SizedBox(width: ClaySpace.s2),
            Expanded(child: Text(dayLabel, style: theme.labelLarge)),
            if (cp.late || cp.state == 'late') ClayBadge(label: s.t('cp.late_ribbon'), tone: ClayBadgeTone.warn),
            if (cp.solved) ClayBadge(label: s.t('cp.stamp'), tone: ClayBadgeTone.done),
          ]),
          const SizedBox(height: ClaySpace.s1),
          Semantics(header: true, child: Text(s.t('cp.postcard', {'town': cp.town}), style: theme.headlineSmall)),
          if (cp.county != null) Text(s.t('cp.county', {'county': cp.county!}), style: theme.bodyMedium),
          if (cp.special != null) Text(cp.special!, style: theme.labelLarge),
        ],
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.s, required this.c, required this.cp, required this.result, required this.onClose});
  final QuestStrings s;
  final CheckpointController c;
  final Checkpoint cp;
  final CheckpointResult? result;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final r = result;
    final finished = cp.finished;

    final tries = cp.attemptsLeft == 1 ? s.t('cp.last_try') : s.t('cp.tries_left', {'n': cp.attemptsLeft});
    final secondTry = cp.answers.length == 1 && !cp.late && cp.state != 'late' && cp.kmExpected != cp.fullKm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(s.t('cp.question'), style: theme.titleMedium)),
        const SizedBox(height: ClaySpace.s2),
        ClayCard(child: Text(cp.question!, style: theme.titleLarge)),
        if (cp.answers.isNotEmpty) ...[
          const SizedBox(height: ClaySpace.s2),
          for (final a in cp.answers)
            Padding(
              padding: const EdgeInsets.only(top: ClaySpace.s1),
              child: Row(children: [
                ExcludeSemantics(child: Icon(a.correct ? ClayIcons.check : ClayIcons.warning, size: 18)),
                const SizedBox(width: ClaySpace.s2),
                Expanded(child: Text(s.t('cp.try', {'n': a.attempt, 'answer': a.chosen}), style: theme.bodyMedium)),
              ]),
            ),
        ],
        if (r != null) ...[
          const SizedBox(height: ClaySpace.s3),
          _Result(s: s, cp: cp, r: r),
          const SizedBox(height: ClaySpace.s3),
          if (!r.correct && r.attemptsLeft > 0)
            ClayButton(label: s.t('states.retry'), onPressed: c.tryAgain)
          else
            ClayButton(label: s.t('cp.continue'), icon: ClayIcons.chevronRight, onPressed: onClose),
        ] else if (finished) ...[
          const SizedBox(height: ClaySpace.s3),
          ClayCard(
            tone: cp.solved ? ClayCardTone.green : ClayCardTone.soft,
            child: Semantics(
              container: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cp.solved ? s.t('cp.unlocked') : s.t('cp.out_of_tries'), style: theme.titleMedium),
                  if (cp.correctAnswer != null) Text('${s.t('cp.the_answer')} ${cp.correctAnswer}', style: theme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: ClaySpace.s3),
          ClayButton(label: s.t('cp.continue'), icon: ClayIcons.chevronRight, onPressed: onClose),
        ] else if (cp.canAnswer) ...[
          const SizedBox(height: ClaySpace.s3),
          for (final o in cp.options)
            Padding(
              padding: const EdgeInsets.only(bottom: ClaySpace.s2),
              child: ClayListTile(
                title: o,
                selected: c.selected == o,
                trailing: c.selected == o ? const Icon(ClayIcons.check) : const SizedBox(width: 24),
                onTap: c.busy ? null : () => c.select(o),
              ),
            ),
          const SizedBox(height: ClaySpace.s1),
          if (cp.late || cp.state == 'late')
            Text(s.t('cp.late'), style: theme.titleSmall)
          else if (!cp.isLaunchDay)
            Text(
              secondTry
                  ? s.t('cp.second_try', {'km': formatKm(cp.kmExpected), 'full': formatKm(cp.fullKm)})
                  : s.t('cp.worth', {'km': formatKm(cp.kmExpected)}),
              style: theme.titleSmall,
            ),
          if (cp.isLaunchDay) Text(s.t('cp.practice'), style: theme.bodySmall),
          Text(tries, style: theme.bodySmall),
          if (c.offlineKept) QuestError(text: s.t('quest.answer_kept')),
          if (c.answerError != null) QuestError(text: c.answerError!),
          const SizedBox(height: ClaySpace.s3),
          ClayButton(label: s.t('cp.answer'), loading: c.busy, onPressed: c.canSubmit ? c.submit : null),
        ],
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.s, required this.cp, required this.r});
  final QuestStrings s;
  final Checkpoint cp;
  final CheckpointResult r;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final outOfTries = !r.correct && r.attemptsLeft == 0;
    return Semantics(
      liveRegion: true,
      container: true,
      child: ClayCard(
        tone: r.correct ? ClayCardTone.green : ClayCardTone.rose,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (r.correct) ...[
              Text(s.t('cp.hongera'), style: theme.headlineSmall),
              Text(s.t('cp.correct', {'town': cp.town}), style: theme.titleMedium),
              if (r.coins > 0) Text(s.t('cp.coins', {'n': formatKm(r.coins)}), style: theme.bodyMedium),
              if (r.kmExpected > 0) Text(s.t('cp.km_coming', {'km': formatKm(r.kmExpected)}), style: theme.bodyMedium),
              if (cp.isLaunchDay) Text(s.t('cp.practice'), style: theme.bodySmall) else Text(s.t('cp.km_note'), style: theme.bodySmall),
            ] else if (outOfTries) ...[
              Text(s.t('cp.out_of_tries'), style: theme.titleMedium),
              if (r.correctAnswer != null) Text('${s.t('cp.the_answer')} ${r.correctAnswer}', style: theme.bodyMedium),
            ] else
              Text(s.t('cp.try_again'), style: theme.titleMedium),
          ],
        ),
      ),
    );
  }
}
