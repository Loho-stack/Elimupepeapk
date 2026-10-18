import '../json.dart';

class BoardRow {
  const BoardRow({
    required this.rank,
    required this.displayName,
    required this.km,
    required this.county,
    required this.grade,
    required this.movement,
    required this.me,
  });

  final int rank;

  /// Already reduced by the display rule ("Amina W.", or "A." without parental consent). Shown as sent.
  final String displayName;
  final double km;
  final String? county;
  final String? grade;

  /// Positive: moved up that many places against the previous period. Null: no previous rank.
  final int? movement;
  final bool me;

  factory BoardRow.fromJson(Map<String, dynamic> j) => BoardRow(
        rank: j.integer('rank'),
        displayName: j.str('display_name'),
        km: j.number('km'),
        county: j.strOrNull('county'),
        grade: j.strOrNull('grade'),
        movement: j.intOrNull('movement'),
        me: j.boolOrNull('me') ?? false,
      );
}

/// The learner's own snapshot row, even when not eligible (no rank) or hidden.
class BoardMe {
  const BoardMe({
    required this.rank,
    required this.km,
    required this.eligible,
    required this.hidden,
    required this.displayName,
    required this.movement,
  });

  final int? rank;
  final double km;
  final bool eligible;
  final bool hidden;
  final String? displayName;
  final int? movement;

  factory BoardMe.fromJson(Map<String, dynamic> j) => BoardMe(
        rank: j.intOrNull('rank'),
        km: j.numberOrNull('km') ?? 0,
        eligible: j.boolOrNull('eligible') ?? false,
        hidden: j.boolOrNull('hidden') ?? false,
        displayName: j.strOrNull('display_name'),
        movement: j.intOrNull('movement'),
      );
}

/// `GET /msafara/boards/{daily|weekly}`: the learner's own grade band only.
class Board {
  const Board({
    required this.board,
    required this.periodKey,
    required this.open,
    required this.gradeBand,
    required this.top,
    required this.rows,
    required this.me,
    required this.hideName,
    required this.eligibleRule,
  });

  /// `daily` or `weekly`.
  final String board;
  final String periodKey;

  /// False (and [rows] empty) outside days 1 to 92.
  final bool open;
  final String? gradeBand;
  final int top;
  final List<BoardRow> rows;
  final BoardMe? me;
  final bool hideName;
  final String? eligibleRule;

  bool get weekly => board == 'weekly';
  bool get meInRows => rows.any((r) => r.me);

  factory Board.fromJson(Map<String, dynamic> j) => Board(
        board: j.str('board'),
        periodKey: j.str('period_key'),
        open: j.boolean('open'),
        gradeBand: j.strOrNull('grade_band'),
        top: j.intOrNull('top') ?? 50,
        rows: j.list('rows', BoardRow.fromJson),
        me: j.objOrNull('me') == null ? null : BoardMe.fromJson(j.obj('me')),
        hideName: j.boolOrNull('hide_name') ?? false,
        eligibleRule: j.strOrNull('eligible_rule'),
      );
}
