import 'package:flutter/foundation.dart';
import 'package:elimupepe/features/quiz/learner_dashboard_api_service.dart';

/// A high-level service to fetch and normalize user-related data.
///
/// This service acts as a facade, delegating network calls to the
/// [LearnerDashboardApiService] and normalizing the data for UI consumption.
/// It does not contain any direct networking logic itself.
class UserDataService {
  static final UserDataService instance = UserDataService._internal();
  factory UserDataService() => instance;
  UserDataService._internal();

  Future<Map<String, dynamic>?> fetchUserProfile() async {
    try {
      // Delegate to the centralized API service.
      return await LearnerDashboardApiService.instance.fetchProfile();
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) debugPrint('Error fetching user profile');
      }
      return null;
    }
  }

  Future<List<dynamic>?> fetchNotifications() async {
    try {
      final notifications = await LearnerDashboardApiService.instance
          .fetchNotifications();
      if (notifications.isEmpty) {
        return [];
      }
      return notifications
          .whereType<Map<String, dynamic>>()
          .map(_normalizeNotification)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) debugPrint('Error fetching notifications');
      }
      return [];
    }
  }

  Future<bool> checkSubscriptionStatus() async {
    try {
      final response = await LearnerDashboardApiService.instance
          .checkSubscriptionStatus();
      if (response != null) {
        // Handle multiple possible keys for subscription status
        return response['subscribed'] == true ||
            response['active'] == true ||
            response['has_subscription'] == true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) debugPrint('Error checking subscription');
      }
      return false;
    }
  }

  Future<List<dynamic>?> fetchGrades() async {
    try {
      return await LearnerDashboardApiService.instance.fetchGrades();
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) debugPrint('Error fetching grades');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchStudentGradebook() {
    // Directly delegate to the API service.
    return LearnerDashboardApiService.instance.fetchStudentGradebook();
  }

  Future<List<dynamic>?> fetchBadges() async {
    try {
      return await LearnerDashboardApiService.instance.fetchBadges();
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) debugPrint('Error fetching badges');
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchWallet() async {
    try {
      return await LearnerDashboardApiService.instance.fetchWallet();
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) debugPrint('Error fetching wallet');
      }
    }
    return null;
  }

  Future<bool> updateProfile(Map<String, dynamic> updateData) async {
    try {
      final response = await LearnerDashboardApiService.instance.updateProfile(
        updateData,
      );
      return response != null && response['success'] == true;
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) debugPrint('Error updating profile');
      }
      return false;
    }
  }

  Future<bool> markNotificationsAsRead() async {
    try {
      final response = await LearnerDashboardApiService.instance
          .markNotificationsAsRead();
      return response != null && response['success'] == true;
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) debugPrint('Error marking notifications as read');
      }
      return false;
    }
  }

  Map<String, dynamic> _normalizeNotification(
    Map<String, dynamic> notification,
  ) {
    final title =
        notification['title']?.toString() ??
        notification['subject']?.toString() ??
        notification['heading']?.toString() ??
        'Notification';
    final message =
        notification['message']?.toString() ??
        notification['body']?.toString() ??
        notification['content']?.toString() ??
        '';
    final time =
        notification['time']?.toString() ??
        notification['created_at']?.toString() ??
        notification['date']?.toString() ??
        '';

    final isRead =
        notification['is_read'] == true ||
        notification['read'] == true ||
        notification['read_at'] != null;

    return {
      ...notification,
      'title': title,
      'message': message,
      'time': time,
      'is_read': isRead,
    };
  }
}
