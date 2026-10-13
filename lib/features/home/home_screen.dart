import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:elimupepe/models/ebook.dart';
import 'package:elimupepe/models/menu_item.dart';
import 'package:elimupepe/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:elimupepe/core/widgets/elimu_card.dart';
import 'package:elimupepe/core/widgets/elimu_button.dart';
import 'package:elimupepe/core/config/app_endpoints.dart';
import 'package:elimupepe/core/utils/error_feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elimupepe/features/reader/reader_screen.dart';
import 'package:elimupepe/core/services/storage_service.dart';
import 'package:elimupepe/core/services/php_api_service.dart';
import 'package:elimupepe/core/widgets/category_nav_bar.dart';
import 'package:elimupepe/core/utils/image_url_resolver.dart';
import 'package:elimupepe/core/services/database_service.dart';
import 'package:elimupepe/core/services/analytics_service.dart';
import 'package:elimupepe/core/services/thumbnail_service.dart';
import 'package:elimupepe/core/services/user_data_service.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:elimupepe/features/settings/settings_screen.dart';
import 'package:elimupepe/features/home/category_items_screen.dart';
import 'package:elimupepe/core/services/cloud_sync_service_php.dart';
import 'package:elimupepe/features/settings/webview_content_screen.dart';
import 'package:elimupepe/features/quiz/learner_dashboard_api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.scaffoldKey});

  final GlobalKey<ScaffoldState>? scaffoldKey;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const String _booksImageBaseUrl = AppEndpoints.ebooksApiBaseUrl;
  final DatabaseService _databaseService = DatabaseService.instance;
  final StorageService _storageService = StorageService.instance;
  final PhpApiService _apiService = PhpApiService.instance;
  final CloudSyncServicePhp _cloudSyncService = CloudSyncServicePhp.instance;

  late final GlobalKey<ScaffoldState> _scaffoldKey;
  late AnimationController _drawerController;

  List<Ebook> _ebooks = [];
  List<Ebook> _cloudBooks = [];
  bool _isLoadingEbooks = true;
  bool _isLoadingCloudBooks = true;
  String? _ebooksError;
  String? _cloudBooksError;
  String _searchQuery = '';
  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String? _selectedCourse;
  String? _learnerGrade;
  List<String> _studentCourses = [
    'PP1',
    'PP2',
    'Grade 1',
    'Grade 2',
    'Grade 3',
    'Grade 4',
    'Grade 5',
    'Grade 6',
    'Grade 7',
    'Grade 8',
    'Grade 9',
    'Grade 10',
    'Grade 11',
    'Grade 12',
  ];
  // Use ValueNotifier for each download to avoid full page rebuilds
  final Map<String, ValueNotifier<double>> _downloadProgress =
      {}; // Track download progress per book ID

  @override
  void initState() {
    super.initState();
    _scaffoldKey = widget.scaffoldKey ?? GlobalKey<ScaffoldState>();
    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadCloudBooks();
    _warmUpLibraryData();
    _loadLearnerGrade();
    _loadStudentCourses();
  }

  @override
  void dispose() {
    _drawerController.dispose();
    // Clean up ValueNotifiers to prevent memory leaks
    for (var notifier in _downloadProgress.values) {
      notifier.dispose();
    }
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _showActionError(
    Object error, {
    required String title,
    String fallback = 'Something went wrong. Please try again.',
  }) async {
    if (!mounted) return;

    if (ErrorFeedback.shouldShowDialog(error)) {
      await ErrorFeedback.showErrorDialog(
        context,
        title: title,
        error: error,
        fallback: fallback,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ErrorFeedback.userMessage(error, fallback: fallback)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  void _resetSearch({bool refreshBooks = false}) {
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
    }

    if (_searchQuery.isNotEmpty) {
      setState(() {
        _searchQuery = '';
        _isSearchActive = false;
      });
    } else {
      setState(() {
        _isSearchActive = false;
      });
    }

    if (refreshBooks) {
      _loadEbooks();
      _loadCloudBooks();
    }
  }

  void _toggleDrawer() {
    if (_drawerController.isDismissed) {
      _drawerController.forward();
    } else {
      _drawerController.reverse();
    }
  }

  Future<void> _warmUpLibraryData() async {
    // Keep the first frame responsive by loading the visible data immediately.
    try {
      await _cloudSyncService.removeBundledBooks();
      await _loadEbooks();
    } catch (e) {
      debugPrint('Cannot remove bundled books: $e');
    }

    // Try to sync with Firebase if connected.
    try {
      await _cloudSyncService.syncDownloadedBookMetadata();
    } catch (e) {
      debugPrint('Cannot sync metadata (offline or error): $e');
      // Continue anyway - user can still read offline books
    }
  }

  Future<void> _refreshLibrary() async {
    final refreshTrace = FirebasePerformance.instance.newTrace(
      'library_refresh',
    );
    await refreshTrace.start();
    try {
      await Future.wait([
        _loadLearnerGrade(),
        _loadStudentCourses(),
        _loadEbooks(),
        _loadCloudBooks(),
      ]);
    } finally {
      await refreshTrace.stop();
    }
  }

  Future<void> _loadEbooks() async {
    if (mounted) {
      setState(() {
        _isLoadingEbooks = true;
        _ebooksError = null;
      });
    } else {
      _isLoadingEbooks = true;
      _ebooksError = null;
    }

    try {
      final books = await _databaseService.getAllEbooks();
      if (!mounted) return;
      setState(() {
        _ebooks = books;
        _isLoadingEbooks = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ebooksError = ErrorFeedback.userMessage(e);
        _isLoadingEbooks = false;
      });
    }
  }

  Future<void> _loadCloudBooks() async {
    if (mounted) {
      setState(() {
        _isLoadingCloudBooks = true;
        _cloudBooksError = null;
      });
    } else {
      _isLoadingCloudBooks = true;
      _cloudBooksError = null;
    }

    try {
      final books = await _fetchLearnerTextbooks();
      if (!mounted) return;
      setState(() {
        _cloudBooks = books;
        _isLoadingCloudBooks = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cloudBooksError = ErrorFeedback.userMessage(e);
        _isLoadingCloudBooks = false;
      });
    }
  }

  Future<List<Ebook>> _fetchLearnerTextbooks() async {
    try {
      debugPrint('Fetching books from PhpApiService...');
      final results = await Future.wait([
        _apiService.getCloudBooks(),
        LearnerDashboardApiService.instance.fetchBooks(),
        LearnerDashboardApiService.instance.fetchELibrary(),
      ]);
      final cloudBooksFromPhp = results[0] is List<Ebook>
          ? results[0] as List<Ebook>
          : const <Ebook>[];
      debugPrint('PhpApiService returned ${cloudBooksFromPhp.length} books');

      final Map<String, Ebook> cloudBooksMap = {};

      for (final book in cloudBooksFromPhp) {
        if (book.id.isEmpty) continue;
        cloudBooksMap[book.id] = book;
      }

      // Merge learner dashboard books as a fallback source so any extra books
      // still show up, but keep the PHP API covers and URLs when duplicates
      // exist for the same book ID.
      debugPrint('Merging learner dashboard fallback books...');
      final List<dynamic> allData = [];
      for (final data in results.sublist(1)) {
        allData.addAll(data);
      }

      debugPrint('Learner dashboard returned ${allData.length} items');

      for (final json in allData.whereType<Map<String, dynamic>>()) {
        final id = json['id']?.toString() ?? '';
        if (id.isEmpty || cloudBooksMap.containsKey(id)) continue;

        final rawCover =
            json['cover_url'] ??
            json['coverUrl'] ??
            ImageUrlResolver.fromMap(json, baseUrl: _booksImageBaseUrl);
        final coverUrl = ImageUrlResolver.normalize(
          rawCover,
          baseUrl: _booksImageBaseUrl,
        );

        String? rawPdf = json['pdf_url'] ?? json['file_url'] ?? json['url'];
        if (rawPdf != null && rawPdf.contains(' ') && !rawPdf.contains('%20')) {
          rawPdf = rawPdf.replaceAll(' ', '%20');
        }

        cloudBooksMap[id] = Ebook(
          id: id,
          title: json['title'] ?? json['book_title'] ?? '',
          author: json['author'] ?? json['publisher'] ?? 'Unknown Author',
          coverUrl: coverUrl,
          serverUrl: rawPdf ?? '',
          fileSize: json['file_size'] is int
              ? json['file_size']
              : int.tryParse(json['file_size']?.toString() ?? '0') ?? 0,
          downloadedDate: null,
          grade: json['grade']?.toString() ?? json['course']?.toString() ?? '',
          category: json['category'] ?? 'Textbooks',
          coverImagePath:
              coverUrl, // Use this for the URL as in reference project
          totalPages: json['pages'] ?? json['total_pages'] ?? 0,
          isDownloaded: false,
        );
      }

      List<Ebook> cloudBooks = cloudBooksMap.values.toList();
      debugPrint('Parsed ${cloudBooks.length} unique books from API');

      if (cloudBooks.isEmpty) {
        debugPrint('No books from API, falling back to Textbooks category...');
        cloudBooks = await _apiService.getBooksByCategory('Textbooks');
        debugPrint('Category fallback returned ${cloudBooks.length} books');
      }

      final localBooks = await _databaseService.getAllEbooks();
      final localBookIds = localBooks.map((b) => b.id).toSet();
      final filteredBooks = cloudBooks
          .where((book) => !localBookIds.contains(book.id))
          .toList();
      debugPrint('After filtering local books: ${filteredBooks.length} books');
      return filteredBooks;
    } catch (e) {
      debugPrint('Error fetching learner textbooks: $e');
      return _apiService.getBooksByCategory('Textbooks');
    }
  }

  Future<void> _loadStudentCourses() async {
    try {
      final data = await LearnerDashboardApiService.instance.fetchCourses();
      final courseNames = data
          .whereType<Map<String, dynamic>>()
          .map(
            (c) =>
                c['name']?.toString() ??
                c['title']?.toString() ??
                c['course_name']?.toString() ??
                'Unknown',
          )
          .where((c) => c != 'Unknown')
          .toList();

      if (courseNames.isNotEmpty) {
        if (mounted) {
          setState(() {
            _studentCourses = courseNames;

            if (_learnerGrade != null &&
                _learnerGrade!.isNotEmpty &&
                !_studentCourses.contains(_learnerGrade)) {
              _studentCourses.insert(0, _learnerGrade!);
            }

            if (_selectedCourse == null) {
              if (_learnerGrade != null && _learnerGrade!.isNotEmpty) {
                _selectedCourse = _learnerGrade;
              } else if (_studentCourses.isNotEmpty) {
                _selectedCourse = _studentCourses.first;
              }
            }

            final targetGrade = _learnerGrade ?? _selectedCourse;
            if (targetGrade != null && targetGrade.isNotEmpty) {
              _storageService
                  .copyBundledEbooksToStorage(
                    _databaseService,
                    targetGrade: targetGrade,
                  )
                  .then((_) {
                    if (mounted) {
                      _loadEbooks();
                    }
                  });
            }
          });
        }
        return;
      }
      _setFallbackCourses();
    } catch (e) {
      debugPrint('Error fetching courses dynamically: $e');
      _setFallbackCourses();
    }
  }

  void _setFallbackCourses() {
    // Keeps the fallback grades if API fails so the UI doesn't break
    // Handled inherently by the initial values, but we can call it to refresh
    // if loading states are added later.
  }

  Future<void> _loadLearnerGrade() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('grade');
    if (cached != null &&
        cached.isNotEmpty &&
        cached.toLowerCase() != 'grade ...') {
      if (mounted) {
        setState(() {
          _learnerGrade = cached;
          _selectedCourse = cached;
        });
      } else {
        _learnerGrade = cached;
        _selectedCourse = cached;
      }
    }

    try {
      final apiData = await UserDataService.instance.fetchUserProfile();
      if (apiData == null) return;
      final userData = apiData['data'] ?? apiData['user'] ?? apiData;
      if (userData is! Map<String, dynamic>) return;

      final fetched = _extractGradeFromProfile(userData);
      if (fetched == null || fetched.isEmpty) return;

      if (mounted) {
        setState(() {
          _learnerGrade = fetched;
          _selectedCourse = fetched;
        });
      } else {
        _learnerGrade = fetched;
        _selectedCourse = fetched;
      }
      await prefs.setString('grade', fetched);
    } catch (e) {
      debugPrint('Error loading learner grade from profile: $e');
    }
  }

  String? _extractGradeFromProfile(Map<String, dynamic> userData) {
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

  String _normalizeGrade(String grade) {
    final trimmed = grade.trim();
    if (trimmed.toUpperCase().startsWith('PP')) {
      return trimmed.toUpperCase();
    }
    if (trimmed.toLowerCase().startsWith('grade ')) {
      return trimmed.substring(6).trim();
    }
    return trimmed;
  }

  Future<void> _downloadBook(Ebook cloudBook) async {
    // Create a ValueNotifier for this book's progress
    final progressNotifier = ValueNotifier<double>(0.0);

    // Log download start
    AnalyticsService.instance.logEvent(
      'book_download_start',
      parameters: {'book_id': cloudBook.id},
    );

    if (mounted) {
      setState(() {
        _downloadProgress[cloudBook.id] = progressNotifier;
      });
    } else {
      _downloadProgress[cloudBook.id] = progressNotifier;
    }

    try {
      final success = await _cloudSyncService.downloadBook(
        cloudBook,
        onProgress: (progress) {
          // Only update the ValueNotifier, not the entire widget
          progressNotifier.value = progress;
        },
      );

      if (mounted) {
        setState(() {
          _downloadProgress.remove(cloudBook.id);
        });

        if (success) {
          // Log successful download with metadata
          AnalyticsService.instance.logEvent(
            'book_download_success',
            parameters: {
              'book_id': cloudBook.id,
              'book_category': cloudBook.category,
            },
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Downloaded: ${cloudBook.title}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          // Refresh books list after download
          _loadEbooks();
          _loadCloudBooks();
        } else {
          AnalyticsService.instance.logEvent(
            'book_download_failed',
            parameters: {'book_id': cloudBook.id},
          );
          await _showActionError(
            'Please check your network connection and try again.',
            title: 'Download failed',
            fallback: 'Please check your network connection and try again.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AnalyticsService.instance.logEvent(
          'book_download_error',
          parameters: {
            'book_id': cloudBook.id,
            'error_type': e.runtimeType.toString(),
          },
        );
        setState(() {
          _downloadProgress.remove(cloudBook.id);
        });
        await _showActionError(
          e,
          title: 'Download error',
          fallback: 'Please check your network connection and try again.',
        );
      }
    }
  }

  Future<void> _confirmDeleteDownloadedBook(Ebook book) async {
    if (!book.isDownloaded) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete downloaded book?'),
          content: Text(
            'This will remove "${book.title}" from your device and downloaded library.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await _deleteDownloadedBook(book);
    }
  }

  Future<void> _deleteDownloadedBook(Ebook book) async {
    try {
      final success = await _cloudSyncService.deleteDownloadedBook(book.id);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted: ${book.title}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        await _loadEbooks();
        await _loadCloudBooks();
      } else {
        await _showActionError(
          'The book could not be deleted. Please try again.',
          title: 'Delete failed',
          fallback: 'The book could not be deleted. Please try again.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      await _showActionError(
        e,
        title: 'Delete failed',
        fallback: 'The book could not be deleted. Please try again.',
      );
    }
  }

  Future<void> _handleCategoryTap(MenuItem item) async {
    if (item.isComingSoon) return;

    // Close the drawer before navigating to prevent routing/rendering issues
    // that can cause a black screen when pressing the back arrow.
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
    }

    final intendedPath = MenuItem.directIntendedPathFor(item.id);
    if (intendedPath != null) {
      await _openProtectedIntegration(
        title: item.title,
        intendedPath: intendedPath,
      );
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

  Future<void> _openProtectedIntegration({
    required String title,
    required String intendedPath,
  }) async {
    final targetUrl = '${AppEndpoints.webBaseUrl}$intendedPath';
    final webviewLoginUrl = await LearnerDashboardApiService.instance
        .fetchWebviewLoginUrl(targetUrl: targetUrl);

    if (!mounted) {
      return;
    }

    if (webviewLoginUrl == null) {
      await ErrorFeedback.showErrorDialog(
        context,
        title: 'Secure access unavailable',
        error: 'Please check your network connection and try again.',
        fallback: 'Could not open this area securely. Please try again.',
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            WebViewContentScreen(title: title, url: webviewLoginUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.surfaceGray,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Background Hidden Drawer Menu
          Container(
            width: double.infinity,
            height: double.infinity,
            color: AppColors.surfaceGray,
            child: SafeArea(
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(canvasColor: Colors.transparent),
                child: CategoryNavBar(
                  isDrawer: false,
                  onItemTap: (item) {
                    _toggleDrawer();
                    _handleCategoryTap(item);
                  },
                ),
              ),
            ),
          ),

          // Foreground Main Content
          AnimatedBuilder(
            animation: _drawerController,
            builder: (context, child) {
              final double slide = 260.0 * _drawerController.value;
              final double scale = 1.0 - (_drawerController.value * 0.12);
              final double radius = _drawerController.value * 32.0;

              return Transform(
                transform: Matrix4.identity()
                  ..translateByDouble(slide, 0.0, 0.0, 1)
                  ..scaleByDouble(scale, scale, 1.0, 1),
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    boxShadow: [
                      if (_drawerController.value > 0)
                        BoxShadow(
                          color: Colors.blueGrey.withValues(alpha: 0.2),
                          blurRadius: 24,
                          spreadRadius: 8,
                          offset: const Offset(-5, 0),
                        ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: Stack(
                      children: [
                        child ?? const SizedBox.shrink(),

                        // Edge swipe detector to open the drawer
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: 24,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onHorizontalDragUpdate: (details) {
                              if (_searchFocusNode.hasFocus) return;
                              _drawerController.value +=
                                  details.primaryDelta! / 260.0;
                            },
                            onHorizontalDragEnd: (details) {
                              if (_searchFocusNode.hasFocus) return;
                              if (details.primaryVelocity! > 300) {
                                _drawerController.forward();
                              } else if (details.primaryVelocity! < -300) {
                                _drawerController.reverse();
                              } else if (_drawerController.value > 0.5) {
                                _drawerController.forward();
                              } else {
                                _drawerController.reverse();
                              }
                            },
                          ),
                        ),

                        // Full overlay to capture gestures when drawer is partially/fully open
                        if (_drawerController.value > 0)
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: _toggleDrawer,
                              onHorizontalDragUpdate: (details) {
                                if (_searchFocusNode.hasFocus) return;
                                _drawerController.value +=
                                    details.primaryDelta! / 260.0;
                              },
                              onHorizontalDragEnd: (details) {
                                if (_searchFocusNode.hasFocus) return;
                                if (details.primaryVelocity! > 300) {
                                  _drawerController.forward();
                                } else if (details.primaryVelocity! < -300) {
                                  _drawerController.reverse();
                                } else if (_drawerController.value > 0.5) {
                                  _drawerController.forward();
                                } else {
                                  _drawerController.reverse();
                                }
                              },
                              child: Container(color: Colors.transparent),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
            child: _buildMainScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildMainScreen() {
    return Scaffold(
      backgroundColor: AppColors.surfaceGray,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surfaceGray,
        leading: IconButton(
          icon: const Icon(
            Icons.menu_rounded,
            color: AppColors.brandGreen,
            size: 28,
          ),
          onPressed: _toggleDrawer,
        ),
        title: const Text(
          'Elimu Library',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.brandGreen, // Gamified header color
          ),
        ),
        actions: [
          // Library filter icon with circular background

          // Settings with circular background
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.lightGreen,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.settings_rounded,
                  size: 24,
                  color: Colors.white,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: null,
      // SUGGESTION: To add a mascot, you could wrap the body in a Stack
      // and place the Rive animation in a corner.
      // body: Stack(
      //   children: [
      //     _buildBody(), // The main content, wrapped in a function
      //     Positioned(
      //       bottom: 16,
      //       right: 16,
      //       child: SizedBox(
      //         width: 120,
      //         height: 120,
      //         child: RiveAnimation.asset('assets/animations/mascot.riv'),
      //       ),
      //     ),
      //   ],
      // ),
      body: DefaultTabController(
        length: 2,
        child: Builder(
          builder: (context) {
            final learnerCourse =
                _learnerGrade ??
                _selectedCourse ??
                (_studentCourses.isNotEmpty ? _studentCourses.first : null);

            var myBooks = _ebooks.toList();
            var discoverBooks = _cloudBooks.toList();

            final learnerCloudBooks = _booksForLearnerCourse(
              discoverBooks,
              learnerCourse,
            );
            for (final book in learnerCloudBooks) {
              if (!myBooks.any((b) => b.id == book.id)) {
                myBooks.add(book);
              }
            }

            if (_searchQuery.isNotEmpty) {
              myBooks = _searchBooks(myBooks, _searchQuery);
              discoverBooks = _searchBooks(discoverBooks, _searchQuery);
            }

            final catalogBooks = _dedupeBooks([...myBooks, ...discoverBooks]);
            final searchSuggestions =
                _searchQuery.trim().isNotEmpty && _isSearchActive
                ? _buildSearchSuggestions(catalogBooks, _searchQuery)
                : <Ebook>[];
            final mediaQuery = MediaQuery.of(context);
            final isLandscape = mediaQuery.orientation == Orientation.landscape;
            final keyboardInset = mediaQuery.viewInsets.bottom;
            final isCompactSearchMode = isLandscape && keyboardInset > 0;
            final availableSuggestionHeight =
                mediaQuery.size.height -
                mediaQuery.padding.top -
                mediaQuery.padding.bottom -
                keyboardInset -
                (isCompactSearchMode ? 180 : 260);
            final suggestionMaxHeight = availableSuggestionHeight
                .clamp(
                  80.0,
                  isCompactSearchMode
                      ? 120.0
                      : isLandscape
                      ? 150.0
                      : 220.0,
                )
                .toDouble();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: isCompactSearchMode
                        ? 4
                        : isLandscape
                        ? 8
                        : 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          autofocus: false,
                          textInputAction: TextInputAction.search,
                          autocorrect: false,
                          enableSuggestions: false,
                          textAlignVertical: TextAlignVertical.center,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                              _isSearchActive = _searchFocusNode.hasFocus;
                            });
                          },
                          onSubmitted: (_) {
                            if (_searchQuery.trim().isEmpty) {
                              _resetSearch(refreshBooks: true);
                            } else {
                              setState(() {
                                _isSearchActive = false;
                              });
                              _searchFocusNode.unfocus();
                            }
                          },
                          onTapOutside: (_) {
                            _searchFocusNode.unfocus();
                            setState(() {
                              _isSearchActive = false;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search books...',
                            prefixIcon: const Icon(
                              Icons.search,
                              color: AppColors.lightGreen,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    tooltip: 'Clear search',
                                    icon: const Icon(
                                      Icons.close,
                                      color: AppColors.lightGreen,
                                    ),
                                    onPressed: () {
                                      _resetSearch(refreshBooks: true);
                                      _searchFocusNode.unfocus();
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                              horizontal: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(
                                color: AppColors.darkGray.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(
                                color: AppColors.darkGray.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: const BorderSide(
                                color: AppColors.lightGreen,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      if (isCompactSearchMode) const SizedBox(width: 8),
                      if (isCompactSearchMode)
                        IconButton(
                          tooltip: 'Done searching',
                          onPressed: () {
                            _searchFocusNode.unfocus();
                            setState(() {
                              _isSearchActive = false;
                            });
                          },
                          icon: const Icon(
                            Icons.keyboard_hide_rounded,
                            color: AppColors.brandGreen,
                          ),
                        ),
                    ],
                  ),
                ),
                if (searchSuggestions.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      isCompactSearchMode ? 4 : 8,
                    ),
                    child: Material(
                      color: Colors.white,
                      elevation: 4,
                      shadowColor: Colors.black12,
                      borderRadius: BorderRadius.circular(20),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: suggestionMaxHeight,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: searchSuggestions.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, thickness: 1),
                          itemBuilder: (context, index) {
                            final book = searchSuggestions[index];
                            return _buildSearchSuggestionTile(book);
                          },
                        ),
                      ),
                    ),
                  ),
                // Tabs
                if (!isCompactSearchMode)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TabBar(
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        color: AppColors.lightGreen,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.lightGreen.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.black54,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      tabs: const [
                        Tab(text: 'Downloaded Books'),
                        Tab(text: 'Get Books'),
                      ],
                    ),
                  ),
                SizedBox(
                  height: isCompactSearchMode
                      ? 4
                      : isLandscape
                      ? 8
                      : 16,
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.lightGreen,
                    onRefresh: _refreshLibrary,
                    child: TabBarView(
                      children: [
                        _buildBooksTab(
                          sectionLabel: 'Downloaded books',
                          books: myBooks,
                          isLoading: _isLoadingEbooks,
                          error: _ebooksError,
                          emptyMessage: _searchQuery.isNotEmpty
                              ? 'No downloaded books match your search'
                              : 'No downloaded books available',
                        ),
                        _buildBooksTab(
                          sectionLabel: 'Available books',
                          books: discoverBooks,
                          isLoading: _isLoadingCloudBooks,
                          error: _cloudBooksError,
                          emptyMessage: _searchQuery.isNotEmpty
                              ? 'No books match your search'
                              : 'No books available',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Ebook> _booksForLearnerCourse(List<Ebook> books, String? learnerCourse) {
    if (learnerCourse == null || learnerCourse.isEmpty) {
      return books.toList();
    }

    final normalizedLearnerCourse = _normalizeGrade(learnerCourse);
    return books
        .where(
          (e) =>
              e.category == learnerCourse ||
              e.grade == learnerCourse ||
              _normalizeGrade(e.grade) == normalizedLearnerCourse,
        )
        .toList();
  }

  bool _isRecommendedForLearner(Ebook book, String? learnerCourse) {
    if (learnerCourse == null || learnerCourse.isEmpty) {
      return false;
    }

    final normalizedLearnerCourse = _normalizeGrade(learnerCourse);
    return book.category == learnerCourse ||
        book.grade == learnerCourse ||
        _normalizeGrade(book.grade) == normalizedLearnerCourse;
  }

  List<Ebook> _dedupeBooks(List<Ebook> books) {
    final seen = <String>{};
    final deduped = <Ebook>[];

    for (final book in books) {
      final key = book.id.trim();
      if (key.isEmpty) continue;
      if (seen.add(key)) {
        deduped.add(book);
      }
    }

    return deduped;
  }

  List<Ebook> _buildSearchSuggestions(List<Ebook> books, String query) {
    final normalizedQuery = _normalizeSearchText(query);
    if (normalizedQuery.isEmpty) {
      return [];
    }

    final scored =
        books
            .map(
              (book) =>
                  MapEntry(book, _scoreBookForQuery(book, normalizedQuery)),
            )
            .where((entry) => entry.value > 0)
            .toList()
          ..sort((a, b) {
            final scoreCompare = b.value.compareTo(a.value);
            if (scoreCompare != 0) return scoreCompare;
            return a.key.title.compareTo(b.key.title);
          });

    return scored.take(6).map((entry) => entry.key).toList();
  }

  Widget _buildBooksTab({
    required String sectionLabel,
    required List<Ebook> books,
    required bool isLoading,
    required String? error,
    required String emptyMessage,
  }) {
    if (error != null && books.isEmpty) {
      final isNetworkError = ErrorFeedback.isNetworkError(error);
      final message = isNetworkError
          ? 'The app cannot reach the library server right now.\nPlease check your network connection and try again.'
          : error;

      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 64,
                    color: Colors.black45,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isNetworkError
                        ? '$sectionLabel unavailable'
                        : 'Library unavailable',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  ElimuButton(
                    text: 'Try Again',
                    icon: Icons.refresh,
                    width: 150,
                    onPressed: _refreshLibrary,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (isLoading && books.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 140),
          Center(child: CircularProgressIndicator(color: AppColors.lightGreen)),
        ],
      );
    }

    return _buildBookGrid(books, emptyMessage: emptyMessage);
  }

  List<Ebook> _searchBooks(List<Ebook> books, String query) {
    final normalizedQuery = _normalizeSearchText(query);
    if (normalizedQuery.isEmpty) {
      return books;
    }

    final scored =
        books
            .map(
              (book) =>
                  MapEntry(book, _scoreBookForQuery(book, normalizedQuery)),
            )
            .where((entry) => entry.value > 0)
            .toList()
          ..sort((a, b) {
            final scoreCompare = b.value.compareTo(a.value);
            if (scoreCompare != 0) return scoreCompare;
            return a.key.title.compareTo(b.key.title);
          });

    return scored.map((entry) => entry.key).toList();
  }

  int _scoreBookForQuery(Ebook book, String normalizedQuery) {
    final normalizedTitle = _normalizeSearchText(book.title);
    final normalizedAuthor = _normalizeSearchText(book.author);
    final normalizedGrade = _normalizeSearchText(book.grade);
    final normalizedCategory = _normalizeSearchText(book.category);
    final normalizedDescription = _normalizeSearchText(book.description ?? '');
    final tokens = normalizedQuery
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toList();

    var score = 0;

    if (normalizedTitle == normalizedQuery) score += 200;
    if (normalizedAuthor == normalizedQuery) score += 160;

    if (normalizedTitle.startsWith(normalizedQuery)) score += 120;
    if (normalizedAuthor.startsWith(normalizedQuery)) score += 90;

    if (normalizedTitle.contains(normalizedQuery)) score += 80;
    if (normalizedAuthor.contains(normalizedQuery)) score += 60;
    if (normalizedGrade.contains(normalizedQuery)) score += 50;
    if (normalizedCategory.contains(normalizedQuery)) score += 40;
    if (normalizedDescription.contains(normalizedQuery)) score += 20;

    for (final token in tokens) {
      if (normalizedTitle.contains(token)) score += 25;
      if (normalizedAuthor.contains(token)) score += 18;
      if (normalizedGrade.contains(token)) score += 14;
      if (normalizedCategory.contains(token)) score += 10;
      if (normalizedDescription.contains(token)) score += 6;
    }

    return score;
  }

  String _normalizeSearchText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Widget _buildSearchSuggestionTile(Ebook book) {
    final coverUrl = book.coverUrl ?? _remoteCoverFromPath(book.coverImagePath);

    return ListTile(
      onTap: () {
        setState(() {
          _searchController.text = book.title;
          _searchController.selection = TextSelection.fromPosition(
            TextPosition(offset: _searchController.text.length),
          );
          _searchQuery = book.title;
          _isSearchActive = false;
        });
      },
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 44,
          height: 56,
          color: Colors.grey.shade200,
          child: coverUrl != null && coverUrl.isNotEmpty
              ? Image.network(
                  coverUrl,
                  width: 44,
                  height: 56,
                  fit: BoxFit.cover,
                  webHtmlElementStrategy: kIsWeb
                      ? WebHtmlElementStrategy.prefer
                      : WebHtmlElementStrategy.never,
                  errorBuilder: (_, _, _) => _buildPlaceholderCover(),
                )
              : _buildPlaceholderCover(),
        ),
      ),
      title: Text(
        book.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.brandGreen,
        ),
      ),
      subtitle: Text(
        [
          if (book.author.isNotEmpty) book.author,
          if (book.grade.isNotEmpty) book.grade,
          if (book.category.isNotEmpty) book.category,
        ].join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      ),
      trailing: const Icon(
        Icons.north_west_rounded,
        color: AppColors.lightGreen,
      ),
    );
  }

  String? _remoteCoverFromPath(String? coverImagePath) {
    if (coverImagePath == null || coverImagePath.isEmpty) {
      return null;
    }

    final trimmed = coverImagePath.trim();
    final looksRemote =
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('//') ||
        trimmed.startsWith('www.');
    if (!looksRemote) {
      return null;
    }

    final normalized = ImageUrlResolver.normalize(
      trimmed,
      baseUrl: _booksImageBaseUrl,
    );
    if (normalized == null) {
      return null;
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme) {
      return null;
    }

    return normalized;
  }

  Widget _buildBookGrid(List<Ebook> books, {required String emptyMessage}) {
    if (books.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/app_icon.png',
                  width: 64,
                  height: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  emptyMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black45),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        16,
        0,
        16,
        100,
      ), // Padding at bottom for BottomNavigationBar and potential FAB
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.52,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return _buildBookCard(book)
            .animate()
            .fadeIn(duration: 400.ms, delay: (50 * index).ms)
            .slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOut);
      },
    );
  }

  Widget _buildBookCard(Ebook book) {
    final isDownloading = _downloadProgress.containsKey(book.id);
    final progressNotifier = _downloadProgress[book.id];
    final isDownloaded = book.isDownloaded;
    final learnerCourse =
        _learnerGrade ??
        _selectedCourse ??
        (_studentCourses.isNotEmpty ? _studentCourses.first : null);
    final isRecommended = _isRecommendedForLearner(book, learnerCourse);

    // In this project, we align with the reference project where
    // cloud cover URLs are stored in coverImagePath for cloud books.
    final remoteCoverUrl = ImageUrlResolver.normalize(
      book.coverImagePath,
      baseUrl: _booksImageBaseUrl,
    );

    return GestureDetector(
      onTap: isDownloaded
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReaderScreen(ebook: book),
                ),
              );
            }
          : null,
      child: ElimuCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book cover/thumbnail
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  color: Colors.grey[200],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: FutureBuilder<Uint8List?>(
                          future: isDownloaded && book.localPath != null
                              ? _getThumbnail(
                                  book.localPath!,
                                  coverImagePath: book.coverImagePath,
                                )
                              : Future.value(null),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              return Image.memory(
                                snapshot.data!,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              );
                            } else if (remoteCoverUrl != null &&
                                remoteCoverUrl.isNotEmpty) {
                              return Image.network(
                                remoteCoverUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _buildPlaceholderCover(),
                              );
                            }
                            return _buildPlaceholderCover();
                          },
                        ),
                      ),
                      if (isRecommended)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.28),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Recommended',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (isDownloaded)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Semantics(
                            label: 'Delete downloaded book',
                            button: true,
                            child: Material(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: const CircleBorder(),
                              child: IconButton(
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Delete downloaded book',
                                onPressed: () =>
                                    _confirmDeleteDownloadedBook(book),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Book info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),

                  const SizedBox(height: 8),
                  if (!isDownloaded)
                    SizedBox(
                      width: double.infinity,
                      child: isDownloading && progressNotifier != null
                          ? ListenableBuilder(
                              listenable: progressNotifier,
                              builder: (context, child) {
                                final progress = progressNotifier.value;
                                return Column(
                                  children: [
                                    LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: Colors.grey[300],
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            AppColors.lightGreen,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(progress * 100).toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            )
                          : ElimuButton(
                              text: 'Download',
                              icon: Icons.download,
                              onPressed: () => _downloadBook(book),
                            ),
                    )
                  else
                    ElimuButton(
                      text: 'Read',
                      icon: Icons.menu_book,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReaderScreen(ebook: book),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.lightGreen.withValues(alpha: 0.3),
            AppColors.lightGreen.withValues(alpha: 0.3),
          ],
        ),
      ),
      child: Center(
        child: Image.asset('assets/images/app_icon.png', width: 60, height: 60),
      ),
    );
  }

  Future<Uint8List?> _getThumbnail(
    String localPath, {
    String? coverImagePath,
  }) async {
    try {
      // If coverImagePath is absolute, use it directly
      if (coverImagePath != null &&
          (coverImagePath.startsWith('/') ||
              coverImagePath.contains(':/') ||
              coverImagePath.contains(':\\'))) {
        final file = File(coverImagePath);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      }

      // If localPath is absolute, use it directly
      String fullPath = localPath;
      if (!localPath.startsWith('/') &&
          !localPath.contains(':/') &&
          !localPath.contains(':\\')) {
        final storageDir = await _storageService.getEbooksDirectory();
        fullPath = '${storageDir.path}/$localPath';
      }

      final thumbnailService = ThumbnailService();
      return await thumbnailService.getThumbnail(
        fullPath,
        coverImagePath: coverImagePath,
      );
    } catch (e) {
      return null;
    }
  }
}
