import 'package:flutter/material.dart';

import '../../core/design/clay.dart';
import '../../data/api_error.dart';
import 'quest_session.dart';
import 'quest_strings.dart';

/// A short date in East Africa Time ("19 Oct 2026", "19 Okt 2026"). The API sends instants with
/// `+03:00`; Dart parses them to UTC, so the offset is added back here.
String formatEatDate(DateTime instant, String lang) {
  final eat = instant.toUtc().add(const Duration(hours: 3));
  const en = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const sw = ['Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', 'Jul', 'Ago', 'Sep', 'Okt', 'Nov', 'Des'];
  final month = (lang == 'sw' ? sw : en)[eat.month - 1];
  return '${eat.day} $month ${eat.year}';
}

/// 10.0 -> "10", 7.5 -> "7.5".
String formatKm(double km) => km == km.roundToDouble() ? km.toInt().toString() : km.toStringAsFixed(1);

/// The page frame of every Elimu Quest screen.
class QuestScaffold extends StatelessWidget {
  const QuestScaffold({super.key, required this.title, required this.body, this.actions = const [], this.leading});
  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: ClayTokens.of(context).palette.page,
        appBar: ClayAppBar(title: title, actions: actions, leading: leading),
        body: SafeArea(top: false, child: body),
      );
}

/// A gentle fade and rise on first build. With reduced motion it is just the child.
class QuestEntrance extends StatelessWidget {
  const QuestEntrance({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = ClayMotion.of(context).entrance;
    if (d == Duration.zero) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: d,
      curve: ClayCurves.out,
      builder: (context, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: c),
      ),
      child: child,
    );
  }
}

/// English / Kiswahili switch for the Elimu Quest copy.
class QuestLanguageChips extends StatelessWidget {
  const QuestLanguageChips({super.key, required this.session});
  final MsafaraSession session;

  @override
  Widget build(BuildContext context) {
    final s = session.strings;
    return Semantics(
      container: true,
      label: s.t('terms.language'),
      child: Wrap(
        spacing: ClaySpace.s2,
        runSpacing: ClaySpace.s2,
        children: [
          ClayChip(label: 'English', selected: session.lang == 'en', onTap: () => session.setLanguage('en')),
          ClayChip(label: 'Kiswahili', selected: session.lang == 'sw', onTap: () => session.setLanguage('sw')),
        ],
      ),
    );
  }
}

/// A one-line message for a failed write, in the learner's language where the web has the words.
String questErrorText(AppApiError e, QuestStrings s) => e is OfflineError ? s.t('states.offline') : e.message;

/// Inline, announced error under a form.
class QuestError extends StatelessWidget {
  const QuestError({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = ClayTokens.of(context).palette;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Padding(
        padding: const EdgeInsets.only(top: ClaySpace.s3),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: p.danger)),
      ),
    );
  }
}
