import 'package:elimupepe/core/webview/webview_policy.dart';
import 'package:elimupepe/core/webview/sso_webview.dart';
import 'package:flutter/material.dart';
import 'package:elimupepe/models/menu_item.dart';
import 'package:elimupepe/core/theme/app_theme.dart';
import 'package:elimupepe/core/widgets/elimu_card.dart';
import 'package:elimupepe/core/config/app_endpoints.dart';
import 'package:elimupepe/core/utils/image_url_resolver.dart';
import 'package:elimupepe/features/quiz/quiz_session_screen.dart';
import 'package:elimupepe/features/quiz/learner_dashboard_api_service.dart';
import 'package:elimupepe/core/utils/error_feedback.dart';

class CategoryItemsScreen extends StatefulWidget {
  final MenuItem menuItem;

  const CategoryItemsScreen({super.key, required this.menuItem});

  @override
  State<CategoryItemsScreen> createState() => _CategoryItemsScreenState();
}

class _CategoryItemsScreenState extends State<CategoryItemsScreen> {
  late Future<List<dynamic>> _itemsFuture;

  Future<void> _handleBackNavigation() async {
    if (!mounted) return;

    // Keep back behavior local to this route so we return to the library
    // screen instead of falling through to a higher-level exit path.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).maybePop();
  }

  @override
  void initState() {
    super.initState();
    _itemsFuture = LearnerDashboardApiService.instance.fetchMenuItems(
      menuId: widget.menuItem.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: AppColors.lightGreen,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.lightGreen,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _handleBackNavigation,
          ),
          title: Row(
            children: [
              Icon(widget.menuItem.icon, size: 24, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.menuItem.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: widget.menuItem.isComingSoon
            ? _buildComingSoonView()
            : _buildItemsView(),
      ),
    );
  }

  Widget _buildComingSoonView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(widget.menuItem.icon, size: 80, color: Colors.white),
          const SizedBox(height: 24),
          const Text(
            'Coming Soon!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              '${widget.menuItem.title} will be available soon.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsView() {
    return FutureBuilder<List<dynamic>>(
      future: _itemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.lightGreen),
          );
        }

        if (snapshot.hasError) {
          return ErrorFeedback.buildInlineError(
            context: context,
            title: 'Failed to load ${widget.menuItem.title}',
            error: snapshot.error,
            onRetry: () {
              setState(() {
                _itemsFuture = LearnerDashboardApiService.instance
                    .fetchMenuItems(menuId: widget.menuItem.id);
              });
            },
          );
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.inbox_outlined,
                    size: 56,
                    color: Colors.white70,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No ${widget.menuItem.title} available yet',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final title = _extractTitle(item, index, widget.menuItem.id);
            final subtitle = _extractSubtitle(item, widget.menuItem.id);
            String? imageUrl = item is Map<String, dynamic>
                ? ImageUrlResolver.fromMap(item)
                : null;

            if (imageUrl != null) {
              if (imageUrl.contains('/http')) {
                imageUrl = imageUrl.substring(imageUrl.indexOf('/http') + 1);
              }
              if (imageUrl.contains(' ') && !imageUrl.contains('%20')) {
                imageUrl = imageUrl.replaceAll(' ', '%20');
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ElimuCard(
                padding: const EdgeInsets.all(4),
                child: ListTile(
                  onTap: () => _openItem(item, title),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  leading: _buildItemLeading(imageUrl),
                  title: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandGreen,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: subtitle == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF5C6F8A)),
                          ),
                        ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF5C6F8A),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildItemLeading(String? imageUrl) {
    if (imageUrl != null) {
      return CircleAvatar(
        backgroundColor: AppColors.lightGreen.withValues(alpha: 0.08),
        backgroundImage: NetworkImage(imageUrl),
        onBackgroundImageError: (exception, stackTrace) {},
        child: null,
      );
    }

    return CircleAvatar(
      backgroundColor: AppColors.lightGreen.withValues(alpha: 0.15),
      child: Icon(widget.menuItem.icon, size: 20, color: AppColors.lightGreen),
    );
  }

  String _extractTitle(dynamic item, int index, String menuId) {
    if (item is Map<String, dynamic>) {
      final value = switch (menuId) {
        'learning_areas' =>
          item['title'] ?? item['course_name'] ?? item['name'],
        'virtual_labs' => item['title'] ?? item['lab_title'] ?? item['name'],
        'elimu_quest' ||
        'leaderboard' ||
        'my_questions' ||
        'games' => item['title'] ?? item['quiz_title'] ?? item['name'],
        'interactive_books' ||
        'non_interactive_books' ||
        'esoma_kids' => item['title'] ?? item['book_title'] ?? item['name'],
        _ => item['title'] ?? item['name'] ?? item['course_name'],
      };

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return '${widget.menuItem.title} Item ${index + 1}';
  }

  String? _extractSubtitle(dynamic item, String menuId) {
    if (item is Map<String, dynamic>) {
      final value = switch (menuId) {
        'learning_areas' => _buildLearningAreaSubtitle(item),
        'virtual_labs' => _buildLabSubtitle(item),
        'elimu_quest' ||
        'leaderboard' ||
        'my_questions' ||
        'games' => _buildQuizSubtitle(item),
        'interactive_books' ||
        'non_interactive_books' ||
        'esoma_kids' => _buildBookSubtitle(item),
        _ => item['description'] ?? item['summary'] ?? item['publisher'],
      };

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }

  String? _buildLearningAreaSubtitle(Map<String, dynamic> item) {
    final teacher = _asText(item['']);
    final percentage = item['totalCompletePercentage'];
    final progress = percentage is num
        ? '${percentage.toStringAsFixed(0)}% complete'
        : null;

    if (teacher != null && progress != null) {
      return '$teacher • $progress';
    }
    return teacher ?? progress;
  }

  String? _buildBookSubtitle(Map<String, dynamic> item) {
    final description = _asText(item['description']);
    final publisher = _asText(item['publisher']);
    final language = _asText(item['language']);
    final subject = _asText(item['learning area']);
    final grade = _asText(item['grade']);

    if (publisher != null && language != null) {
      return '$publisher • $language';
    }
    return description ?? publisher ?? subject ?? grade ?? language;
  }

  String? _buildLabSubtitle(Map<String, dynamic> item) {
    final description = _asText(item['description']);
    final low = _asText(item['low_grade_level']);
    final high = _asText(item['high_grade_level']);

    if (low != null && high != null) {
      return '$low to $high';
    }
    return description ?? low ?? high;
  }

  String? _buildQuizSubtitle(Map<String, dynamic> item) {
    final teacher = _asText(item['']);
    final quizId = item['quiz_id'];

    if (teacher != null && quizId != null) {
      return '$teacher • Quiz #$quizId';
    }
    if (quizId != null) {
      return 'Quiz #$quizId';
    }
    return teacher;
  }

  String? _asText(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  Future<void> _openItem(dynamic item, String title) async {
    if (_shouldOpenAsQuiz(item)) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizSessionScreen(
            title: title,
            quizItem: Map<String, dynamic>.from(item),
          ),
        ),
      );
      return;
    }

    String? url = _extractContentUrl(item);

    if (url == null && item is Map<String, dynamic>) {
      url = await LearnerDashboardApiService.instance.resolveItemContentUrl(
        menuId: widget.menuItem.id,
        item: item,
      );
    }

    if (url == null) {
      if (!mounted) return;
      final message = widget.menuItem.id == 'learning_areas'
          ? 'This learning area is not yet linked to content by the server.'
          : 'No direct content URL was provided for this item yet.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final normalizedUrl = _normalizeUrl(url);
    if (normalizedUrl == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid content URL for this item.')),
      );
      return;
    }

    // Virtual labs open the simulation page; our own pages open signed in;
    // everything else is a public page (other hosts leave the app).
    String? ssoPath;
    if (widget.menuItem.id == 'virtual_labs' && item is Map<String, dynamic>) {
      final simulationId =
          item['phet_id']?.toString() ?? item['id']?.toString() ?? '';
      if (simulationId.isNotEmpty) ssoPath = '/phet/simulations/$simulationId';
    }
    final parsed = Uri.tryParse(normalizedUrl);
    if (ssoPath == null &&
        parsed != null &&
        _shouldWrapWithWebviewLogin(normalizedUrl) &&
        WebviewPolicy(ownHost: AppEndpoints.primaryHost)
            .isOwnHost(parsed.host)) {
      ssoPath = parsed.hasQuery ? '${parsed.path}?${parsed.query}' : parsed.path;
    }

    if (!mounted) return;

    if (ssoPath != null && WebviewPolicy.isSafeIntendedPath(ssoPath)) {
      await SsoWebViewScreen.open(context, title: title, path: ssoPath);
    } else {
      await SsoWebViewScreen.openPublic(context,
          title: title, url: normalizedUrl);
    }
  }

  bool _shouldOpenAsQuiz(dynamic item) {
    if (item is! Map<String, dynamic>) {
      return false;
    }

    if (!{'elimu_quest', 'my_questions'}.contains(widget.menuItem.id)) {
      return false;
    }

    final hasQuizIdentifier =
        item['quiz_id'] != null ||
        item['id'] != null ||
        item['question_id'] != null;
    final hasDirectUrl = _extractContentUrl(item) != null;

    return hasQuizIdentifier && !hasDirectUrl;
  }

  String? _normalizeUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      return uri?.toString();
    }

    if (trimmed.startsWith('/')) {
      final uri = Uri.tryParse('${AppEndpoints.webBaseUrl}$trimmed');
      return uri?.toString();
    }

    final uri = Uri.tryParse('https://$trimmed');
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open item content.')),
      );
      return null;
    }
    return uri.toString();
  }

  String? _extractContentUrl(dynamic item) {
    if (item is! Map<String, dynamic>) {
      return null;
    }

    final url =
        item['book_url'] ??
        item['course_url'] ??
        item['quiz_url'] ??
        item['run_url'] ??
        item['url'] ??
        item['link'] ??
        item['pdf_url'] ??
        item['resource_url'];

    if (url is String && url.trim().isNotEmpty) {
      return url.trim();
    }
    return null;
  }

  bool _shouldWrapWithWebviewLogin(String normalizedUrl) {
    if (widget.menuItem.id == 'non_interactive_books') {
      return false;
    }

    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) {
      return true;
    }

    final path = uri.path.toLowerCase();
    if (path.contains('/api/webview-auth') ||
        path.contains('/student/webview-token') ||
        path.endsWith('.pdf')) {
      return false;
    }

    return true;
  }
}
