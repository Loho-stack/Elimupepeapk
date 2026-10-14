import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/webview/sso_webview.dart';
import '../../core/webview/webview_policy.dart';
import '../../features/auth/welcome_screen.dart';
import '../../features/home/category_items_screen.dart';
import '../../features/home/dashboard_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/main_view.dart';
import '../../features/parental_control/parent_dashboard.dart';
import '../../features/parental_control/parent_messages_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/teacher/teacher_dashboard.dart';
import '../../models/menu_item.dart';
import '../app_services.dart';
import '../menu/student_menu.dart';
import '../session_controller.dart';
import 'student_routes.dart';
import '../shell/student_shell.dart';

/// Static route names. They are what Analytics sees as the screen name, so
/// they never contain ids, paths or anything about the learner.
abstract final class RouteNames {
  static const welcome = 'welcome';
  static const studentHome = 'student_home';
  static const studentLearn = 'student_learn';
  static const studentQuest = 'student_quest';
  static const studentLibrary = 'student_library';
  static const studentProfile = 'student_profile';
  static const studentQuestHub = 'student_quest_hub';
  static const studentWeb = 'sso_webview';
  static const studentPage = 'public_webview';
  static const parentHome = 'parent_home';
  static const parentMessages = 'parent_messages';
  static const teacherHome = 'teacher_home';
}

/// Builds the app's GoRouter. The redirect is driven by [SessionController]:
/// signed out goes to Welcome, signed in goes to the role's home, and a role
/// cannot open another role's area.
GoRouter buildRouter({
  required SessionController session,
  required GlobalKey<NavigatorState> navigatorKey,
  List<NavigatorObserver> observers = const [],
  String initialLocation = '/',
}) {
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: initialLocation,
    refreshListenable: session,
    observers: observers,
    redirect: (context, state) => redirectFor(session, state.matchedLocation),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _Splash(),
      ),
      GoRoute(
        path: '/welcome',
        name: RouteNames.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),

      // ------------------------------------------------------------ student
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => StudentShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/student/home',
              name: RouteNames.studentHome,
              builder: (context, state) => AppServices.instance.config.appApiV1
                  ? StudentHomeRoute(repositories: AppServices.instance.repositories)
                  : MainView(
                      onNavigate: (legacyIndex) =>
                          _legacyNavigate(context, legacyIndex),
                    ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/student/learn',
              name: RouteNames.studentLearn,
              builder: (context, state) => AppServices.instance.config.appApiV1
                  ? LearningAreasRoute(repositories: AppServices.instance.repositories)
                  : CategoryItemsScreen(
                      menuItem: MenuItem.getDefaultMenuItems()
                          .firstWhere((m) => m.id == 'learning_areas'),
                    ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/student/quest',
              name: RouteNames.studentQuest,
              builder: (context, state) => SsoWebViewScreen(
                title: 'Elimu Quest',
                path: '/my-quizzes',
                onRootBack: () => StatefulNavigationShell.of(context)
                    .goBranch(StudentMenu.homeBranch),
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/student/library',
              name: RouteNames.studentLibrary,
              builder: (context, state) => const HomeScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/student/profile',
        name: RouteNames.studentProfile,
        parentNavigatorKey: navigatorKey,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/student/quest-hub',
        name: RouteNames.studentQuestHub,
        parentNavigatorKey: navigatorKey,
        builder: (context, state) => const GamifiedDashboardScreen(
          initialIndex: 2,
          restoreLastTab: false,
        ),
      ),
      GoRoute(
        path: '/student/web',
        name: RouteNames.studentWeb,
        parentNavigatorKey: navigatorKey,
        redirect: (context, state) {
          final args = state.extra;
          return args is WebArgs && WebviewPolicy.isSafeIntendedPath(args.path)
              ? null
              : '/student/home';
        },
        builder: (context, state) {
          final args = state.extra! as WebArgs;
          return SsoWebViewScreen(title: args.title, path: args.path);
        },
      ),
      GoRoute(
        path: '/student/page',
        name: RouteNames.studentPage,
        parentNavigatorKey: navigatorKey,
        redirect: (context, state) {
          final args = state.extra;
          return args is WebArgs && WebviewPolicy.isSafeIntendedPath(args.path)
              ? null
              : '/student/home';
        },
        builder: (context, state) {
          final args = state.extra! as WebArgs;
          return SsoWebViewScreen(
            title: args.title,
            publicUrl: '${AppServices.instance.config.webBaseUrl}${args.path}',
          );
        },
      ),

      // ------------------------------------------------------------- parent
      GoRoute(
        path: '/parent',
        name: RouteNames.parentHome,
        builder: (context, state) => RoleShell(
          groups: ParentMenu.groups,
          onSelectExtra: (context, entry) {
            final t = entry.target;
            if (t is RouteTarget && t.location != '/parent') {
              context.push(t.location);
            }
          },
          child: const ParentDashboard(),
        ),
        routes: [
          GoRoute(
            path: 'messages',
            name: RouteNames.parentMessages,
            builder: (context, state) => const ParentMessagesScreen(),
          ),
        ],
      ),

      // ------------------------------------------------------------ teacher
      GoRoute(
        path: '/teacher',
        name: RouteNames.teacherHome,
        builder: (context, state) => const RoleShell(
          groups: TeacherMenu.groups,
          child: TeacherDashboard(),
        ),
      ),
    ],
  );
}

/// The redirect rule, separate from the router so it can be tested.
String? redirectFor(SessionController session, String location) {
  switch (session.status) {
    case SessionStatus.unknown:
      return location == '/' ? null : '/';
    case SessionStatus.signedOut:
      return location == '/welcome' ? null : '/welcome';
    case SessionStatus.signedIn:
      if (location == '/' || location == '/welcome') {
        return session.homeLocation;
      }
      final area = '/${location.split('/').where((s) => s.isNotEmpty).firstOrNull ?? ''}';
      final allowed = switch (session.role) {
        AppRole.student => area == '/student',
        AppRole.parent => area == '/parent',
        AppRole.teacher => area == '/teacher',
      };
      return allowed ? null : session.homeLocation;
  }
}

/// MainView still speaks the old bottom-bar indexes:
/// 0 Home, 1 Library, 2 Quest, 3 Menu, 4 Profile.
void _legacyNavigate(BuildContext context, int legacyIndex) {
  final shell = StatefulNavigationShell.of(context);
  switch (legacyIndex) {
    case 0:
      shell.goBranch(StudentMenu.homeBranch);
    case 1:
      shell.goBranch(StudentMenu.libraryBranch);
    case 2:
      shell.goBranch(StudentMenu.questBranch);
    case 3:
      ShellActions.maybeOf(context)?.openMenu();
    case 4:
      context.push('/student/profile');
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}
