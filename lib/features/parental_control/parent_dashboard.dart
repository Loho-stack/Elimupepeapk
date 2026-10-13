import 'package:elimupepe/app/session_controller.dart';
import 'package:elimupepe/app/app_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:elimupepe/core/theme/app_theme.dart';
import 'package:elimupepe/core/services/parent_api_service.dart';
import 'package:elimupepe/core/services/auth_service.dart';
import 'package:elimupepe/core/utils/error_feedback.dart';
import 'package:elimupepe/features/parental_control/linked_children_screen.dart';
import 'package:elimupepe/features/parental_control/parent_child_detail_screen.dart';
import 'package:elimupepe/features/parental_control/parent_controls_screen.dart';
import 'package:elimupepe/features/parental_control/parent_messages_screen.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  String _displayName = 'Parent';
  bool _isLoading = true;
  String? _errorMessage;
  List<ParentLinkedChild> _children = [];
  Map<String, dynamic>? _dashboard;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadUserName();
    await _refresh();
  }

  Future<void> _loadUserName() async {
    final name = (await AppServices.instance.profile.read()).name;
    if (!mounted) return;
    setState(() {
      _displayName = (name != null && name.trim().isNotEmpty) ? name : 'Parent';
    });
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ParentApiService.instance;
      final children = await api.fetchLinkedChildren();
      final dashboard = await api.fetchDashboard();
      if (!mounted) return;
      setState(() {
        _children = children;
        _dashboard = dashboard;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ErrorFeedback.userMessage(
          e,
          fallback: 'Could not load parent dashboard right now.',
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    context.leaveSession();
  }

  void _openLinkedChildren() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LinkedChildrenScreen(children: _children),
      ),
    ).then((_) => _refresh());
  }

  void _openChildDetail(ParentLinkedChild child) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ParentChildDetailScreen(child: child),
      ),
    ).then((_) => _refresh());
  }

  void _openControls() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ParentControlsScreen(children: _children),
      ),
    ).then((_) => _refresh());
  }

  void _openMessages() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ParentMessagesScreen(dashboard: _dashboard),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final greeting = _getGreeting();
    final hasChildren = _children.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.surfaceGray,
      appBar: AppBar(
        title: const Text('Parent Dashboard'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _refresh,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF7F4FF), AppColors.surfaceGray],
                ),
              ),
            ),
          ),
          RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.brandGreen,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _headerCard(
                  greeting: greeting,
                  name: _displayName,
                  isTablet: isTablet,
                ),
                const SizedBox(height: 20),
                if (_errorMessage != null) _errorBanner(),
                if (_isLoading && _children.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation(AppColors.primaryBlue),
                      ),
                    ),
                  )
                else if (!hasChildren)
                  _emptyState(),
                if (hasChildren) ...[
                  _sectionTitle('Children Under Your Care'),
                  const SizedBox(height: 12),
                  _linkedChildrenRow(),
                  const SizedBox(height: 20),
                  _sectionTitle('At a Glance'),
                  const SizedBox(height: 12),
                  _overviewRow(),
                  const SizedBox(height: 20),
                  _sectionTitle('Oversight'),
                  const SizedBox(height: 12),
                  _actionTile(
                    title: 'Linked Children',
                    subtitle: '${_children.length} learner${_children.length == 1 ? '' : 's'} linked',
                    icon: Icons.family_restroom,
                    onTap: _openLinkedChildren,
                  ),
                  const SizedBox(height: 10),
                  _actionTile(
                    title: 'Parental Controls',
                    subtitle: 'Screen time, content access & safety',
                    icon: Icons.shield_outlined,
                    onTap: _openControls,
                  ),
                  const SizedBox(height: 10),
                  _actionTile(
                    title: 'Messages',
                    subtitle: 'Reach teachers and the school',
                    icon: Icons.chat_bubble_outline,
                    onTap: _openMessages,
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('Latest Activity'),
                  const SizedBox(height: 12),
                  _recentActivityList(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCard({
    required String greeting,
    required String name,
    required bool isTablet,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accentPurple, AppColors.primaryBlue],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        '${_children.length} child${_children.length == 1 ? '' : 'ren'} overseen',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isTablet) const SizedBox(width: 16),
          CircleAvatar(
            radius: isTablet ? 32 : 26,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'P',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.05);
  }

  Widget _linkedChildrenRow() {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final child = _children[index];
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openChildDetail(child),
            child: Container(
              width: 130,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryBlue.withValues(alpha: 0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        AppColors.primaryBlue.withValues(alpha: 0.12),
                    backgroundImage:
                        (child.avatarUrl != null && child.avatarUrl!.isNotEmpty)
                            ? NetworkImage(child.avatarUrl!)
                            : null,
                    child:
                        (child.avatarUrl == null || child.avatarUrl!.isEmpty)
                            ? Text(
                                child.name.isNotEmpty
                                    ? child.name[0].toUpperCase()
                                    : 'S',
                                style: const TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              )
                            : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    child.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    child.grade,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.blueGrey.shade600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _overviewRow() {
    final totalLessons =
        _dashboard?['lessons_this_week'] ?? _dashboard?['lessons_completed'] ?? 0;
    final assignmentsDue =
        _dashboard?['assignments_due'] ?? _dashboard?['pending_assignments'] ?? 0;
    final streak =
        _dashboard?['attendance_streak'] ?? _dashboard?['attendance'] ?? '—';
    final unread = _dashboard?['unread_messages'] ?? 0;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _metricCard(
          title: 'Lessons',
          value: totalLessons.toString(),
          icon: Icons.menu_book_rounded,
        ),
        _metricCard(
          title: 'Due',
          value: assignmentsDue.toString(),
          icon: Icons.assignment_rounded,
        ),
        _metricCard(
          title: 'Streak',
          value: streak.toString(),
          icon: Icons.local_fire_department_rounded,
        ),
        _metricCard(
          title: 'Messages',
          value: unread.toString(),
          icon: Icons.chat_bubble_outline,
        ),
      ],
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryBlue, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.blueGrey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(icon, color: AppColors.primaryBlue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _recentActivityList() {
    final raw = _dashboard?['recent_activity'] ?? _dashboard?['activity'];
    final items = raw is List ? raw : const [];

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.history, color: AppColors.primaryBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No recent activity yet. Updates will appear here as your child learns.',
                style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: items.take(5).map((entry) {
        final map = entry is Map<String, dynamic>
            ? entry
            : entry is Map
                ? Map<String, dynamic>.from(entry)
                : <String, dynamic>{};
        final sender = (map['sender'] ?? map['from'] ?? 'System').toString();
        final subtitle = (map['message'] ??
                map['description'] ??
                map['text'] ??
                '')
            .toString();
        final time = (map['time'] ?? map['created_at'] ?? '').toString();

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    AppColors.primaryBlue.withValues(alpha: 0.12),
                child: Text(
                  sender.isNotEmpty ? sender[0].toUpperCase() : 'S',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sender,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (time.isNotEmpty)
                          Text(
                            time,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.family_restroom,
                color: AppColors.primaryBlue, size: 32),
          ),
          const SizedBox(height: 12),
          const Text(
            'No children linked yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Visit ${AppEndpointsText.primaryHost} and link your child\'s learner account to start oversight.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textMain,
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class AppEndpointsText {
  static const String primaryHost = 'elimupepe.loholearning.co.ke';
}