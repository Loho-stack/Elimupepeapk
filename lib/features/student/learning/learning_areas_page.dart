import 'package:flutter/material.dart';

import '../../../core/design/clay.dart';
import '../../../data/models/account.dart';
import '../../../data/models/learning.dart';
import '../widgets/adaptive.dart';
import '../widgets/load_view.dart';
import '../widgets/student_scaffold.dart';
import 'learning_areas_controller.dart';

class LearningActions {
  const LearningActions({
    required this.openArea,
    required this.openLesson,
    required this.openPath,
  });
  final void Function(int courseId) openArea;
  final void Function(int courseId, int lessonId) openLesson;

  /// A page of the website in the SSO webview (title, path). Quizzes open this way.
  final void Function(String title, String path) openPath;
}

/// My Learning Areas (E-24, E-26, E-87): tabs Learning Areas / Saved / Quizzes.
class LearningAreasPage extends StatelessWidget {
  const LearningAreasPage({
    super.key,
    required this.controller,
    required this.actions,
  });
  final LearningAreasController controller;
  final LearningActions actions;

  static const tabs = [
    ClayTab(label: 'Areas'),
    ClayTab(label: 'Saved'),
    ClayTab(label: 'Quizzes'),
  ];

  @override
  Widget build(BuildContext context) {
    return StudentScaffold(
      title: 'My Learning Areas',
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ClaySpace.s4,
                ClaySpace.s3,
                ClaySpace.s4,
                ClaySpace.s2,
              ),
              child: ClayTabBar(
                tabs: tabs,
                index: controller.tab,
                onChanged: controller.selectTab,
              ),
            ),
            Expanded(
              child: switch (controller.tab) {
                0 => _AreasTab(controller: controller, actions: actions),
                1 => _SavedTab(controller: controller, actions: actions),
                _ => _QuizzesTab(controller: controller, actions: actions),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();
  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(ClaySpace.s4),
    children: const [
      ClaySkeleton(shape: ClaySkeletonShape.box, height: 120),
      SizedBox(height: ClaySpace.s3),
      ClaySkeleton(shape: ClaySkeletonShape.box, height: 96),
      SizedBox(height: ClaySpace.s3),
      ClaySkeleton(shape: ClaySkeletonShape.box, height: 96),
    ],
  );
}

// --------------------------------------------------------------------------- areas

class _AreasTab extends StatefulWidget {
  const _AreasTab({required this.controller, required this.actions});
  final LearningAreasController controller;
  final LearningActions actions;

  @override
  State<_AreasTab> createState() => _AreasTabState();
}

class _AreasTabState extends State<_AreasTab> {
  late final TextEditingController _search = TextEditingController(
    text: widget.controller.query,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return LoadView<LearningAreasData>(
      controller: c.areas,
      loadingLabel: 'Loading your learning areas',
      skeleton: const _ListSkeleton(),
      builder: (context, data, banner) {
        final t = Theme.of(context).textTheme;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            ClaySpace.s4,
            ClaySpace.s2,
            ClaySpace.s4,
            ClaySpace.s7,
          ),
          children: [
            if (banner != null) ...[
              banner,
              const SizedBox(height: ClaySpace.s3),
            ],
            if (data.hero != null && !c.filtering) ...[
              _Hero(area: data.hero!, onOpen: widget.actions),
              const SizedBox(height: ClaySpace.s3),
            ],
            Wrap(
              spacing: ClaySpace.s2,
              runSpacing: ClaySpace.s2,
              children: [
                ClayChip(
                  label: 'In progress',
                  value: '${data.chips.inProgress}',
                  icon: ClayIcons.learn,
                ),
                ClayChip(
                  label: 'Lessons this week',
                  value: '${data.chips.lessonsWeek}',
                  icon: ClayIcons.check,
                ),
                ClayChip(
                  label: 'Books reading',
                  value: '${data.chips.booksReading}',
                  icon: ClayIcons.library,
                ),
              ],
            ),
            const SizedBox(height: ClaySpace.s4),
            ClayTextField(
              label: 'Search learning areas',
              controller: _search,
              hint: 'Type a name',
              prefixIcon: ClayIcons.search,
              textInputAction: TextInputAction.search,
              onChanged: c.setQuery,
            ),
            const SizedBox(height: ClaySpace.s3),
            Semantics(
              container: true,
              label: 'Filter',
              child: Wrap(
                spacing: ClaySpace.s2,
                runSpacing: ClaySpace.s2,
                children: [
                  for (final f in AreaFilter.values)
                    ClayChip(
                      label: f.label,
                      selected: c.filter == f,
                      onTap: () => c.setFilter(f),
                    ),
                ],
              ),
            ),
            const SizedBox(height: ClaySpace.s3),
            Semantics(
              container: true,
              label: 'Sort by',
              child: Wrap(
                spacing: ClaySpace.s2,
                runSpacing: ClaySpace.s2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ExcludeSemantics(
                    child: Text('Sort by', style: t.labelMedium),
                  ),
                  for (final s in AreaSort.values)
                    ClayChip(
                      label: s.label,
                      selected: c.sort == s,
                      onTap: () => c.setSort(s),
                    ),
                ],
              ),
            ),
            const SizedBox(height: ClaySpace.s4),
            if (data.areas.isEmpty)
              c.filtering
                  ? const ClayEmptyState(
                      title: 'Nothing matches',
                      message: 'Try another filter or a different name.',
                      icon: ClayIcons.search,
                    )
                  : const ClayEmptyState(
                      title: 'No learning areas yet',
                      message:
                          'When your class has learning areas they will show here.',
                    )
            else
              for (final a in data.areas) ...[
                _AreaCard(area: a, onOpen: widget.actions),
                const SizedBox(height: ClaySpace.s3),
              ],
          ],
        );
      },
    );
  }
}

String _stateLabel(AreaState s) => switch (s) {
  AreaState.inProgress => 'In progress',
  AreaState.notStarted => 'Not started',
  AreaState.done => 'Done',
  AreaState.comingSoon => 'Coming soon',
};

ClayBadgeTone _stateTone(AreaState s) => switch (s) {
  AreaState.inProgress => ClayBadgeTone.soft,
  AreaState.notStarted => ClayBadgeTone.neutral,
  AreaState.done => ClayBadgeTone.done,
  AreaState.comingSoon => ClayBadgeTone.soon,
};

String _mix(LearningArea a) => [
  if (a.videos > 0) '${a.videos} ${a.videos == 1 ? 'video' : 'videos'}',
  if (a.slides > 0)
    '${a.slides} ${a.slides == 1 ? 'slide deck' : 'slide decks'}',
  if (a.notes > 0) '${a.notes} ${a.notes == 1 ? 'reading' : 'readings'}',
].join(', ');

class _Hero extends StatelessWidget {
  const _Hero({required this.area, required this.onOpen});
  final LearningArea area;
  final LearningActions onOpen;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final lessonId = area.nextLessonId;
    return ClayCard(
      tone: ClayCardTone.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text('Continue where you stopped', style: t.labelMedium),
          ),
          const SizedBox(height: ClaySpace.s2),
          LeadingAndText(
            leading: RingBadge(
              percent: area.percent,
              semanticLabel: '${area.title}, ${area.percent} percent done',
            ),
            text: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(area.title, style: t.titleMedium),
                if (area.nextLesson != null)
                  Text('Next: ${area.nextLesson}', style: t.bodyMedium),
                if (area.minutesLeft != null)
                  Text(
                    'About ${area.minutesLeft} min left',
                    style: t.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(height: ClaySpace.s3),
          ClayButton(
            label: lessonId == null ? 'Open learning area' : 'Continue',
            icon: ClayIcons.chevronRight,
            onPressed: () => lessonId == null
                ? onOpen.openArea(area.id)
                : onOpen.openLesson(area.id, lessonId),
          ),
        ],
      ),
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.area, required this.onOpen});
  final LearningArea area;
  final LearningActions onOpen;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final soon = area.state == AreaState.comingSoon;
    final mix = _mix(area);
    final spoken = [
      area.title,
      _stateLabel(area.state),
      if (!soon) '${area.done} of ${area.total} lessons done',
      if (soon) 'Opens when lessons are added',
    ].join(', ');
    return ClayCard(
      onTap: soon ? null : () => onOpen.openArea(area.id),
      semanticLabel: spoken,
      child: ExcludeSemantics(
        child: LeadingAndText(
          leading: RingBadge(
            percent: area.percent,
            semanticLabel: '${area.percent} percent',
            size: 64,
            label: soon ? '-' : null,
          ),
          text: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(area.title, style: t.titleMedium),
              if (area.level.isNotEmpty) Text(area.level, style: t.bodySmall),
              const SizedBox(height: ClaySpace.s1),
              ClayBadge(
                label: _stateLabel(area.state),
                tone: _stateTone(area.state),
              ),
              const SizedBox(height: ClaySpace.s1),
              if (soon)
                Text('Lessons are on the way.', style: t.bodySmall)
              else ...[
                Text(
                  '${area.done} of ${area.total} lessons done',
                  style: t.bodySmall,
                ),
                if (area.nextLesson != null)
                  Text('Next: ${area.nextLesson}', style: t.bodySmall),
                if (area.minutesLeft != null)
                  Text(
                    'About ${area.minutesLeft} min left',
                    style: t.bodySmall,
                  ),
                if (mix.isNotEmpty) Text(mix, style: t.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------- saved

class _SavedTab extends StatelessWidget {
  const _SavedTab({required this.controller, required this.actions});
  final LearningAreasController controller;
  final LearningActions actions;

  @override
  Widget build(BuildContext context) {
    return LoadView<Paged<SavedLesson>>(
      controller: controller.saved,
      loadingLabel: 'Loading saved lessons',
      skeleton: const _ListSkeleton(),
      builder: (context, page, banner) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(ClaySpace.s4),
          children: [
            if (banner != null) ...[
              banner,
              const SizedBox(height: ClaySpace.s3),
            ],
            if (page.items.isEmpty)
              const ClayEmptyState(
                title: 'No saved lessons',
                message:
                    'Save a lesson while you learn and it will wait for you here.',
                icon: ClayIcons.achievements,
              )
            else
              for (final s in page.items)
                ClayListTile(
                  leading: const Icon(ClayIcons.learn),
                  title: s.title,
                  subtitle: s.area,
                  trailing: const Icon(ClayIcons.chevronRight),
                  onTap: () => actions.openLesson(s.courseId, s.lessonId),
                ),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------------------- quizzes

class _QuizzesTab extends StatelessWidget {
  const _QuizzesTab({required this.controller, required this.actions});
  final LearningAreasController controller;
  final LearningActions actions;

  static String _stateLabel(String s) => switch (s) {
    'passed' => 'Passed',
    'attempted' => 'Attempted',
    _ => 'Not started',
  };

  static ClayBadgeTone _tone(String s) => switch (s) {
    'passed' => ClayBadgeTone.done,
    'attempted' => ClayBadgeTone.warn,
    _ => ClayBadgeTone.neutral,
  };

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return LoadView<List<QuizEntry>>(
      controller: controller.quizzes,
      loadingLabel: 'Loading quizzes',
      skeleton: const _ListSkeleton(),
      builder: (context, quizzes, banner) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(ClaySpace.s4),
          children: [
            if (banner != null) ...[
              banner,
              const SizedBox(height: ClaySpace.s3),
            ],
            if (quizzes.isEmpty)
              const ClayEmptyState(
                title: 'No quizzes yet',
                message:
                    'Quizzes from your learning areas will be listed here.',
                icon: ClayIcons.quest,
              )
            else
              for (final q in quizzes)
                ClayListTile(
                  leading: const Icon(ClayIcons.quest),
                  title: q.title,
                  subtitle: [
                    q.attempts == 0
                        ? 'No attempts yet'
                        : '${q.attempts} ${q.attempts == 1 ? 'attempt' : 'attempts'}',
                    if (q.best != null)
                      'Best ${_num(q.best!)}${q.total == null ? '' : '/${_num(q.total!)}'}',
                  ].join(', '),
                  trailing: ClayBadge(
                    label: _stateLabel(q.state),
                    tone: _tone(q.state),
                  ),
                  onTap: () =>
                      actions.openPath(q.title, q.webviewPath ?? '/my-quizzes'),
                ),
          ],
        );
      },
    );
  }
}
