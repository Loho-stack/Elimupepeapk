import 'package:elimupepe/app/session_controller.dart';
import 'package:elimupepe/core/webview/sso_webview.dart';
import 'package:elimupepe/app/app_services.dart';
import 'package:flutter/material.dart';
import '../parental_control/parental_gate.dart';
import 'package:elimupepe/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:elimupepe/core/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elimupepe/core/utils/image_url_resolver.dart';
import 'package:elimupepe/features/settings/about_screen.dart';
import 'package:elimupepe/core/services/user_data_service.dart';
import 'package:elimupepe/features/settings/notifications_screen.dart';
import 'package:elimupepe/core/utils/error_feedback.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'Loading...';
  String _lohoId = '...';
  String _grade = 'Grade ...';
  String _profileImageUrl = '';
  bool _isSubscribed = false;
  String _points = '0';
  String _books = '0';
  String _quests = '0';
  List<Map<String, dynamic>> _badges = [];
  List<dynamic> _recentNotifications = [];
  int _unreadCount = 0;

  Future<void> _openProtectedWebView({
    required String title,
    required String intendedPath,
  }) async {
    if (!mounted) return;
    await SsoWebViewScreen.open(context, title: title, path: intendedPath);
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // 1. Immediately load whatever cached info we have locally
    final prefs = await SharedPreferences.getInstance();
    final services = AppServices.instance;
    final profile = await services.profile.read();
    final studentId = await AuthService.instance.getSavedStudentId();
    if (!mounted) return;
    setState(() {
      _userName = profile.name ?? 'Learner';
      _lohoId = studentId ?? '';
      _grade = prefs.getString('grade') ?? 'Grade ...';
      _profileImageUrl =
          ImageUrlResolver.withCacheBuster(
            profile.avatarUrl ?? '',
            cacheKey: services.profile.avatarCacheKey,
          ) ??
          '';
      _isSubscribed = prefs.getBool('is_subscribed') ?? false;
      _points = prefs.getString('points') ?? '0';
      _books = prefs.getString('books') ?? '0';
      _quests = prefs.getString('quests') ?? '0';
    });

    final futures = await Future.wait<dynamic>([
      UserDataService.instance.fetchUserProfile(),
      UserDataService.instance.checkSubscriptionStatus(),
      UserDataService.instance.fetchGrades(),
      UserDataService.instance.fetchNotifications(),
      UserDataService.instance.fetchBadges(),
      UserDataService.instance.fetchWallet(),
    ]);

    final apiData = futures[0] is Map<String, dynamic>
        ? futures[0] as Map<String, dynamic>
        : null;
    if (apiData != null && mounted) {
      final userData = apiData['data'] ?? apiData['user'] ?? apiData;

      setState(() {
        // Pick out fields from API. Update 'name' or 'first_name' depending on your JSON structure
        _userName = userData['name'] ?? userData['first_name'] ?? _userName;

        // Fetch Loho ID or fallback to standard ID/student_id
        _lohoId =
            userData['loho_id']?.toString() ??
            userData['student_id']?.toString() ??
            _lohoId;

        // Fetch grade and format it if necessary
        final fetchedGrade = _extractGrade(userData);
        if (fetchedGrade != null && fetchedGrade.isNotEmpty) {
          _grade = fetchedGrade;
        }

        // Fetch profile image URL (Specifically using 'avatar' from API)
        final avatar = ImageUrlResolver.fromMap(userData);
        if (avatar != null && avatar.isNotEmpty) {
          _profileImageUrl = avatar;
        }

        // Fetch gamification points if provided in the profile
        if (userData['gamification_points'] != null) {
          _points = userData['gamification_points'].toString();
        } else if (userData['points'] != null) {
          _points = userData['points'].toString();
        }
      });

      // Update local storage so the next immediate load displays the correct fresh data
      await services.profile.update(name: _userName);
      await prefs.setString('grade', _grade);
      final avatarCacheKey =
          services.profile.avatarCacheKey ??
          DateTime.now().millisecondsSinceEpoch.toString();
      final refreshedAvatar = ImageUrlResolver.withCacheBuster(
        _profileImageUrl,
        cacheKey: avatarCacheKey,
      );
      _profileImageUrl = refreshedAvatar ?? _profileImageUrl;
      await services.profile.update(avatarUrl: _profileImageUrl);
      services.profile.avatarCacheKey = avatarCacheKey;
      await prefs.setString('points', _points);
    }

    final isSubStatus = futures[1] is bool ? futures[1] as bool : false;
    if (mounted) {
      setState(() {
        _isSubscribed = isSubStatus;
      });
      await prefs.setBool('is_subscribed', _isSubscribed);
    }

    final grades = futures[2] is List ? futures[2] as List<dynamic> : null;
    if (mounted && grades != null) {
      setState(() {
        _quests = grades.length.toString();
        _books = (grades.isNotEmpty ? (grades.length / 2).round() : 0)
            .toString(); // Fallback placeholder
      });
      await prefs.setString('quests', _quests);
      await prefs.setString('books', _books);
    }

    final badges = futures[4] is List ? futures[4] as List<dynamic> : [];
    if (mounted) {
      setState(() {
        _badges = badges
            .whereType<Map<String, dynamic>>()
            .map(_normalizeBadge)
            .take(6)
            .toList();
      });
    }

    final wallet = futures[5] is Map<String, dynamic>
        ? futures[5] as Map<String, dynamic>
        : null;
    final walletPoints = _readInt([
      wallet?['balance'],
      wallet?['coins'],
      wallet?['loho_coins'],
    ]);
    if (walletPoints != null && mounted) {
      setState(() {
        _points = walletPoints.toString();
      });
      await prefs.setString('points', _points);
    }

    // 5. Fetch recent notifications
    final notifications = futures[3] is List
        ? futures[3] as List<dynamic>
        : null;
    if (mounted && notifications != null) {
      setState(() {
        _recentNotifications = notifications.take(2).toList();
        _unreadCount = notifications
            .where((n) => n is Map && n['is_read'] == false)
            .length;
      });
    }
  }

  String? _extractGrade(Map<String, dynamic> userData) {
    final direct = _readGradeField(userData);
    if (direct != null) return direct;

    final possibleNestedKeys = [
      'student',
      'learner',
      'profile',
      'child',
      'user',
      'data',
    ];

    for (final key in possibleNestedKeys) {
      final nested = userData[key];
      if (nested is Map<String, dynamic>) {
        final nestedGrade = _readGradeField(nested);
        if (nestedGrade != null) return nestedGrade;
      }
    }

    return null;
  }

  String? _readGradeField(Map<String, dynamic> data) {
    final raw =
        data['grade'] ??
        data['grade_level'] ??
        data['gradeLevel'] ??
        data['class'] ??
        data['class_name'] ??
        data['level'] ??
        data['course'] ??
        data['current_grade'] ??
        data['current_grade_level'];

    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;

    return text.toLowerCase().startsWith('grade') ? text : 'Grade $text';
  }

  Map<String, dynamic> _normalizeBadge(Map<String, dynamic> badge) {
    final name =
        badge['name']?.toString() ??
        badge['title']?.toString() ??
        badge['label']?.toString() ??
        'Achievement';
    final slug =
        badge['slug']?.toString().toLowerCase() ??
        badge['type']?.toString().toLowerCase() ??
        name.toLowerCase();

    final (icon, color) = _badgePresentation(slug);
    return {...badge, 'name': name, 'icon': icon, 'color': color};
  }

  (IconData, Color) _badgePresentation(String slug) {
    if (slug.contains('science')) {
      return (Icons.science_rounded, Colors.green);
    }
    if (slug.contains('math')) {
      return (Icons.calculate_rounded, Colors.lightBlue);
    }
    if (slug.contains('book') || slug.contains('read')) {
      return (Icons.auto_stories_rounded, AppColors.accentOrange);
    }
    if (slug.contains('top') || slug.contains('leader')) {
      return (Icons.emoji_events_rounded, AppColors.accentYellow);
    }
    if (slug.contains('code') || slug.contains('tech')) {
      return (Icons.code_rounded, Colors.purple);
    }
    return (Icons.workspace_premium_rounded, AppColors.lightGreen);
  }

  int? _readInt(List<dynamic> values) {
    for (final value in values) {
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lightGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true && context.mounted) {
      // Clears tokens, profile, preferences and webview data; keeps only
      // the Student ID if the learner chose to be remembered.
      await AuthService.instance.logout();

      if (!context.mounted) return;
      // 3. Navigate back to the pre-login welcome flow
      context.leaveSession();
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final passed = await showParentalGate(context);
    if (!passed || !context.mounted) return;

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'This action is permanent and cannot be undone. All your progress, points, and saved books will be lost.\n\nAre you absolutely sure you want to delete your account?',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true && context.mounted) {
      setState(() {
        // We could show a global loading overlay if we had one
      });

      final success = await AuthService.instance.deleteAccount();

      if (!context.mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account successfully deleted.')),
        );
      } else {
        await ErrorFeedback.showErrorDialog(
          context,
          title: 'Account deletion not confirmed',
          error: 'Please check your network connection and try again.',
          fallback:
              'Your session was cleared, but the remote account deletion request might not have completed. Please contact support to ensure complete data removal.',
        );
      }

      if (!context.mounted) return;

      // Navigate back to the pre-login welcome flow
      context.leaveSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF0F8FF),
        title: const Text(
          'My Profile',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.brandGreen,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text(_unreadCount.toString()),
              child: const Icon(
                Icons.notifications_rounded,
                color: AppColors.lightGreen,
              ),
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
              if (mounted) _loadUserData();
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.settings_rounded,
              color: AppColors.lightGreen,
            ),
            onPressed: () async {
              // Await navigation and refresh data on return.
              await _openProtectedWebView(
                title: 'Update Profile',
                intendedPath: '/users/settings',
              );
              // This will run when the user comes back from the update screen
              if (mounted) _loadUserData();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        color: AppColors.brandGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Avatar and Name
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.lightGreen,
                          width: 4,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: NetworkImage(
                          _profileImageUrl.isNotEmpty
                              ? _profileImageUrl
                              : 'https://ui-avatars.com/api/?background=random&name=${Uri.encodeComponent(_userName)}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _userName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Loho ID: $_lohoId',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_grade • Explorer',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
              ),
              const SizedBox(height: 32),

              // Subscription Plan
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.lightGreen, AppColors.brandGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandGreen.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: AppColors.accentYellow,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isSubscribed ? 'Premium Plan' : 'Free Plan',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isSubscribed
                                ? 'Active Subscription'
                                : 'No active subscription',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final passed = await showParentalGate(context);

                        if (passed && context.mounted) {
                          // TODO: Manage subscription
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Parental gate passed. Open subscription manager here.',
                              ),
                            ),
                          );
                        }
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.brandGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isSubscribed ? 'Manage' : 'Upgrade',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.2),

              const SizedBox(height: 32),

              // Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard(
                    _points,
                    'Points',
                    Icons.star_rounded,
                    AppColors.accentYellow,
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.18),
                  _buildStatCard(
                    _books,
                    'Books',
                    Icons.menu_book_rounded,
                    AppColors.lightGreen,
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.18),
                  _buildStatCard(
                    _quests,
                    'Quests',
                    Icons.local_fire_department_rounded,
                    AppColors.lightGreen,
                  ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.18),
                ],
              ),

              const SizedBox(height: 40),

              // Badges Section
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'My Badges',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandGreen,
                  ),
                ),
              ).animate().fadeIn(delay: 650.ms).slideX(begin: -0.08),
              const SizedBox(height: 16),
              GridView.extent(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                maxCrossAxisExtent: 120,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.8,
                children:
                    (_badges.isNotEmpty
                            ? _badges
                            : [
                                {
                                  'icon': Icons.lock_outline_rounded,
                                  'color': Colors.grey.shade400,
                                  'name': 'No badges yet',
                                },
                              ])
                        .asMap()
                        .entries
                        .map((entry) {
                          final index = entry.key;
                          final badge = entry.value;
                          return _buildBadge(
                                badge['icon'] as IconData,
                                badge['color'] as Color,
                                badge['name']?.toString(),
                              )
                              .animate()
                              .fadeIn(delay: (700 + (index * 80)).ms)
                              .scale(begin: const Offset(0.86, 0.86));
                        })
                        .toList(),
              ),

              const SizedBox(height: 28),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.brandGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.assignment_rounded,
                    color: AppColors.brandGreen,
                  ),
                ),
                title: const Text(
                  'Open Grade Book',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'View CBC summaries and assessment history',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  await _openProtectedWebView(
                    title: 'Grade Book',
                    intendedPath: '/student/gradebook',
                  );
                },
              ),

              const SizedBox(height: 24),

              // Messages Section
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recent Messages',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandGreen,
                  ),
                ),
              ).animate().fadeIn(delay: 760.ms).slideX(begin: -0.08),
              const SizedBox(height: 16),
              if (_recentNotifications.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No recent messages.',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                ).animate().fadeIn(delay: 820.ms)
              else
                Column(
                  children: _recentNotifications.asMap().entries.map((entry) {
                    final index = entry.key;
                    final notification = entry.value;
                    if (notification is! Map) return const SizedBox.shrink();
                    final isUnread = notification['is_read'] == false;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child:
                          _buildMessageCard(
                                notification['title']?.toString() ??
                                    'System Notification',
                                notification['message']?.toString() ?? '',
                                notification['time']?.toString() ?? '',
                                isUnread,
                                avatarUrl: _profileImageUrl,
                              )
                              .animate()
                              .fadeIn(delay: (820 + (index * 120)).ms)
                              .slideX(begin: 0.08),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 32),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmLogout(context),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    'Logout',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.lightGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(
                        color: AppColors.lightGreen,
                        width: 2,
                      ),
                    ),
                    elevation: 0,
                  ),
                ),
              ).animate().fadeIn(delay: 1080.ms).slideY(begin: 0.16),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => _confirmDeleteAccount(context),
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text(
                    'Delete Account',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ).animate().fadeIn(delay: 1120.ms).slideY(begin: 0.16),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.blueGrey,
                ),
                title: const Text('About this App'),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.blueGrey,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AboutScreen(),
                    ),
                  );
                },
              ).animate().fadeIn(delay: 1160.ms).slideY(begin: 0.16),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, Color color, [String? label]) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: label == 'Locked' ? 0.05 : 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 40),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: label == 'Locked' ? Colors.grey.shade500 : Colors.blueGrey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildMessageCard(
    String sender,
    String message,
    String time,
    bool isUnread, {
    String? avatarUrl,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnread
            ? AppColors.lightGreen.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread
              ? AppColors.lightGreen.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isUnread
                ? AppColors.lightGreen.withValues(alpha: 0.2)
                : const Color(0xFFF0F8FF),
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? NetworkImage(avatarUrl)
                : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? const Icon(
                    Icons.notifications_rounded,
                    color: AppColors.lightGreen,
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      sender,
                      style: TextStyle(
                        fontWeight: isUnread
                            ? FontWeight.bold
                            : FontWeight.w600,
                        fontSize: 16,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        color: isUnread
                            ? AppColors.lightGreen
                            : Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: isUnread
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.blueGrey.shade700,
                    fontSize: 14,
                    fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
