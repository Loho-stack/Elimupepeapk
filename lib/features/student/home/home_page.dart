import 'package:flutter/material.dart';

import '../../../core/design/clay.dart';
import '../../../data/models/home.dart';
import '../load_controller.dart';
import '../widgets/adaptive.dart';
import '../widgets/load_view.dart';
import '../widgets/student_scaffold.dart';

/// Where the home screen sends the learner. The router supplies these; tests use fakes.
class HomeActions {
  const HomeActions({
    required this.openLesson,
    required this.openArea,
    required this.openPath,
  });

  /// Continue learning: a lesson of an area.
  final void Function(int courseId, int lessonId) openLesson;
  final void Function(int courseId) openArea;

  /// A page of the website in the SSO webview (title, path).
  final void Function(String title, String path) openPath;
}

/// Home (E-23): what the web dashboard shows, in its order. Sections with nothing in them
/// say so instead of disappearing, except the ones that only exist for some learners.
class StudentHomePage extends StatelessWidget {
  const StudentHomePage({
    super.key,
    required this.controller,
    required this.actions,
    this.actionsInBar = const [],
  });

  final LoadController<HomeData> controller;
  final HomeActions actions;
  final List<Widget> actionsInBar;

  @override
  Widget build(BuildContext context) {
    return StudentScaffold(
      title: 'Home',
      actions: actionsInBar,
      body: LoadView<HomeData>(
        controller: controller,
        loadingLabel: 'Loading your home',
        skeleton: const HomeSkeleton(),
        builder: (context, home, banner) =>
            HomeBody(home: home, actions: actions, banner: banner),
      ),
    );
  }
}

class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(ClaySpace.s4),
    children: const [
      ClaySkeleton(shape: ClaySkeletonShape.title, width: 180),
      SizedBox(height: ClaySpace.s3),
      ClaySkeleton(shape: ClaySkeletonShape.box, height: 140),
      SizedBox(height: ClaySpace.s5),
      ClaySkeleton(shape: ClaySkeletonShape.title, width: 140),
      SizedBox(height: ClaySpace.s3),
      ClaySkeleton(shape: ClaySkeletonShape.box, height: 84),
      SizedBox(height: ClaySpace.s3),
      ClaySkeleton(shape: ClaySkeletonShape.box, height: 84),
    ],
  );
}

class HomeBody extends StatelessWidget {
  const HomeBody({
    super.key,
    required this.home,
    required this.actions,
    this.banner,
  });
  final HomeData home;
  final HomeActions actions;
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    final w = home.widgets;
    final nothingYet =
        w.continueLearning == null &&
        w.reading.isEmpty &&
        w.classes.isEmpty &&
        w.dueAssignments.isEmpty;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        ClaySpace.s4,
        ClaySpace.s4,
        ClaySpace.s4,
        ClaySpace.s7,
      ),
      children: [
        if (banner != null) ...[banner!, const SizedBox(height: ClaySpace.s3)],
        _StreakAndCoins(streak: home.streak, coins: w.coins),
        const SectionTitle('Continue learning'),
        if (w.continueLearning != null)
          _ContinueCard(item: w.continueLearning!, actions: actions)
        else
          const ClayCard(
            child: _Empty(
              'Nothing to continue yet. Open Learn to start a learning area.',
            ),
          ),
        const SectionTitle('Live classes today'),
        if (w.classes.isEmpty)
          const ClayCard(child: _Empty('No live classes today.'))
        else
          for (final c in w.classes) _ClassTile(item: c),
        const SectionTitle('Keep reading'),
        if (w.reading.isEmpty)
          const ClayCard(child: _Empty('No books in progress.'))
        else
          for (final b in w.reading) _ReadingTile(book: b),
        const SectionTitle('Assignments'),
        _Assignments(due: w.dueAssignments, returned: w.returnedAssignments),
        if (w.quizzes.isNotEmpty) ...[
          const SectionTitle('Recent quizzes'),
          for (final q in w.quizzes) _QuizTile(quiz: q),
        ],
        if (w.grades.isNotEmpty) ...[
          const SectionTitle('Latest grades'),
          for (final g in w.grades) _GradeTile(grade: g),
        ],
        if (w.week != null) ...[
          const SectionTitle('Learning time this week'),
          _WeekChart(week: w.week!),
        ],
        if (w.msafara != null) ...[
          const SectionTitle('Msafara today'),
          _MsafaraCard(msafara: w.msafara!),
        ],
        if (w.videos.isNotEmpty) ...[
          const SectionTitle('Videos'),
          for (final v in w.videos) _VideoTile(video: v),
        ],
        if (home.school != null) ..._schoolSections(context, home.school!),
        if (nothingYet && w.coins == null) ...[
          const SizedBox(height: ClaySpace.s5),
          const ClayEmptyState(
            title: 'Welcome',
            message:
                'Your learning areas, books and classes will show up here as you start.',
          ),
        ],
      ],
    );
  }

  List<Widget> _schoolSections(BuildContext context, HomeSchool school) {
    final day = school.lessonDay;
    return [
      if (day != null) ...[
        SectionTitle(
          day.today ? 'Your lessons today' : 'Your lessons on ${day.name}',
        ),
        for (final s in day.slots)
          ClayListTile(
            title: s.subject,
            subtitle: [
              s.time,
              if (s.teacher != null) s.teacher!,
            ].where((e) => e.isNotEmpty).join(' - '),
          ),
      ],
      if (school.pendingHomework.isNotEmpty) ...[
        const SectionTitle('Homework to hand in'),
        for (final h in school.pendingHomework)
          ClayListTile(
            title: h.title,
            subtitle: h.deadline,
            trailing: h.isUrgent
                ? const ClayBadge(label: 'Soon', tone: ClayBadgeTone.warn)
                : null,
          ),
      ],
      if (school.calendar.isNotEmpty) ...[
        const SectionTitle('School calendar'),
        for (final e in school.calendar)
          ClayListTile(
            title: e.title,
            subtitle: [
              if (e.date != null) e.date!,
              if (e.time != null) e.time!,
            ].join(' '),
          ),
      ],
    ];
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.bodyMedium);
}

class _StreakAndCoins extends StatelessWidget {
  const _StreakAndCoins({required this.streak, required this.coins});
  final int streak;
  final Coins? coins;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ClaySpace.s2,
      runSpacing: ClaySpace.s2,
      children: [
        ClayChip(
          label: 'Streak',
          value: streak == 1 ? '1 day' : '$streak days',
          icon: ClayIcons.achievements,
        ),
        if (coins != null)
          ClayChip(
            label: 'Coins',
            value: _coins(coins!.balance),
            icon: ClayIcons.rewards,
          ),
      ],
    );
  }

  static String _coins(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.item, required this.actions});
  final ContinueLearning item;
  final HomeActions actions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final lessonId = item.lessonId;
    final done = lessonId == null;
    return ClayCard(
      tone: ClayCardTone.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LeadingAndText(
            leading: RingBadge(
              percent: item.percent,
              semanticLabel: '${item.title}, ${item.percent} percent done',
            ),
            text: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: t.titleMedium),
                const SizedBox(height: ClaySpace.s1),
                Text(
                  '${item.done} of ${item.total} lessons done',
                  style: t.bodySmall,
                ),
                if (item.lesson != null) ...[
                  const SizedBox(height: ClaySpace.s1),
                  Text('Next: ${item.lesson}', style: t.bodyMedium),
                ],
              ],
            ),
          ),
          const SizedBox(height: ClaySpace.s3),
          ClayButton(
            label: done ? 'Open learning area' : 'Continue',
            icon: ClayIcons.chevronRight,
            onPressed: () => done
                ? actions.openArea(item.id)
                : actions.openLesson(item.id, lessonId),
          ),
        ],
      ),
    );
  }
}

class _ClassTile extends StatelessWidget {
  const _ClassTile({required this.item});
  final LiveClass item;

  @override
  Widget build(BuildContext context) => ClayListTile(
    leading: const Icon(ClayIcons.liveClass),
    title: item.title,
    subtitle: '${item.when}, ${item.time}',
    trailing: item.live
        ? const ClayBadge(label: 'Live now', tone: ClayBadgeTone.danger)
        : (item.canJoin
              ? const ClayBadge(label: 'Starting', tone: ClayBadgeTone.warn)
              : null),
  );
}

class _ReadingTile extends StatelessWidget {
  const _ReadingTile({required this.book});
  final ReadingBook book;

  @override
  Widget build(BuildContext context) => ClayListTile(
    leading: const Icon(ClayIcons.library),
    title: book.title,
    subtitle: 'Page ${book.page}, ${book.percent}% read',
  );
}

class _Assignments extends StatelessWidget {
  const _Assignments({required this.due, required this.returned});
  final List<DueAssignment> due;
  final List<ReturnedAssignment> returned;

  @override
  Widget build(BuildContext context) {
    if (due.isEmpty && returned.isEmpty) {
      return const ClayCard(child: _Empty('No assignments due. Nice work.'));
    }
    return Column(
      children: [
        for (final a in due)
          ClayListTile(
            leading: const Icon(ClayIcons.gradebook),
            title: a.title,
            subtitle: a.deadline == null ? null : 'Due ${a.deadline}',
            trailing: a.overdue
                ? const ClayBadge(label: 'Overdue', tone: ClayBadgeTone.danger)
                : (a.urgent
                      ? const ClayBadge(label: 'Soon', tone: ClayBadgeTone.warn)
                      : null),
          ),
        for (final r in returned)
          ClayListTile(
            leading: const Icon(ClayIcons.check),
            title: r.title,
            subtitle: 'Returned ${r.on}',
            trailing: r.score == null
                ? null
                : ClayBadge(
                    label: _score(r.score!, r.max),
                    tone: ClayBadgeTone.done,
                  ),
          ),
      ],
    );
  }
}

String _num(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
String _score(double score, double? max) =>
    max == null ? _num(score) : '${_num(score)}/${_num(max)}';

class _QuizTile extends StatelessWidget {
  const _QuizTile({required this.quiz});
  final RecentQuiz quiz;

  @override
  Widget build(BuildContext context) => ClayListTile(
    leading: const Icon(ClayIcons.quest),
    title: quiz.title,
    subtitle: quiz.marked && quiz.marks != null
        ? '${_score(quiz.marks!, quiz.total)}, ${quiz.date}'
        : 'Waiting to be marked, ${quiz.date}',
    trailing: quiz.passed == null
        ? null
        : ClayBadge(
            label: quiz.passed! ? 'Passed' : 'Try again',
            tone: quiz.passed! ? ClayBadgeTone.done : ClayBadgeTone.warn,
          ),
  );
}

class _GradeTile extends StatelessWidget {
  const _GradeTile({required this.grade});
  final GradeEntry grade;

  @override
  Widget build(BuildContext context) => ClayListTile(
    leading: const Icon(ClayIcons.gradebook),
    title: grade.title,
    subtitle: [
      if (grade.score != null) _score(grade.score!, grade.max),
      grade.on,
    ].join(', '),
    trailing: grade.level == null
        ? null
        : ClayBadge(label: grade.level!, tone: ClayBadgeTone.soft),
  );
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.week});
  final LearningWeek week;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final max = week.days.fold<int>(1, (m, d) => d.minutes > m ? d.minutes : m);
    final summary =
        '${week.totalMinutes} minutes this week. ${week.days.map((d) => '${d.label} ${d.minutes}').join(', ')}';
    return ClayCard(
      semanticLabel: summary,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${week.totalMinutes} min', style: t.titleMedium),
            const SizedBox(height: ClaySpace.s3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in week.days)
                  Expanded(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 56,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: d.minutes == 0
                                  ? 0.04
                                  : (d.minutes / max).clamp(0.08, 1.0),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: d.today
                                      ? ClayTokens.of(
                                          context,
                                        ).palette.primaryDeep
                                      : ClayTokens.of(context).palette.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: ClaySpace.s1),
                        Text(
                          d.label.characters.take(1).toString(),
                          style: t.labelSmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MsafaraCard extends StatelessWidget {
  const _MsafaraCard({required this.msafara});
  final MsafaraToday msafara;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final km = msafara.kmToday == msafara.kmToday.roundToDouble()
        ? msafara.kmToday.toInt().toString()
        : msafara.kmToday.toStringAsFixed(1);
    return ClayCard(
      child: LeadingAndText(
        leading: RingBadge(
          percent: msafara.total == 0
              ? 0
              : (100 * msafara.done / msafara.total).round(),
          semanticLabel: '${msafara.done} of ${msafara.total} stops done',
          size: 64,
          label: '${msafara.done}/${msafara.total}',
        ),
        text: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msafara.town ?? 'On the road', style: t.titleMedium),
            if (msafara.label != null)
              Text(msafara.label!, style: t.bodyMedium),
            Text('$km km today', style: t.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.video});
  final VideoProgress video;

  @override
  Widget build(BuildContext context) => ClayListTile(
    leading: const Icon(ClayIcons.tv),
    title: video.title,
    subtitle: '${video.percent}% watched',
  );
}
