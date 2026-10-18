import 'package:flutter/foundation.dart';

import '../../data/api_error.dart';
import '../../data/idempotency.dart';
import '../../data/models/msafara_quests.dart';
import '../../data/repositories/repositories.dart';

enum QuestionsPhase {
  /// Waiting for the questions.
  loading,

  /// The reading time is not done (409 `quest_locked`).
  locked,

  /// A question to answer.
  question,

  /// The reply to the answer just given.
  feedback,

  /// The quest is finished: score and kilometres, and the answers.
  result,

  /// Nothing to show; [QuestionsController.error] says why.
  failed,
}

/// One question at a time: MCQ, true or false, fill in the blank. Every answer has its own
/// Idempotency-Key that stays the same through retries, so an answer sent while the network drops is
/// either stored once or not at all. A failed send never throws the chosen answer away.
class QuestionsController extends ChangeNotifier {
  QuestionsController({required this.repo, required this.no, this.onGate});

  final MsafaraRepository repo;
  final int no;

  /// A Msafara gate 409 (not started, terms, profile): the screen should leave.
  final void Function(AppApiError error)? onGate;

  QuestionsPhase phase = QuestionsPhase.loading;
  QuestionSet? set;
  List<QuestQuestion> questions = const [];
  int index = 0;
  AnswerResult? last;
  QuestProgress? progress;
  AppApiError? error;
  int? lockedRemaining;

  int? choice;
  String text = '';
  bool busy = false;

  /// The last answer could not be sent because the device is offline; the answer is kept.
  bool offlineKept = false;

  /// A message for the last failed answer (validation or server), null otherwise.
  String? answerError;

  PendingAction? _action;
  int? _actionQuestion;
  bool _disposed = false;

  bool get isBonus => no == 6;
  int get size => set?.size ?? questions.length;
  int get answered => questions.where((q) => q.answered).length;
  int get right => progress?.right ?? questions.where((q) => q.correct == true).length;

  QuestQuestion? get current => index < questions.length ? questions[index] : null;

  bool get canSubmit {
    final q = current;
    if (q == null || busy) return false;
    return q.isFill ? text.trim().isNotEmpty : choice != null;
  }

  /// True when the answer just given finished the quest.
  bool get finishedNow => last?.quest.completed ?? false;

  Future<void> load() async {
    phase = QuestionsPhase.loading;
    error = null;
    _notify();
    try {
      final s = await repo.questions(no);
      set = s;
      questions = s.questions;
      progress = null;
      last = null;
      if (s.completed) {
        phase = QuestionsPhase.result;
      } else {
        final next = questions.indexWhere((q) => !q.answered);
        index = next < 0 ? 0 : next;
        phase = next < 0 ? QuestionsPhase.result : QuestionsPhase.question;
      }
      _resetInput();
    } catch (e) {
      _fail(AppApiError.from(e));
    }
    _notify();
  }

  void select(int option) {
    if (busy) return;
    choice = option;
    answerError = null;
    _notify();
  }

  void setText(String value) {
    text = value;
    answerError = null;
    _notify();
  }

  Future<void> submit() async {
    final q = current;
    if (q == null || !canSubmit) return;
    // One key per question. A retry of the same question reuses it.
    if (_actionQuestion != q.id) {
      _action = PendingAction();
      _actionQuestion = q.id;
    }
    busy = true;
    offlineKept = false;
    answerError = null;
    _notify();
    try {
      final r = await repo.answer(
        no,
        questionId: q.id,
        choice: q.isFill ? null : choice,
        text: q.isFill ? text.trim() : null,
        key: _action!.key,
      );
      questions = [
        for (final x in questions) x.id == q.id ? x.withAnswer(r) : x,
      ];
      last = r;
      progress = r.quest;
      _action = null;
      _actionQuestion = null;
      phase = QuestionsPhase.feedback;
    } catch (e) {
      final err = AppApiError.from(e);
      if (err is OfflineError) {
        offlineKept = true;
      } else if (err is QuestLockedError) {
        lockedRemaining = err.remaining;
        phase = QuestionsPhase.locked;
      } else if (err is MsafaraGateError) {
        _fail(err);
      } else if (err is ConflictError && err.code == 'quest_completed') {
        // Closed already (another device): show what the server has.
        busy = false;
        await load();
        return;
      } else if (err is ValidationError) {
        // The server refused this body; a corrected answer is a new action.
        _action = null;
        _actionQuestion = null;
        answerError = err.message;
      } else {
        answerError = err.message;
      }
    } finally {
      busy = false;
    }
    _notify();
  }

  /// From the feedback to the next unanswered question, or to the result.
  void next() {
    if (phase != QuestionsPhase.feedback) return;
    final nextIndex = questions.indexWhere((q) => !q.answered);
    if (finishedNow || nextIndex < 0) {
      phase = QuestionsPhase.result;
    } else {
      index = nextIndex;
      phase = QuestionsPhase.question;
      _resetInput();
    }
    _notify();
  }

  void _resetInput() {
    choice = null;
    text = '';
    offlineKept = false;
    answerError = null;
  }

  void _fail(AppApiError err) {
    if (err is QuestLockedError) {
      lockedRemaining = err.remaining;
      phase = QuestionsPhase.locked;
    } else {
      error = err;
      phase = QuestionsPhase.failed;
      if (err is MsafaraGateError) onGate?.call(err);
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
