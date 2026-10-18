import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/design/clay.dart';
import '../student/widgets/adaptive.dart';
import 'quest_session.dart';
import 'quest_widgets.dart';

/// Before Day 1: a live countdown to `opens_at` and the "reserve your seat" steps.
/// The seconds come from the server (`seconds_to_start` of the last state plus the time since,
/// measured on a monotonic clock), never from the phone's date.
class CountdownPage extends StatefulWidget {
  const CountdownPage({
    super.key,
    required this.session,
    required this.onReserve,
    required this.onProfile,
    this.tick = const Duration(seconds: 1),
  });

  final MsafaraSession session;
  final VoidCallback onReserve;
  final VoidCallback onProfile;
  final Duration tick;

  @override
  State<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends State<CountdownPage> {
  Timer? _timer;
  int _ticks = 0;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.tick, (_) => _onTick());
  }

  void _onTick() {
    if (!mounted) return;
    _ticks++;
    final left = widget.session.secondsToStart;
    if (left == 0 && !_opened) {
      // The journey starts: ask the server what the learner sees now.
      _opened = true;
      widget.session.refresh();
    } else if (_ticks % 60 == 0) {
      // Keeps the seat count fresh and corrects any drift.
      widget.session.refresh();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final s = session.strings;
    final state = session.state!;
    final left = session.secondsToStart ?? 0;
    final d = left ~/ 86400;
    final h = (left % 86400) ~/ 3600;
    final m = (left % 3600) ~/ 60;
    final sec = left % 60;
    final date = state.opensAt == null ? '' : formatEatDate(state.opensAt!, session.lang);
    final theme = Theme.of(context).textTheme;

    final units = [
      _Unit('$d', s.t('boarding.days')),
      _Unit(h.toString().padLeft(2, '0'), s.t('boarding.hours')),
      _Unit(m.toString().padLeft(2, '0'), s.t('boarding.minutes')),
      _Unit(sec.toString().padLeft(2, '0'), s.t('boarding.seconds')),
    ];

    return ListView(
      padding: const EdgeInsets.all(ClaySpace.s4),
      children: [
        QuestEntrance(
          child: ClayCard(
            tone: ClayCardTone.soft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(child: Icon(ClayIcons.msafara, size: 32)),
                const SizedBox(height: ClaySpace.s2),
                Text(s.t('boarding.kicker'), style: theme.labelLarge),
                Semantics(header: true, child: Text(s.t('boarding.title'), style: theme.headlineSmall)),
              ],
            ),
          ),
        ),
        const SizedBox(height: ClaySpace.s4),
        if (left > 0)
          // One label that changes once a minute, so a screen reader is not read every second.
          Semantics(
            container: true,
            label: s.t('boarding.countdown_label', {'d': d, 'h': h, 'm': m}),
            child: ExcludeSemantics(child: _Clock(units: units)),
          )
        else
          Semantics(
            liveRegion: true,
            child: ClayCard(child: Text(s.t('boarding.starting'), style: theme.titleMedium)),
          ),
        if (date.isNotEmpty) ...[
          const SizedBox(height: ClaySpace.s3),
          Center(child: Text(s.t('boarding.leaves', {'date': date}), style: theme.bodyMedium, textAlign: TextAlign.center)),
        ],
        const SizedBox(height: ClaySpace.s4),
        _Seat(session: session, date: date, onReserve: widget.onReserve, onProfile: widget.onProfile),
        const SizedBox(height: ClaySpace.s4),
        Center(
          child: Text(s.seats(state.seatsReserved), style: theme.bodyMedium, textAlign: TextAlign.center),
        ),
        const SizedBox(height: ClaySpace.s4),
        Center(child: QuestLanguageChips(session: session)),
      ],
    );
  }
}

class _Unit {
  const _Unit(this.value, this.label);
  final String value;
  final String label;
}

class _Clock extends StatelessWidget {
  const _Clock({required this.units});
  final List<_Unit> units;

  @override
  Widget build(BuildContext context) {
    Widget box(_Unit u) => ClayCard(
          tight: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(u.value, style: Theme.of(context).textTheme.headlineMedium),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(u.label, style: Theme.of(context).textTheme.bodySmall, maxLines: 1),
              ),
            ],
          ),
        );

    // At large text two rows of two keep every label whole.
    if (largeText(context)) {
      return Column(
        children: [
          for (var r = 0; r < 4; r += 2) ...[
            if (r > 0) const SizedBox(height: ClaySpace.s2),
            Row(children: [
              Expanded(child: box(units[r])),
              const SizedBox(width: ClaySpace.s2),
              Expanded(child: box(units[r + 1])),
            ]),
          ],
        ],
      );
    }
    return Row(children: [
      for (var i = 0; i < units.length; i++) ...[
        if (i > 0) const SizedBox(width: ClaySpace.s2),
        Expanded(child: box(units[i])),
      ],
    ]);
  }
}

class _Seat extends StatelessWidget {
  const _Seat({required this.session, required this.date, required this.onReserve, required this.onProfile});
  final MsafaraSession session;
  final String date;
  final VoidCallback onReserve;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final s = session.strings;
    final theme = Theme.of(context).textTheme;
    final seat = session.state!.seat;

    final (title, text, label, action) = switch (seat) {
      'open' => (s.t('boarding.reserve'), s.t('boarding.reserve_text'), s.t('boarding.reserve'), onReserve),
      'profile' => (
          s.t('boarding.profile_title'),
          s.t('boarding.profile_text'),
          s.t('boarding.profile'),
          onProfile
        ),
      _ => (s.t('boarding.reserved'), s.t('boarding.reserved_text', {'date': date}), null, null),
    };

    return QuestEntrance(
      child: ClayCard(
        tone: seat == 'reserved' ? ClayCardTone.green : ClayCardTone.plain,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t('boarding.ticket_kicker'), style: theme.labelLarge),
            const SizedBox(height: ClaySpace.s1),
            Semantics(header: true, child: Text(title, style: theme.titleLarge)),
            const SizedBox(height: ClaySpace.s2),
            Text(text, style: theme.bodyMedium),
            if (label != null) ...[
              const SizedBox(height: ClaySpace.s4),
              ClayButton(label: label, icon: ClayIcons.chevronRight, onPressed: action),
            ],
          ],
        ),
      ),
    );
  }
}
