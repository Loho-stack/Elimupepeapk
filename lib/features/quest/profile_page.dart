import 'package:flutter/material.dart';

import '../../core/design/clay.dart';
import '../../data/api_error.dart';
import '../../data/idempotency.dart';
import '../../data/models/msafara.dart';
import '../student/load_controller.dart';
import '../student/widgets/load_view.dart';
import 'quest_session.dart';
import 'quest_widgets.dart';

/// Grade and county, for the fields the server says are missing. A field the account already has is
/// shown but cannot be changed (the server ignores it).
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.session, this.onDone, this.showBar = true});
  final MsafaraSession session;
  final VoidCallback? onDone;
  final bool showBar;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final LoadController<ProfileForm> _form = LoadController(widget.session.repo.profile)..load();
  String? _grade;
  String? _county;
  PendingAction _action = PendingAction();
  bool _busy = false;
  String? _error;
  bool _fieldErrorGrade = false;
  bool _fieldErrorCounty = false;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _pick({
    required String title,
    required List<(String key, String label)> options,
    required String? current,
    required ValueChanged<String> onPick,
  }) async {
    final picked = await showClaySheet<String>(
      context: context,
      title: title,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            ClayListTile(
              title: o.$2,
              selected: o.$1 == current,
              trailing: o.$1 == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(ctx).pop(o.$1),
            ),
        ],
      ),
    );
    if (picked != null) onPick(picked);
  }

  Future<void> _save(ProfileForm f) async {
    final s = widget.session.strings;
    setState(() {
      _busy = true;
      _error = null;
      _fieldErrorGrade = false;
      _fieldErrorCounty = false;
    });
    try {
      await widget.session.repo.saveProfile(
        grade: f.needsGrade ? _grade : null,
        county: f.needsCounty ? _county : null,
        key: _action.key,
      );
      _action = PendingAction();
      await widget.session.refresh();
      if (mounted) widget.onDone?.call();
    } catch (e) {
      if (widget.session.handleError(e)) {
        if (mounted) widget.onDone?.call();
        return;
      }
      final err = AppApiError.from(e);
      if (mounted) {
        setState(() {
          if (err is ValidationError) {
            _fieldErrorGrade = err.has('grade');
            _fieldErrorCounty = err.has('county');
            // The server refused this body; a corrected body is a new action.
            _action = PendingAction();
          }
          _error = questErrorText(err, s);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) => LoadView<ProfileForm>(
        controller: _form,
        loadingLabel: widget.session.strings.t('states.loading'),
        skeleton: const Padding(
          padding: EdgeInsets.all(ClaySpace.s4),
          child: Column(children: [ClaySkeleton(height: 28), SizedBox(height: 12), ClaySkeleton(height: 56)]),
        ),
        builder: (context, f, banner) => _content(context, f, banner),
      ),
    );
    if (!widget.showBar) return body;
    return QuestScaffold(title: widget.session.strings.t('title'), body: body);
  }

  Widget _content(BuildContext context, ProfileForm f, Widget? banner) {
    final s = widget.session.strings;
    final theme = Theme.of(context).textTheme;
    final gradeKey = f.needsGrade ? _grade : f.grade;
    final gradeLabel = f.grades.where((g) => g.key == gradeKey).map((g) => g.label).firstOrNull ?? gradeKey;
    final county = f.needsCounty ? _county : f.county;
    final ready = (!f.needsGrade || _grade != null) && (!f.needsCounty || _county != null);

    Widget field({
      required String label,
      required String? value,
      required bool editable,
      required bool invalid,
      required VoidCallback onTap,
    }) {
      final shown = value ?? s.t('profile.choose');
      return ClayCard(
        onTap: editable && !_busy ? onTap : null,
        semanticLabel: '$label, $shown',
        tone: editable ? ClayCardTone.plain : ClayCardTone.soft,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.labelLarge?.copyWith(color: invalid ? ClayTokens.of(context).palette.danger : null)),
                  Text(shown, style: theme.titleMedium),
                ],
              ),
            ),
            if (editable) const ExcludeSemantics(child: Icon(ClayIcons.chevronRight)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(ClaySpace.s4),
      children: [
        if (banner != null) ...[banner, const SizedBox(height: ClaySpace.s3)],
        QuestEntrance(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(s.t('profile.title'), style: theme.headlineSmall)),
              const SizedBox(height: ClaySpace.s2),
              Text(s.t('boarding.profile_text'), style: theme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: ClaySpace.s4),
        field(
          label: s.t('profile.grade'),
          value: gradeLabel,
          editable: f.needsGrade,
          invalid: _fieldErrorGrade,
          onTap: () => _pick(
            title: s.t('profile.grade'),
            options: [for (final g in f.grades) (g.key, g.label)],
            current: _grade,
            onPick: (k) => setState(() => _grade = k),
          ),
        ),
        const SizedBox(height: ClaySpace.s3),
        field(
          label: s.t('profile.county'),
          value: county,
          editable: f.needsCounty,
          invalid: _fieldErrorCounty,
          onTap: () => _pick(
            title: s.t('profile.county'),
            options: [for (final c in f.counties) (c, c)],
            current: _county,
            onPick: (c) => setState(() => _county = c),
          ),
        ),
        if (_error != null) QuestError(text: _error!),
        const SizedBox(height: ClaySpace.s5),
        ClayButton(
          label: s.t('profile.start'),
          icon: ClayIcons.check,
          loading: _busy,
          onPressed: ready && !_busy ? () => _save(f) : null,
        ),
      ],
    );
  }
}
