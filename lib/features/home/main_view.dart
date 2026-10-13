import 'package:elimupepe/app/session_controller.dart';
import 'package:elimupepe/core/webview/sso_webview.dart';
import 'package:elimupepe/app/app_services.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:elimupepe/models/menu_item.dart';
import 'package:elimupepe/models/competency.dart';
import 'package:elimupepe/core/theme/app_theme.dart';
import 'package:elimupepe/core/widgets/elimu_card.dart';
import 'package:elimupepe/core/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elimupepe/features/home/category_items_screen.dart';
import 'package:elimupepe/features/quiz/learner_dashboard_api_service.dart';

enum DashboardSection {
  overview,
  pillars,
  competencies,
  tasks,
  outcomes,
  activity,
  achievements,
  timetable,
  summary,
  parentTip,
}

class _DashboardSectionInfo {
  const _DashboardSectionInfo({
    required this.section,
    required this.label,
    required this.icon,
  });

  final DashboardSection section;
  final String label;
  final IconData icon;
}

class MainView extends StatefulWidget {
  final Function(int) onNavigate;

  const MainView({super.key, required this.onNavigate});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  String _userName = "Learner";
  String _grade = "";
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _sectionScrollController = ScrollController();
  DashboardSection _selectedSection = DashboardSection.overview;

  List<Competency> _competencies = [];
  String _weeklyGoalTitle = "Loading...";
  double _weeklyProgress = 0.0;
  int _openTaskCount = 0;
  bool _isLoading = true;

  static const List<_DashboardSectionInfo> _dashboardSections = [
    _DashboardSectionInfo(
      section: DashboardSection.overview,
      label: 'Overview',
      icon: Icons.dashboard_rounded,
    ),
    _DashboardSectionInfo(
      section: DashboardSection.pillars,
      label: 'Pathways',
      icon: Icons.grid_view_rounded,
    ),
    _DashboardSectionInfo(
      section: DashboardSection.competencies,
      label: 'Competencies',
      icon: Icons.timeline_rounded,
    ),
    _DashboardSectionInfo(
      section: DashboardSection.tasks,
      label: 'Tasks',
      icon: Icons.assignment_rounded,
    ),
    _DashboardSectionInfo(
      section: DashboardSection.outcomes,
      label: 'Outcomes',
      icon: Icons.flag_rounded,
    ),
    _DashboardSectionInfo(
      section: DashboardSection.activity,
      label: 'Activity',
      icon: Icons.history_rounded,
    ),
    _DashboardSectionInfo(
      section: DashboardSection.achievements,
      label: 'Awards',
      icon: Icons.emoji_events_rounded,
    ),
    _DashboardSectionInfo(
      section: DashboardSection.timetable,
      label: 'Timetable',
      icon: Icons.schedule_rounded,
    ),
    _DashboardSectionInfo(
      section: DashboardSection.summary,
      label: 'Summary',
      icon: Icons.insights_rounded,
    ),
    _DashboardSectionInfo(
      section: DashboardSection.parentTip,
      label: 'Parent Tip',
      icon: Icons.family_restroom_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      await _fetchUserProfile();

      final results = await Future.wait<dynamic>([
        LearnerDashboardApiService.instance.fetchCompetencies(),
        LearnerDashboardApiService.instance.fetchWeeklyGoal(),
        LearnerDashboardApiService.instance.fetchQuizzes(),
      ]);

      final competencies = results[0] is List
          ? results[0] as List<dynamic>
          : const [];
      final weeklyGoal = results[1] is Map<String, dynamic>
          ? results[1] as Map<String, dynamic>
          : null;
      final quizzes = results[2] is List
          ? results[2] as List<dynamic>
          : const [];

      if (mounted) {
        setState(() {
          _competencies = competencies
              .whereType<Map<String, dynamic>>()
              .map((e) => Competency.fromJson(e))
              .toList();
          _weeklyGoalTitle = weeklyGoal?['title'] ?? "Weekly Goal";
          _weeklyProgress =
              (weeklyGoal?['progress'] as num?)?.toDouble() ?? 0.0;
          _openTaskCount = _countOpenTasks(quizzes);
        });
      }
    } catch (e) {
      debugPrint("Error loading dashboard data: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sectionScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profile = await AppServices.instance.profile.read();
      if (mounted) {
        setState(() {
          _userName = profile.name ?? _userName;
          _grade = prefs.getString('grade') ?? _grade;
        });
      }

      final user = await AuthService.instance.getCurrentUser();
      if (mounted) {
        setState(() {
          _userName = user['name'] ?? "Learner";
        });
      }
    } catch (e) {
      // Fallback for Guest mode
    }
  }

  int _countOpenTasks(List<dynamic> quizzes) {
    if (quizzes.isEmpty) {
      return 0;
    }

    var openCount = 0;
    for (final item in quizzes) {
      if (item is! Map<String, dynamic>) {
        openCount++;
        continue;
      }
      if (_isOpenTask(item)) {
        openCount++;
      }
    }

    return openCount;
  }

  bool _isOpenTask(Map<String, dynamic> item) {
    final rawStatus =
        item['status']?.toString().trim().toLowerCase() ??
        item['state']?.toString().trim().toLowerCase() ??
        item['quiz_status']?.toString().trim().toLowerCase() ??
        '';

    const closedStatuses = {
      'completed',
      'complete',
      'done',
      'submitted',
      'graded',
      'closed',
      'finished',
      'archived',
    };
    if (closedStatuses.contains(rawStatus)) {
      return false;
    }

    const openStatuses = {
      'open',
      'available',
      'pending',
      'active',
      'in_progress',
      'assigned',
      'due',
    };
    if (openStatuses.contains(rawStatus)) {
      return true;
    }

    final isCompleted =
        item['is_completed'] == true ||
        item['completed'] == true ||
        item['submitted'] == true ||
        item['is_submitted'] == true ||
        item['done'] == true;
    if (isCompleted) {
      return false;
    }

    final isOpen =
        item['is_open'] == true ||
        item['available'] == true ||
        item['pending'] == true ||
        item['assigned'] == true ||
        item['active'] == true;
    if (isOpen) {
      return true;
    }

    return true;
  }

  Future<void> _onSelectItem(MenuItem item) async {
    if (item.isComingSoon) return;

    final intendedPath = MenuItem.directIntendedPathFor(item.id);
    if (intendedPath != null) {
      await SsoWebViewScreen.open(context, title: item.title, path: intendedPath);
      return;
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryItemsScreen(menuItem: item),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lightGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !mounted) {
      return;
    }

    await AuthService.instance.logout();

    if (!mounted) return;

    context.leaveSession();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceGray,
      appBar: AppBar(
        backgroundColor: AppColors.brandGreen,
        elevation: 0,
        title: const Text(
          "Elimu Pepe",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => widget.onNavigate(1), // Go to Library/Search
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () =>
                widget.onNavigate(4), // View feedback/notifications
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _confirmLogout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  // --- MAIN DASHBOARD BODY ---
  Widget _buildBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final navigator = isWide ? _buildSectionRail() : _buildSectionChips();

        final content = RefreshIndicator(
          color: AppColors.lightGreen,
          onRefresh: _loadDashboardData,
          child: Scrollbar(
            controller: _sectionScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            thickness: 8,
            radius: const Radius.circular(20),
            child: SingleChildScrollView(
              controller: _sectionScrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                isWide ? 24 : 16,
                12,
                isWide ? 24 : 16,
                72,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: _isLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 100),
                            child: CircularProgressIndicator(
                              color: AppColors.brandGreen,
                            ),
                          ),
                        )
                      : _buildSelectedSectionContent(),
                ),
              ),
            ),
          ),
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 280, child: navigator),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          );
        }

        return Column(
          children: [
            navigator,
            Expanded(child: content),
          ],
        );
      },
    );
  }

  Widget _buildSectionChips() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _dashboardSections.map((section) {
            final selected = _selectedSection == section.section;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: selected,
                label: Text(section.label),
                onSelected: (_) {
                  setState(() {
                    _selectedSection = section.section;
                  });
                },
                selectedColor: AppColors.brandGreen,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.textMain,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: selected
                      ? AppColors.brandGreen
                      : AppColors.darkGray.withValues(alpha: 0.18),
                ),
                backgroundColor: Colors.white,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSectionRail() {
    final selectedIndex = _dashboardSections.indexWhere(
      (section) => section.section == _selectedSection,
    );

    return Container(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          Widget rail = NavigationRail(
            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedSection = _dashboardSections[index].section;
              });
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.white,
            minWidth: 280,
            groupAlignment: -0.9,
            destinations: _dashboardSections
                .map(
                  (section) => NavigationRailDestination(
                    icon: Icon(section.icon),
                    selectedIcon: Icon(section.icon),
                    label: Text(section.label),
                  ),
                )
                .toList(),
          );

          if (constraints.maxHeight < 800) {
            return SingleChildScrollView(
              child: SizedBox(height: 800, child: rail),
            );
          }
          return rail;
        },
      ),
    );
  }

  Widget _buildSelectedSectionContent() {
    switch (_selectedSection) {
      case DashboardSection.overview:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLearnerProfileCard(),
            const SizedBox(height: 16),
            _buildOverviewHighlights(),
            const SizedBox(height: 20),
            _buildQuickAccessSection(),
            const SizedBox(height: 20),
            _buildWeeklyGoalHero(),
          ],
        );
      case DashboardSection.pillars:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              "Core Learning Pathways",
              onTap: _showAllPillars,
              trailing: const Icon(
                Icons.grid_view_rounded,
                color: AppColors.primaryBlue,
                size: 18,
              ),
            ),
            const SizedBox(height: 12),
            _buildPillarsGrid(),
          ],
        );
      case DashboardSection.competencies:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Core Competencies"),
            const SizedBox(height: 12),
            _buildCompetencyProgress(),
          ],
        );
      case DashboardSection.tasks:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Assignments & Tasks"),
            const SizedBox(height: 12),
            _buildAssignments(),
          ],
        );
      case DashboardSection.outcomes:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Learning Objectives"),
            const SizedBox(height: 12),
            _buildLearningOutcomes(),
          ],
        );
      case DashboardSection.activity:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Recent Activity"),
            const SizedBox(height: 12),
            _buildRecentActivities(),
          ],
        );
      case DashboardSection.achievements:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Achievements"),
            const SizedBox(height: 12),
            _buildBadges(),
          ],
        );
      case DashboardSection.timetable:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Timetable"),
            const SizedBox(height: 12),
            _buildTimetable(),
          ],
        );
      case DashboardSection.summary:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Weekly Learning Summary"),
            const SizedBox(height: 16),
            _buildWeeklySummaryFeed(),
          ],
        );
      case DashboardSection.parentTip:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Parent Tip"),
            const SizedBox(height: 16),
            _buildParentTipSection(),
          ],
        );
    }
  }

  Widget _buildQuickAccessSection() {
    final actions = _quickAccessActions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          "Quick Access",
          trailing: _buildSectionBadge("Tap to open"),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: actions.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final action = actions[index];
                    return _buildQuickAccessCard(action, compact: true);
                  },
                ),
              );
            }

            final columns = constraints.maxWidth >= 900
                ? 5
                : constraints.maxWidth >= 700
                ? 4
                : 3;
            const spacing = 12.0;
            final cardWidth =
                ((constraints.maxWidth - spacing * (columns - 1)) / columns)
                    .floorToDouble();

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: actions
                  .map(
                    (action) => SizedBox(
                      width: cardWidth,
                      child: _buildQuickAccessCard(action),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    return "Good evening";
  }

  Widget _buildLearnerProfileCard() {
    final initial = _userName.trim().isNotEmpty ? _userName.trim()[0] : 'L';

    return ElimuCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.brandGreen, AppColors.brandGreen],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.34),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting().toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _grade,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.86),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildHeroBadge("CBC Learner"),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.waving_hand_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "here is a learnshapshot for today.",

                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.94),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewHighlights() {
    final completedCount = _competencies
        .where((item) => item.progress >= 0.8)
        .length;
    final progressPercent = (_weeklyProgress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          "Overview",
          trailing: _buildSectionBadge("This week"),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 720;
            final cards = [
              _buildOverviewStatCard(
                title: "Weekly progress",
                value: "$progressPercent%",
                caption: _weeklyProgress >= 1 ? "Goal reached" : "Keep going",
                icon: Icons.trending_up_rounded,
                accent: AppColors.primaryBlue,
              ),
              _buildOverviewStatCard(
                title: "Strong competencies",
                value: completedCount.toString(),
                caption: completedCount == 1
                    ? "Competency above 80%"
                    : "Competencies above 80%",
                icon: Icons.auto_graph_rounded,
                accent: AppColors.brandGreen,
              ),
              _buildOverviewStatCard(
                title: "Open tasks",
                value: _openTaskCount.toString(),
                caption: _openTaskCount == 0
                    ? "No active quizzes yet"
                    : _openTaskCount == 1
                    ? "1 active quiz available"
                    : "Active quizzes available",
                icon: Icons.assignment_late_rounded,
                accent: AppColors.accentOrange,
              ),
            ];

            if (isCompact) {
              return Column(
                children: cards
                    .map(
                      (card) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: card,
                      ),
                    )
                    .toList(),
              );
            }

            return Row(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  Expanded(child: cards[i]),
                  if (i != cards.length - 1) const SizedBox(width: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildOverviewStatCard({
    required String title,
    required String value,
    required String caption,
    required IconData icon,
    required Color accent,
  }) {
    return ElimuCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  caption,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompetencyProgress() {
    if (_competencies.isEmpty) {
      return const ElimuCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              "No competency data available yet",
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ),
      );
    }

    return Column(
      children: _competencies.map((competency) {
        final name = competency.name;
        final progress = competency.progress;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ElimuCard(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CustomPaint(
                    painter: RingProgressPainter(
                      progress: progress,
                      color: AppColors.brandGreen,
                    ),
                    child: Center(
                      child: Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandGreen,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                      fontSize: 15,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAssignments() {
    // In a real app, this would also come from an API
    final assignments = [
      ("Science Project", "Due Tomorrow"),
      ("Math Quiz", "2 Days Left"),
    ];

    if (assignments.isEmpty) {
      return const ElimuCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              "No pending assignments",
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ),
      );
    }

    return Column(
      children: assignments
          .map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _assignmentTile(a.$1, a.$2),
            ),
          )
          .toList(),
    );
  }

  Widget _assignmentTile(String title, String subtitle) {
    return ElimuCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(
          backgroundColor: AppColors.primaryBlue,
          child: Icon(Icons.assignment_rounded, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textMuted),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      ),
    );
  }

  Widget _buildLearningOutcomes() {
    return const ElimuCard(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("• Understand water conservation methods"),
          SizedBox(height: 8),
          Text("• Apply math in real-life situations"),
          SizedBox(height: 8),
          Text("• Work effectively in groups"),
        ],
      ),
    );
  }

  Widget _buildRecentActivities() {
    // In a real app, this would also come from an API
    final activities = [
      ("Completed Science Quiz", "Today"),
      ("Read English Story", "Yesterday"),
    ];

    if (activities.isEmpty) {
      return const ElimuCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              "No recent activity recorded",
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ),
      );
    }

    return Column(
      children: activities
          .map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _activityTile(a.$1, a.$2),
            ),
          )
          .toList(),
    );
  }

  Widget _activityTile(String title, String subtitle) {
    return ElimuCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(
          backgroundColor: AppColors.accentOrange,
          child: Icon(Icons.history_rounded, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textMuted),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      ),
    );
  }

  Widget _buildBadges() {
    return const ElimuCard(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Icon(Icons.star, color: Colors.amber, size: 32),
          Icon(Icons.emoji_events, color: Colors.orange, size: 32),
          Icon(Icons.workspace_premium, color: Colors.blue, size: 32),
        ],
      ),
    );
  }

  Widget _buildTimetable() {
    final timetable = [
      ("7:30 AM", "Literacy"),
      ("9:00 AM", "Mathematics"),
      ("11:00 AM", "Science"),
      ("1:00 PM", "Creative Arts"),
    ];

    if (timetable.isEmpty) {
      return const ElimuCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              "No timetable scheduled",
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ),
      );
    }

    return Column(
      children: timetable.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ElimuCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    entry.$1,
                    style: const TextStyle(
                      color: AppColors.brandGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.$2,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickAccessCard(
    _QuickAccessAction action, {
    bool compact = false,
  }) {
    return SizedBox(
      width: compact ? 140 : null,
      height: compact ? 110 : 106,
      child: Stack(
        children: [
          ElimuCard(
            padding: EdgeInsets.all(compact ? 8 : 10),
            onTap: action.onTap,
            backgroundColor: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(compact ? 8 : 10),
                      decoration: BoxDecoration(
                        color: action.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        action.icon,
                        color: action.color,
                        size: compact ? 20 : 22,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: compact ? 14 : 16,
                      color: AppColors.textMuted.withValues(alpha: 0.8),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  action.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Open ${action.title.toLowerCase()}",
                  style: TextStyle(
                    fontSize: compact ? 9 : 10,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (action.badgeCount > 0)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentCoral,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  action.badgeCount > 9 ? "9+" : action.badgeCount.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openMenuItem(List<MenuItem> menuItems) {
    if (menuItems.isEmpty) return;
    _onSelectItem(menuItems.first);
  }

  List<_QuickAccessAction> get _quickAccessActions => [
    _QuickAccessAction(
      title: 'My Learning Areas',
      icon: Icons.menu_book_rounded,
      color: AppColors.brandGreen,
      badgeCount: 0,
      onTap: () => _openMenuItem([
        MenuItem(
          id: 'learning_areas',
          title: 'My Learning Areas',
          icon: Icons.menu_book_rounded,
        ),
      ]),
    ),
    _QuickAccessAction(
      title: 'Library',
      icon: Icons.local_library_rounded,
      color: AppColors.accentCoral,
      badgeCount: 0,
      onTap: () => widget.onNavigate(1),
    ),
    _QuickAccessAction(
      title: 'Grade Book',
      icon: Icons.assignment_turned_in_rounded,
      color: AppColors.primaryBlue,
      badgeCount: 3, // Mocking some pending assignments
      onTap: _openGradeBook,
    ),
    _QuickAccessAction(
      title: 'Interactive Books',
      icon: Icons.laptop_mac_rounded,
      color: AppColors.accentPurple,
      badgeCount: 0,
      onTap: () => _openMenuItem([
        MenuItem(
          id: 'interactive_books',
          title: 'Interactive Books',
          icon: Icons.laptop_mac_rounded,
        ),
      ]),
    ),
    _QuickAccessAction(
      title: 'Leaderboard',
      icon: Icons.emoji_events_rounded,
      color: AppColors.accentYellow,
      badgeCount: 0,
      onTap: () => _openMenuItem([
        MenuItem(
          id: 'leaderboard',
          title: 'Leaderboard',
          icon: Icons.emoji_events_rounded,
        ),
      ]),
    ),
    _QuickAccessAction(
      title: 'Elimu Quest',
      icon: Icons.bolt_rounded,
      color: AppColors.accentOrange,
      badgeCount: 5, // Mocking new quests
      onTap: () => widget.onNavigate(2),
    ),
    _QuickAccessAction(
      title: 'More',
      icon: Icons.menu_rounded,
      color: AppColors.accentCoral,
      badgeCount: 0,
      onTap: () => widget.onNavigate(3),
    ),
  ];

  Future<void> _openGradeBook() async {
    await SsoWebViewScreen.open(context,
        title: 'Grade Book', path: '/student/gradebook');
  }

  Widget _buildWeeklyGoalHero() {
    final progressPercent = (_weeklyProgress * 100).round();

    return ElimuCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryBlue,
                  AppColors.primaryBlue.withValues(alpha: 0.82),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.flag_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "WEEKLY GOAL",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _weeklyGoalTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildHeroBadge("$progressPercent%"),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                  child: LinearProgressIndicator(
                    value: _weeklyProgress,
                    minHeight: 12,
                    backgroundColor: Colors.white24,
                    color: AppColors.accentYellow,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _weeklyProgress >= 1.0
                      ? "Congratulations! You reached your goal."
                      : "Finish your activities to move this bar to 100%.",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: _buildGoalMeta(
                    label: "Progress",
                    value: "$progressPercent%",
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGoalMeta(
                    label: "Status",
                    value: _weeklyProgress >= 1 ? "Complete" : "In progress",
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalMeta({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceGray,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textMain,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 700;
        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 800
            ? 3
            : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: isTablet ? 14 : 12,
            mainAxisSpacing: isTablet ? 14 : 12,
            childAspectRatio: isTablet ? 2.2 : 1.4,
          ),
          itemCount: _featuredCoreLearningPillars.length,
          itemBuilder: (context, index) {
            return _buildPillarCard(
              _featuredCoreLearningPillars[index],
              isTablet: isTablet,
            );
          },
        );
      },
    );
  }

  List<Map<String, Object>> get _featuredCoreLearningPillars =>
      _coreLearningPillars.take(4).toList();

  List<Map<String, Object>> get _coreLearningPillars => [
    {
      "title": "Literacy",
      "icon": Icons.menu_book_rounded,
      "color": AppColors.primaryBlue,
      "desc":
          "Communication skills in English, Kiswahili, and local languages.",
    },
    {
      "title": "Mathematics",
      "icon": Icons.calculate_rounded,
      "color": AppColors.accentPurple,
      "desc": "Focusing on logical thinking and problem-solving.",
    },
    {
      "title": "Science and Technology",
      "icon": Icons.biotech_rounded,
      "color": AppColors.brandGreen,
      "desc": "Nature, experimentation, and digital literacy.",
    },
    {
      "title": "Social Studies",
      "icon": Icons.public_rounded,
      "color": AppColors.accentOrange,
      "desc": "Citizenship, geography, history, and community life.",
    },
    {
      "title": "Creative Arts & Sports",
      "icon": Icons.palette_rounded,
      "color": AppColors.accentYellow,
      "desc": "Performing arts, visual arts, and PE.",
    },
    {
      "title": "Religious Education",
      "icon": Icons.church_rounded,
      "color": AppColors.primaryBlue,
      "desc": "CRE, IRE, and HRE for values and growth.",
    },
    {
      "title": "Agriculture and Nutrition",
      "icon": Icons.agriculture_rounded,
      "color": AppColors.brandGreen,
      "desc": "Food production and healthy living skills.",
    },
    {
      "title": "Life Skills Education",
      "icon": Icons.psychology_rounded,
      "color": AppColors.accentPurple,
      "desc": "Self-awareness and social-emotional growth.",
    },
  ];

  Widget _buildPillarCard(Map<String, Object> p, {bool isTablet = false}) {
    return ElimuCard(
      padding: EdgeInsets.all(isTablet ? 12 : 10),
      onTap: () => widget.onNavigate(1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isTablet)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['title'] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textMain,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p['desc'] as String,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (p['color'] as Color).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    p['icon'] as IconData,
                    color: p['color'] as Color,
                    size: 24,
                  ),
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 8 : 10),
                  decoration: BoxDecoration(
                    color: (p['color'] as Color).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    p['icon'] as IconData,
                    color: p['color'] as Color,
                    size: isTablet ? 20 : 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['title'] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isTablet ? 13 : 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p['desc'] as String,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: isTablet ? 10 : 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _showAllPillars() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surfaceGray,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.darkGray.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "All Core Learning Pathways",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: GridView.builder(
                          controller: scrollController,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.15,
                              ),
                          itemCount: _coreLearningPillars.length,
                          itemBuilder: (context, index) {
                            return _buildPillarCard(
                              _coreLearningPillars[index],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWeeklySummaryFeed() {
    return Column(
      children: [
        _buildSummaryAccordion(
          "Key Inquiry Question",
          "How do we conserve water in our community?",
          Icons.help_outline_rounded,
        ),
        const SizedBox(height: 12),
        _buildSummaryAccordion(
          "Core Competencies",
          "This week we focused on Collaboration and Critical Thinking through group experiments.",
          Icons.psychology_rounded,
        ),
      ],
    );
  }

  Widget _buildSummaryAccordion(String title, String content, IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ExpansionTile(
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.white,
        leading: Icon(icon, color: AppColors.primaryBlue),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textMain,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              content,
              style: const TextStyle(color: AppColors.textMuted, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentTipSection() {
    return ElimuCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: AppColors.accentYellow.withValues(alpha: 0.1),
      borderColor: AppColors.accentYellow.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "PARENT'S TIP OF THE DAY",
            style: TextStyle(
              color: AppColors.accentOrange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Ask your child to show you how they can save water while brushing their teeth today!",
            style: TextStyle(
              color: AppColors.textMain,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title, {
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.brandGreen,
            ),
          ),
        ),
        if (trailing != null) ...[trailing, const SizedBox(width: 4)],
        if (onTap != null)
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                "See All",
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brandGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.brandGreen,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildHeroBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _QuickAccessAction {
  _QuickAccessAction({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int badgeCount;
}

// --- CUSTOM PAINTER FOR CIRCULAR CHART ---
class RingProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  RingProgressPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 8.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final pgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      pgPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
