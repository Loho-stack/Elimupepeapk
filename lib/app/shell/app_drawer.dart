import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/design/clay.dart';
import '../../core/auth/user_profile_store.dart';
import '../menu/student_menu.dart';

/// The full menu, grouped like the web sidebar. [onSelect] receives the
/// entry; the shell decides what each target does.
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.groups,
    required this.onSelect,
    this.selectedId,
    this.profile,
  });

  final List<MenuGroup> groups;
  final void Function(MenuEntry entry) onSelect;
  final String? selectedId;

  /// For tests; defaults to the stored display name and avatar.
  final Future<UserProfile>? profile;

  @override
  Widget build(BuildContext context) {
    final p = ClayTokens.of(context).palette;
    final theme = Theme.of(context).textTheme;

    return Drawer(
      backgroundColor: p.card,
      width: 320,
      child: SafeArea(
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: 'Menu',
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                ClaySpace.s3, ClaySpace.s3, ClaySpace.s3, ClaySpace.s5),
            children: [
              _Header(profile: profile),
              const SizedBox(height: ClaySpace.s3),
              for (final g in groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      ClaySpace.s3, ClaySpace.s3, ClaySpace.s3, ClaySpace.s1),
                  child: Semantics(
                    header: true,
                    child: Text(
                      g.label.toUpperCase(),
                      style: theme.labelSmall!.copyWith(
                        color: p.muted,
                        letterSpacing: 0.06 * 14,
                      ),
                    ),
                  ),
                ),
                for (final e in g.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: ClaySpace.s1),
                    child: ClayListTile(
                      title: e.label,
                      selected: e.id == selectedId,
                      leading: Icon(e.icon, size: 22, color: p.primaryDeep),
                      onTap: () => onSelect(e),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.profile});
  final Future<UserProfile>? profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return FutureBuilder<UserProfile>(
      future: profile ?? AppServices.instance.profile.read(),
      builder: (context, snap) {
        // Real data only: nothing is shown until the stored name is read,
        // and an unknown name shows the generic title.
        final name = snap.data?.name;
        final shown = (name == null || name.isEmpty) ? 'Learner' : name;
        return Row(
          children: [
            ClayAvatar(name: shown, size: 48, semanticLabel: 'Your avatar'),
            const SizedBox(width: ClaySpace.s3),
            Expanded(
              child: Text(shown,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleMedium),
            ),
          ],
        );
      },
    );
  }
}
