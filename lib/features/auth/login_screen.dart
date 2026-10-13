import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:elimupepe/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:elimupepe/core/theme/wave_clipper.dart';
import 'package:elimupepe/core/widgets/elimu_button.dart';
import 'package:elimupepe/core/utils/error_feedback.dart';
import 'package:elimupepe/core/services/auth_service.dart';
import 'package:elimupepe/core/widgets/elimu_text_field.dart';
import 'package:elimupepe/features/home/dashboard_screen.dart';
import 'package:elimupepe/core/services/analytics_service.dart';
import 'package:elimupepe/core/theme/app_page_transitions.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:elimupepe/features/teacher/teacher_dashboard.dart';
import 'package:elimupepe/app/app_services.dart';
import 'package:elimupepe/core/webview/sso_webview.dart';
import 'package:elimupepe/features/parental_control/parent_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _studentIdFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _rememberMe = false;
  bool _isLoading = false;
  bool _hasAgreed = false;

  static const Color _primaryGreen = AppColors.brandGreen;
  static const Color _softBackground = AppColors.brandGreen;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  /// "Remember me" fills in the Student ID only. Passwords are never saved.
  Future<void> _loadSavedCredentials() async {
    final studentId = await AppServices.instance.remembered.studentId();
    if (studentId == null || !mounted) return;
    _studentIdController.text = studentId;
    setState(() => _rememberMe = true);
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _passwordController.dispose();
    _studentIdFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    if (!_hasAgreed) {
      AnalyticsService.instance.logEvent('login_terms_not_agreed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please agree to the Terms & Conditions and Privacy Policy to continue.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      AnalyticsService.instance.logEvent(
        'login_attempt',
        parameters: {'remember_me': _rememberMe ? 1 : 0},
      );

      final loginTrace = FirebasePerformance.instance.newTrace('student_login');
      await loginTrace.start();
      late final LoginResult loginResult;
      try {
        loginResult = await AuthService.instance.login(
          studentId: _studentIdController.text,
          password: _passwordController.text,
        );
      } finally {
        await loginTrace.stop();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      if (!loginResult.success) {
        final reason = loginResult.message.trim();
        // A fixed code, never the server message (it can echo user input).
        AnalyticsService.instance.logEvent(
          'login_failed',
          parameters: {'reason': _failureCode(reason)},
        );
        if (mounted) {
          if (ErrorFeedback.isNetworkError(reason) ||
              ErrorFeedback.isServerError(reason) ||
              ErrorFeedback.isSecureAccessError(reason)) {
            await ErrorFeedback.showErrorDialog(
              context,
              title: 'Login unavailable',
              error: reason,
              fallback: 'Could not complete login right now.',
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(loginResult.message),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
        }
        return;
      }

      // Remember me keeps the Student ID only, and only if opted in.
      if (_rememberMe) {
        await AppServices.instance.remembered
            .remember(_studentIdController.text);
      } else {
        await AppServices.instance.remembered.forget();
      }

      await AnalyticsService.instance.logLogin(method: 'student_id');

      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      // Display name and avatar live in secure storage (UserProfileStore);
      // the Student ID is already in secure storage from the login call.
      await AppServices.instance.profile.update(name: loginResult.name);

      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(AppPageTransitions.route(_routeForRole(loginResult)));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      await ErrorFeedback.showErrorDialog(
        context,
        title: 'Login error',
        error: e,
        fallback: 'Could not complete login right now.',
      );
      AnalyticsService.instance.logEvent('login_error');
    }
  }

  static String _failureCode(String message) {
    if (ErrorFeedback.isNetworkError(message)) return 'network';
    if (ErrorFeedback.isServerError(message)) return 'server';
    return 'rejected';
  }

  Widget _routeForRole(LoginResult loginResult) {
    final roleId = loginResult.roleId;
    final roleName = loginResult.roleName?.toLowerCase();

    if (roleId == 2 || roleName == 'teacher' || roleName == 'educator') {
      return const TeacherDashboard();
    }

    if (roleId == 7 || roleName == 'parent' || roleName == 'guardian') {
      return const ParentDashboard();
    }

    return const GamifiedDashboardScreen(
      initialIndex: 0,
      restoreLastTab: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final shortestSide = screenSize.shortestSide;
    final isTablet = shortestSide >= 600;
    final isWideLayout =
        screenSize.width >= 900 ||
        (screenSize.width / screenSize.height) > 1.15;
    final headerImageFit = BoxFit.cover;
    final imageAlignment = Alignment.topCenter;

    // ADJUSTABLE RATIOS:
    // Header takes a slightly larger portion on tablet/wide layouts so the image fits better.
    final headerHeight = screenSize.height * (isTablet ? 0.42 : 0.40);
    final contentTopPadding = headerHeight * 0.85;
    return Scaffold(
      backgroundColor: _softBackground,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.brandGreen, AppColors.lightGreen],
                ),
              ),
            ),
          ),

          // Wavy Header Image
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: WaveClipper(),
              child: Container(
                height: headerHeight,
                decoration: const BoxDecoration(color: Colors.white),
                child: SizedBox.expand(
                  child:
                      Image.asset(
                            'assets/images/fam.png',
                            fit: headerImageFit,
                            alignment: imageAlignment,
                            filterQuality: FilterQuality.high,
                          )
                          .animate()
                          .fadeIn(duration: 800.ms)
                          .scale(
                            begin: isWideLayout
                                ? const Offset(1.0, 1.0)
                                : const Offset(1.1, 1.1),
                            duration: 1000.ms,
                          ),
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double maxWidth = isTablet ? 450 : double.infinity;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Center(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: maxWidth,
                        minHeight: constraints.maxHeight,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Spacer for the header image
                          SizedBox(height: contentTopPadding),

                          const SizedBox(height: 12),
                          const Text(
                                'Welcome Back!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black26,
                                      offset: Offset(0, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              )
                              .animate()
                              .fadeIn(delay: 400.ms, duration: 600.ms)
                              .slideY(begin: 0.2),
                          const SizedBox(height: 8),
                          Text(
                                'Enter your details to continue.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              )
                              .animate()
                              .fadeIn(delay: 500.ms, duration: 600.ms)
                              .slideY(begin: 0.2),
                          const SizedBox(height: 24),

                          Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    ElimuTextField(
                                      icon: Icons.person_outline_rounded,
                                      label: 'Student ID',
                                      hint:
                                          'Enter your Student ID (LO-XXXXXXXX)',
                                      controller: _studentIdController,
                                      focusNode: _studentIdFocusNode,
                                      autofocus: true,
                                      keyboardType: TextInputType.text,
                                      textInputAction: TextInputAction.next,
                                      onFieldSubmitted: (_) {
                                        FocusScope.of(context).requestFocus(
                                          _passwordFocusNode,
                                        );
                                      },
                                      validator: (value) {
                                        final text = (value ?? '')
                                            .trim()
                                            .toUpperCase();
                                        if (text.isEmpty) {
                                          return 'Please enter your Student ID';
                                        }
                                        if (text.contains('@')) {
                                          return 'Email login is not supported. Use your Student ID.';
                                        }
                                        final isValid = RegExp(
                                          r'^LO-[A-Z0-9]{8}$',
                                          caseSensitive: false,
                                        ).hasMatch(text);
                                        if (!isValid) {
                                          return 'Invalid Student ID format. Expected: LO-XXXXXXXX';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    ElimuTextField(
                                      icon: Icons.lock_outline,
                                      label: 'Password',
                                      hint: 'Enter your password',
                                      controller: _passwordController,
                                      focusNode: _passwordFocusNode,
                                      isPassword: true,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _handleLogin(),
                                      validator: (value) {
                                        if ((value ?? '').isEmpty) {
                                          return 'Password is required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              )
                              .animate()
                              .fadeIn(delay: 600.ms, duration: 600.ms)
                              .slideY(begin: 0.2),
                          const SizedBox(height: 12),
                          _buildRememberMeRow(),
                          const SizedBox(height: 12),
                          _buildAgreementRow(),
                          const SizedBox(height: 24),
                          Text(
                            'No account yet? Ask your parent/teacher to create one for you .',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ).animate().fadeIn(delay: 900.ms, duration: 600.ms),
                          const SizedBox(height: 12),
                          ElimuButton(
                                text: 'Login',
                                isLoading: _isLoading,
                                onPressed: _handleLogin,
                              )
                              .animate()
                              .fadeIn(delay: 800.ms, duration: 600.ms)
                              .slideY(begin: 0.2),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 4,
            child: const BackButton(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildRememberMeRow() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => _rememberMe = !_rememberMe),
          child: Row(
            children: [
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(unselectedWidgetColor: Colors.white70),
                child: Checkbox(
                  value: _rememberMe,
                  onChanged: (value) {
                    setState(() {
                      _rememberMe = value ?? false;
                    });
                  },
                  activeColor: Colors.white,
                  checkColor: _primaryGreen,
                  side: const BorderSide(color: Colors.white, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Remember my Student ID',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 700.ms, duration: 600.ms);
  }

  Widget _buildAgreementRow() {
    return Row(
      children: [
        Theme(
          data: Theme.of(
            context,
          ).copyWith(unselectedWidgetColor: Colors.white70),
          child: Checkbox(
            value: _hasAgreed,
            onChanged: (value) {
              setState(() {
                _hasAgreed = value ?? false;
              });
            },
            activeColor: Colors.white,
            checkColor: _primaryGreen,
            side: const BorderSide(color: Colors.white, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            children: [
              const Text(
                'I agree to the ',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SsoWebViewScreen(
                      title: 'Terms & Conditions',
                      publicUrl: 'https://loho-stack.github.io/app-policies/',
                    ),
                  ),
                ),
                child: const Text(
                  'Terms & Conditions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const Text(
                ' and ',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SsoWebViewScreen(
                      title: 'Privacy Policy',
                      publicUrl:
                          'https://loho-stack.github.io/app-policies/index.html',
                    ),
                  ),
                ),
                child: const Text(
                  'Privacy Policy',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 750.ms, duration: 600.ms);
  }
}
