import 'package:flutter/material.dart';

import '../../core/design/clay.dart';
import '../../data/api_error.dart';
import '../../data/models/msafara_boards.dart';
import '../student/load_controller.dart';
import '../student/widgets/load_view.dart';
import 'quest_session.dart';
import 'quest_strings.dart';
import 'quest_widgets.dart';

/// Daily and weekly leaderboards of the learner's own grade band. Names are shown exactly as the API
/// sends them (already reduced, or hidden by the learner).
class BoardsPage extends StatefulWidget {
  const BoardsPage({super.key, required this.session, required this.daily, required this.weekly});
  final MsafaraSession session;
  final LoadController<Board> daily;
  final LoadController<Board> weekly;

  @override
  State<BoardsPage> createState() => _BoardsPageState();
}

class _BoardsPageState extends State<BoardsPage> {
  int _tab = 0;

  void _select(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    final c = i == 0 ? widget.daily : widget.weekly;
    if (c.data == null && !c.loading) c.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        final s = widget.session.strings;
        final c = _tab == 0 ? widget.daily : widget.weekly;
        return QuestScaffold(
          title: s.t('board.title'),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(ClaySpace.s4, ClaySpace.s3, ClaySpace.s4, ClaySpace.s2),
                child: ClayTabBar(
                  tabs: [ClayTab(label: s.t('board.today')), ClayTab(label: s.t('board.week'))],
                  index: _tab,
                  onChanged: _select,
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: c,
                  builder: (context, _) {
                    // The boards switched off: a kind note, not an error page.
                    if (c.data == null && c.error is NotFoundError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(ClaySpace.s4),
                          child: ClayEmptyState(title: s.t('board.closed'), icon: ClayIcons.leaderboard),
                        ),
                      );
                    }
                    return LoadView<Board>(
                      controller: c,
                      loadingLabel: s.t('states.loading'),
                      skeleton: const Padding(
                        padding: EdgeInsets.all(ClaySpace.s4),
                        child: Column(children: [ClaySkeleton(height: 64), SizedBox(height: 12), ClaySkeleton(height: 64)]),
                      ),
                      builder: (context, b, banner) => BoardView(s: s, board: b, banner: banner),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One board: its rows and the learner's own place.
class BoardView extends StatelessWidget {
  const BoardView({super.key, required this.s, required this.board, this.banner});
  final QuestStrings s;
  final Board board;
  final Widget? banner;

  String _since() => s.t(board.weekly ? 'board.since_week' : 'board.since_day');

  String? movementText(int? m) {
    if (m == null) return null;
    if (m > 0) return s.t('board.up', {'n': m, 'since': _since()});
    if (m < 0) return s.t('board.down', {'n': -m, 'since': _since()});
    return s.t('board.same', {'since': _since()});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final suffix = board.weekly ? 'week' : 'day';

    final children = <Widget>[
      if (banner != null) ...[banner!, const SizedBox(height: ClaySpace.s3)],
    ];

    if (!board.open) {
      children.add(_Note(title: null, text: s.t('board.opens_day_1')));
    } else if (board.gradeBand == null) {
      children.add(_Note(title: s.t('board.unbanded_title'), text: s.t('board.unbanded')));
    } else {
      if (board.rows.isEmpty) {
        children.add(_Note(title: s.t('board.empty'), text: s.t('board.empty_$suffix')));
      }
      for (final r in board.rows) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: ClaySpace.s2),
          child: _RowTile(s: s, row: r, movement: movementText(r.movement)),
        ));
      }
      if (!board.meInRows) {
        children.add(const SizedBox(height: ClaySpace.s3));
        children.add(_MeCard(s: s, board: board, movement: movementText(board.me?.movement)));
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(ClaySpace.s4),
      children: [
        Text(board.periodKey, style: theme.labelMedium),
        const SizedBox(height: ClaySpace.s2),
        ...children,
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.title, required this.text});
  final String? title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return ClayCard(
      tone: ClayCardTone.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) Semantics(header: true, child: Text(title!, style: theme.titleMedium)),
          Text(text, style: theme.bodyMedium),
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.s, required this.row, required this.movement});
  final QuestStrings s;
  final BoardRow row;
  final String? movement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final detail = [if (row.grade != null) row.grade!, if (row.county != null) row.county!].join(', ');
    final label = [
      s.t('board.place', {'rank': row.rank}),
      row.displayName,
      if (row.me) s.t('board.you'),
      if (detail.isNotEmpty) detail,
      '${formatKm(row.km)} km',
      if (movement != null) movement!,
    ].join('. ');

    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: ClayCard(
          tight: true,
          tone: row.me ? ClayCardTone.green : ClayCardTone.plain,
          child: Row(
            children: [
              SizedBox(width: 40, child: Text('${row.rank}', style: theme.titleLarge, textAlign: TextAlign.center)),
              const SizedBox(width: ClaySpace.s2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(child: Text(row.displayName, style: theme.titleSmall)),
                      if (row.me) ...[
                        const SizedBox(width: ClaySpace.s2),
                        ClayBadge(label: s.t('board.you'), tone: ClayBadgeTone.solid),
                      ],
                    ]),
                    if (detail.isNotEmpty) Text(detail, style: theme.bodySmall),
                    if (movement != null) Text(movement!, style: theme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: ClaySpace.s2),
              Text('${formatKm(row.km)} km', style: theme.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// The learner's place when it is not in the top rows: hidden, not yet eligible, or no kilometres.
class _MeCard extends StatelessWidget {
  const _MeCard({required this.s, required this.board, required this.movement});
  final QuestStrings s;
  final Board board;
  final String? movement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final me = board.me;
    final suffix = board.weekly ? 'week' : 'day';

    final String title;
    final String text;
    if (me == null) {
      title = s.t('board.keep_travelling');
      text = s.t('board.no_km_$suffix');
    } else if (me.hidden) {
      title = me.rank == null ? s.t('board.you') : s.t('board.place', {'rank': me.rank!});
      text = s.t('board.hidden_note');
    } else if (me.rank == null) {
      title = s.t('board.keep_travelling');
      text = s.t('board.need_$suffix');
    } else {
      title = s.t('board.place', {'rank': me.rank!});
      text = s.t('board.shown_note');
    }

    return Semantics(
      container: true,
      child: ClayCard(
        tone: ClayCardTone.green,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Semantics(header: true, child: Text(title, style: theme.titleMedium))),
              if (me != null && me.km > 0) Text('${formatKm(me.km)} km', style: theme.titleSmall),
            ]),
            if (me?.displayName != null) Text(me!.displayName!, style: theme.bodyMedium),
            Text(text, style: theme.bodySmall),
            if (movement != null) Text(movement!, style: theme.bodySmall),
          ],
        ),
      ),
    );
  }
}
