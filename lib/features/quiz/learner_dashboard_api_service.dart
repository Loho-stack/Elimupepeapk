import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:elimupepe/app/app_services.dart';
import 'package:elimupepe/core/services/auth_service.dart';
import 'package:elimupepe/core/services/user_data_service.dart';

class LearnerDashboardApiService {
  static final LearnerDashboardApiService instance =
      LearnerDashboardApiService._internal();
  factory LearnerDashboardApiService() => instance;
  LearnerDashboardApiService._internal();

  /// The shared client adds the bearer token, handles 401 (refresh or
  /// logout) and 429 backoff, and maps 401/404 to friendly messages.
  Dio get _dio => AppServices.instance.apiClient.api;

  Future<String?> _getToken() async {
    return AuthService.instance.getToken();
  }

  Future<List<dynamic>> fetchCourses() =>
      _fetchAuthorizedCollection('/student/courses');

  Future<List<dynamic>> fetchQuizzes() =>
      _fetchAuthorizedCollection('/student/quizzes');

  Future<List<dynamic>> fetchBooks() =>
      _fetchAuthorizedCollection('/student/books');

  Future<List<dynamic>> fetchLabs() =>
      _fetchAuthorizedCollection('/student/labs');

  Future<List<dynamic>> fetchELibrary() =>
      _fetchAuthorizedCollection('/student/elibrary');

  Future<Map<String, dynamic>?> fetchGamificationDashboard() =>
      _fetchAuthorizedMap('/student/dashboard');

  Future<Map<String, dynamic>?> fetchWallet() =>
      _fetchAuthorizedMap('/student/wallet');

  Future<List<dynamic>> fetchTransactions() =>
      _fetchAuthorizedCollection('/student/transactions');

  Future<Map<String, dynamic>?> fetchStreaks() =>
      _fetchAuthorizedMap('/student/streaks');

  Future<List<dynamic>> fetchMilestones() =>
      _fetchAuthorizedCollection('/student/milestones');

  Future<List<dynamic>> fetchCompetencies() =>
      _fetchAuthorizedCollection('/student/competencies');

  Future<Map<String, dynamic>?> fetchWeeklyGoal() =>
      _fetchAuthorizedMap('/student/weekly-goal');

  Future<List<dynamic>> fetchBadges() =>
      _fetchAuthorizedCollection('/student/badges');

  Future<List<dynamic>> fetchMarketplace() =>
      _fetchAuthorizedCollection('/student/marketplace');

  Future<Map<String, dynamic>?> spendCoins(Map<String, dynamic> payload) =>
      _postAuthorizedMap('/student/spend', data: payload);

  Future<List<dynamic>> fetchConsumptionHistory() =>
      _fetchAuthorizedCollection('/student/consumption-history');

  Future<List<dynamic>> fetchLeaderboard() =>
      _fetchAuthorizedCollection('/student/leaderboard');

  Future<List<dynamic>> fetchNotifications() =>
      _fetchAuthorizedCollection('/student/notifications');

  Future<Map<String, dynamic>?> markNotificationsAsRead({
    Map<String, dynamic>? payload,
  }) => _postAuthorizedMap(
    '/student/notifications/mark-read',
    data: payload ?? const {},
  );

  Future<Map<String, dynamic>?> checkSubscriptionStatus() =>
      _postAuthorizedMap('/student/subscription/check');

  Future<Map<String, dynamic>?> fetchProfile() =>
      _postAuthorizedMap('/student/profile');

  Future<Map<String, dynamic>?> updateProfile(Map<String, dynamic> payload) =>
      _postAuthorizedMap('/student/profile/update', data: payload);

  Future<Map<String, dynamic>?> uploadStudentAvatar(String avatarPath) async {
    // Prepare the multipart form data for file upload.
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(avatarPath),
    });

    // API Endpoint Strategy:
    // 1. Try the modern, token-based endpoint first: POST /student/avatar
    // 2. Fallback to the older, ID-based endpoint: POST /students/{id}/avatar

    try {
      final response = await _dio.post(
        '/student/avatar',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return _extractMap(response.data);
      }
    } on DioException catch (e) {
      debugPrint(
        'Learner API -> POST /student/avatar failed (${e.response?.statusCode}), trying ID-based fallback.',
      );
    }

    // Fallback to ID-based endpoint.
    final studentId = await _getStudentId();
    if (studentId != null) {
      try {
        final response = await _dio.post(
          '/students/$studentId/avatar',
          data: formData,
          options: Options(headers: {'Content-Type': 'multipart/form-data'}),
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          return _extractMap(response.data);
        }
      } on DioException catch (e) {
        debugPrint(
          'Learner API -> POST /students/$studentId/avatar also failed (${e.response?.statusCode}).',
        );
      }
    }

    // If both attempts fail, throw a clear exception.
    throw Exception(
      'Avatar upload failed. Please check your connection and try again.',
    );
  }

  Future<Map<String, dynamic>?> fetchStudentGradebook() async {
    // API Endpoint Strategy:
    // 1. Try the modern, token-based endpoint first: GET /student/gradebook
    // 2. Fallback to the older, ID-based endpoint: GET /students/{id}/gradebook

    try {
      final response = await _dio.get('/student/gradebook');
      if (response.statusCode == 200) {
        // Use compute() to parse large JSON payloads on a background isolate
        // to prevent blocking the UI thread.
        final data = await compute(_extractMapPayload, response.data);
        if (data != null && data.isNotEmpty) {
          return data;
        }
      }
    } on DioException catch (e) {
      debugPrint(
        'Learner API -> GET /student/gradebook failed (${e.response?.statusCode}), trying ID-based fallback.',
      );
    }

    // Fallback to ID-based endpoint.
    final studentId = await _getStudentId();
    if (studentId != null) {
      try {
        final response = await _dio.get('/students/$studentId/gradebook');
        if (response.statusCode == 200) {
          return await compute(_extractMapPayload, response.data);
        }
      } on DioException catch (e) {
        debugPrint(
          'Learner API -> GET /students/$studentId/gradebook also failed (${e.response?.statusCode}).',
        );
      }
    }

    return null;
  }

  Future<List<dynamic>> fetchGrades() =>
      _fetchAuthorizedCollection('/student/grades');

  Future<Map<String, dynamic>?> startQuiz(Map<String, dynamic> payload) =>
      _postAuthorizedMap('/student/quizStart', data: payload);

  Future<Map<String, dynamic>?> submitSingleQuestion(
    Map<String, dynamic> payload,
  ) => _postAuthorizedMap('/student/singleQusSubmit', data: payload);

  Future<Map<String, dynamic>?> submitFinalQuiz(Map<String, dynamic> payload) =>
      _postAuthorizedMap('/student/finalQusSubmit', data: payload);

  Future<Map<String, dynamic>?> fetchQuizResult(Map<String, dynamic> payload) =>
      _postAuthorizedMap('/student/api.quizResult', data: payload);

  Future<List<dynamic>> fetchMenuItems({required String menuId}) async {
    final endpoints = _menuEndpoints(menuId);
    if (endpoints.isEmpty) {
      return [];
    }

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No active session. Please log in again.');
    }

    try {
      if (menuId == 'interactive_books') {
        return _fetchInteractiveBooks(token);
      }

      if (menuId == 'non_interactive_books') {
        return _fetchNonInteractiveBooks(token);
      }

      for (final endpoint in endpoints) {
        try {
          final items = await _fetchEndpointItems(endpoint, token);
          final filtered = _filterItemsForMenu(items, menuId);
          if (filtered.isNotEmpty) {
            return filtered;
          }

          // Some endpoints can return empty arrays for a user; keep trying fallbacks.
          debugPrint(
            'Learner API [$menuId] -> $endpoint returned empty. Trying next fallback.',
          );
        } on DioException catch (e) {
          if (e.response?.statusCode == 404) {
            debugPrint('Learner API [$menuId] -> $endpoint (404 fallback)');
            continue;
          }
          rethrow;
        }
      }

      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please log in again.');
      }
      if (e.response?.statusCode == 403) {
        throw Exception('Access denied. Student account required.');
      }
      if (e.response?.statusCode == 429) {
        throw Exception('Too many requests. Please try again in a minute.');
      }

      final responseData = e.response?.data;
      if (responseData is Map<String, dynamic>) {
        final message = responseData['message'] ?? responseData['error'];
        if (message is String && message.isNotEmpty) {
          throw Exception(message);
        }
      }

      throw Exception('Could not load data from learner API.');
    } catch (e) {
      throw Exception('Unexpected API error: $e');
    }
  }

  Future<String?> resolveItemContentUrl({
    required String menuId,
    required Map<String, dynamic> item,
  }) async {
    final direct = _extractUrlFromMap(item);
    if (direct != null) {
      return direct;
    }

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    final id = item['id']?.toString();
    final quizId = item['quiz_id']?.toString();
    final detailEndpoints = _detailEndpoints(menuId, id: id, quizId: quizId);

    for (final endpoint in detailEndpoints) {
      try {
        final response = await _dio.get(
          endpoint,
          options: await _authorizedOptions(),
        );

        final nestedUrl = _extractUrlFromAny(response.data);
        if (nestedUrl != null) {
          debugPrint('Resolved content URL [$menuId] from $endpoint');
          return nestedUrl;
        }
      } on DioException {
        // Keep trying fallback detail endpoints.
      }
    }

    if (menuId == 'learning_areas' && id != null && id.isNotEmpty) {
      final linked = await _resolveLearningAreaLinkedUrl(id);
      if (linked != null) {
        return linked;
      }
    }

    return null;
  }

  Future<String?> _resolveLearningAreaLinkedUrl(String courseId) async {
    final candidates = <String, Map<String, dynamic>>{
      '/student/books': {'course_id': courseId},
      '/student/elibrary': {'course_id': courseId},
      '/student/quizzes': {'course_id': courseId},
    };

    for (final entry in candidates.entries) {
      try {
        final response = await _dio.get(
          entry.key,
          queryParameters: entry.value,
          options: await _authorizedOptions(),
        );

        final items = _extractItems(response.data);
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final url = _extractUrlFromMap(item);
            if (url != null) {
              debugPrint(
                'Resolved learning area URL via ${entry.key}?course_id=$courseId',
              );
              return url;
            }
          }
        }
      } on DioException {
        // Try the next candidate endpoint.
      }
    }

    return null;
  }

  Future<List<dynamic>> _fetchInteractiveBooks(String token) async {
    final elibrary = await _fetchEndpointItems('/student/elibrary', token);
    final mapItems = elibrary.whereType<Map<String, dynamic>>().toList();
    return _dedupeByStableKey(mapItems);
  }

  Future<List<dynamic>> _fetchNonInteractiveBooks(String token) async {
    final books = await _fetchEndpointItems('/student/books', token);
    final elibrary = await _fetchEndpointItems('/student/elibrary', token);

    final bookMaps = books.whereType<Map<String, dynamic>>().toList();
    final elibraryIds = elibrary
        .whereType<Map<String, dynamic>>()
        .map((item) => item['id']?.toString())
        .whereType<String>()
        .toSet();

    final nonOverlap = bookMaps
        .where((item) => !elibraryIds.contains(item['id']?.toString()))
        .toList();

    if (nonOverlap.isNotEmpty) {
      return _dedupeByStableKey(nonOverlap);
    }

    return _dedupeByStableKey(bookMaps);
  }

  Future<List<dynamic>> _fetchEndpointItems(
    String endpoint,
    String token,
  ) async {
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };

    try {
      final response = await _dio.post(
        endpoint,
        data: const {},
        options: Options(headers: headers),
      );
      final postItems = _extractItems(response.data);
      if (postItems.isNotEmpty) {
        debugPrint(
          'Learner API -> POST $endpoint returned ${postItems.length} items',
        );
        return postItems;
      }

      debugPrint(
        'Learner API -> POST $endpoint returned 0 items, trying GET fallback',
      );
    } on DioException catch (e) {
      debugPrint(
        'Learner API -> POST $endpoint failed (${e.response?.statusCode}), trying GET fallback',
      );
    }

    try {
      final response = await _dio.get(
        endpoint,
        options: Options(headers: headers),
      );
      final getItems = _extractItems(response.data);
      if (getItems.isNotEmpty) {
        debugPrint(
          'Learner API -> GET $endpoint returned ${getItems.length} items',
        );
      } else {
        debugPrint('Learner API -> GET $endpoint returned 0 items');
      }
      return getItems;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return [];
      }
      rethrow;
    }
  }

  List<dynamic> _filterItemsForMenu(List<dynamic> items, String menuId) {
    final mapItems = items.whereType<Map<String, dynamic>>().toList();
    if (mapItems.isEmpty) {
      return items;
    }

    switch (menuId) {
      case 'interactive_books':
        // Prefer items that look interactive; if none are marked, use elibrary-like items.
        final interactive = mapItems
            .where(
              (item) =>
                  item['run_url'] != null ||
                  item['interactive_url'] != null ||
                  item['is_interactive'] == true,
            )
            .toList();
        if (interactive.isNotEmpty) {
          return _dedupeByStableKey(interactive);
        }
        final elibraryStyle = mapItems
            .where((item) => item['book_url'] != null)
            .toList();
        return _dedupeByStableKey(
          elibraryStyle.isNotEmpty ? elibraryStyle : mapItems,
        );

      case 'non_interactive_books':
        final nonInteractive = mapItems
            .where(
              (item) =>
                  item['book_url'] != null &&
                  item['run_url'] == null &&
                  item['interactive_url'] == null,
            )
            .toList();
        return _dedupeByStableKey(
          nonInteractive.isNotEmpty ? nonInteractive : mapItems,
        );

      case 'esoma_kids':
        final kids = mapItems
            .where(
              (item) =>
                  (item['publisher']?.toString().toLowerCase().contains(
                        'ubongo',
                      ) ??
                      false) ||
                  (item['title']?.toString().toLowerCase().contains('akili') ??
                      false),
            )
            .toList();
        return _dedupeByStableKey(kids.isNotEmpty ? kids : mapItems);

      default:
        return _dedupeByStableKey(mapItems);
    }
  }

  List<Map<String, dynamic>> _dedupeByStableKey(
    List<Map<String, dynamic>> items,
  ) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];

    for (final item in items) {
      final key =
          item['id']?.toString() ??
          item['quiz_id']?.toString() ??
          item['title']?.toString() ??
          item.toString();
      if (seen.add(key)) {
        result.add(item);
      }
    }

    return result;
  }

  List<String> _detailEndpoints(String menuId, {String? id, String? quizId}) {
    final itemId = id ?? quizId;
    if (itemId == null || itemId.isEmpty) {
      return [];
    }

    switch (menuId) {
      case 'learning_areas':
        return ['/student/courses/$itemId'];
      case 'interactive_books':
      case 'non_interactive_books':
      case 'esoma_kids':
        return ['/student/books/$itemId', '/student/elibrary/$itemId'];
      case 'virtual_labs':
        return ['/student/labs/$itemId'];
      case 'elimu_quest':
      case 'games':
      case 'leaderboard':
      case 'my_questions':
        return ['/student/quizzes/$itemId'];
      default:
        return [];
    }
  }

  String? _extractUrlFromAny(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final direct = _extractUrlFromMap(payload);
      if (direct != null) {
        return direct;
      }

      final data = payload['data'];
      if (data is Map<String, dynamic>) {
        final nested = _extractUrlFromMap(data);
        if (nested != null) {
          return nested;
        }
      }
      if (data is List &&
          data.isNotEmpty &&
          data.first is Map<String, dynamic>) {
        return _extractUrlFromMap(data.first as Map<String, dynamic>);
      }

      final books = payload['books'];
      if (books is List &&
          books.isNotEmpty &&
          books.first is Map<String, dynamic>) {
        return _extractUrlFromMap(books.first as Map<String, dynamic>);
      }
    }
    return null;
  }

  String? _extractUrlFromMap(Map<String, dynamic> item) {
    final url =
        item['book_url'] ??
        item['course_url'] ??
        item['quiz_url'] ??
        item['run_url'] ??
        item['url'] ??
        item['link'] ??
        item['pdf_url'] ??
        item['resource_url'] ??
        item['interactive_url'];

    if (url is String && url.trim().isNotEmpty) {
      return url.trim();
    }
    return null;
  }

  List<dynamic> _extractItems(dynamic data) {
    if (data is List) {
      return data
          .where((item) => item is Map<String, dynamic> || item is Map)
          .toList();
    }

    if (data is Map<String, dynamic>) {
      final bodyData = data['data'];
      if (bodyData is List) {
        return bodyData
            .where((item) => item is Map<String, dynamic> || item is Map)
            .toList();
      }

      if (bodyData is Map<String, dynamic>) {
        final books = bodyData['books'];
        if (books is List) {
          return books
              .where((item) => item is Map<String, dynamic> || item is Map)
              .toList();
        }
        return [bodyData];
      }

      final books = data['books'];
      if (books is List) {
        return books
            .where((item) => item is Map<String, dynamic> || item is Map)
            .toList();
      }
    }

    return [];
  }

  List<String> _menuEndpoints(String menuId) {
    switch (menuId) {
      case 'learning_areas':
        return ['/student/courses'];
      case 'interactive_books':
        return ['/student/elibrary'];
      case 'non_interactive_books':
        return ['/student/books'];
      case 'esoma_kids':
        return ['/student/elibrary', '/student/books'];
      case 'virtual_labs':
        return ['/student/labs'];
      case 'elimu_quest':
        return ['/student/quizzes'];
      case 'my_questions':
        return ['/student/questions'];
      case 'leaderboard':
        return ['/leaderboard'];
      case 'games':
        return ['/student/marketplace'];
      default:
        return ['/student/elibrary'];
    }
  }

  Future<Map<String, String>> _authorizedHeaders() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No active session. Please log in again.');
    }

    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  Future<Options> _authorizedOptions() async {
    return Options(headers: await _authorizedHeaders());
  }

  Future<int?> _getStudentId() async {
    final savedId = await AuthService.instance.getSavedUserId();
    if (savedId != null) {
      return savedId;
    }

    final user = await AuthService.instance.getCurrentUser();
    final dynamic rawId = user['id'] ?? user['user_id'] ?? user['student_id'];
    if (rawId is int) {
      return rawId;
    }
    if (rawId is String) {
      return int.tryParse(rawId);
    }

    // Try to fetch user profile as fallback
    try {
      // This call is now internal to the service, avoiding cross-service dependency
      final profile = await UserDataService.instance.fetchUserProfile();
      if (profile != null) {
        final userData = profile['data'] ?? profile['user'] ?? profile;
        final dynamic profileId =
            userData['id'] ?? userData['user_id'] ?? userData['student_id'];
        if (profileId is int) {
          return profileId;
        }
        if (profileId is String) {
          return int.tryParse(profileId);
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch user profile for student ID: $e');
    }

    return null;
  }

  Future<List<dynamic>> _fetchAuthorizedCollection(String endpoint) async {
    // This pattern attempts a POST request first, then falls back to GET,
    // which is robust for APIs that might have inconsistent verb usage.
    try {
      final response = await _dio.post(endpoint, data: const {});
      return _extractItems(response.data);
    } on DioException {
      final response = await _dio.get(endpoint);
      return _extractItems(response.data);
    }
  }

  Future<Map<String, dynamic>?> _fetchAuthorizedMap(String endpoint) async {
    try {
      final response = await _dio.post(endpoint, data: const {});
      return _extractMap(response.data);
    } on DioException {
      final response = await _dio.get(endpoint);
      return _extractMap(response.data);
    }
  }

  Future<Map<String, dynamic>?> _postAuthorizedMap(
    String endpoint, {
    Map<String, dynamic>? data,
  }) async {
    final response = await _dio.post(endpoint, data: data ?? const {});
    return _extractMap(response.data);
  }

  Map<String, dynamic>? _extractMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      final bodyData = data['data'];
      if (bodyData is Map<String, dynamic>) {
        return bodyData;
      }
      return data;
    }

    if (data is List && data.isNotEmpty) {
      final first = data.first;
      if (first is Map<String, dynamic>) {
        return first;
      }
      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }

    return null;
  }
}

Map<String, dynamic>? _extractMapPayload(dynamic data) {
  if (data is Map<String, dynamic>) {
    final bodyData = data['data'];
    if (bodyData is Map<String, dynamic>) {
      return bodyData;
    }
    return data;
  }

  if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
    final first = data.first;
    if (first is Map<String, dynamic>) {
      return first;
    }
    if (first is Map) {
      return Map<String, dynamic>.from(first);
    }
  }

  return null;
}
