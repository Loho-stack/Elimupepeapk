import 'package:dio/dio.dart';
import 'package:elimupepe/app/app_config.dart';
import 'package:elimupepe/core/services/remote_app_config.dart';
import 'package:elimupepe/core/services/update_checker.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

Map<String, dynamic> configBody({
  int min = 10,
  int latest = 20,
  String version = '1.3.0',
  bool force = false,
  String store = 'https://play.google.com/store/apps/details?id=com.loho.elimupepe',
}) =>
    {
      'success': true,
      'data': {
        'server_time': '2026-10-13T12:00:00+03:00',
        'app': {
          'min_supported_build': min,
          'latest_build': latest,
          'latest_version': version,
          'force_update': force,
          'store_url': store,
        },
        'flags': {
          'msafara': {'enabled': true}
        },
        'subscription': null,
        'support': {
          'email': 'help@example.test',
          'phone': '+254700000000',
          'faq_url': 'https://elimupepe.loholearning.co.ke/contact-us',
          'contact_url': 'https://elimupepe.loholearning.co.ke/contact-us'
        },
        'webview_origin': 'https://elimupepe.loholearning.co.ke',
      },
    };

void main() {
  group('RemoteAppConfig (GET /api/app/v1/app/config)', () {
    test('parses the documented envelope', () {
      final c = RemoteAppConfig.fromJson(configBody());
      expect(c.minSupportedBuild, 10);
      expect(c.latestBuild, 20);
      expect(c.latestVersion, '1.3.0');
      expect(c.forceUpdate, isFalse);
      expect(c.storeUrl, startsWith('https://play.google.com/'));
      expect(c.supportEmail, 'help@example.test');
      expect(c.faqUrl, contains('contact-us'));
      expect(c.msafaraEnabled, isTrue);
    });

    test('update available and mandatory rules', () {
      final c = RemoteAppConfig.fromJson(configBody(min: 16, latest: 18));
      expect(c.updateAvailable(16), isTrue);
      expect(c.updateAvailable(18), isFalse);
      expect(c.mustUpdate(15), isTrue); // below min_supported_build
      expect(c.mustUpdate(16), isFalse);
      expect(RemoteAppConfig.fromJson(configBody(force: true)).mustUpdate(99),
          isTrue);
    });

    test('missing fields do not throw', () {
      final c = RemoteAppConfig.fromJson({'success': true});
      expect(c.latestBuild, 0);
      expect(c.updateAvailable(16), isFalse);
      expect(c.storeUrl, '');
    });

    test('the service sends ?build= and returns null on 404, 429 or offline',
        () async {
      final adapter = ScriptedAdapter((o) => jsonBody(configBody()));
      final dio = Dio(BaseOptions(baseUrl: 'https://x.test/api/app/v1'))
        ..httpClientAdapter = adapter;
      final service = RemoteAppConfigService(dio);
      final c = await service.fetch(build: 16);
      expect(c!.latestBuild, 20);
      expect(adapter.seen.single.path, '/app/config');
      expect(adapter.seen.single.queryParameters, {'build': 16});

      for (final code in [404, 429, 500]) {
        adapter.handler = (o) => status(code);
        expect(await service.fetch(build: 16), isNull, reason: '$code');
      }
      adapter.handler = (o) => throw DioException(
          requestOptions: o, type: DioExceptionType.connectionError);
      expect(await service.fetch(build: 16), isNull);
    });
  });

  group('UpdateChecker', () {
    test('update links may only point at our site or Google Play', () {
      for (final ok in [
        'https://play.google.com/store/apps/details?id=com.loho.elimupepe',
        'https://elimupepe.loholearning.co.ke/app.apk',
        'https://dl.elimupepe.loholearning.co.ke/app.apk',
      ]) {
        expect(UpdateChecker.isTrustedStoreUrl(ok), isTrue, reason: ok);
      }
      for (final bad in [
        'http://play.google.com/x',
        'https://evil.test/app.apk',
        'https://play.google.com.evil.test/x',
        'https://elimupepe.loholearning.co.ke.evil.test/app.apk',
        'javascript:alert(1)',
        '',
      ]) {
        expect(UpdateChecker.isTrustedStoreUrl(bad), isFalse, reason: bad);
      }
    });
  });

  group('AppConfig start-up flag', () {
    test('APP_CONFIG is off by default and on with APP_API_V1', () {
      expect(AppConfig.resolve(envDefine: 'prod').appConfigEndpoint, isFalse);
      expect(
          AppConfig.resolve(envDefine: 'prod', appConfigEndpoint: true)
              .appConfigEndpoint,
          isTrue);
    });
  });
}
