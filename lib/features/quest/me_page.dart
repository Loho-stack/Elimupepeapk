import 'package:flutter/material.dart';

import '../../core/design/clay.dart';
import '../../data/api_error.dart';
import '../../data/idempotency.dart';
import '../../data/models/msafara_me.dart';
import '../student/load_controller.dart';
import '../student/widgets/load_view.dart';
import 'quest_session.dart';
import 'quest_strings.dart';
import 'quest_widgets.dart';

/// "Me": who the learner is in Elimu Quest, how others see them on the boards (with the hide-my-name
/// switch), the sound switch, the language and a link to the terms.
class MePage extends StatefulWidget {
  const MePage({super.key, required this.session, required this.controller, required this.onOpenTerms});
  final MsafaraSession session;
  final LoadController<MeData> controller;

  /// Opens the terms, read only.
  final VoidCallback onOpenTerms;

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  bool _busySound = false;
  bool _busyHide = false;
  String? _error;

  /// A change the learner asked for is kept as an action until it succeeds, so a retry of the same
  /// change after a dropped connection sends the same key.
  PendingAction? _soundAction;
  PendingAction? _hideAction;
  bool? _soundWanted;
  bool? _hideWanted;

  Future<void> _setSound(MeData d, bool on) async {
    final s = widget.session.strings;
    if (_soundWanted != on || _soundAction == null) {
      _soundAction = PendingAction();
      _soundWanted = on;
    }
    setState(() {
      _busySound = true;
      _error = null;
    });
    try {
      final now = await widget.session.repo.setSound(on, key: _soundAction!.key);
      _soundAction = null;
      _soundWanted = null;
      widget.controller.set(d.copyWith(sound: now));
    } catch (e) {
      if (widget.session.handleError(e)) return;
      if (mounted) setState(() => _error = questErrorText(AppApiError.from(e), s));
    } finally {
      if (mounted) setState(() => _busySound = false);
    }
  }

  Future<void> _setHide(MeData d, bool hide) async {
    final s = widget.session.strings;
    if (_hideWanted != hide || _hideAction == null) {
      _hideAction = PendingAction();
      _hideWanted = hide;
    }
    setState(() {
      _busyHide = true;
      _error = null;
    });
    try {
      final now = await widget.session.repo.setHideName(hide, key: _hideAction!.key);
      _hideAction = null;
      _hideWanted = null;
      widget.controller.set(d.copyWith(hideName: now));
    } catch (e) {
      if (widget.session.handleError(e)) return;
      final err = AppApiError.from(e);
      if (mounted) setState(() => _error = err is NotFoundError ? s.t('me.boards_closed') : questErrorText(err, s));
    } finally {
      if (mounted) setState(() => _busyHide = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        final s = widget.session.strings;
        return QuestScaffold(
          title: s.t('me.title'),
          body: LoadView<MeData>(
            controller: widget.controller,
            loadingLabel: s.t('states.loading'),
            skeleton: const Padding(
              padding: EdgeInsets.all(ClaySpace.s4),
              child: Column(children: [ClaySkeleton(height: 120), SizedBox(height: 12), ClaySkeleton(height: 120)]),
            ),
            builder: (context, d, banner) => _content(context, s, d, banner),
          ),
        );
      },
    );
  }

  Widget _content(BuildContext context, QuestStrings s, MeData d, Widget? banner) {
    final theme = Theme.of(context).textTheme;

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(top: ClaySpace.s2),
          child: Semantics(
            container: true,
            label: '$label: $value',
            child: ExcludeSemantics(
              child: Row(children: [
                Expanded(child: Text(label, style: theme.bodySmall)),
                Flexible(child: Text(value, style: theme.titleSmall, textAlign: TextAlign.end)),
              ]),
            ),
          ),
        );

    final preview = d.hideName ? s.t('me.hidden_row') : (d.boardName ?? s.t('me.none'));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(ClaySpace.s4),
      children: [
        if (banner != null) ...[banner, const SizedBox(height: ClaySpace.s3)],
        ClayCard(
          tone: ClayCardTone.soft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(d.name, style: theme.headlineSmall)),
              row(s.t('me.grade'), d.grade ?? s.t('me.none')),
              row(s.t('me.band'), d.gradeBand ?? s.t('me.no_band')),
              row(s.t('me.county'), d.county ?? s.t('me.none')),
              row(s.t('me.total_km'), formatKm(d.km.total)),
            ],
          ),
        ),
        const SizedBox(height: ClaySpace.s4),
        Semantics(header: true, child: Text(s.t('me.board_kicker'), style: theme.titleMedium)),
        const SizedBox(height: ClaySpace.s2),
        if (!d.boards)
          ClayCard(tone: ClayCardTone.soft, child: Text(s.t('me.boards_closed'), style: theme.bodyMedium))
        else if (d.gradeBand == null)
          ClayCard(
            tone: ClayCardTone.soft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('me.unbanded_title'), style: theme.titleSmall),
                Text(s.t('me.unbanded_text'), style: theme.bodyMedium),
              ],
            ),
          )
        else
          ClayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('me.board_title'), style: theme.titleSmall),
                const SizedBox(height: ClaySpace.s2),
                Semantics(
                  container: true,
                  label: '${s.t('me.preview')}: $preview',
                  child: ExcludeSemantics(
                    child: Row(children: [
                      Text('${s.t('me.preview')}: ', style: theme.bodySmall),
                      Flexible(child: Text(preview, style: theme.titleMedium)),
                    ]),
                  ),
                ),
                const SizedBox(height: ClaySpace.s2),
                Text(
                  d.hideName
                      ? s.t('me.hidden_text')
                      : s.t(d.parentalConsent ? 'me.shown_full' : 'me.shown_initial'),
                  style: theme.bodySmall,
                ),
                Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: d.hideName,
                    onChanged: _busyHide ? null : (v) => _setHide(d, v),
                    title: Text(s.t(d.hideName ? 'board.show_name' : 'board.hide_name'), style: theme.bodyMedium),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: ClaySpace.s3),
        ClayCard(
          child: Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: d.sound,
              onChanged: _busySound ? null : (v) => _setSound(d, v),
              title: Text(s.t('sound.label'), style: theme.titleSmall),
              subtitle: Text(s.t(d.sound ? 'sound.is_on' : 'sound.is_off'), style: theme.bodySmall),
            ),
          ),
        ),
        if (_error != null) QuestError(text: _error!),
        const SizedBox(height: ClaySpace.s3),
        ClayListTile(
          title: s.t('me.terms'),
          subtitle: s.t('me.terms_hint'),
          leading: const ExcludeSemantics(child: Icon(ClayIcons.help)),
          onTap: widget.onOpenTerms,
        ),
        const SizedBox(height: ClaySpace.s4),
        Center(child: QuestLanguageChips(session: widget.session)),
        const SizedBox(height: ClaySpace.s4),
      ],
    );
  }
}
