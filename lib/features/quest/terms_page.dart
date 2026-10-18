import 'package:flutter/material.dart';

import '../../core/design/clay.dart';
import '../../data/api_error.dart';
import '../../data/idempotency.dart';
import '../../data/models/msafara.dart';
import '../student/load_controller.dart';
import '../student/widgets/load_view.dart';
import 'quest_session.dart';
import 'quest_widgets.dart';

/// The Elimu Quest terms. The text is DP-approved and comes only from `GET /msafara/terms`; this page
/// adds the two attestation boxes the server sends and posts both as `true`.
class TermsPage extends StatefulWidget {
  const TermsPage({super.key, required this.session, this.onDone, this.showBar = true});
  final MsafaraSession session;

  /// Called after the terms were accepted and the state refreshed.
  final VoidCallback? onDone;

  /// False when the page sits inside another scaffold.
  final bool showBar;

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  late final LoadController<Terms> _terms = LoadController(() => widget.session.repo.terms(lang: widget.session.lang))
    ..load();
  final Map<String, bool> _ticked = {};
  PendingAction _action = PendingAction();
  bool _busy = false;
  String? _error;
  late String _lang;

  @override
  void initState() {
    super.initState();
    _lang = widget.session.lang;
    widget.session.addListener(_onSession);
  }

  void _onSession() {
    // The language chips changed the session language: fetch the terms in it.
    if (widget.session.lang != _lang) {
      _lang = widget.session.lang;
      _terms.load();
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    _terms.dispose();
    super.dispose();
  }

  Future<void> _accept(Terms t) async {
    final s = widget.session.strings;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.repo.acceptTerms(key: _action.key);
      _action = PendingAction();
      await widget.session.refresh();
      if (mounted) widget.onDone?.call();
    } catch (e) {
      if (widget.session.handleError(e)) {
        if (mounted) widget.onDone?.call();
        return;
      }
      // The same key stays for the retry: the server runs the action once.
      if (mounted) setState(() => _error = questErrorText(AppApiError.from(e), s));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        final s = widget.session.strings;
        return LoadView<Terms>(
          controller: _terms,
          loadingLabel: s.t('states.loading'),
          skeleton: const Padding(
            padding: EdgeInsets.all(ClaySpace.s4),
            child: Column(children: [ClaySkeleton(height: 28), SizedBox(height: 12), ClaySkeleton(height: 120)]),
          ),
          builder: (context, t, banner) => _content(context, t, banner),
        );
      },
    );
    if (!widget.showBar) return body;
    return QuestScaffold(title: widget.session.strings.t('title'), body: body);
  }

  Widget _content(BuildContext context, Terms t, Widget? banner) {
    final s = widget.session.strings;
    final theme = Theme.of(context).textTheme;
    final allTicked = t.attestations.every((a) => _ticked[a.key] == true);

    return ListView(
      padding: const EdgeInsets.all(ClaySpace.s4),
      children: [
        if (banner != null) ...[banner, const SizedBox(height: ClaySpace.s3)],
        QuestLanguageChips(session: widget.session),
        const SizedBox(height: ClaySpace.s4),
        Semantics(header: true, child: Text(t.title, style: theme.headlineSmall)),
        const SizedBox(height: ClaySpace.s2),
        Text(t.intro, style: theme.bodyLarge),
        for (final section in t.sections) ...[
          const SizedBox(height: ClaySpace.s4),
          Semantics(header: true, child: Text(section.heading, style: theme.titleMedium)),
          const SizedBox(height: ClaySpace.s1),
          for (final item in section.items)
            Padding(
              padding: const EdgeInsets.only(top: ClaySpace.s1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ExcludeSemantics(child: Text('•  ')),
                  Expanded(child: Text(item, style: theme.bodyMedium)),
                ],
              ),
            ),
        ],
        const SizedBox(height: ClaySpace.s5),
        ClayCard(
          tone: ClayCardTone.soft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(s.t('terms.parent_note_title'), style: theme.titleSmall)),
              for (final a in t.attestations)
                // The card paints its own background; ListTile needs a Material of its own to draw on.
                Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _ticked[a.key] ?? false,
                    onChanged: _busy ? null : (v) => setState(() => _ticked[a.key] = v ?? false),
                    title: Text(a.label, style: theme.bodyMedium),
                    subtitle: a.note == null ? null : Text(a.note!, style: theme.bodySmall),
                  ),
                ),
            ],
          ),
        ),
        if (!allTicked)
          Padding(
            padding: const EdgeInsets.only(top: ClaySpace.s2),
            child: Text(s.t('terms.accept_needed'), style: theme.bodySmall),
          ),
        if (_error != null) QuestError(text: _error!),
        const SizedBox(height: ClaySpace.s4),
        ClayButton(
          label: t.continueLabel,
          icon: ClayIcons.check,
          loading: _busy,
          onPressed: allTicked && !_busy ? () => _accept(t) : null,
        ),
      ],
    );
  }
}
