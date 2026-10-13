import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:elimupepe/app/app_services.dart';

class ParentLinkedChild {
  final String id;
  final String studentId;
  final String name;
  final String grade;
  final String? className;
  final String? avatarUrl;
  final String? schoolName;

  const ParentLinkedChild({
    required this.id,
    required this.studentId,
    required this.name,
    required this.grade,
    this.className,
    this.avatarUrl,
    this.schoolName,
  });

  factory ParentLinkedChild.fromMap(Map<String, dynamic> map) {
    final id =
        (map['id'] ?? map['user_id'] ?? map['student_id'] ?? '').toString();
    final studentId =
        (map['student_id'] ?? map['loho_id'] ?? map['id'] ?? '').toString();
    final name =
        (map['name'] ?? map['full_name'] ?? map['first_name'] ?? 'Student')
            .toString();
    final grade =
        (map['grade'] ?? map['grade_level'] ?? map['class_name'] ?? 'Grade')
            .toString();
    final className = map['class'] ?? map['class_name'];
    final avatar = map['avatar'] ?? map['profile_image'] ?? map['photo'];
    final school = map['school'] ?? map['school_name'];

    return ParentLinkedChild(
      id: id,
      studentId: studentId,
      name: name,
      grade: grade,
      className: className?.toString(),
      avatarUrl: avatar?.toString(),
      schoolName: school?.toString(),
    );
  }
}

class ParentApiService {
  static final ParentApiService instance = ParentApiService._internal();
  factory ParentApiService() => instance;
  ParentApiService._internal();

  /// The shared client adds the bearer token and handles 401 and 429.
  Dio get _dio => AppServices.instance.apiClient.api;

  Future<Map<String, dynamic>?> _safeMap(Future<Response<dynamic>> request) async {
    try {
      final response = await request;
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
      }
    } on DioException catch (e) {
      // Never print the body: it can contain children's data.
      if (kDebugMode) debugPrint('Parent API error ${e.response?.statusCode}');
    } catch (e) {
      debugPrint('Parent API unexpected error: $e');
    }
    return null;
  }

  Future<List<dynamic>> _safeList(Future<Response<dynamic>> request) async {
    try {
      final response = await request;
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is List) return data;
        if (data is Map<String, dynamic>) {
          final nested = data['data'] ?? data['children'] ?? data['items'];
          if (nested is List) return nested;
        }
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('Parent API list error ${e.response?.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Parent API list unexpected error');
    }
    return <dynamic>[];
  }

  Future<List<ParentLinkedChild>> fetchLinkedChildren() async {
    final candidates = [
      () => _dio.get('/parent/children'),
      () => _dio.get('/parent/students'),
      () => _dio.get('/parent/dashboard'),
      () => _dio.get('/v1/parent/children'),
    ];

    for (final req in candidates) {
      final list = await _safeList(req());
      if (list.isNotEmpty) {
        return list
          .whereType<Map>()
          .map((m) => ParentLinkedChild.fromMap(Map<String, dynamic>.from(m)))
          .toList();
      }
    }

    final dash = await fetchDashboard();
    if (dash != null) {
      final childrenRaw = dash['children'] ?? dash['students'] ?? dash['data'];
      if (childrenRaw is List) {
        return childrenRaw
            .whereType<Map>()
            .map((m) => ParentLinkedChild.fromMap(Map<String, dynamic>.from(m)))
            .toList();
      }
    }

    return <ParentLinkedChild>[];
  }

  Future<Map<String, dynamic>?> fetchDashboard() async {
    final endpoints = ['/parent/dashboard', '/parent/home', '/v1/parent/dashboard'];
    for (final endpoint in endpoints) {
      final result = await _safeMap(_dio.get(endpoint));
      if (result != null && result.isNotEmpty) return result;
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchChildOverview(String childId) async {
    final endpoints = [
      '/parent/children/$childId/overview',
      '/parent/students/$childId',
      '/parent/children/$childId',
      '/v1/parent/children/$childId',
    ];
    for (final endpoint in endpoints) {
      final result = await _safeMap(_dio.get(endpoint));
      if (result != null && result.isNotEmpty) return result;
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchChildProgress(String childId) async {
    final endpoints = [
      '/parent/children/$childId/progress',
      '/parent/students/$childId/progress',
      '/v1/parent/children/$childId/progress',
    ];
    for (final endpoint in endpoints) {
      final result = await _safeMap(_dio.get(endpoint));
      if (result != null && result.isNotEmpty) return result;
    }
    return null;
  }

  Future<List<dynamic>> fetchChildNotifications(String childId) async {
    final endpoints = [
      '/parent/children/$childId/notifications',
      '/parent/students/$childId/notifications',
      '/v1/parent/children/$childId/notifications',
    ];
    for (final endpoint in endpoints) {
      final list = await _safeList(_dio.get(endpoint));
      if (list.isNotEmpty) return list;
    }
    return <dynamic>[];
  }

  Future<List<dynamic>> fetchChildActivity(String childId) async {
    final endpoints = [
      '/parent/children/$childId/activity',
      '/parent/students/$childId/activity',
      '/v1/parent/children/$childId/activity',
    ];
    for (final endpoint in endpoints) {
      final list = await _safeList(_dio.get(endpoint));
      if (list.isNotEmpty) return list;
    }
    return <dynamic>[];
  }

  Future<bool> setScreenTimeLimit(String childId, int minutesPerDay) async {
    final payload = <String, dynamic>{
      'child_id': childId,
      'minutes_per_day': minutesPerDay,
    };
    final endpoints = [
      '/parent/children/$childId/screen-time',
      '/v1/parent/children/$childId/screen-time',
    ];
    for (final endpoint in endpoints) {
      final result = await _safeMap(
        _dio.post(endpoint, data: payload),
      );
      if (result != null) return true;
    }
    return false;
  }

  Future<bool> toggleChildAccess(String childId, {required bool enabled}) async {
    final payload = <String, dynamic>{
      'child_id': childId,
      'enabled': enabled,
    };
    final endpoints = [
      '/parent/children/$childId/access',
      '/v1/parent/children/$childId/access',
    ];
    for (final endpoint in endpoints) {
      final result = await _safeMap(
        _dio.post(endpoint, data: payload),
      );
      if (result != null) return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> fetchParentProfile() async {
    final endpoints = [
      '/parent/profile',
      '/v1/parent/profile',
      '/parent/me',
    ];
    for (final endpoint in endpoints) {
      final result = await _safeMap(_dio.get(endpoint));
      if (result != null && result.isNotEmpty) return result;
    }
    return null;
  }
}