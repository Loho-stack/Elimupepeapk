import 'package:elimupepe/app/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dio/dio.dart';
import 'package:elimupepe/app/app_services.dart';
import 'package:elimupepe/core/config/app_endpoints.dart';
import 'package:elimupepe/core/services/analytics_service.dart';
import 'package:elimupepe/core/services/auth_service.dart';
import 'package:elimupepe/core/theme/app_theme.dart';
import 'package:elimupepe/core/utils/error_feedback.dart';
import 'package:elimupepe/core/widgets/elimu_button.dart';
import 'package:elimupepe/core/widgets/elimu_text_field.dart';
import 'package:firebase_performance/firebase_performance.dart';

class ParentLoginScreen extends StatefulWidget {
  const ParentLoginScreen({super.key});

  @override
  State<ParentLoginScreen> createState() => _ParentLoginScreenState();
}

class _ParentLoginScreenState extends State<ParentLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _hasAgreed = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_hasAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms & Conditions to continue.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    AnalyticsService.instance.logEvent('parent_login_attempt');

    final trace = FirebasePerformance.instance.newTrace('parent_login');
    await trace.start();
    bool success = false;
    String? message;
    try {
      if (AppServices.instance.config.appApiV1Login) {
        final result = await AuthService.instance.loginWithAppApi(
          role: 'parent',
          identifier: _emailController.text,
          password: _passwordController.text,
        );
        success = result.success;
        message = result.message;
      } else {
        final response = await AppServices.instance.apiClient.api.post(
          '/v1/auth/login',
          data: {
            'email': _emailController.text.trim(),
            'password': _passwordController.text,
            'role': 'parent',
          },
          options: Options(
            validateStatus: (_) => true,
            extra: const {'noAuth': true},
          ),
        );

        if (response.statusCode != 200) {
          message =
              _extractMessage(response.data) ??
              'Login failed. Please check your credentials.';
        } else {
          final data = response.data;
          final token = _extractToken(data);
          if (token == null || token.isEmpty) {
            message = 'Login response missing token.';
          } else {
            final user = _extractUser(data);
            await AuthService.instance.persistParentSession(
              token: token,
              user: user,
            );
            success = true;
          }
        }
      }
    } catch (e) {
      message = ErrorFeedback.userMessage(
        e,
        fallback: 'Could not connect to the login server.',
      );
    } finally {
      await trace.stop();
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      AnalyticsService.instance.logLogin(method: 'parent_email');
      if (!mounted) return;
      await context.enterSession();
    } else {
      AnalyticsService.instance.logEvent(
        'parent_login_failed',
        parameters: {'reason': 'rejected'},
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message ?? 'Login failed.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  String? _extractToken(dynamic payload) {
    if (payload is! Map) return null;
    final direct = payload['token'] ?? payload['access_token'];
    if (direct is String && direct.isNotEmpty) return direct;
    final data = payload['data'];
    if (data is Map) {
      final nested = data['token'] ?? data['access_token'];
      if (nested is String && nested.isNotEmpty) return nested;
    }
    return null;
  }

  Map<String, dynamic> _extractUser(dynamic payload) {
    if (payload is! Map) return {};
    final user = payload['user'];
    if (user is Map<String, dynamic>) return user;
    final data = payload['data'];
    if (data is Map && data['user'] is Map) {
      return Map<String, dynamic>.from(data['user'] as Map);
    }
    return {};
  }

  String? _extractMessage(dynamic payload) {
    if (payload is Map) {
      final message = payload['message'] ?? payload['error'];
      if (message is String && message.isNotEmpty) return message;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isWide = screenSize.width >= 900;

    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primaryBlue, AppColors.accentPurple],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Center(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: isWide ? 480 : double.infinity,
                        minHeight: constraints.maxHeight,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 32),
                          Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shield_outlined,
                              color: Colors.white,
                              size: 56,
                            ),
                          ).animate().fadeIn(duration: 600.ms).scale(),
                          const SizedBox(height: 16),
                          const Text(
                            'Parent / Guardian Sign-In',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                          const SizedBox(height: 8),
                          Text(
                            'Oversee your child\'s learning journey and parental controls.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ).animate().fadeIn(delay: 300.ms),
                          const SizedBox(height: 28),
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                ElimuTextField(
                                  icon: Icons.email_outlined,
                                  label: 'Email or Phone',
                                  hint: 'parent@example.com',
                                  controller: _emailController,
                                  focusNode: _emailFocus,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) =>
                                      _emailFocus.unfocus(),
                                  validator: (value) {
                                    final text = (value ?? '').trim();
                                    if (text.isEmpty) {
                                      return 'Please enter your email or phone';
                                    }
                                    final isEmail = RegExp(
                                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                    ).hasMatch(text);
                                    final isPhone = RegExp(
                                      r'^\+?[0-9]{7,15}$',
                                    ).hasMatch(text);
                                    if (!isEmail && !isPhone) {
                                      return 'Enter a valid email or phone number';
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
                                  focusNode: _passwordFocus,
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
                          ),
                          const SizedBox(height: 14),
                          _agreementRow(),
                          const SizedBox(height: 24),
                          ElimuButton(
                            text: 'Login as Parent',
                            isLoading: _isLoading,
                            onPressed: _handleLogin,
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              'No parent account yet? Create one at ${AppEndpoints.webBaseUrl}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
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

  Widget _agreementRow() {
    return Row(
      children: [
        Theme(
          data: Theme.of(
            context,
          ).copyWith(unselectedWidgetColor: Colors.white70),
          child: Checkbox(
            value: _hasAgreed,
            onChanged: (v) => setState(() => _hasAgreed = v ?? false),
            activeColor: Colors.white,
            checkColor: AppColors.primaryBlue,
            side: const BorderSide(color: Colors.white, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const Expanded(
          child: Text(
            'I agree to the platform Terms & Privacy Policy.',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
