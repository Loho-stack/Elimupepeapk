import 'package:dio/dio.dart';

import '../core/network/api_exception.dart';

/// Every failure a repository can throw. Screens switch on the type and show
/// [message], a short friendly sentence written here. The server text is never
/// shown: it can name tables, ids or internals.
sealed class AppApiError implements Exception {
  const AppApiError();

  /// Safe to show to a learner.
  String get message;

  /// True when trying the same action again later can work.
  bool get retryable => false;

  @override
  String toString() => '$runtimeType';

  /// Maps whatever a Dio call threw (or a parse failure) to one of the types.
  static AppApiError from(Object error) {
    if (error is AppApiError) return error;
    if (error is FormatException || error is TypeError) {
      return const ParseError();
    }
    if (error is OfflineException) return const OfflineError();
    if (error is SessionExpiredException) return const SessionExpiredError();
    if (error is DioException) return _fromDio(error);
    return const UnknownError();
  }

  static AppApiError _fromDio(DioException e) {
    if (e.error is OfflineException) return const OfflineError();
    if (e.error is SessionExpiredException) return const SessionExpiredError();

    final response = e.response;
    if (response == null) {
      return switch (e.type) {
        DioExceptionType.connectionError ||
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          const OfflineError(),
        _ => const UnknownError(),
      };
    }

    final status = response.statusCode ?? 0;
    final body = response.data;
    final map = body is Map ? Map<String, dynamic>.from(body) : const <String, dynamic>{};
    final code = map['error_code'] is String ? map['error_code'] as String : null;
    final errors = _fieldErrors(map['errors']);

    switch (status) {
      case 401:
        return const SessionExpiredError();
      case 403:
        return switch (code) {
          'subscription_required' => const SubscriptionRequiredError(),
          'lesson_locked' => LessonLockedError(lock: map['lock'] as String?),
          'access_expired' => const AccessExpiredError(),
          _ => ForbiddenError(code: code),
        };
      case 404:
        return const NotFoundError();
      case 409:
        // 409 without a code is the Idempotency-Key "request in progress" answer.
        return code == null ? const InFlightError() : ConflictError(code: code);
      case 422:
        if (errors.containsKey('Idempotency-Key')) return const IdempotencyKeyError();
        return ValidationError(fields: errors);
      case 429:
        return RateLimitedError(retryAfter: _retryAfter(response));
      default:
        return status >= 500 ? const ServerError() : const UnknownError();
    }
  }

  static Map<String, List<String>> _fieldErrors(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        entry.key.toString(): [
          if (entry.value is List) ...(entry.value as List).map((v) => v.toString()),
        ],
    };
  }

  static Duration? _retryAfter(Response<dynamic> r) {
    final secs = int.tryParse((r.headers.value('retry-after') ?? '').trim());
    return secs == null ? null : Duration(seconds: secs);
  }
}

class OfflineError extends AppApiError {
  const OfflineError();
  @override
  String get message => 'No internet connection. Check it and try again.';
  @override
  bool get retryable => true;
}

class SessionExpiredError extends AppApiError {
  const SessionExpiredError();
  @override
  String get message => 'Your session ended. Please log in again.';
}

class SubscriptionRequiredError extends AppApiError {
  const SubscriptionRequiredError();
  @override
  String get message => 'A subscription is needed to open this.';
}

/// A lesson that is closed for now. [lock] is `drip`, `order` or `enrol`.
class LessonLockedError extends AppApiError {
  const LessonLockedError({this.lock});
  final String? lock;
  @override
  String get message => switch (lock) {
        'drip' => 'This lesson opens on a later day.',
        'order' => 'Finish the lesson before it first.',
        'enrol' => 'Join this learning area to open this lesson.',
        _ => 'This lesson is not open yet.',
      };
}

class AccessExpiredError extends AppApiError {
  const AccessExpiredError();
  @override
  String get message => 'Your time on this learning area has ended.';
}

class ForbiddenError extends AppApiError {
  const ForbiddenError({this.code});
  final String? code;
  @override
  String get message => 'You cannot open this.';
}

/// Also what the server answers for something that exists but is not yours.
class NotFoundError extends AppApiError {
  const NotFoundError();
  @override
  String get message => 'We could not find that. It may have been removed.';
}

/// 409 with a code. `question_answered`: the question has a reply, so it cannot
/// be edited any more.
class ConflictError extends AppApiError {
  const ConflictError({required this.code});
  final String code;
  bool get questionAnswered => code == 'question_answered';
  @override
  String get message => questionAnswered
      ? 'This question has an answer, so it cannot be changed.'
      : 'That cannot be done right now.';
}

/// 409 without a code: the same action is still being processed.
class InFlightError extends AppApiError {
  const InFlightError();
  @override
  String get message => 'Still working on it. Try again in a moment.';
  @override
  bool get retryable => true;
}

class ValidationError extends AppApiError {
  const ValidationError({this.fields = const {}});
  final Map<String, List<String>> fields;
  bool has(String field) => fields.containsKey(field);
  @override
  String get message => 'Check what you entered and try again.';
}

/// 422 about the Idempotency-Key itself: a bug in the app, never the learner's doing.
class IdempotencyKeyError extends AppApiError {
  const IdempotencyKeyError();
  @override
  String get message => 'Something went wrong on our side. Please try again.';
}

class RateLimitedError extends AppApiError {
  const RateLimitedError({this.retryAfter});
  final Duration? retryAfter;
  @override
  String get message => 'Too many tries. Wait a little and try again.';
  @override
  bool get retryable => true;
}

class ServerError extends AppApiError {
  const ServerError();
  @override
  String get message => 'Something went wrong on our side. Try again soon.';
  @override
  bool get retryable => true;
}

/// The server answered, but not in the shape this app version knows.
class ParseError extends AppApiError {
  const ParseError();
  @override
  String get message => 'We could not read the answer. Update the app and try again.';
}

class UnknownError extends AppApiError {
  const UnknownError();
  @override
  String get message => 'Something went wrong. Please try again.';
  @override
  bool get retryable => true;
}
