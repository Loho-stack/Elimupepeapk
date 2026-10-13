import '../../core/network/api_client.dart';
import '../api_call.dart';
import 'repositories.dart';

/// The repositories of App API v1, built on the one `ApiClient.appV1` Dio so
/// they share its auth, 401 refresh and 429 back-off.
class AppRepositories {
  AppRepositories(ApiCall api)
      : home = HomeRepository(api),
        learning = LearningRepository(api),
        lessons = LessonRepository(api),
        questions = QuestionsRepository(api),
        notifications = NotificationsRepository(api),
        account = AccountRepository(api);

  factory AppRepositories.fromClient(ApiClient client) =>
      AppRepositories(ApiCall(client.appV1));

  final HomeRepository home;
  final LearningRepository learning;
  final LessonRepository lessons;
  final QuestionsRepository questions;
  final NotificationsRepository notifications;
  final AccountRepository account;
}
