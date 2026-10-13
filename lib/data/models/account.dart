import '../json.dart';

/// A row of `GET /student/questions` (E-31), and the head of E-33.
class MyQuestion {
  const MyQuestion({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.lessonId,
    required this.lessonName,
    required this.text,
    required this.approved,
    required this.answered,
    required this.answersCount,
    required this.createdAt,
    this.answers = const [],
  });

  final int id;
  final int courseId;
  final String courseTitle;
  final int lessonId;
  final String lessonName;
  final String text;

  /// `approved`, otherwise it is waiting for review.
  final bool approved;
  final bool answered;
  final int answersCount;
  final DateTime? createdAt;

  /// Only on the detail call (E-33).
  final List<QuestionAnswer> answers;

  factory MyQuestion.fromJson(Map<String, dynamic> j) {
    final course = j.obj('course');
    final lesson = j.obj('lesson');
    final status = j.str('status');
    if (status != 'approved' && status != 'pending') {
      throw FormatException('unknown question status "$status"');
    }
    return MyQuestion(
      id: j.integer('id'),
      courseId: course.integer('id'),
      courseTitle: course.str('title'),
      lessonId: lesson.integer('id'),
      lessonName: lesson.str('name'),
      text: j.str('text'),
      approved: status == 'approved',
      answered: j.boolean('answered'),
      answersCount: j.integer('answers_count'),
      createdAt: j.timeOrNull('created_at'),
      answers: j['answers'] == null ? const [] : j.list('answers', QuestionAnswer.fromJson),
    );
  }
}

class QuestionAnswer {
  const QuestionAnswer({required this.id, required this.text, required this.who, required this.createdAt});
  final int id;
  final String text;
  final String who;
  final DateTime? createdAt;
  factory QuestionAnswer.fromJson(Map<String, dynamic> j) => QuestionAnswer(
        id: j.integer('id'),
        text: j.str('text'),
        who: j.str('who'),
        createdAt: j.timeOrNull('created_at'),
      );
}

/// A page of a list answer, with the server's `meta`.
class Paged<T> {
  const Paged({required this.items, required this.currentPage, required this.lastPage, required this.total});
  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;
  bool get hasMore => currentPage < lastPage;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.readAt,
    required this.createdAt,
  });
  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime? readAt;
  final DateTime? createdAt;
  bool get unread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j.str('id'),
        type: j.str('type'),
        title: j.str('title'),
        body: j.str('body'),
        readAt: j.timeOrNull('read_at'),
        createdAt: j.timeOrNull('created_at'),
      );
}

/// `GET /me` (E-07). Student fields are set for students; the others for parent and teacher.
class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.role,
    required this.avatarUrl,
    required this.language,
    this.studentId,
    this.grade,
    this.email,
    this.childrenCount,
    this.schoolId,
  });
  final int id;
  final String name;

  /// `student`, `parent`, `teacher` or `other`.
  final String role;
  final String? avatarUrl;
  final String language;
  final String? studentId;
  final String? grade;
  final String? email;
  final int? childrenCount;
  final int? schoolId;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j.integer('id'),
        name: j.str('name'),
        role: j.str('role'),
        avatarUrl: j.strOrNull('avatar_url'),
        language: j.strOrNull('language') ?? 'en',
        studentId: j.strOrNull('student_id'),
        grade: j.strOrNull('grade'),
        email: j.strOrNull('email'),
        childrenCount: j.intOrNull('children_count'),
        schoolId: j.intOrNull('school_id'),
      );
}
