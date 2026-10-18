import '../json.dart';

class Km {
  const Km({required this.total, required this.today, required this.dailyCap});
  final double total;
  final double today;
  final double dailyCap;

  factory Km.fromJson(Map<String, dynamic> j) =>
      Km(total: j.number('total'), today: j.number('today'), dailyCap: j.number('daily_cap'));
}

class DailyGoal {
  const DailyGoal({required this.minutes, required this.done, required this.percent});
  final int minutes;
  final int done;
  final int percent;

  factory DailyGoal.fromJson(Map<String, dynamic> j) =>
      DailyGoal(minutes: j.integer('minutes'), done: j.integer('done'), percent: j.integer('percent'));
}

class LegProgress {
  const LegProgress({required this.no, required this.name, required this.day, required this.days, required this.percent});
  final int no;
  final String name;
  final int day;
  final int days;
  final int percent;

  factory LegProgress.fromJson(Map<String, dynamic> j) => LegProgress(
        no: j.integer('no'),
        name: j.str('name'),
        day: j.integer('day'),
        days: j.integer('days'),
        percent: j.integer('percent'),
      );
}

class HomeTown {
  const HomeTown({required this.name, required this.county, required this.planDay});
  final String name;
  final String? county;
  final int planDay;

  factory HomeTown.fromJson(Map<String, dynamic> j) =>
      HomeTown(name: j.str('name'), county: j.strOrNull('county'), planDay: j.integer('plan_day'));
}

/// A Quest card, from `GET /home` (summary fields) or `GET /quests` (all fields). Fields only the list
/// sends are nullable.
class QuestCard {
  const QuestCard({
    required this.no,
    required this.type,
    required this.typeName,
    required this.kind,
    required this.title,
    required this.publisher,
    required this.coverUrl,
    required this.instruction,
    required this.pageFrom,
    required this.pageTo,
    required this.requiredSeconds,
    required this.readSeconds,
    required this.unlocked,
    required this.completed,
    required this.questions,
    required this.score,
    required this.kmExpected,
    required this.km,
    this.concept,
    this.pageCount,
    this.right,
    this.remainingSeconds,
    this.listen = false,
    this.lang,
  });

  final int no;

  /// `english|kiswahili|mathematics|storybook|research`; null for a day with no plan line.
  final String? type;
  final String? typeName;

  /// `book` or `lesson`.
  final String kind;
  final String title;
  final String? publisher;
  final String? coverUrl;
  final String instruction;
  final int? pageFrom;
  final int? pageTo;
  final int requiredSeconds;
  final int readSeconds;
  final bool unlocked;
  final bool completed;
  final int questions;
  final double? score;
  final double kmExpected;
  final double km;
  final String? concept;
  final int? pageCount;
  final int? right;
  final int? remainingSeconds;
  final bool listen;
  final String? lang;

  bool get isBook => kind == 'book';

  factory QuestCard.fromJson(Map<String, dynamic> j) => QuestCard(
        no: j.integer('no'),
        type: j.strOrNull('type'),
        typeName: j.strOrNull('type_name'),
        kind: j.str('kind'),
        title: j.str('title'),
        publisher: j.strOrNull('publisher'),
        coverUrl: j.strOrNull('cover_url'),
        instruction: j.str('instruction'),
        pageFrom: j.intOrNull('page_from'),
        pageTo: j.intOrNull('page_to'),
        requiredSeconds: j.integer('required_seconds'),
        readSeconds: j.integer('read_seconds'),
        unlocked: j.boolean('unlocked'),
        completed: j.boolean('completed'),
        questions: j.integer('questions'),
        score: j.numberOrNull('score'),
        kmExpected: j.number('km_expected'),
        km: j.number('km'),
        concept: j.strOrNull('concept'),
        pageCount: j.intOrNull('page_count'),
        right: j.intOrNull('right'),
        remainingSeconds: j.intOrNull('remaining_seconds'),
        listen: j.boolOrNull('listen') ?? false,
        lang: j.strOrNull('lang'),
      );
}

/// The bonus card (quest 6): practice on missed questions, no kilometres.
class BonusCard {
  const BonusCard({required this.no, required this.questions, required this.unlocked, required this.completed});
  final int no;
  final int questions;
  final bool unlocked;
  final bool completed;

  factory BonusCard.fromJson(Map<String, dynamic> j) => BonusCard(
        no: j.integer('no'),
        questions: j.integer('questions'),
        unlocked: j.boolean('unlocked'),
        completed: j.boolean('completed'),
      );
}

/// The checkpoint summary on the home screen. `available` false means no checkpoint for this learner today.
class HomeCheckpoint {
  const HomeCheckpoint({
    required this.day,
    required this.available,
    required this.state,
    required this.answered,
    required this.solved,
    required this.attemptsLeft,
    required this.town,
    required this.kmExpected,
  });

  final int? day;
  final bool available;

  /// `locked|open|late|closed`.
  final String? state;
  final bool answered;
  final bool solved;
  final int? attemptsLeft;
  final String? town;
  final double? kmExpected;

  factory HomeCheckpoint.fromJson(Map<String, dynamic> j) => HomeCheckpoint(
        day: j.intOrNull('day'),
        available: j.boolean('available'),
        state: j.strOrNull('state'),
        answered: j.boolOrNull('answered') ?? false,
        solved: j.boolOrNull('solved') ?? false,
        attemptsLeft: j.intOrNull('attempts_left'),
        town: j.strOrNull('town'),
        kmExpected: j.numberOrNull('km_expected'),
      );
}

class MissedTown {
  const MissedTown({required this.day, required this.town, required this.state, required this.kmExpected});
  final int day;
  final String town;
  final String state;
  final double kmExpected;

  factory MissedTown.fromJson(Map<String, dynamic> j) => MissedTown(
        day: j.integer('day'),
        town: j.str('town'),
        state: j.str('state'),
        kmExpected: j.number('km_expected'),
      );
}

class BoardPreview {
  const BoardPreview({required this.rank, required this.km, required this.previous, required this.movement});
  final int? rank;
  final double? km;
  final int? previous;
  final int? movement;

  factory BoardPreview.fromJson(Map<String, dynamic> j) => BoardPreview(
        rank: j.intOrNull('rank'),
        km: j.numberOrNull('km'),
        previous: j.intOrNull('previous'),
        movement: j.intOrNull('movement'),
      );
}

/// `GET /msafara/home`. Outside the run (`day` null: before launch or after the end) most of it is empty.
class QuestHome {
  const QuestHome({
    required this.day,
    required this.date,
    required this.totalDays,
    required this.label,
    required this.dayType,
    required this.leg,
    required this.town,
    required this.special,
    required this.nextTown,
    required this.km,
    required this.dailyGoal,
    required this.quests,
    required this.bonus,
    required this.checkpoint,
    required this.missed,
    required this.board,
    required this.ended,
  });

  final int? day;
  final String? date;
  final int totalDays;
  final String? label;
  final String? dayType;
  final LegProgress? leg;
  final HomeTown? town;
  final String? special;
  final String? nextTown;
  final Km km;
  final DailyGoal? dailyGoal;
  final List<QuestCard> quests;
  final BonusCard? bonus;
  final HomeCheckpoint? checkpoint;
  final List<MissedTown> missed;
  final BoardPreview? board;
  final bool ended;

  bool get inRun => day != null;

  factory QuestHome.fromJson(Map<String, dynamic> j) => QuestHome(
        day: j.intOrNull('day'),
        date: j.strOrNull('date'),
        totalDays: j.intOrNull('total_days') ?? 92,
        label: j.strOrNull('label'),
        dayType: j.strOrNull('day_type'),
        leg: j.objOrNull('leg') == null ? null : LegProgress.fromJson(j.obj('leg')),
        town: j.objOrNull('town') == null ? null : HomeTown.fromJson(j.obj('town')),
        special: j.strOrNull('special'),
        nextTown: j.strOrNull('next_town'),
        km: Km.fromJson(j.obj('km')),
        dailyGoal: j.objOrNull('daily_goal') == null ? null : DailyGoal.fromJson(j.obj('daily_goal')),
        quests: j['quests'] == null ? const [] : j.list('quests', QuestCard.fromJson),
        bonus: j.objOrNull('bonus') == null ? null : BonusCard.fromJson(j.obj('bonus')),
        checkpoint: j.objOrNull('checkpoint') == null ? null : HomeCheckpoint.fromJson(j.obj('checkpoint')),
        missed: j['missed'] == null ? const [] : j.list('missed', MissedTown.fromJson),
        board: j.objOrNull('board') == null ? null : BoardPreview.fromJson(j.obj('board')),
        ended: j.boolOrNull('ended') ?? false,
      );
}

/// The reading lock, from `GET quests/{no}` and from every ping reply. The server is the clock.
class QuestLock {
  const QuestLock({
    required this.unlocked,
    required this.seconds,
    required this.remaining,
    required this.requiredSeconds,
    required this.inRange,
    required this.pageFrom,
    required this.pageTo,
  });

  final bool unlocked;
  final int seconds;
  final int remaining;
  final int requiredSeconds;

  /// False when the page seen is outside the quest's range: no time is credited.
  final bool inRange;
  final int? pageFrom;
  final int? pageTo;

  double get fraction => requiredSeconds <= 0 ? 1 : (seconds / requiredSeconds).clamp(0.0, 1.0);

  factory QuestLock.fromJson(Map<String, dynamic> j) => QuestLock(
        unlocked: j.boolean('unlocked'),
        seconds: j.integer('seconds'),
        remaining: j.integer('remaining'),
        requiredSeconds: j.integer('required'),
        inRange: j.boolOrNull('in_range') ?? true,
        pageFrom: j.intOrNull('page_from'),
        pageTo: j.intOrNull('page_to'),
      );
}

class QuestBook {
  const QuestBook({
    required this.itemId,
    required this.ebookId,
    required this.pdfUrl,
    required this.pageCount,
    required this.startPage,
    required this.pageFrom,
    required this.pageTo,
  });

  final int itemId;
  final int? ebookId;
  final String pdfUrl;
  final int pageCount;
  final int startPage;
  final int pageFrom;
  final int pageTo;

  factory QuestBook.fromJson(Map<String, dynamic> j) => QuestBook(
        itemId: j.integer('item_id'),
        ebookId: j.intOrNull('ebook_id'),
        pdfUrl: j.str('pdf_url'),
        pageCount: j.integer('page_count'),
        startPage: j.integer('start_page'),
        pageFrom: j.integer('page_from'),
        pageTo: j.integer('page_to'),
      );
}

class QuestLesson {
  const QuestLesson({required this.id, required this.kind, required this.title, required this.language, required this.body});
  final int id;

  /// `lesson_ai` or `story_ai`.
  final String kind;
  final String title;
  final String language;

  /// Paragraphs separated by blank lines.
  final String body;

  List<String> get paragraphs =>
      body.split(RegExp(r'\n\s*\n')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

  factory QuestLesson.fromJson(Map<String, dynamic> j) => QuestLesson(
        id: j.integer('id'),
        kind: j.str('kind'),
        title: j.str('title'),
        language: j.str('language'),
        body: j.str('body'),
      );
}

/// `GET /msafara/quests/{no}`.
class QuestDetail {
  const QuestDetail({
    required this.no,
    required this.kind,
    required this.title,
    required this.lock,
    required this.book,
    required this.lesson,
    required this.listen,
  });

  final int no;

  /// `book`, `lesson` or `bonus`.
  final String kind;
  final String title;
  final QuestLock lock;
  final QuestBook? book;
  final QuestLesson? lesson;
  final bool listen;

  factory QuestDetail.fromJson(Map<String, dynamic> j) => QuestDetail(
        no: j.integer('no'),
        kind: j.str('kind'),
        title: j.str('title'),
        lock: QuestLock.fromJson(j.obj('lock')),
        book: j.objOrNull('book') == null ? null : QuestBook.fromJson(j.obj('book')),
        lesson: j.objOrNull('lesson') == null ? null : QuestLesson.fromJson(j.obj('lesson')),
        listen: j.boolOrNull('listen') ?? false,
      );
}

/// `GET /msafara/quests`.
class QuestList {
  const QuestList({required this.date, required this.dailyGoal, required this.quests, required this.bonus});
  final String date;
  final DailyGoal? dailyGoal;
  final List<QuestCard> quests;
  final BonusCard? bonus;

  factory QuestList.fromJson(Map<String, dynamic> j) => QuestList(
        date: j.str('date'),
        dailyGoal: j.objOrNull('daily_goal') == null ? null : DailyGoal.fromJson(j.obj('daily_goal')),
        quests: j.list('quests', QuestCard.fromJson),
        bonus: j.objOrNull('bonus') == null ? null : BonusCard.fromJson(j.obj('bonus')),
      );
}

class QuestQuestion {
  const QuestQuestion({
    required this.id,
    required this.type,
    required this.question,
    required this.options,
    required this.answered,
    required this.chosen,
    required this.correct,
    required this.answerLabel,
    required this.explanation,
    required this.pageRef,
  });

  final int id;

  /// `mcq`, `true_false` or `fill_blank`.
  final String type;
  final String question;

  /// Empty for `fill_blank`.
  final List<String> options;
  final bool answered;
  final String? chosen;
  final bool? correct;
  final String? answerLabel;
  final String? explanation;
  final int? pageRef;

  bool get isFill => type == 'fill_blank';

  QuestQuestion withAnswer(AnswerResult r) => QuestQuestion(
        id: id,
        type: type,
        question: question,
        options: options,
        answered: true,
        chosen: r.chosen,
        correct: r.correct,
        answerLabel: r.answerLabel,
        explanation: r.explanation,
        pageRef: r.pageRef,
      );

  factory QuestQuestion.fromJson(Map<String, dynamic> j) => QuestQuestion(
        id: j.integer('id'),
        type: j.str('type'),
        question: j.str('question'),
        options: [for (final o in (j['options'] as List? ?? const [])) o.toString()],
        answered: j.boolean('answered'),
        chosen: j.strOrNull('chosen'),
        correct: j.boolOrNull('correct'),
        answerLabel: j.strOrNull('answer_label'),
        explanation: j.strOrNull('explanation'),
        pageRef: j.intOrNull('page_ref'),
      );
}

/// `GET /msafara/quests/{no}/questions`.
class QuestionSet {
  const QuestionSet({
    required this.no,
    required this.completed,
    required this.size,
    required this.right,
    required this.nextQuestionId,
    required this.questions,
  });

  final int no;
  final bool completed;
  final int size;
  final int right;
  final int? nextQuestionId;
  final List<QuestQuestion> questions;

  factory QuestionSet.fromJson(Map<String, dynamic> j) => QuestionSet(
        no: j.integer('no'),
        completed: j.boolean('completed'),
        size: j.integer('size'),
        right: j.integer('right'),
        nextQuestionId: j.intOrNull('next_question_id'),
        questions: j.list('questions', QuestQuestion.fromJson),
      );
}

/// The quest totals inside an answer reply.
class QuestProgress {
  const QuestProgress({
    required this.no,
    required this.completed,
    required this.answered,
    required this.size,
    required this.right,
    required this.score,
    required this.passed,
    required this.kmExpected,
    required this.km,
  });

  final int no;
  final bool completed;
  final int answered;
  final int size;
  final int right;
  final double? score;
  final bool? passed;
  final double kmExpected;
  final double km;

  factory QuestProgress.fromJson(Map<String, dynamic> j) => QuestProgress(
        no: j.integer('no'),
        completed: j.boolean('completed'),
        answered: j.integer('answered'),
        size: j.integer('size'),
        right: j.integer('right'),
        score: j.numberOrNull('score'),
        passed: j.boolOrNull('passed'),
        kmExpected: j.number('km_expected'),
        km: j.number('km'),
      );
}

/// `POST /msafara/quests/{no}/answer`.
class AnswerResult {
  const AnswerResult({
    required this.questionId,
    required this.alreadyAnswered,
    required this.correct,
    required this.chosen,
    required this.answerLabel,
    required this.explanation,
    required this.pageRef,
    required this.quest,
  });

  final int questionId;
  final bool alreadyAnswered;
  final bool correct;
  final String? chosen;
  final String? answerLabel;
  final String? explanation;
  final int? pageRef;
  final QuestProgress quest;

  factory AnswerResult.fromJson(Map<String, dynamic> j) => AnswerResult(
        questionId: j.integer('question_id'),
        alreadyAnswered: j.boolean('already_answered'),
        correct: j.boolean('correct'),
        chosen: j.strOrNull('chosen'),
        answerLabel: j.strOrNull('answer_label'),
        explanation: j.strOrNull('explanation'),
        pageRef: j.intOrNull('page_ref'),
        quest: QuestProgress.fromJson(j.obj('quest')),
      );
}
