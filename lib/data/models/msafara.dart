import '../json.dart';

/// `state.stage` of `GET /msafara/state`. An unknown value reads as [disabled]
/// so a newer server never traps the learner in a screen this build lacks.
enum QuestStage {
  disabled,
  hidden,
  countdown,
  terms,
  profile,
  active;

  static QuestStage parse(String v) => values.firstWhere((s) => s.name == v, orElse: () => disabled);
}

class QuestFlags {
  const QuestFlags({required this.boards, required this.map});
  final bool boards;
  final bool map;

  factory QuestFlags.fromJson(Map<String, dynamic> j) =>
      QuestFlags(boards: j.boolean('boards'), map: j.boolean('map'));
}

class QuestToday {
  const QuestToday({
    required this.day,
    required this.date,
    required this.totalDays,
    required this.leg,
    required this.legName,
    required this.dayType,
    required this.town,
    required this.special,
  });

  /// 0 on a Day 0, 1 to 92 in the run, null outside it.
  final int? day;
  final String? date;
  final int totalDays;
  final int? leg;
  final String? legName;
  final String? dayType;
  final String? town;
  final String? special;

  factory QuestToday.fromJson(Map<String, dynamic> j) => QuestToday(
        day: j.intOrNull('day'),
        date: j.strOrNull('date'),
        totalDays: j.integer('total_days'),
        leg: j.intOrNull('leg'),
        legName: j.strOrNull('leg_name'),
        dayType: j.strOrNull('day_type'),
        town: j.strOrNull('town'),
        special: j.strOrNull('special'),
      );
}

class QuestCalendar {
  const QuestCalendar({required this.today, required this.startsOn, required this.ended});
  final QuestToday today;
  final String? startsOn;
  final bool ended;

  factory QuestCalendar.fromJson(Map<String, dynamic> j) => QuestCalendar(
        today: QuestToday.fromJson(j.obj('today')),
        startsOn: j.strOrNull('starts_on'),
        ended: j.boolean('ended'),
      );
}

class QuestLearner {
  const QuestLearner({required this.gradeBand, required this.hideName, required this.sound});
  final String gradeBand;
  final bool hideName;
  final bool sound;

  factory QuestLearner.fromJson(Map<String, dynamic> j) => QuestLearner(
        gradeBand: j.str('grade_band'),
        hideName: j.boolean('hide_name'),
        sound: j.boolean('sound'),
      );
}

/// `GET /msafara/state`: the one call that decides which screen to show.
class MsafaraState {
  const MsafaraState({
    required this.stage,
    required this.serverTime,
    required this.secondsToStart,
    required this.opensAt,
    required this.seat,
    required this.seatsReserved,
    required this.termsVersion,
    required this.termsAccepted,
    required this.profileMissing,
    required this.flags,
    required this.calendar,
    required this.learner,
  });

  final QuestStage stage;
  final DateTime serverTime;

  /// Null unless [stage] is `countdown`.
  final int? secondsToStart;
  final DateTime? opensAt;

  /// `open` (terms not accepted), `profile`, `reserved`; null when disabled or hidden.
  final String? seat;
  final int seatsReserved;
  final String termsVersion;
  final bool termsAccepted;
  final List<String> profileMissing;
  final QuestFlags flags;
  final QuestCalendar calendar;
  final QuestLearner? learner;

  factory MsafaraState.fromJson(Map<String, dynamic> j) => MsafaraState(
        stage: QuestStage.parse(j.str('stage')),
        serverTime: j.time('server_time'),
        secondsToStart: j.intOrNull('seconds_to_start'),
        opensAt: j.timeOrNull('opens_at'),
        seat: j.strOrNull('seat'),
        seatsReserved: j.integer('seats_reserved'),
        termsVersion: j.str('terms_version'),
        termsAccepted: j.boolean('terms_accepted'),
        profileMissing: [for (final m in (j['profile_missing'] as List? ?? const [])) m.toString()],
        flags: QuestFlags.fromJson(j.obj('flags')),
        calendar: QuestCalendar.fromJson(j.obj('calendar')),
        learner: j.objOrNull('learner') == null ? null : QuestLearner.fromJson(j.obj('learner')),
      );
}

class TermsSection {
  const TermsSection({required this.heading, required this.items});
  final String heading;
  final List<String> items;

  factory TermsSection.fromJson(Map<String, dynamic> j) => TermsSection(
        heading: j.str('heading'),
        items: [for (final i in (j['items'] as List? ?? const [])) i.toString()],
      );
}

class TermsAttestation {
  const TermsAttestation({required this.key, required this.label, this.note});

  /// `accept_terms` or `parent_agreed`: the body field to send as `true`.
  final String key;
  final String label;
  final String? note;

  factory TermsAttestation.fromJson(Map<String, dynamic> j) =>
      TermsAttestation(key: j.str('key'), label: j.str('label'), note: j.strOrNull('note'));
}

/// `GET /msafara/terms`. The text is DP-approved: it is shown exactly as sent.
class Terms {
  const Terms({
    required this.version,
    required this.lang,
    required this.accepted,
    required this.contactEmail,
    required this.title,
    required this.intro,
    required this.sections,
    required this.attestations,
    required this.continueLabel,
  });

  final String version;
  final String lang;
  final bool accepted;
  final String? contactEmail;
  final String title;
  final String intro;
  final List<TermsSection> sections;
  final List<TermsAttestation> attestations;
  final String continueLabel;

  factory Terms.fromJson(Map<String, dynamic> j) => Terms(
        version: j.str('version'),
        lang: j.str('lang'),
        accepted: j.boolean('accepted'),
        contactEmail: j.strOrNull('contact_email'),
        title: j.str('title'),
        intro: j.str('intro'),
        sections: j.list('sections', TermsSection.fromJson),
        attestations: j.list('attestations', TermsAttestation.fromJson),
        continueLabel: j.str('continue_label'),
      );
}

/// `POST /msafara/terms`.
class TermsResult {
  const TermsResult({required this.accepted, required this.version, required this.recorded, required this.stage});
  final bool accepted;
  final String version;
  final bool recorded;
  final QuestStage stage;

  factory TermsResult.fromJson(Map<String, dynamic> j) => TermsResult(
        accepted: j.boolean('accepted'),
        version: j.str('version'),
        recorded: j.boolean('recorded'),
        stage: QuestStage.parse(j.str('stage')),
      );
}

class GradeOption {
  const GradeOption({required this.key, required this.label});
  final String key;
  final String label;

  factory GradeOption.fromJson(Map<String, dynamic> j) => GradeOption(key: j.str('key'), label: j.str('label'));
}

/// `GET /msafara/profile`.
class ProfileForm {
  const ProfileForm({
    required this.missing,
    required this.grade,
    required this.county,
    required this.grades,
    required this.counties,
  });

  /// `grade` and/or `county`. A field that is not missing is read only.
  final List<String> missing;
  final String? grade;
  final String? county;
  final List<GradeOption> grades;
  final List<String> counties;

  bool get needsGrade => missing.contains('grade');
  bool get needsCounty => missing.contains('county');

  factory ProfileForm.fromJson(Map<String, dynamic> j) => ProfileForm(
        missing: [for (final m in (j['missing'] as List? ?? const [])) m.toString()],
        grade: j.strOrNull('grade'),
        county: j.strOrNull('county'),
        grades: j.list('grades', GradeOption.fromJson),
        counties: [for (final c in (j['counties'] as List? ?? const [])) c.toString()],
      );
}

/// `POST /msafara/profile`.
class ProfileResult {
  const ProfileResult({
    required this.missing,
    required this.grade,
    required this.gradeLabel,
    required this.county,
    required this.gradeBand,
    required this.stage,
  });

  final List<String> missing;
  final String? grade;
  final String? gradeLabel;
  final String? county;
  final String? gradeBand;
  final QuestStage stage;

  factory ProfileResult.fromJson(Map<String, dynamic> j) => ProfileResult(
        missing: [for (final m in (j['missing'] as List? ?? const [])) m.toString()],
        grade: j.strOrNull('grade'),
        gradeLabel: j.strOrNull('grade_label'),
        county: j.strOrNull('county'),
        gradeBand: j.strOrNull('grade_band'),
        stage: QuestStage.parse(j.str('stage')),
      );
}
