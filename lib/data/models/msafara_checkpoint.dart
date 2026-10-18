import '../json.dart';

/// One attempt at a checkpoint question.
class CheckpointAttempt {
  const CheckpointAttempt({
    required this.attempt,
    required this.chosen,
    required this.correct,
    required this.late,
    required this.answeredAt,
  });

  final int attempt;
  final String chosen;
  final bool correct;
  final bool late;
  final DateTime? answeredAt;

  factory CheckpointAttempt.fromJson(Map<String, dynamic> j) => CheckpointAttempt(
        attempt: j.integer('attempt'),
        chosen: j.str('chosen'),
        correct: j.boolean('correct'),
        late: j.boolOrNull('late') ?? false,
        answeredAt: j.timeOrNull('answered_at'),
      );
}

/// `GET /msafara/checkpoint/{day?}`: the "Did you know" of a town and its one question.
class Checkpoint {
  const Checkpoint({
    required this.day,
    required this.date,
    required this.state,
    required this.town,
    required this.county,
    required this.special,
    required this.fact,
    required this.question,
    required this.options,
    required this.canAnswer,
    required this.attemptsLeft,
    required this.maxAttempts,
    required this.solved,
    required this.answers,
    required this.late,
    required this.kmExpected,
    required this.fullKm,
    required this.coinsExpected,
    required this.correctAnswer,
    required this.listen,
  });

  /// 0 is the Launch Day welcome checkpoint (practice: no km or coins).
  final int day;
  final DateTime? date;

  /// `locked|open|late|closed`.
  final String state;
  final String town;
  final String? county;
  final String? special;

  /// Null with [question] and [options] when no approved question exists for the learner's band yet.
  final String? fact;
  final String? question;
  final List<String> options;
  final bool canAnswer;
  final int attemptsLeft;
  final int maxAttempts;
  final bool solved;
  final List<CheckpointAttempt> answers;
  final bool late;
  final double kmExpected;
  final double fullKm;
  final int coinsExpected;

  /// Only once solved or out of tries.
  final String? correctAnswer;
  final bool listen;

  bool get bandPending => question == null;
  bool get isLaunchDay => day == 0;
  bool get finished => solved || (answers.isNotEmpty && attemptsLeft == 0);

  factory Checkpoint.fromJson(Map<String, dynamic> j) => Checkpoint(
        day: j.integer('day'),
        date: j.timeOrNull('date'),
        state: j.str('state'),
        town: j.str('town'),
        county: j.strOrNull('county'),
        special: j.strOrNull('special'),
        fact: j.strOrNull('fact'),
        question: j.strOrNull('question'),
        options: [for (final o in (j['options'] as List? ?? const [])) o.toString()],
        canAnswer: j.boolean('can_answer'),
        attemptsLeft: j.integer('attempts_left'),
        maxAttempts: j.integer('max_attempts'),
        solved: j.boolean('solved'),
        answers: j['answers'] == null ? const [] : j.list('answers', CheckpointAttempt.fromJson),
        late: j.boolean('late'),
        kmExpected: j.number('km_expected'),
        fullKm: j.number('full_km'),
        coinsExpected: j.integer('coins_expected'),
        correctAnswer: j.strOrNull('correct_answer'),
        listen: j.boolOrNull('listen') ?? false,
      );
}

/// `POST /msafara/checkpoint/{day}`.
class CheckpointResult {
  const CheckpointResult({
    required this.day,
    required this.attempt,
    required this.correct,
    required this.late,
    required this.attemptsLeft,
    required this.solved,
    required this.coins,
    required this.kmExpected,
    required this.correctAnswer,
  });

  final int day;
  final int attempt;
  final bool correct;
  final bool late;
  final int attemptsLeft;
  final bool solved;
  final double coins;
  final double kmExpected;
  final String? correctAnswer;

  factory CheckpointResult.fromJson(Map<String, dynamic> j) => CheckpointResult(
        day: j.integer('day'),
        attempt: j.integer('attempt'),
        correct: j.boolean('correct'),
        late: j.boolean('late'),
        attemptsLeft: j.integer('attempts_left'),
        solved: j.boolean('solved'),
        coins: j.number('coins'),
        kmExpected: j.number('km_expected'),
        correctAnswer: j.strOrNull('correct_answer'),
      );
}
