import '../json.dart';
import 'msafara_quests.dart';

/// `GET /msafara/me`.
class MeData {
  const MeData({
    required this.name,
    required this.grade,
    required this.gradeKey,
    required this.gradeBand,
    required this.county,
    required this.boardName,
    required this.parentalConsent,
    required this.hideName,
    required this.boards,
    required this.sound,
    required this.km,
  });

  final String name;
  final String? grade;
  final String? gradeKey;

  /// `PP|G1-3|G4-6|G7-9|G10`, or null when the grade is outside PP1 to Grade 10.
  final String? gradeBand;
  final String? county;

  /// Exactly what a leaderboard row would show for this learner.
  final String? boardName;
  final bool parentalConsent;
  final bool hideName;

  /// The leaderboards are switched on.
  final bool boards;
  final bool sound;
  final Km km;

  MeData copyWith({bool? hideName, bool? sound}) => MeData(
        name: name,
        grade: grade,
        gradeKey: gradeKey,
        gradeBand: gradeBand,
        county: county,
        boardName: boardName,
        parentalConsent: parentalConsent,
        hideName: hideName ?? this.hideName,
        boards: boards,
        sound: sound ?? this.sound,
        km: km,
      );

  factory MeData.fromJson(Map<String, dynamic> j) => MeData(
        name: j.str('name'),
        grade: j.strOrNull('grade'),
        gradeKey: j.strOrNull('grade_key'),
        gradeBand: j.strOrNull('grade_band'),
        county: j.strOrNull('county'),
        boardName: j.strOrNull('board_name'),
        parentalConsent: j.boolOrNull('parental_consent') ?? false,
        hideName: j.boolean('hide_name'),
        boards: j.boolean('boards'),
        sound: j.boolean('sound'),
        km: Km.fromJson(j.obj('km')),
      );
}
