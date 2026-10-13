import 'package:elimupepe/core/webview/sso_webview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:elimupepe/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:elimupepe/core/widgets/elimu_button.dart';
import 'package:elimupepe/core/widgets/elimu_card.dart';
import 'package:elimupepe/app/app_services.dart';
import 'package:elimupepe/features/home/main_view.dart';
import 'package:elimupepe/features/home/home_screen.dart';
import 'package:elimupepe/features/home/menu_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elimupepe/core/utils/image_url_resolver.dart';
import 'package:elimupepe/features/profile/profile_screen.dart';
import 'package:elimupepe/features/parental_control/parental_gate.dart';
import 'package:elimupepe/features/quiz/learner_dashboard_api_service.dart';

class GamifiedDashboardScreen extends StatefulWidget {
  const GamifiedDashboardScreen({
    super.key,
    this.initialIndex = 0,
    this.restoreLastTab = true,
  });

  final int initialIndex;
  final bool restoreLastTab;

  @override
  State<GamifiedDashboardScreen> createState() =>
      _GamifiedDashboardScreenState();
}

class _GamifiedDashboardScreenState extends State<GamifiedDashboardScreen> {
  int _selectedIndex = 0; // 0: Home, 1: Library, 2: Quest, 3: Menu, 4: Profile
  final GlobalKey<ScaffoldState> _homeScaffoldKey = GlobalKey<ScaffoldState>();
  final List<Widget?> _tabCache = List<Widget?>.filled(5, null);
  String _userName = 'Learner';
  String? _userAvatar;
  bool _isOpeningStudentDashboard = false;
  bool _questLoading = true;
  int _coins = 0;
  int _streakDays = 0;
  int _badgeCount = 0;
  int _leaderboardRank = 0;
  int _questCount = 0;

  @override
  void initState() {
    super.initState();
    _loadLastSessionState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadQuestData();
    });
  }

  Future<void> _loadLastSessionState() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await AppServices.instance.profile.read();
    if (mounted) {
      setState(() {
        _selectedIndex = widget.restoreLastTab
            ? prefs.getInt('last_dashboard_tab_index') ?? widget.initialIndex
            : widget.initialIndex;
        _userName = profile.name ?? 'Learner';
        _userAvatar = ImageUrlResolver.withCacheBuster(
          profile.avatarUrl,
          cacheKey: AppServices.instance.profile.avatarCacheKey,
        );
      });
    }
  }

  Future<void> _onItemTapped(int index) async {
    setState(() {
      _selectedIndex = index;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_dashboard_tab_index', index);
  }

  Future<void> _openProtectedWebView({
    required String title,
    required String intendedPath,
  }) async {
    if (_isOpeningStudentDashboard) {
      return;
    }
    setState(() {
      _isOpeningStudentDashboard = true;
    });
    try {
      if (!mounted) return;
      await SsoWebViewScreen.open(context, title: title, path: intendedPath);
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningStudentDashboard = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = List<Widget>.generate(5, (index) {
      final cached = _tabCache[index];
      if (cached != null) {
        return cached;
      }

      if (index != _selectedIndex) {
        return const SizedBox.shrink();
      }

      final tab = _buildTab(index);
      _tabCache[index] = tab;
      return tab;
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;

        if (_selectedIndex != 0) {
          await _onItemTapped(0);
          return;
        }

        SystemNavigator.pop();
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: const Color(0xFFF0F8FF),
            body: IndexedStack(index: _selectedIndex, children: tabs),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppColors.accentCoral,
              unselectedItemColor: Colors.blueGrey.shade300,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined, size: 28),
                  activeIcon: Icon(Icons.home_rounded, size: 28),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.local_library_outlined, size: 28),
                  activeIcon: Icon(Icons.local_library_rounded, size: 28),
                  label: 'Library',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bolt_outlined, size: 28),
                  activeIcon: Icon(Icons.bolt_rounded, size: 28),
                  label: 'Quest',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.menu_outlined, size: 28),
                  activeIcon: Icon(Icons.menu_rounded, size: 28),
                  label: 'Menu',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded, size: 28),
                  activeIcon: Icon(Icons.person_rounded, size: 28),
                  label: 'Profile',
                ),
              ],
            ),
          ),
          if (_isOpeningStudentDashboard)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.lightGreen),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return MainView(onNavigate: _onItemTapped);
      case 1:
        return HomeScreen(scaffoldKey: _homeScaffoldKey);
      case 2:
        return _buildDashboardContent();
      case 3:
        return const MenuScreen();
      case 4:
        return const ProfileScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- UI COMPONENTS ---

  Widget _buildDashboardContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallPhone = screenWidth < 360;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final horizontalPadding = isSmallPhone ? 16.0 : 24.0;
    final sectionGap = isSmallPhone ? 14.0 : 18.0;

    Widget summaryButton = Padding(
      padding: EdgeInsets.symmetric(horizontal: isLandscape ? 0 : horizontalPadding),
      child: _questLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.lightGreen,
              ),
            )
          : ElimuButton(
              text: 'View Progress Summary',
              onPressed: _showQuestSummaryDialog,
              type: ElimuButtonType.secondary,
              icon: Icons.bar_chart_rounded,
            ),
    );

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadQuestData,
        color: AppColors.brandGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(horizontalPadding: horizontalPadding),
              SizedBox(height: sectionGap),
              if (isLandscape)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _buildQuestCard(horizontalPadding: 0),
                            SizedBox(height: sectionGap),
                            summaryButton,
                          ],
                        ),
                      ),
                      SizedBox(width: sectionGap),
                      Expanded(
                        child: Column(
                          children: [
                            _buildLeaderboardCard(horizontalPadding: 0),
                            SizedBox(height: sectionGap),
                            _buildSupportSection(horizontalPadding: 0),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    _buildQuestCard(horizontalPadding: horizontalPadding),
                    SizedBox(height: sectionGap),
                    summaryButton,
                    SizedBox(height: sectionGap),
                    _buildLeaderboardCard(horizontalPadding: horizontalPadding),
                    SizedBox(height: isSmallPhone ? 16 : 20),
                    _buildSupportSection(horizontalPadding: horizontalPadding),
                  ],
                ),
              const SizedBox(height: 80),
            ],
          ).animate().fadeIn(duration: 500.ms),
        ),
      ),
    );
  }

  Widget _buildHeader({required double horizontalPadding}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallPhone = screenWidth < 360;
    final titleSize = isSmallPhone ? 19.0 : 23.0;
    final subtitleSize = isSmallPhone ? 12.0 : 13.0;
    final avatarRadius = isSmallPhone ? 22.0 : 26.0;
    final boltIconSize = isSmallPhone ? 24.0 : 28.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 14, horizontalPadding, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      color: AppColors.accentYellow,
                      size: boltIconSize,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Quest Hub',
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w900,
                        color: AppColors.brandGreen,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Ready for your next challenge, ${_userName.split(' ').first}?",
                  style: TextStyle(
                    fontSize: subtitleSize,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.lightGreen.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: CircleAvatar(
              radius: avatarRadius,
              backgroundColor: AppColors.surfaceGray,
              backgroundImage: _userAvatar != null
                  ? NetworkImage(_userAvatar!)
                  : null,
              child: _userAvatar == null
                  ? Text(
                      (_userName.trim().isNotEmpty ? _userName.trim()[0] : '?')
                          .toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: isSmallPhone ? 15 : 17,
                        color: AppColors.brandGreen,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestCard({required double horizontalPadding}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallPhone = screenWidth < 360;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ElimuCard(
            onTap: () => _openProtectedWebView(
              title: 'Elimu Quest',
              intendedPath: '/my-quizzes',
            ),
            padding: EdgeInsets.zero,
            backgroundColor: AppColors.brandGreen,
            borderColor: AppColors.brandGreen.withValues(alpha: 0.8),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.brandGreen, AppColors.lightGreen],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: EdgeInsets.fromLTRB(
                isSmallPhone ? 14 : 18,
                isSmallPhone ? 18 : 22,
                isSmallPhone ? 14 : 18,
                isSmallPhone ? 16 : 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallPhone ? 12 : 16,
                      vertical: isSmallPhone ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          color: AppColors.accentYellow,
                          size: isSmallPhone ? 16 : 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _questCount > 0
                              ? '$_questCount NEW QUESTS'
                              : 'DAILY QUEST',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: isSmallPhone ? 11 : 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isSmallPhone ? 10 : 14),
                  Text(
                    'Elimu Quest',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallPhone ? 22 : 28,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete missions to earn LohoCoins\nand climb the leaderboard.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: isSmallPhone ? 12 : 13,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: isSmallPhone ? 12 : 16),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      vertical: isSmallPhone ? 10 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brandGreen.withValues(alpha: 0.35),
                          offset: const Offset(0, 4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'START PLAYING',
                          style: TextStyle(
                            color: AppColors.brandGreen,
                            fontWeight: FontWeight.w900,
                            fontSize: isSmallPhone ? 12 : 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.sports_esports_rounded,
                          color: AppColors.brandGreen,
                          size: isSmallPhone ? 18 : 20,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: isSmallPhone ? -12 : -20,
            right: isSmallPhone ? 12 : 20,
            child: Container(
              padding: EdgeInsets.all(isSmallPhone ? 12 : 16),
              decoration: BoxDecoration(
                color: AppColors.accentYellow,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                Icons.extension_rounded,
                color: Colors.white,
                size: isSmallPhone ? 28 : 40,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestStatTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return ElimuCard(
      backgroundColor: Colors.white,
      borderColor: color.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection({required double horizontalPadding}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallPhone = screenWidth < 360;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ElimuCard(
            onTap: _launchWhatsApp,
            padding: EdgeInsets.zero,
            backgroundColor: AppColors.brandGreen,
            borderColor: AppColors.brandGreen.withValues(alpha: 0.4),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandGreen.withValues(alpha: 0.08),
                    offset: const Offset(0, 8),
                    blurRadius: 16,
                  ),
                ],
              ),
              padding: EdgeInsets.all(isSmallPhone ? 16 : 24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Need Support?',
                          style: TextStyle(
                            color: AppColors.textMain,
                            fontSize: isSmallPhone ? 15 : 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Chat with us on WhatsApp for quick help.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: isSmallPhone ? 12 : 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: isSmallPhone ? 12 : 20),
                  Container(
                    padding: EdgeInsets.all(isSmallPhone ? 10 : 14),
                    decoration: BoxDecoration(
                      color: AppColors.brandGreen.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.support_agent_rounded,
                      color: AppColors.brandGreen,
                      size: isSmallPhone ? 24 : 32,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardCard({required double horizontalPadding}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallPhone = screenWidth < 360;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ElimuCard(
            onTap: () => _openProtectedWebView(
              title: 'Leaderboard',
              intendedPath: '/leaderboard/embed',
            ),
            padding: EdgeInsets.zero,
            backgroundColor: AppColors.primaryBlue,
            borderColor: AppColors.primaryBlue.withValues(alpha: 0.8),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryBlue, AppColors.deepBlue],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: EdgeInsets.all(isSmallPhone ? 16 : 24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'HALL OF FAME',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallPhone ? 10 : 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(height: isSmallPhone ? 12 : 16),
                        Text(
                          'Leaderboard',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallPhone ? 19 : 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'See where you rank among top learners',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: isSmallPhone ? 12 : 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: isSmallPhone ? 10 : 16),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white54,
                    size: isSmallPhone ? 16 : 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: isSmallPhone ? -10 : -15,
            right: isSmallPhone ? 14 : 24,
            child: Container(
              padding: EdgeInsets.all(isSmallPhone ? 10 : 14),
              decoration: BoxDecoration(
                color: AppColors.accentYellow,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                color: Colors.white,
                size: isSmallPhone ? 28 : 36,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showQuestSummaryDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Your Progress Summary',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.brandGreen,
            ),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: _buildQuestSummaryGrid(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuestSummaryGrid() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildQuestStatTile(
                label: 'Coins',
                value: _coins.toString(),
                icon: Icons.monetization_on_rounded,
                color: AppColors.accentYellow,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuestStatTile(
                label: 'Streak',
                value: '$_streakDays d',
                icon: Icons.local_fire_department_rounded,
                color: AppColors.accentOrange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuestStatTile(
                label: 'Badges',
                value: _badgeCount.toString(),
                icon: Icons.workspace_premium_rounded,
                color: AppColors.lightGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuestStatTile(
                label: 'Rank',
                value: _leaderboardRank > 0 ? '#$_leaderboardRank' : '-',
                icon: Icons.emoji_events_rounded,
                color: Colors.orange.shade500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _loadQuestData() async {
    if (mounted) {
      setState(() {
        _questLoading = true;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        LearnerDashboardApiService.instance.fetchGamificationDashboard(),
        LearnerDashboardApiService.instance.fetchWallet(),
        LearnerDashboardApiService.instance.fetchStreaks(),
        LearnerDashboardApiService.instance.fetchBadges(),
        LearnerDashboardApiService.instance.fetchLeaderboard(),
        LearnerDashboardApiService.instance.fetchQuizzes(),
      ]);

      final dashboard = results[0] is Map<String, dynamic>
          ? results[0] as Map<String, dynamic>
          : null;
      final wallet = results[1] is Map<String, dynamic>
          ? results[1] as Map<String, dynamic>
          : null;
      final streaks = results[2] is Map<String, dynamic>
          ? results[2] as Map<String, dynamic>
          : null;
      final badges = results[3] is List
          ? results[3] as List<dynamic>
          : const [];
      final leaderboard = results[4] is List
          ? results[4] as List<dynamic>
          : const [];
      final quizzes = results[5] is List
          ? results[5] as List<dynamic>
          : const [];

      final coins = _firstInt([
        wallet?['balance'],
        wallet?['coins'],
        wallet?['loho_coins'],
        dashboard?['coins'],
        dashboard?['wallet_balance'],
      ]);
      final streak = _firstInt([
        streaks?['current_streak'],
        streaks?['streak'],
        streaks?['days'],
        dashboard?['streak'],
      ]);
      final rank = _firstInt([
        dashboard?['rank'],
        dashboard?['leaderboard_rank'],
      ]);

      if (mounted) {
        setState(() {
          _coins = coins;
          _streakDays = streak;
          _badgeCount = badges.length;
          _leaderboardRank = rank > 0
              ? rank
              : _inferLeaderboardRank(leaderboard);
          _questCount = quizzes.length;
          _questLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _questLoading = false;
        });
      }
    }
  }

  int _firstInt(List<dynamic> values) {
    for (final value in values) {
      if (value is int) return value;
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
      if (value is double) return value.round();
    }
    return 0;
  }

  int _inferLeaderboardRank(List<dynamic> leaderboard) {
    final normalizedName = _userName.trim().toLowerCase();
    for (var i = 0; i < leaderboard.length; i++) {
      final item = leaderboard[i];
      if (item is! Map<String, dynamic>) continue;
      final name =
          [
            item['name']?.toString(),
            item['username']?.toString(),
            [item['first_name']?.toString(), item['last_name']?.toString()]
                .whereType<String>()
                .where((part) => part.trim().isNotEmpty)
                .join(' '),
          ].whereType<String>().firstWhere(
            (candidate) => candidate.trim().isNotEmpty,
            orElse: () => '',
          );
      if (name.trim().toLowerCase() == normalizedName) {
        return i + 1;
      }
    }
    return 0;
  }

  Future<void> _launchWhatsApp() async {
    final passed = await showParentalGate(context);

    if (passed) {
      final Uri url = Uri.parse('https://wa.me/254797349396');
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        debugPrint('Could not launch WhatsApp');
      }
    }
  }

}
