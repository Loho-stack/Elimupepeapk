import '../json.dart';

/// `GET /student/home` (E-23). Fields exactly as App API HomePayload lists them.
class HomeData {
  const HomeData({
    required this.serverTime,
    required this.widgets,
    required this.streak,
    required this.school,
    required this.subscription,
  });

  final DateTime serverTime;
  final HomeWidgets widgets;
  final int streak;
  final HomeSchool? school;
  final SubscriptionInfo subscription;

  factory HomeData.fromJson(Map<String, dynamic> j) => HomeData(
        serverTime: j.time('server_time'),
        widgets: HomeWidgets.fromJson(j.obj('widgets')),
        streak: j.integer('streak'),
        school: j.objOrNull('school') == null ? null : HomeSchool.fromJson(j.obj('school')),
        subscription: SubscriptionInfo.fromJson(j.obj('subscription')),
      );
}

class SubscriptionInfo {
  const SubscriptionInfo({required this.required, required this.active, this.coveredBy});
  final bool required;
  final bool active;

  /// `school`, `organization` or `parent` when someone else pays; null otherwise.
  final String? coveredBy;

  factory SubscriptionInfo.fromJson(Map<String, dynamic> j) => SubscriptionInfo(
        required: j.boolean('required'),
        active: j.boolean('active'),
        coveredBy: j.strOrNull('covered_by'),
      );
}

class HomeWidgets {
  const HomeWidgets({
    required this.continueLearning,
    required this.reading,
    required this.classes,
    required this.dueAssignments,
    required this.returnedAssignments,
    required this.quizzes,
    required this.grades,
    required this.coins,
    required this.week,
    required this.msafara,
    required this.videos,
  });

  final ContinueLearning? continueLearning;
  final List<ReadingBook> reading;
  final List<LiveClass> classes;
  final List<DueAssignment> dueAssignments;
  final List<ReturnedAssignment> returnedAssignments;
  final List<RecentQuiz> quizzes;
  final List<GradeEntry> grades;
  final Coins? coins;
  final LearningWeek? week;
  final MsafaraToday? msafara;
  final List<VideoProgress> videos;

  factory HomeWidgets.fromJson(Map<String, dynamic> j) {
    final assignments = j.obj('assignments');
    return HomeWidgets(
      continueLearning:
          j.objOrNull('continue') == null ? null : ContinueLearning.fromJson(j.obj('continue')),
      reading: j.list('reading', ReadingBook.fromJson),
      classes: j.list('classes', LiveClass.fromJson),
      dueAssignments: assignments.list('due', DueAssignment.fromJson),
      returnedAssignments: assignments.list('returned', ReturnedAssignment.fromJson),
      quizzes: j.list('quizzes', RecentQuiz.fromJson),
      grades: j.list('grades', GradeEntry.fromJson),
      coins: j.objOrNull('coins') == null ? null : Coins.fromJson(j.obj('coins')),
      week: j.objOrNull('week') == null ? null : LearningWeek.fromJson(j.obj('week')),
      msafara: j.objOrNull('msafara') == null ? null : MsafaraToday.fromJson(j.obj('msafara')),
      videos: j.list('videos', VideoProgress.fromJson),
    );
  }
}

class ContinueLearning {
  const ContinueLearning({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.percent,
    required this.done,
    required this.total,
    required this.lessonId,
    required this.lesson,
  });
  final int id;
  final String title;
  final String? thumbnail;
  final int percent;
  final int done;
  final int total;
  final int? lessonId;
  final String? lesson;

  factory ContinueLearning.fromJson(Map<String, dynamic> j) => ContinueLearning(
        id: j.integer('id'),
        title: j.str('title'),
        thumbnail: j.strOrNull('thumbnail'),
        percent: j.integer('percent'),
        done: j.integer('done'),
        total: j.integer('total'),
        lessonId: j.intOrNull('lesson_id'),
        lesson: j.strOrNull('lesson'),
      );
}

class ReadingBook {
  const ReadingBook({required this.id, required this.title, required this.page, required this.percent, required this.thumbnail});
  final int id;
  final String title;
  final int page;
  final int percent;
  final String? thumbnail;

  factory ReadingBook.fromJson(Map<String, dynamic> j) => ReadingBook(
        id: j.integer('id'),
        title: j.str('title'),
        page: j.integer('page'),
        percent: j.integer('percent'),
        thumbnail: j.strOrNull('thumbnail'),
      );
}

/// A live class today. Read-only in Phase 4a: joining arrives with the live class endpoints.
class LiveClass {
  const LiveClass({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.when,
    required this.time,
    required this.canJoin,
    required this.live,
  });
  final int id;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final String when;
  final String time;
  final bool canJoin;
  final bool live;

  factory LiveClass.fromJson(Map<String, dynamic> j) => LiveClass(
        id: j.integer('id'),
        title: j.str('title'),
        startsAt: j.time('starts_at'),
        endsAt: j.time('ends_at'),
        when: j.str('when'),
        time: j.str('time'),
        canJoin: j.boolean('can_join'),
        live: j.boolean('live'),
      );
}

class DueAssignment {
  const DueAssignment({required this.id, required this.title, required this.deadline, required this.overdue, required this.urgent});
  final int id;
  final String title;
  final String? deadline;
  final bool overdue;
  final bool urgent;

  factory DueAssignment.fromJson(Map<String, dynamic> j) => DueAssignment(
        id: j.integer('id'),
        title: j.str('title'),
        deadline: j.strOrNull('deadline'),
        overdue: j.boolean('overdue'),
        urgent: j.boolean('urgent'),
      );
}

class ReturnedAssignment {
  const ReturnedAssignment({required this.id, required this.title, required this.score, required this.max, required this.on});
  final int id;
  final String title;
  final double? score;
  final double? max;
  final String on;

  factory ReturnedAssignment.fromJson(Map<String, dynamic> j) => ReturnedAssignment(
        id: j.integer('id'),
        title: j.str('title'),
        score: j.numberOrNull('score'),
        max: j.numberOrNull('max'),
        on: j.str('on'),
      );
}

class RecentQuiz {
  const RecentQuiz({
    required this.id,
    required this.title,
    required this.marks,
    required this.total,
    required this.percent,
    required this.passed,
    required this.marked,
    required this.date,
  });
  final int id;
  final String title;
  final double? marks;
  final double? total;
  final int? percent;
  final bool? passed;
  final bool marked;
  final String date;

  factory RecentQuiz.fromJson(Map<String, dynamic> j) => RecentQuiz(
        id: j.integer('id'),
        title: j.str('title'),
        marks: j.numberOrNull('marks'),
        total: j.numberOrNull('total'),
        percent: j.intOrNull('percent'),
        passed: j.boolOrNull('passed'),
        marked: j.boolean('marked'),
        date: j.str('date'),
      );
}

class GradeEntry {
  const GradeEntry({required this.title, required this.score, required this.max, required this.level, required this.on});
  final String title;
  final double? score;
  final double? max;
  final String? level;
  final String on;

  factory GradeEntry.fromJson(Map<String, dynamic> j) => GradeEntry(
        title: j.str('title'),
        score: j.numberOrNull('score'),
        max: j.numberOrNull('max'),
        level: j.strOrNull('level'),
        on: j.str('on'),
      );
}

class Coins {
  const Coins({required this.balance, required this.transactions, required this.badges, required this.milestones});
  final double balance;
  final List<CoinTransaction> transactions;
  final List<CoinBadge> badges;
  final List<CoinMilestone> milestones;

  factory Coins.fromJson(Map<String, dynamic> j) => Coins(
        balance: j.number('balance'),
        transactions: j.list('transactions', CoinTransaction.fromJson),
        badges: j.list('badges', CoinBadge.fromJson),
        milestones: j.list('milestones', CoinMilestone.fromJson),
      );
}

class CoinTransaction {
  const CoinTransaction({required this.amount, required this.label, required this.on});
  final double amount;
  final String label;
  final String on;
  factory CoinTransaction.fromJson(Map<String, dynamic> j) =>
      CoinTransaction(amount: j.number('amount'), label: j.str('label'), on: j.str('on'));
}

class CoinBadge {
  const CoinBadge({required this.name, required this.tier, required this.on});
  final String name;
  final String? tier;
  final String on;
  factory CoinBadge.fromJson(Map<String, dynamic> j) =>
      CoinBadge(name: j.str('name'), tier: j.strOrNull('tier'), on: j.str('on'));
}

class CoinMilestone {
  const CoinMilestone({required this.name, required this.on});
  final String name;
  final String on;
  factory CoinMilestone.fromJson(Map<String, dynamic> j) => CoinMilestone(name: j.str('name'), on: j.str('on'));
}

class LearningWeek {
  const LearningWeek({required this.days, required this.totalMinutes});
  final List<WeekDay> days;
  final int totalMinutes;

  factory LearningWeek.fromJson(Map<String, dynamic> j) =>
      LearningWeek(days: j.list('days', WeekDay.fromJson), totalMinutes: j.integer('total_minutes'));
}

class WeekDay {
  const WeekDay({required this.label, required this.minutes, required this.today});
  final String label;
  final int minutes;
  final bool today;
  factory WeekDay.fromJson(Map<String, dynamic> j) =>
      WeekDay(label: j.str('label'), minutes: j.integer('minutes'), today: j.boolean('today'));
}

class MsafaraToday {
  const MsafaraToday({required this.label, required this.town, required this.done, required this.total, required this.kmToday});
  final String? label;
  final String? town;
  final int done;
  final int total;
  final double kmToday;

  factory MsafaraToday.fromJson(Map<String, dynamic> j) => MsafaraToday(
        label: j.strOrNull('label'),
        town: j.strOrNull('town'),
        done: j.integer('done'),
        total: j.integer('total'),
        kmToday: j.number('km_today'),
      );
}

class VideoProgress {
  const VideoProgress({required this.id, required this.title, required this.percent, required this.thumbnail});
  final int id;
  final String title;
  final int percent;
  final String? thumbnail;
  factory VideoProgress.fromJson(Map<String, dynamic> j) => VideoProgress(
        id: j.integer('id'),
        title: j.str('title'),
        percent: j.integer('percent'),
        thumbnail: j.strOrNull('thumbnail'),
      );
}

/// Present only for learners with a school class.
class HomeSchool {
  const HomeSchool({required this.lessonDay, required this.timetable, required this.calendar, required this.pendingHomework});
  final LessonDay? lessonDay;
  final List<TimetableSlot> timetable;
  final List<CalendarEvent> calendar;
  final List<PendingHomework> pendingHomework;

  factory HomeSchool.fromJson(Map<String, dynamic> j) => HomeSchool(
        lessonDay: j.objOrNull('lesson_day') == null ? null : LessonDay.fromJson(j.obj('lesson_day')),
        timetable: j.list('timetable', TimetableSlot.fromJson),
        calendar: j.list('calendar', CalendarEvent.fromJson),
        pendingHomework: j.list('pending_homework', PendingHomework.fromJson),
      );
}

class LessonDay {
  const LessonDay({required this.name, required this.today, required this.slots});
  final String name;
  final bool today;
  final List<TimetableSlot> slots;
  factory LessonDay.fromJson(Map<String, dynamic> j) =>
      LessonDay(name: j.str('name'), today: j.boolean('today'), slots: j.list('slots', TimetableSlot.fromJson));
}

class TimetableSlot {
  const TimetableSlot({required this.day, required this.time, required this.subject, required this.teacher});
  final String day;
  final String time;
  final String subject;
  final String? teacher;
  factory TimetableSlot.fromJson(Map<String, dynamic> j) => TimetableSlot(
        day: j.strOrNull('day') ?? '',
        time: j.strOrNull('time') ?? '',
        subject: j.strOrNull('subject') ?? '',
        teacher: j.strOrNull('teacher'),
      );
}

class CalendarEvent {
  const CalendarEvent({required this.title, required this.date, required this.time, required this.body, required this.type});
  final String title;
  final String? date;
  final String? time;
  final String? body;
  final String? type;
  factory CalendarEvent.fromJson(Map<String, dynamic> j) => CalendarEvent(
        title: j.strOrNull('title') ?? '',
        date: j.strOrNull('date'),
        time: j.strOrNull('time'),
        body: j.strOrNull('body'),
        type: j.strOrNull('type'),
      );
}

class PendingHomework {
  const PendingHomework({
    required this.id,
    required this.title,
    required this.type,
    required this.deadlineAt,
    required this.deadline,
    required this.isUrgent,
  });
  final int id;
  final String title;
  final String? type;
  final DateTime? deadlineAt;
  final String? deadline;
  final bool isUrgent;
  factory PendingHomework.fromJson(Map<String, dynamic> j) => PendingHomework(
        id: j.integer('id'),
        title: j.str('title'),
        type: j.strOrNull('type'),
        deadlineAt: j.timeOrNull('deadline_at'),
        deadline: j.strOrNull('deadline'),
        isUrgent: j.boolean('is_urgent'),
      );
}
