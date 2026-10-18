import 'package:flutter/material.dart';

import '../../core/design/clay.dart';
import '../student/widgets/load_view.dart';
import 'quest_session.dart';
import 'quest_strings.dart';
import 'quest_widgets.dart';
import 'questions_controller.dart';

/// The questions of a quest, one at a time, with feedback, then the result.
class QuestionsPage extends StatefulWidget {
  const QuestionsPage({super.key, required this.session, required this.controller, required this.onClose, this.onReadPage});
  final MsafaraSession session;
  final QuestionsController controller;

  /// Back to Elimu Quest (the home), or to the reading when the quest is locked.
  final VoidCallback onClose;

  /// "Read page N again". Null hides the link.
  final void Function(int page)? onReadPage;

  @override
  State<QuestionsPage> createState() => _QuestionsPageState();
}

class _QuestionsPageState extends State<QuestionsPage> {
  @override
  Widget build(BuildContext context) {
    final s = widget.session.strings;
    return QuestScaffold(
      title: s.t('title'),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final c = widget.controller;
          return switch (c.phase) {
            QuestionsPhase.loading => Semantics(
                label: s.t('quest.loading_questions'),
                liveRegion: true,
                child: const Padding(
                  padding: EdgeInsets.all(ClaySpace.s4),
                  child: Column(children: [ClaySkeleton(height: 48), SizedBox(height: 12), ClaySkeleton(height: 160)]),
                ),
              ),
            QuestionsPhase.locked => _locked(context, s),
            QuestionsPhase.failed => Center(
                child: Padding(
                  padding: const EdgeInsets.all(ClaySpace.s4),
                  child: ErrorView(error: c.error!, onRetry: c.load),
                ),
              ),
            QuestionsPhase.question => _question(context, c, s),
            QuestionsPhase.feedback => _feedback(context, c, s),
            QuestionsPhase.result => _result(context, c, s),
          };
        },
      ),
    );
  }

  Widget _locked(BuildContext context, QuestStrings s) => Center(
        child: Padding(
          padding: const EdgeInsets.all(ClaySpace.s4),
          child: ClayEmptyState(
            title: s.t('quest.locked_questions'),
            icon: ClayIcons.lock,
            actionLabel: s.t('quest.read_more'),
            onAction: widget.onClose,
          ),
        ),
      );

  Widget _progress(QuestionsController c, QuestStrings s, {required int number}) {
    final size = c.size;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(s.t('quest.question_of', {'n': number, 'size': size}), style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: ClaySpace.s2),
        ClayProgressBar(
          value: size == 0 ? 0 : c.answered / size,
          semanticLabel: s.t('quest.stones', {'answered': c.answered, 'size': size, 'right': c.right}),
        ),
      ],
    );
  }

  Widget _question(BuildContext context, QuestionsController c, QuestStrings s) {
    final q = c.current!;
    final theme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(ClaySpace.s4),
      children: [
        _progress(c, s, number: c.index + 1),
        const SizedBox(height: ClaySpace.s4),
        ClayCard(child: Text(q.question, style: theme.titleLarge)),
        const SizedBox(height: ClaySpace.s3),
        if (q.isFill)
          // Keyed by the question, so the box starts empty for each one.
          _FillBox(
            key: ValueKey(q.id),
            label: s.t('quest.fill_label'),
            initial: c.text,
            enabled: !c.busy,
            onChanged: c.setText,
            onSubmit: () => c.canSubmit ? c.submit() : null,
          )
        else
          for (var i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: ClaySpace.s2),
              child: ClayListTile(
                title: q.options[i],
                selected: c.choice == i + 1,
                trailing: c.choice == i + 1 ? const Icon(ClayIcons.check) : const SizedBox(width: 24),
                onTap: c.busy ? null : () => c.select(i + 1),
              ),
            ),
        if (c.offlineKept) QuestError(text: s.t('quest.answer_kept')),
        if (c.answerError != null) QuestError(text: c.answerError!),
        const SizedBox(height: ClaySpace.s4),
        ClayButton(
          label: s.t('quest.answer'),
          loading: c.busy,
          onPressed: c.canSubmit ? c.submit : null,
        ),
      ],
    );
  }

  Widget _feedback(BuildContext context, QuestionsController c, QuestStrings s) {
    final r = c.last!;
    final q = c.questions.firstWhere((x) => x.id == r.questionId, orElse: () => c.current!);
    final theme = Theme.of(context).textTheme;
    final isLast = c.finishedNow;
    return ListView(
      padding: const EdgeInsets.all(ClaySpace.s4),
      children: [
        _progress(c, s, number: c.questions.indexWhere((x) => x.id == r.questionId) + 1),
        const SizedBox(height: ClaySpace.s4),
        ClayCard(child: Text(q.question, style: theme.titleMedium)),
        const SizedBox(height: ClaySpace.s3),
        Semantics(
          liveRegion: true,
          container: true,
          child: ClayCard(
            tone: r.correct ? ClayCardTone.green : ClayCardTone.rose,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  ExcludeSemantics(child: Icon(r.correct ? ClayIcons.check : ClayIcons.warning)),
                  const SizedBox(width: ClaySpace.s2),
                  Expanded(
                    child: Text(s.t(r.correct ? 'quest.right_title' : 'quest.wrong_title'), style: theme.titleMedium),
                  ),
                ]),
                if (r.chosen != null) ...[
                  const SizedBox(height: ClaySpace.s2),
                  Text(s.t('quest.you_answered', {'answer': r.chosen!}), style: theme.bodyMedium),
                ],
                if (!r.correct && r.answerLabel != null) ...[
                  const SizedBox(height: ClaySpace.s1),
                  Text('${s.t('quest.the_answer')} ${r.answerLabel}', style: theme.titleSmall),
                ],
                if (r.explanation != null && r.explanation!.isNotEmpty) ...[
                  const SizedBox(height: ClaySpace.s2),
                  Text(r.explanation!, style: theme.bodyMedium),
                ],
              ],
            ),
          ),
        ),
        if (r.pageRef != null && widget.onReadPage != null && !r.correct) ...[
          const SizedBox(height: ClaySpace.s3),
          ClayButton(
            label: s.t('quest.read_again', {'page': r.pageRef!}),
            variant: ClayButtonVariant.secondary,
            onPressed: () => widget.onReadPage!(r.pageRef!),
          ),
        ],
        const SizedBox(height: ClaySpace.s4),
        ClayButton(
          label: s.t(isLast ? 'quest.see_result' : 'quest.next_question'),
          icon: ClayIcons.chevronRight,
          onPressed: c.next,
        ),
      ],
    );
  }

  Widget _result(BuildContext context, QuestionsController c, QuestStrings s) {
    final theme = Theme.of(context).textTheme;
    final p = c.progress;
    final size = p?.size ?? c.size;
    final right = p?.right ?? c.right;
    final score = p?.score ?? (size == 0 ? 0.0 : right / size);
    final message = score >= 0.8 ? 'quest.result_great' : (score >= 0.5 ? 'quest.result_good' : 'quest.result_gentle');
    final km = p?.kmExpected ?? 0;

    return ListView(
      padding: const EdgeInsets.all(ClaySpace.s4),
      children: [
        ClayCard(
          tone: ClayCardTone.green,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(s.t('quest.done'), style: theme.headlineSmall)),
              const SizedBox(height: ClaySpace.s2),
              Text(s.t('quest.score', {'right': right, 'size': size}), style: theme.titleLarge),
              const SizedBox(height: ClaySpace.s2),
              Text(s.t(message), style: theme.bodyMedium),
              if (!c.isBonus && p != null && km > 0) ...[
                const SizedBox(height: ClaySpace.s2),
                Text(s.t('quest.km_coming', {'km': formatKm(km)}), style: theme.titleSmall),
              ],
              if (!c.isBonus && p != null && score < 0.5) ...[
                const SizedBox(height: ClaySpace.s2),
                Text(s.t('quest.half_km', {'full': formatKm(km * 2)}), style: theme.bodySmall),
              ],
            ],
          ),
        ),
        const SizedBox(height: ClaySpace.s5),
        Semantics(header: true, child: Text(s.t('quest.your_answers'), style: theme.titleMedium)),
        const SizedBox(height: ClaySpace.s2),
        for (final q in c.questions)
          Padding(
            padding: const EdgeInsets.only(bottom: ClaySpace.s2),
            child: ClayCard(
              tight: true,
              tone: q.correct == true ? ClayCardTone.soft : ClayCardTone.plain,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(child: Icon(q.correct == true ? ClayIcons.check : ClayIcons.warning, size: 20)),
                  const SizedBox(width: ClaySpace.s2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(q.question, style: theme.bodyMedium),
                        if (q.chosen != null)
                          Text(s.t('quest.you_answered', {'answer': q.chosen!}), style: theme.bodySmall),
                        if (q.correct == false && q.answerLabel != null)
                          Text('${s.t('quest.the_answer')} ${q.answerLabel}', style: theme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: ClaySpace.s4),
        ClayButton(label: s.t('quest.back'), onPressed: widget.onClose),
      ],
    );
  }
}

class _FillBox extends StatefulWidget {
  const _FillBox({super.key, required this.label, required this.initial, required this.enabled, required this.onChanged, required this.onSubmit});
  final String label;
  final String initial;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  State<_FillBox> createState() => _FillBoxState();
}

class _FillBoxState extends State<_FillBox> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClayTextField(
        label: widget.label,
        controller: _controller,
        enabled: widget.enabled,
        textInputAction: TextInputAction.done,
        onChanged: widget.onChanged,
        onSubmitted: (_) => widget.onSubmit(),
      );
}
