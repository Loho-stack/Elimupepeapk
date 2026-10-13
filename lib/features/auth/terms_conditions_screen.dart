import 'package:flutter/material.dart';
import 'package:elimupepe/core/webview/sso_webview.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  static const String _termsUrl =
      'https://loho-stack.github.io/app-policies/';

  @override
  Widget build(BuildContext context) {
    return const SsoWebViewScreen(
      title: 'Terms & Conditions',
      publicUrl: _termsUrl,
    );
  }
}
