import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_services.dart';
import '../../features/parental_control/parental_gate.dart';
import '../config/app_endpoints.dart';
import '../theme/app_theme.dart';
import 'remote_app_config.dart';

/// Start-up update check, moved out of the old dashboard so it runs from the
/// shell. Same behaviour as before:
///
/// 1. On Android, ask Google Play (in_app_update) and run an immediate update
///    if one is available.
/// 2. Otherwise, for sideloaded installs only, ask the server. Until the App
///    API v1 is live that is the legacy `GET /api/v1/app/version` (the route
///    does not exist on production yet, so it quietly does nothing); with
///    `AppConfig.appConfigEndpoint` on it is `GET /api/app/v1/app/config`.
class UpdateChecker {
  UpdateChecker._();

  static bool _ranThisSession = false;

  static Future<void> run(BuildContext context) async {
    if (_ranThisSession) return;
    _ranThisSession = true;

    var playTriggered = false;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final info = await InAppUpdate.checkForUpdate();
        if (info.updateAvailability == UpdateAvailability.updateAvailable) {
          await InAppUpdate.performImmediateUpdate();
          playTriggered = true;
        }
      } catch (_) {
        // Sideloaded APK or no Play services: fall through to the server.
      }
    }

    var checkServer = !playTriggered;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final installer = (await PackageInfo.fromPlatform()).installerStore;
        if (installer != null &&
            (installer.contains('vending') || installer.contains('google'))) {
          checkServer = false; // Play Store handles updates.
        }
      } catch (_) {}
    }
    if (!checkServer || !context.mounted) return;

    try {
      final build =
          int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;
      final services = AppServices.instance;
      final decision = services.config.appConfigEndpoint
          ? await _fromAppConfig(services.apiClient.appV1, build)
          : await _fromLegacy(services.apiClient.api, build);
      if (decision != null && context.mounted) {
        _showDialog(context, decision);
      }
    } catch (_) {
      // An update check must never disturb the app.
    }
  }

  static Future<_UpdateDecision?> _fromAppConfig(Dio appV1, int build) async {
    final cfg = await RemoteAppConfigService(appV1).fetch(build: build);
    if (cfg == null || !cfg.updateAvailable(build)) return null;
    if (!isTrustedStoreUrl(cfg.storeUrl)) return null;
    return _UpdateDecision(
      url: cfg.storeUrl,
      notes: cfg.latestVersion.isEmpty
          ? 'A new version is available with bug fixes and improvements.'
          : 'Version ${cfg.latestVersion} is available with bug fixes and improvements.',
      mandatory: cfg.mustUpdate(build),
    );
  }

  static Future<_UpdateDecision?> _fromLegacy(Dio api, int build) async {
    try {
      final r = await api.get<dynamic>(
        '/v1/app/version',
        options: Options(extra: const {'noAuth': true}),
      );
      final data = r.data;
      if (r.statusCode != 200 || data is! Map) return null;
      final latest = data['build_number'] as int? ?? 0;
      final url = data['download_url'] as String? ?? '';
      if (latest <= build || url.isEmpty || !isTrustedStoreUrl(url)) {
        return null;
      }
      return _UpdateDecision(
        url: url,
        notes: data['release_notes'] as String? ??
            'A new version is available with bug fixes and improvements.',
        mandatory: data['mandatory'] as bool? ?? false,
      );
    } on DioException {
      return null;
    }
  }

  /// Update links may only point at our own site or Google Play.
  @visibleForTesting
  static bool isTrustedStoreUrl(String url) {
    if (AppEndpoints.isTrustedUpdateUrl(url)) return true;
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        (uri.host == 'play.google.com');
  }

  @visibleForTesting
  static void resetForTest() => _ranThisSession = false;

  static void _showDialog(BuildContext context, _UpdateDecision d) {
    showDialog<void>(
      context: context,
      barrierDismissible: !d.mandatory,
      builder: (context) => PopScope(
        canPop: !d.mandatory,
        child: AlertDialog(
          title: const Text(
            'Update Available',
            style: TextStyle(color: AppColors.brandGreen),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('A new version of the app is ready to install!'),
              const SizedBox(height: 12),
              Text(d.notes, style: const TextStyle(color: Colors.blueGrey)),
            ],
          ),
          actions: [
            if (!d.mandatory)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Later',
                    style: TextStyle(color: Colors.grey)),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lightGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                if (!await showParentalGate(context)) return;
                final uri = Uri.tryParse(d.url);
                if (uri == null || !isTrustedStoreUrl(d.url)) {
                  messenger.showSnackBar(const SnackBar(
                    content: Text('Update URL is invalid or untrusted.'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Download Update'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateDecision {
  const _UpdateDecision({
    required this.url,
    required this.notes,
    required this.mandatory,
  });
  final String url;
  final String notes;
  final bool mandatory;
}
