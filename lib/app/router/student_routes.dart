import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/home.dart';
import '../../data/repositories/app_repositories.dart';
import '../../features/student/home/home_page.dart';
import '../../features/student/learning/learning_areas_controller.dart';
import '../../features/student/learning/learning_areas_page.dart';
import '../../features/student/load_controller.dart';
import '../shell/student_shell.dart' show WebArgs;

void _openWeb(BuildContext context, String title, String path) =>
    context.push('/student/web', extra: WebArgs(title: title, path: path));

/// Until the native area and lesson screens exist, an area or lesson opens on the website
/// in the SSO webview, exactly as the older screens did.
void _openAreaOnWeb(BuildContext context, int courseId) => _openWeb(context, 'Learning area', '/my-courses?area=$courseId');
void _openLessonOnWeb(BuildContext context, int courseId, int lessonId) =>
    _openWeb(context, 'Lesson', '/fullscreen-view/$courseId/$lessonId');

/// Owns the home controller for the life of the route.
class StudentHomeRoute extends StatefulWidget {
  const StudentHomeRoute({super.key, required this.repositories});
  final AppRepositories repositories;

  @override
  State<StudentHomeRoute> createState() => _StudentHomeRouteState();
}

class _StudentHomeRouteState extends State<StudentHomeRoute> {
  late final LoadController<HomeData> _home = LoadController(widget.repositories.home.home)..load();

  @override
  void dispose() {
    _home.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StudentHomePage(
        controller: _home,
        actions: HomeActions(
          openLesson: (c, l) => _openLessonOnWeb(context, c, l),
          openArea: (c) => _openAreaOnWeb(context, c),
          openPath: (t, p) => _openWeb(context, t, p),
        ),
      );
}

class LearningAreasRoute extends StatefulWidget {
  const LearningAreasRoute({super.key, required this.repositories});
  final AppRepositories repositories;

  @override
  State<LearningAreasRoute> createState() => _LearningAreasRouteState();
}

class _LearningAreasRouteState extends State<LearningAreasRoute> {
  late final LearningAreasController _controller = LearningAreasController(widget.repositories.learning)..start();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LearningAreasPage(
        controller: _controller,
        actions: LearningActions(
          openArea: (c) => _openAreaOnWeb(context, c),
          openLesson: (c, l) => _openLessonOnWeb(context, c, l),
          openPath: (t, p) => _openWeb(context, t, p),
        ),
      );
}
