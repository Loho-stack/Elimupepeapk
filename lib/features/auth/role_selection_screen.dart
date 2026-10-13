import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:elimupepe/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:elimupepe/core/config/app_endpoints.dart';
import 'package:elimupepe/features/auth/learner_flow.dart';
import 'package:elimupepe/core/theme/app_page_transitions.dart';
import 'package:elimupepe/features/parental_control/parent_login_screen.dart';

Future<void> _launchWhatsApp(BuildContext context) async {
  final Uri url = Uri.parse(
    'https://wa.me/254797349396?text=Hello%20Elimu%20Pepe%20Support',
  );
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch WhatsApp.')),
      );
    }
  }
}

Future<void> _launchWebsite(BuildContext context) async {
  final Uri url = Uri.parse(AppEndpoints.webBaseUrl);
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open website.')));
    }
  }
}

Future<void> _launchEmail(BuildContext context) async {
  final Uri url = Uri.parse('mailto:support@loholearning.co.ke');
  if (!await launchUrl(url)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch email app.')),
      );
    }
  }
}

Future<void> _launchPhone(BuildContext context) async {
  final Uri url = Uri.parse('tel:+254797349396');
  if (!await launchUrl(url)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone app.')),
      );
    }
  }
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    return Scaffold(
      backgroundColor: AppColors.brandGreen,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              contentPadding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              content: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Student Access Only\n\n'
                            '1️⃣ Register on the website.\n'
                            '2️⃣ Get your login details.\n'
                            '3️⃣ Sign in here 🎉\n\n'
                            '✅ Quick and easy!',

                            style: TextStyle(
                              color: Colors.white,
                              height: 1.6,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/images/xenye.png',
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'GOT IT',
                          style: TextStyle(
                            color: AppColors.accentYellow,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        backgroundColor: AppColors.accentOrange,
        child: const Icon(Icons.question_mark_rounded),
      ).animate().fadeIn(delay: 1200.ms).scale(),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/girl.png',
              fit: BoxFit.cover,
            ).animate().fadeIn(duration: 1200.ms, curve: Curves.easeIn),
          ),
          // Background decorations
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.brandGreen.withValues(alpha: 0.8),
                    AppColors.lightGreen.withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              height: 220,
              width: 220,
              decoration: BoxDecoration(
                color: AppColors.brandGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -60,
            child: Container(
              height: 260,
              width: 260,
              decoration: BoxDecoration(
                color: AppColors.brandGreen.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isTablet ? 500 : double.infinity,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/elimu.png',
                          height: 80,
                        ),
                      ).animate().fadeIn(duration: 500.ms).scale(delay: 100.ms),
                      const SizedBox(height: 24),
                      const Text(
                        'Welcome to Elimu Pepe',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),
                      const SizedBox(height: 12),
                      Text(
                        'Please select your role to get started.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
                      const SizedBox(height: 48),
                      _RoleCard(
                        icon: Icons.school_rounded,
                        title: 'I am a Student',
                        subtitle: 'Access your learning materials and quizzes.',
                        onTap: () {
                          Navigator.of(
                            context,
                          ).push(
                            AppPageTransitions.route(const LearnerFlowScreen()),
                          );
                        },
                        delay: 400.ms,
                      ),
                      const SizedBox(height: 20),
                      _RoleCard(
                        icon: Icons.family_restroom_rounded,
                        title: 'I am a Parent/Guardian',
                        subtitle: 'Monitor progress and manage accounts.',
                        webMessage:
                            'Tap "Open App Login" to sign in inside the app, or visit elimupepe.loholearning.co.ke to create your account and manage your child\'s learning journey.',
                        onTap: () => Navigator.of(context).push(
                          AppPageTransitions.route(
                            const ParentLoginScreen(),
                          ),
                        ),
                        delay: 500.ms,
                      ),
                      const SizedBox(height: 20),
                      _RoleCard(
                        icon: Icons.history_edu_rounded,
                        title: 'I am a Teacher/Educator',
                        subtitle: 'Manage classes and create assignments.',
                        webMessage:
                            'Your school admin will create your account. Please log in at elimupepe.loholearning.co.ke to manage your classes.',
                        delay: 600.ms,
                      ),
                      const SizedBox(height: 32),
                      Center(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: 0.25),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(99),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                          onPressed: () => _launchWhatsApp(context),
                          icon: const Icon(
                            Icons.support_agent_rounded,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Contact Admin',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ).animate().fadeIn(delay: 800.ms),
                      ),
                      const SizedBox(height: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => _launchWebsite(context),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.language,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'elimupepe.loholearning.co.ke',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => _launchEmail(context),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.email_outlined,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'support@loholearning.co.ke',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => _launchPhone(context),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.phone_outlined,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '+254 797 349 396',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Duration delay;
  final String? webMessage;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    required this.delay,
    this.webMessage,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _showMessage = false;

  @override
  Widget build(BuildContext context) {
    return Card(
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  if (widget.onTap != null) {
                    widget.onTap!();
                  } else if (widget.webMessage != null) {
                    setState(() {
                      _showMessage = !_showMessage;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(20),
                splashColor: AppColors.lightGreen.withValues(alpha: 0.2),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Row(
                    children: [
                      Icon(widget.icon, size: 30, color: AppColors.brandGreen),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMain,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blueGrey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        widget.webMessage != null
                            ? (_showMessage
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded)
                            : Icons.arrow_forward_ios_rounded,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showMessage && widget.webMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Text(
                    widget.webMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.brandGreen.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: widget.delay)
        .slideX(begin: 0.2, curve: Curves.easeOut);
  }
}
