import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/a11y/a11y_panel.dart';
import '../../core/design/clay.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/update_checker.dart';
import '../menu/student_menu.dart';
import '../session_controller.dart';
import 'app_drawer.dart';
import 'clay_bottom_bar.dart';

/// Lets a tab body open the drawer without owning the Scaffold.
class ShellActions extends InheritedWidget {
  const ShellActions({super.key, required this.openMenu, required super.child});
  final VoidCallback openMenu;

  static ShellActions? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellActions>();

  @override
  bool updateShouldNotify(ShellActions old) => false;
}

/// The student's frame: bottom bar for the five most used places and a drawer
/// with the full menu. Tab bodies are the existing screens; they keep their
/// own app bars until Phase 4 rebuilds them.
///
/// Bottom bar (approved): Home, Learn, Elimu Quest (centre), My Library, More.
class StudentShell extends StatefulWidget {
  const StudentShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const items = [
    ClayNavItem(label: 'Home', icon: ClayIcons.home),
    ClayNavItem(label: 'Learn', icon: ClayIcons.learn),
    ClayNavItem(label: 'Elimu Quest', icon: ClayIcons.msafara),
    ClayNavItem(label: 'My Library', icon: ClayIcons.library),
  ];

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  final GlobalKey<ScaffoldState> _scaffold = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    // Play in-app update, or the server check for sideloaded installs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateChecker.run(context);
    });
  }

  int get _index => widget.navigationShell.currentIndex;

  void _openMenu() => _scaffold.currentState?.openDrawer();

  void _goBranch(int i) =>
      widget.navigationShell.goBranch(i, initialLocation: i == _index);

  String? get _selectedId => switch (_index) {
        StudentMenu.homeBranch => 'dashboard',
        StudentMenu.learnBranch => 'learning_areas',
        StudentMenu.questBranch => 'elimu_quest',
        StudentMenu.libraryBranch => 'library',
        _ => null,
      };

  Future<void> _select(MenuEntry entry) async {
    Navigator.of(context).pop(); // close the drawer
    final router = GoRouter.of(context);
    switch (entry.target) {
      case BranchTarget(:final index):
        _goBranch(index);
      case RouteTarget(:final location):
        router.push(location);
      case WebTarget(:final path):
        router.push('/student/web',
            extra: WebArgs(title: entry.label, path: path));
      case PublicWebTarget(:final path):
        router.push('/student/page',
            extra: WebArgs(title: entry.label, path: path));
      case ActionTarget(:final action):
        switch (action) {
          case MenuAction.accessibility:
            showA11yPanel(context);
          case MenuAction.logout:
            await _confirmLogout();
        }
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await confirmLogout(context);
    if (!ok || !mounted) return;
    await AuthService.instance.logout();
    if (mounted) context.leaveSession();
  }

  @override
  Widget build(BuildContext context) {
    Widget scaffold = ShellActions(
      openMenu: _openMenu,
      child: Scaffold(
        key: _scaffold,
        drawer: AppDrawer(
          groups: StudentMenu.groups,
          selectedId: _selectedId,
          onSelect: _select,
        ),
        body: widget.navigationShell,
        bottomNavigationBar: ClayBottomBar(
          items: StudentShell.items,
          currentIndex: _index,
          centerIndex: StudentMenu.questBranch,
          onTap: _goBranch,
          onMore: _openMenu,
        ),
      ),
    );

    // Back goes Home first, then leaves the app. The Elimu Quest tab is a
    // webview that handles back through its own history, then calls
    // onRootBack (see the router), so it is left alone here.
    if (_index != StudentMenu.questBranch) {
      scaffold = PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_scaffold.currentState?.isDrawerOpen ?? false) {
            Navigator.of(context).pop();
          } else if (_index != StudentMenu.homeBranch) {
            _goBranch(StudentMenu.homeBranch);
          } else {
            SystemNavigator.pop();
          }
        },
        child: scaffold,
      );
    }
    return scaffold;
  }
}

/// What a webview route needs. Passed as `extra`, so the page path never
/// appears in a route name or analytics.
class WebArgs {
  const WebArgs({required this.title, required this.path});
  final String title;
  final String path;
}

/// Asks before logging out; true when confirmed.
Future<bool> confirmLogout(BuildContext context) async {
  final result = await showClaySheet<bool>(
    context: context,
    title: 'Log out?',
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'You will need your Student ID and password to sign in again.',
          style: Theme.of(ctx).textTheme.bodyLarge,
        ),
        const SizedBox(height: ClaySpace.s4),
        ClayButton(
          label: 'Log out',
          icon: ClayIcons.logout,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
        const SizedBox(height: ClaySpace.s2),
        ClayButton(
          label: 'Stay signed in',
          variant: ClayButtonVariant.secondary,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
      ],
    ),
  );
  return result == true;
}

/// Frame for parent and teacher: their existing dashboards navigate onward
/// themselves, so the shell adds the drawer (accessibility, log out) and a
/// menu button.
class RoleShell extends StatefulWidget {
  const RoleShell({
    super.key,
    required this.child,
    required this.groups,
    this.onSelectExtra,
  });

  final Widget child;
  final List<MenuGroup> groups;

  /// Handles route and web targets (the shell handles actions).
  final void Function(BuildContext context, MenuEntry entry)? onSelectExtra;

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  final GlobalKey<ScaffoldState> _scaffold = GlobalKey<ScaffoldState>();

  Future<void> _select(MenuEntry entry) async {
    Navigator.of(context).pop();
    final target = entry.target;
    if (target is ActionTarget) {
      if (target.action == MenuAction.accessibility) {
        showA11yPanel(context);
      } else if (await confirmLogout(context)) {
        await AuthService.instance.logout();
        if (mounted) context.leaveSession();
      }
      return;
    }
    if (mounted) widget.onSelectExtra?.call(context, entry);
  }

  @override
  Widget build(BuildContext context) {
    return ShellActions(
      openMenu: () => _scaffold.currentState?.openDrawer(),
      child: Scaffold(
        key: _scaffold,
        drawer: AppDrawer(groups: widget.groups, onSelect: _select),
        body: Stack(
          children: [
            Positioned.fill(child: widget.child),
            Positioned(
              left: ClaySpace.s2,
              bottom: ClaySpace.s2,
              child: SafeArea(
                child: ClaySurface(
                  radius: ClayRadii.pill,
                  child: ClayIconButton(
                    icon: ClayIcons.menu,
                    label: 'Open menu',
                    onPressed: () => _scaffold.currentState?.openDrawer(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Parent menu: what the existing parent screens offer today.
abstract final class ParentMenu {
  static const groups = [
    MenuGroup('Parent', [
      MenuEntry(
        id: 'parent_home',
        label: 'Home',
        icon: ClayIcons.home,
        target: RouteTarget('/parent'),
        verdict: Verdict.native,
      ),
      MenuEntry(
        id: 'parent_messages',
        label: 'Messages',
        icon: ClayIcons.bell,
        target: RouteTarget('/parent/messages'),
        verdict: Verdict.native,
      ),
    ]),
    MenuGroup('Account', [
      MenuEntry(
        id: 'accessibility',
        label: 'Accessibility',
        icon: ClayIcons.accessibility,
        target: ActionTarget(MenuAction.accessibility),
        verdict: Verdict.native,
      ),
      MenuEntry(
        id: 'logout',
        label: 'Log out',
        icon: ClayIcons.logout,
        target: ActionTarget(MenuAction.logout),
        verdict: Verdict.native,
      ),
    ]),
  ];
}

abstract final class TeacherMenu {
  static const groups = [
    MenuGroup('Teacher', [
      MenuEntry(
        id: 'teacher_home',
        label: 'Home',
        icon: ClayIcons.chalkboard,
        target: RouteTarget('/teacher'),
        verdict: Verdict.native,
      ),
    ]),
    MenuGroup('Account', [
      MenuEntry(
        id: 'accessibility',
        label: 'Accessibility',
        icon: ClayIcons.accessibility,
        target: ActionTarget(MenuAction.accessibility),
        verdict: Verdict.native,
      ),
      MenuEntry(
        id: 'logout',
        label: 'Log out',
        icon: ClayIcons.logout,
        target: ActionTarget(MenuAction.logout),
        verdict: Verdict.native,
      ),
    ]),
  ];
}
