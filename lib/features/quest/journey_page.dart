import 'package:flutter/material.dart';

import '../../core/design/clay.dart';
import '../../data/models/msafara_journey.dart';
import '../student/load_controller.dart';
import '../student/widgets/load_view.dart';
import 'journey_map.dart';
import 'quest_session.dart';
import 'quest_strings.dart';
import 'quest_widgets.dart';

/// The 92 towns: a map drawn from latitude and longitude, and below it the same towns as a list, which
/// is what a screen reader reads. Towns without coordinates are in the list only.
class JourneyPage extends StatelessWidget {
  const JourneyPage({super.key, required this.session, required this.controller, this.onOpenCheckpoint});
  final MsafaraSession session;
  final LoadController<Journey> controller;

  /// Opens the checkpoint of a day (from a town's sheet). Null hides the button.
  final void Function(int day)? onOpenCheckpoint;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final s = session.strings;
        return QuestScaffold(
          title: s.t('nav.map'),
          body: LoadView<Journey>(
            controller: controller,
            loadingLabel: s.t('states.loading'),
            skeleton: const Padding(
              padding: EdgeInsets.all(ClaySpace.s4),
              child: Column(children: [ClaySkeleton(height: 320), SizedBox(height: 12), ClaySkeleton(height: 80)]),
            ),
            builder: (context, j, banner) => _Content(
              session: session,
              journey: j,
              banner: banner,
              onOpenCheckpoint: onOpenCheckpoint,
            ),
          ),
        );
      },
    );
  }
}

String stateLabel(QuestStrings s, String state) => switch (state) {
      'visited' => s.t('map.state_visited'),
      'today' => s.t('map.state_today'),
      'passed' => s.t('map.state_passed'),
      _ => s.t('map.state_future'),
    };

class _Content extends StatelessWidget {
  const _Content({required this.session, required this.journey, required this.banner, required this.onOpenCheckpoint});
  final MsafaraSession session;
  final Journey journey;
  final Widget? banner;
  final void Function(int day)? onOpenCheckpoint;

  void _openTown(BuildContext context, JourneyTown t) {
    final s = session.strings;
    showClaySheet<void>(
      context: context,
      title: s.t('map.sheet_title'),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(ClaySpace.s4, 0, ClaySpace.s4, ClaySpace.s4),
        child: _TownSheet(
          s: s,
          lang: session.lang,
          town: t,
          onOpenCheckpoint: onOpenCheckpoint == null || t.state == 'future'
              ? null
              : () {
                  Navigator.of(ctx).pop();
                  onOpenCheckpoint!(t.day);
                },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = session.strings;
    final theme = Theme.of(context).textTheme;
    final p = ClayTokens.of(context).palette;
    final mapped = journey.mapped;
    final unmapped = journey.unmapped;
    final current = journey.towns.where((t) => t.current).firstOrNull;

    final colors = JourneyMapColors(
      land: p.primarySurface,
      grid: p.line,
      route: p.primary,
      ahead: p.quiet,
      visited: p.primaryDeep,
      missed: p.danger,
      today: p.primary,
      halo: p.primary.withValues(alpha: 0.25),
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(ClaySpace.s4),
      children: [
        if (banner != null) ...[banner!, const SizedBox(height: ClaySpace.s3)],
        Semantics(header: true, child: Text(s.t('map.title'), style: theme.headlineSmall)),
        const SizedBox(height: ClaySpace.s1),
        Text(s.t('map.hint'), style: theme.bodySmall),
        const SizedBox(height: ClaySpace.s3),
        if (mapped.isEmpty)
          ClayCard(
            tone: ClayCardTone.soft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(s.t('map.empty_title'), style: theme.titleMedium)),
                Text(s.t('map.empty_text'), style: theme.bodyMedium),
              ],
            ),
          )
        else
          // The list below is the accessible version of this picture.
          Semantics(
            container: true,
            label: current == null ? s.t('map.label') : '${s.t('map.label')}. ${s.t('map.town', {'town': current.town, 'day': current.day, 'state': stateLabel(s, current.state)})}',
            child: ExcludeSemantics(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: AspectRatio(
                    aspectRatio: KenyaBounds.aspect,
                    child: LayoutBuilder(
                      builder: (context, box) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) {
                          final t = JourneyMapPainter.nearest(mapped, box.biggest, d.localPosition);
                          if (t != null) _openTown(context, t);
                        },
                        child: CustomPaint(painter: JourneyMapPainter(towns: mapped, colors: colors), size: box.biggest),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (unmapped > 0) ...[
          const SizedBox(height: ClaySpace.s2),
          Text(
            s.t(unmapped == 1 ? 'map.skipped_one' : 'map.skipped_many', {'n': unmapped}),
            style: theme.bodySmall,
          ),
        ],
        const SizedBox(height: ClaySpace.s4),
        Semantics(header: true, child: Text(s.t('map.list_title'), style: theme.titleMedium)),
        const SizedBox(height: ClaySpace.s2),
        for (final t in journey.towns)
          Padding(
            padding: const EdgeInsets.only(bottom: ClaySpace.s2),
            child: ClayListTile(
              title: t.town,
              subtitle: '${s.t('map.day', {'day': t.day})} · ${formatDay(t.date, session.lang)} · ${stateLabel(s, t.state)}',
              selected: t.current,
              leading: ExcludeSemantics(child: Icon(_icon(t.state), size: 20)),
              onTap: () => _openTown(context, t),
            ),
          ),
        const SizedBox(height: ClaySpace.s3),
        Text(s.t('map.credit'), style: theme.bodySmall),
        const SizedBox(height: ClaySpace.s4),
      ],
    );
  }

  static IconData _icon(String state) => switch (state) {
        'visited' => ClayIcons.check,
        'today' => ClayIcons.msafara,
        'passed' => ClayIcons.warning,
        _ => ClayIcons.lock,
      };
}

class _TownSheet extends StatelessWidget {
  const _TownSheet({required this.s, required this.lang, required this.town, required this.onOpenCheckpoint});
  final QuestStrings s;
  final String lang;
  final JourneyTown town;
  final VoidCallback? onOpenCheckpoint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(town.town, style: theme.headlineSmall),
        if (town.county != null) Text(s.t('cp.county', {'county': town.county!}), style: theme.bodyMedium),
        const SizedBox(height: ClaySpace.s2),
        Text('${s.t('map.day', {'day': town.day})} · ${formatDay(town.date, lang)}', style: theme.titleSmall),
        Text(stateLabel(s, town.state), style: theme.bodyMedium),
        if (town.special != null) Text(town.special!, style: theme.labelLarge),
        if (town.state == 'future') ...[
          const SizedBox(height: ClaySpace.s2),
          Text(s.t('map.locked', {'date': formatDay(town.date, lang)}), style: theme.bodyMedium),
        ],
        if (onOpenCheckpoint != null) ...[
          const SizedBox(height: ClaySpace.s3),
          ClayButton(label: s.t('cp.did_you_know'), icon: ClayIcons.chevronRight, onPressed: onOpenCheckpoint),
        ],
      ],
    );
  }
}
