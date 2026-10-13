import 'package:flutter/widgets.dart';

import '../../core/design/icons.dart';

/// Where a menu entry goes.
sealed class MenuTarget {
  const MenuTarget();
}

/// A tab of the student shell (0 Home, 1 Learn, 2 Elimu Quest, 3 Library).
class BranchTarget extends MenuTarget {
  const BranchTarget(this.index);
  final int index;
}

/// A full-screen app route.
class RouteTarget extends MenuTarget {
  const RouteTarget(this.location);
  final String location;
}

/// A web page opened signed in through the SSO wrapper.
class WebTarget extends MenuTarget {
  const WebTarget(this.path);
  final String path;
}

/// A public web page (no sign-in).
class PublicWebTarget extends MenuTarget {
  const PublicWebTarget(this.path);
  final String path;
}

enum MenuAction { accessibility, logout }

class ActionTarget extends MenuTarget {
  const ActionTarget(this.action);
  final MenuAction action;
}

/// Verdict from docs/api/STUDENT_RESOURCE_MAP.md.
enum Verdict { native, webview }

@immutable
class MenuEntry {
  const MenuEntry({
    required this.id,
    required this.label,
    required this.icon,
    required this.target,
    required this.verdict,
    this.note,
  });

  final String id;
  final String label;
  final IconData icon;
  final MenuTarget target;
  final Verdict verdict;

  /// Why this entry goes where it does today (Phase 3 interim targets).
  final String? note;
}

@immutable
class MenuGroup {
  const MenuGroup(this.label, this.entries);
  final String label;
  final List<MenuEntry> entries;
}

/// The student menu, mirroring the web sidebar groups
/// (`_sidebar_student.blade.php`). Entries whose map verdict is WEBVIEW open
/// the SSO wrapper. NATIVE entries without a native screen yet (rewards,
/// achievements, questions) open the matching web page in the same wrapper
/// until Phase 4 replaces them.
abstract final class StudentMenu {
  static const int homeBranch = 0;
  static const int learnBranch = 1;
  static const int questBranch = 2;
  static const int libraryBranch = 3;

  static const String coinsBase = '/student-dashboard/loho-coins';

  static const List<MenuGroup> groups = [
    MenuGroup('Home', [
      MenuEntry(
        id: 'dashboard',
        label: 'Dashboard',
        icon: ClayIcons.dashboard,
        target: BranchTarget(homeBranch),
        verdict: Verdict.native,
      ),
      MenuEntry(
        id: 'msafara',
        label: 'Msafara',
        icon: ClayIcons.msafara,
        target: WebTarget('/msafara'),
        verdict: Verdict.webview,
        note: 'Native in a later phase; needs consent endpoints first.',
      ),
    ]),
    MenuGroup('Learn', [
      MenuEntry(
        id: 'learning_areas',
        label: 'My Learning Areas',
        icon: ClayIcons.learn,
        target: BranchTarget(learnBranch),
        verdict: Verdict.native,
      ),
      MenuEntry(
        id: 'interactive_content',
        label: 'Interactive Content',
        icon: ClayIcons.interactive,
        target: WebTarget('/my-interactive-content'),
        verdict: Verdict.webview,
      ),
      MenuEntry(
        id: 'library',
        label: 'My Library',
        icon: ClayIcons.library,
        target: BranchTarget(libraryBranch),
        verdict: Verdict.native,
      ),
      MenuEntry(
        id: 'dals',
        label: 'Dals Learning',
        icon: ClayIcons.dals,
        target: WebTarget('/dals'),
        verdict: Verdict.webview,
      ),
      MenuEntry(
        id: 'esoma',
        label: 'Esoma Kids',
        icon: ClayIcons.esoma,
        target: WebTarget('/esoma'),
        verdict: Verdict.webview,
      ),
      MenuEntry(
        id: 'loho_tv',
        label: 'Loho-TV',
        icon: ClayIcons.tv,
        target: WebTarget('/loho-tv'),
        verdict: Verdict.webview,
      ),
      MenuEntry(
        id: 'live_classes',
        label: 'Live Classes',
        icon: ClayIcons.liveClass,
        target: WebTarget('/my-classes'),
        verdict: Verdict.native,
        note: 'Native list in Phase 4; web page until then.',
      ),
    ]),
    MenuGroup('Practice', [
      MenuEntry(
        id: 'virtual_labs',
        label: 'Virtual Labs',
        icon: ClayIcons.labs,
        target: WebTarget('/phet'),
        verdict: Verdict.webview,
      ),
      MenuEntry(
        id: 'elimu_quest',
        label: 'Elimu Quest',
        icon: ClayIcons.quest,
        target: BranchTarget(questBranch),
        verdict: Verdict.webview,
        note: 'The centre tab hosts /my-quizzes in the SSO wrapper.',
      ),
      MenuEntry(
        id: 'games',
        label: 'Games',
        icon: ClayIcons.games,
        target: WebTarget('/games'),
        verdict: Verdict.webview,
        note: 'The web Games hub (the old app item opened /elimu).',
      ),
    ]),
    MenuGroup('Progress', [
      MenuEntry(
        id: 'leaderboard',
        label: 'Leaderboard',
        icon: ClayIcons.leaderboard,
        target: WebTarget('/leaderboard/embed'),
        verdict: Verdict.webview,
      ),
      MenuEntry(
        id: 'gradebook',
        label: 'My Gradebook',
        icon: ClayIcons.gradebook,
        target: WebTarget('/student/gradebook'),
        verdict: Verdict.native,
        note: 'Native after the server refactor; web page until then.',
      ),
      MenuEntry(
        id: 'achievements',
        label: 'Achievements',
        icon: ClayIcons.achievements,
        target: WebTarget('$coinsBase/hub/achievements'),
        verdict: Verdict.native,
        note: 'Needs new API endpoints; web page until Phase 4.',
      ),
      MenuEntry(
        id: 'my_questions',
        label: 'My Questions',
        icon: ClayIcons.questions,
        target: WebTarget('/my-qa'),
        verdict: Verdict.native,
        note: 'Needs new API endpoints; web page until Phase 4.',
      ),
      MenuEntry(
        id: 'quest_hub',
        label: 'Quest Hub',
        icon: ClayIcons.quest,
        target: RouteTarget('/student/quest-hub'),
        verdict: Verdict.native,
        note: 'The existing native quest summary, kept until Phase 4.',
      ),
    ]),
    MenuGroup('Rewards', [
      MenuEntry(
        id: 'rewards',
        label: 'Overview',
        icon: ClayIcons.rewards,
        target: WebTarget(coinsBase),
        verdict: Verdict.native,
        note: 'Needs new API endpoints; web page until Phase 4.',
      ),
      MenuEntry(
        id: 'wallet',
        label: 'My Wallet',
        icon: ClayIcons.wallet,
        target: WebTarget('$coinsBase/hub/wallet'),
        verdict: Verdict.native,
        note: 'Needs new API endpoints; web page until Phase 4.',
      ),
      MenuEntry(
        id: 'shop',
        label: 'Rewards Shop',
        icon: ClayIcons.shop,
        target: WebTarget('$coinsBase/hub/shop'),
        verdict: Verdict.native,
        note: 'Needs server-side prices first; web page until Phase 4.',
      ),
      MenuEntry(
        id: 'passes',
        label: 'Passes & Unlocks',
        icon: ClayIcons.passes,
        target: WebTarget('$coinsBase/hub/passes'),
        verdict: Verdict.native,
        note: 'Needs new API endpoints; web page until Phase 4.',
      ),
    ]),
    MenuGroup('Community', [
      MenuEntry(
        id: 'my_class',
        label: 'My Class',
        icon: ClayIcons.myClass,
        target: WebTarget('/my-class'),
        verdict: Verdict.webview,
      ),
    ]),
    MenuGroup('Account', [
      MenuEntry(
        id: 'profile',
        label: 'Profile and settings',
        icon: ClayIcons.profile,
        target: RouteTarget('/student/profile'),
        verdict: Verdict.native,
      ),
      MenuEntry(
        id: 'accessibility',
        label: 'Accessibility',
        icon: ClayIcons.accessibility,
        target: ActionTarget(MenuAction.accessibility),
        verdict: Verdict.native,
      ),
    ]),
    MenuGroup('Support', [
      MenuEntry(
        id: 'faq',
        label: 'FAQ / Contact',
        icon: ClayIcons.help,
        target: PublicWebTarget('/contact-us'),
        verdict: Verdict.webview,
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

  static Iterable<MenuEntry> get all => groups.expand((g) => g.entries);

  /// Bottom bar order (proposal approved): Home, Learn, Elimu Quest
  /// (centre), My Library, then More which opens the drawer.
  static const List<String> bottomBarIds = [
    'dashboard',
    'learning_areas',
    'elimu_quest',
    'library',
  ];
}
