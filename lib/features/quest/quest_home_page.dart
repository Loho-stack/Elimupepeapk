import 'package:flutter/material.dart';

import '../../core/design/clay.dart';
import '../../data/models/msafara_quests.dart';
import '../student/load_controller.dart';
import '../student/widgets/adaptive.dart';
import '../student/widgets/load_view.dart';
import '../student/widgets/student_scaffold.dart';
import 'quest_session.dart';
import 'quest_strings.dart';
import 'quest_widgets.dart';

/// What the home screen can open. A null callback hides its link (the screen is not built yet).
class QuestHomeActions {
  const QuestHomeActions({
    required this.openQuest,
    required this.openBonus,
    this.openCheckpoint,
    this.openJourney,
    this.openBoards,
    this.openMe,
  });

  /// A book or lesson quest: the reader, or the questions when it is unlocked or done.
  final void Function(QuestCard card) openQuest;
  final VoidCallback openBonus;

  /// The day of the checkpoint to open.
  final void Function(int day)? openCheckpoint;
  final VoidCallback? openJourney;
  final VoidCallback? openBoards;
  final VoidCallback? openMe;
}

/// Elimu Quest home: today's town and leg, kilometres, the daily goal ring, the five Quest cards,
/// today's "Did you know" checkpoint and the links to the journey, boards and me.
class QuestHomePage extends StatelessWidget {
  const QuestHomePage({super.key, required this.session, required this.controller, required this.actions});
  final MsafaraSession session;
  final LoadController<QuestHome> controller;
  final QuestHomeActions actions;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final s = session.strings;
        return StudentScaffold(
          title: s.t('title'),
          body: LoadView<QuestHome>(
            controller: controller,
            loadingLabel: s.t('states.loading'),
            skeleton: const Padding(
              padding: EdgeInsets.all(ClaySpace.s4),
              child: Column(children: [ClaySkeleton(height: 140), SizedBox(height: 12), ClaySkeleton(height: 120)]),
            ),
            builder: (context, home, banner) => _Content(session: session, home: home, banner: banner, actions: actions),
          ),
        );
      },
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.session, required this.home, required this.banner, required this.actions});
  final MsafaraSession session;
  final QuestHome home;
  final Widget? banner;
  final QuestHomeActions actions;

  @override
  Widget build(BuildContext context) {
    final s = session.strings;
    final theme = Theme.of(context).textTheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(ClaySpace.s4),
      children: [
        if (banner != null) ...[banner!, const SizedBox(height: ClaySpace.s3)],
        QuestEntrance(child: _Header(s: s, home: home)),
        const SizedBox(height: ClaySpace.s3),
        QuestEntrance(child: _Kilometres(s: s, home: home)),
        if (!home.inRun && home.ended) ...[
          const SizedBox(height: ClaySpace.s4),
          ClayCard(
            tone: ClayCardTone.green,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(s.t('home.ended_title'), style: theme.titleLarge)),
                Text(s.t('home.ended_text'), style: theme.bodyMedium),
              ],
            ),
          ),
        ],
        if (home.inRun) ...[
          if (home.dailyGoal != null) ...[
            const SizedBox(height: ClaySpace.s3),
            QuestEntrance(child: _Goal(s: s, goal: home.dailyGoal!)),
          ],
          _Title(s.t('home.quest_kicker')),
          if (home.quests.isEmpty)
            ClayCard(
              tone: ClayCardTone.soft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(header: true, child: Text(s.t('home.quest_wait_title'), style: theme.titleMedium)),
                  Text(s.t('home.quest_wait_text'), style: theme.bodyMedium),
                ],
              ),
            ),
          for (final q in home.quests)
            Padding(
              padding: const EdgeInsets.only(bottom: ClaySpace.s3),
              child: QuestEntrance(child: QuestCardTile(s: s, card: q, onTap: () => actions.openQuest(q))),
            ),
          if (home.bonus != null) _Bonus(s: s, bonus: home.bonus!, onTap: actions.openBonus),
          if (home.checkpoint != null && home.checkpoint!.available) ...[
            _Title(s.t('home.checkpoint_kicker')),
            _Checkpoint(s: s, cp: home.checkpoint!, onOpen: actions.openCheckpoint),
          ],
          if (home.missed.isNotEmpty) ...[
            _Title(s.t('home.missed_kicker')),
            Text(s.t('home.missed_text'), style: theme.bodySmall),
            const SizedBox(height: ClaySpace.s2),
            for (final m in home.missed)
              Padding(
                padding: const EdgeInsets.only(bottom: ClaySpace.s2),
                child: ClayListTile(
                  title: s.t('home.missed_day', {'day': m.day, 'town': m.town}),
                  subtitle: '${formatKm(m.kmExpected)} km',
                  onTap: actions.openCheckpoint == null ? null : () => actions.openCheckpoint!(m.day),
                ),
              ),
          ],
          if (home.board != null) ...[
            _Title(s.t('home.board_kicker')),
            _Board(s: s, board: home.board!),
          ],
        ],
        const SizedBox(height: ClaySpace.s4),
        _Links(session: session, actions: actions),
        const SizedBox(height: ClaySpace.s4),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: ClaySpace.s5, bottom: ClaySpace.s2),
        child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
      );
}

String _dayLabel(QuestStrings s, QuestHome h) {
  if (h.day == 0) return s.t('home.launch_day');
  if (h.day == null) return h.label ?? s.t('title');
  return s.t('home.day', {'day': h.day!, 'days': h.totalDays});
}

class _Header extends StatelessWidget {
  const _Header({required this.s, required this.home});
  final QuestStrings s;
  final QuestHome home;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final leg = home.leg;
    final town = home.town;
    return ClayCard(
      tone: ClayCardTone.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const ExcludeSemantics(child: Icon(ClayIcons.msafara, size: 28)),
            const SizedBox(width: ClaySpace.s2),
            Expanded(child: Semantics(header: true, child: Text(_dayLabel(s, home), style: theme.titleLarge))),
          ]),
          if (town != null) ...[
            const SizedBox(height: ClaySpace.s2),
            Text(town.name, style: theme.headlineSmall),
            if (town.county != null) Text(town.county!, style: theme.bodyMedium),
          ],
          if (home.special != null) Text(home.special!, style: theme.labelLarge),
          if (leg != null) ...[
            const SizedBox(height: ClaySpace.s3),
            Text(s.t('header.leg', {'leg': leg.no, 'name': leg.name}), style: theme.labelLarge),
            const SizedBox(height: ClaySpace.s1),
            ClayProgressBar(
              value: leg.percent / 100,
              semanticLabel: s.t('home.road_label', {'leg': leg.no, 'percent': leg.percent}),
            ),
            const SizedBox(height: ClaySpace.s1),
            Text(s.t('header.leg_day', {'day': leg.day, 'days': leg.days}), style: theme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _Kilometres extends StatelessWidget {
  const _Kilometres({required this.s, required this.home});
  final QuestStrings s;
  final QuestHome home;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final km = home.km;
    final full = km.dailyCap > 0 && km.today >= km.dailyCap;
    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            label: '${formatKm(km.total)} ${s.t('header.km_total')}',
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(formatKm(km.total), style: theme.headlineMedium),
                  const SizedBox(width: ClaySpace.s2),
                  Expanded(child: Text(s.t('header.km_total'), style: theme.bodySmall)),
                ],
              ),
            ),
          ),
          if (home.inRun) ...[
            const SizedBox(height: ClaySpace.s3),
            Text(s.t('home.fuel_kicker'), style: theme.labelLarge),
            const SizedBox(height: ClaySpace.s1),
            ClayProgressBar(
              value: km.dailyCap <= 0 ? 0 : km.today / km.dailyCap,
              semanticLabel: s.t('home.fuel_label'),
            ),
            const SizedBox(height: ClaySpace.s1),
            Text(s.t('home.fuel_text', {'km': formatKm(km.today), 'cap': formatKm(km.dailyCap)}), style: theme.bodyMedium),
            Text(s.t(full ? 'home.fuel_full' : 'home.fuel_hint'), style: theme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _Goal extends StatelessWidget {
  const _Goal({required this.s, required this.goal});
  final QuestStrings s;
  final DailyGoal goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return ClayCard(
      child: LeadingAndText(
        leading: RingBadge(
          percent: goal.percent.clamp(0, 100),
          semanticLabel: s.t('home.goal', {'minutes': goal.minutes}),
          label: '${goal.percent}%',
        ),
        text: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t('home.goal', {'minutes': goal.minutes}), style: theme.titleMedium),
            Text(s.t('home.goal_read', {'done': goal.done, 'minutes': goal.minutes}), style: theme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// One of the day's Quests.
class QuestCardTile extends StatelessWidget {
  const QuestCardTile({super.key, required this.s, required this.card, required this.onTap});
  final QuestStrings s;
  final QuestCard card;
  final VoidCallback onTap;

  String _instruction() {
    if (card.isBook) {
      final from = card.pageFrom;
      final to = card.pageTo;
      if (from != null && to != null) {
        return s.t('home.read_pages', {'from': from, 'to': to});
      }
      return s.t('home.read_whole');
    }
    return s.t('home.read_lesson');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final minutes = (card.requiredSeconds / 60).ceil();
    final right = card.right ?? (card.score == null ? null : (card.score! * card.questions).round());

    final String status;
    final String action;
    if (card.completed) {
      status = right == null ? s.t('quest.done') : s.t('home.quest_done', {'right': right, 'size': card.questions});
      action = s.t('home.see_answers');
    } else if (card.unlocked) {
      status = s.t('home.quest_unlocked', {'size': card.questions});
      action = s.t('home.answer_questions');
    } else {
      status = s.t('home.quest_locked', {'minutes': minutes});
      action = s.t(card.readSeconds > 0 ? 'home.continue_reading' : 'home.start_reading');
    }

    final kicker = s.t('home.quest_card', {'n': card.no, 'type': card.typeName ?? ''});
    final label = '$kicker. ${card.title}. ${_instruction()}. $status. $action';

    return ClayCard(
      onTap: onTap,
      semanticLabel: label,
      tone: card.completed ? ClayCardTone.soft : ClayCardTone.plain,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ExcludeSemantics(child: Icon(card.isBook ? ClayIcons.learn : ClayIcons.quest, size: 24)),
            const SizedBox(width: ClaySpace.s2),
            Expanded(child: Text(kicker, style: theme.labelLarge)),
            if (card.kmExpected > 0)
              ClayBadge(label: '${formatKm(card.kmExpected)} km', tone: card.completed ? ClayBadgeTone.done : ClayBadgeTone.soft),
          ]),
          const SizedBox(height: ClaySpace.s1),
          Text(card.title, style: theme.titleMedium),
          if (card.publisher != null) Text(card.publisher!, style: theme.bodySmall),
          const SizedBox(height: ClaySpace.s1),
          Text(_instruction(), style: theme.bodyMedium),
          if (!card.completed && !card.unlocked) ...[
            const SizedBox(height: ClaySpace.s2),
            ClayProgressBar(
              value: card.requiredSeconds <= 0 ? 0 : card.readSeconds / card.requiredSeconds,
              semanticLabel: s.t('quest.lock_label'),
            ),
          ],
          const SizedBox(height: ClaySpace.s2),
          Text(status, style: theme.bodySmall),
          const SizedBox(height: ClaySpace.s2),
          Row(children: [
            Expanded(child: Text(action, style: theme.titleSmall)),
            const ExcludeSemantics(child: Icon(ClayIcons.chevronRight, size: 20)),
          ]),
        ],
      ),
    );
  }
}

class _Bonus extends StatelessWidget {
  const _Bonus({required this.s, required this.bonus, required this.onTap});
  final QuestStrings s;
  final BonusCard bonus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return ClayCard(
      onTap: onTap,
      semanticLabel: '${s.t('home.bonus_kicker')}. ${s.t('home.bonus_title')}. ${s.t('home.bonus_start')}',
      tone: ClayCardTone.rose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t('home.bonus_kicker'), style: theme.labelLarge),
          Text(bonus.completed ? s.t('quest.done') : s.t('home.bonus_title'), style: theme.titleMedium),
          if (!bonus.completed) Text(s.t('home.bonus_text', {'size': bonus.questions}), style: theme.bodySmall),
          const SizedBox(height: ClaySpace.s2),
          Text(s.t('home.bonus_start'), style: theme.titleSmall),
        ],
      ),
    );
  }
}

class _Checkpoint extends StatelessWidget {
  const _Checkpoint({required this.s, required this.cp, required this.onOpen});
  final QuestStrings s;
  final HomeCheckpoint cp;
  final void Function(int day)? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final done = cp.solved || (cp.answered && (cp.attemptsLeft ?? 0) == 0);
    final canOpen = !done && (cp.state == 'open' || cp.state == 'late') && cp.day != null && onOpen != null;
    return ClayCard(
      tone: done ? ClayCardTone.soft : ClayCardTone.green,
      onTap: onOpen != null && cp.day != null ? () => onOpen!(cp.day!) : null,
      semanticLabel:
          '${s.t('quest.checkpoint_link')} ${cp.town == null ? '' : s.t('home.unlock', {'town': cp.town!})}. ${done ? s.t('home.done_today') : s.t('home.checkpoint_hint')}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const ExcludeSemantics(child: Icon(ClayIcons.questions, size: 24)),
            const SizedBox(width: ClaySpace.s2),
            Expanded(child: Text(s.t('quest.checkpoint_link'), style: theme.labelLarge)),
            if (cp.kmExpected != null && cp.kmExpected! > 0)
              ClayBadge(label: '${formatKm(cp.kmExpected!)} km', tone: ClayBadgeTone.soft),
          ]),
          if (cp.town != null) Text(s.t('home.unlock', {'town': cp.town!}), style: theme.titleMedium),
          Text(s.t(done ? 'home.done_today' : 'home.checkpoint_hint'), style: theme.bodyMedium),
          if (canOpen) ...[
            const SizedBox(height: ClaySpace.s2),
            Text(s.t('home.open_checkpoint'), style: theme.titleSmall),
          ],
        ],
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.s, required this.board});
  final QuestStrings s;
  final BoardPreview board;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    if (board.rank == null) {
      return ClayCard(
        tone: ClayCardTone.soft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t('home.board_none_title'), style: theme.titleMedium),
            Text(s.t('home.board_none_text'), style: theme.bodySmall),
          ],
        ),
      );
    }
    final m = board.movement;
    final move = m == null
        ? null
        : (m > 0
            ? s.t('home.board_up', {'n': m})
            : (m < 0 ? s.t('home.board_down', {'n': -m}) : s.t('home.board_same')));
    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t('home.board_rank', {'rank': board.rank!}), style: theme.titleLarge),
          if (board.km != null) Text('${formatKm(board.km!)} km', style: theme.bodyMedium),
          if (move != null) Text(move, style: theme.bodySmall),
        ],
      ),
    );
  }
}

class _Links extends StatelessWidget {
  const _Links({required this.session, required this.actions});
  final MsafaraSession session;
  final QuestHomeActions actions;

  @override
  Widget build(BuildContext context) {
    final s = session.strings;
    final links = <(String, VoidCallback)>[
      if (actions.openJourney != null) (s.t('nav.map'), actions.openJourney!),
      if (actions.openBoards != null) (s.t('nav.board'), actions.openBoards!),
      if (actions.openMe != null) (s.t('nav.me'), actions.openMe!),
    ];
    if (links.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: ClaySpace.s2,
      runSpacing: ClaySpace.s2,
      children: [for (final l in links) ClayChip(label: l.$1, onTap: l.$2)],
    );
  }
}
