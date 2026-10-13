import 'package:flutter/material.dart';
import 'package:elimupepe/core/theme/app_theme.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:elimupepe/features/auth/privacy_policy_screen.dart';
import 'package:elimupepe/core/webview/sso_webview.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _appName = 'Elimu Pepe';
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appName = info.appName.isNotEmpty ? info.appName : _appName;
        _version = 'Version ${info.version} (${info.buildNumber})';
      });
    }
  }

  void _showPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
    );
  }

  void _showTermsOfService() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SsoWebViewScreen(
          title: 'Terms & Conditions',
          publicUrl: 'https://loho-stack.github.io/app-policies/',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF0F8FF),
        foregroundColor: AppColors.brandGreen,
        title: const Text(
          'About',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            // App Icon / Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandGreen.withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/elimu.png', // Uses the icon from pubspec.yaml
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.menu_book_rounded,
                    size: 64,
                    color: AppColors.lightGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _appName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.brandGreen,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _version,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.blueGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),
            // Action Links
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.privacy_tip_rounded,
                      color: AppColors.lightGreen,
                    ),
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                    ),
                    onTap: _showPrivacyPolicy,
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                  ListTile(
                    leading: const Icon(
                      Icons.description_rounded,
                      color: AppColors.lightGreen,
                    ),
                    title: const Text('Terms of Service'),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                    ),
                    onTap: _showTermsOfService,
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                  ListTile(
                    leading: const Icon(
                      Icons.code_rounded,
                      color: AppColors.lightGreen,
                    ),
                    title: const Text('Open Source Licenses'),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                    ),
                    onTap: () {
                      showLicensePage(
                        context: context,
                        applicationName: _appName,
                        applicationVersion: _version,
                        applicationIcon: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Image.asset(
                            'assets/images/elimu.png',
                            width: 48,
                            height: 48,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            const Text(
              '© 2026 LoHo Learning',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
