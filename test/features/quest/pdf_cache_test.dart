import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:elimupepe/features/quest/quest_pdf_cache.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  late Directory dir;
  late ScriptedAdapter adapter;
  late QuestPdfCache cache;
  DateTime now = DateTime.now();

  const pdf = 'https://staging.loholearning.co.ke/uploads/ebooks/Our%20Land%20and%20People.pdf';

  setUp(() {
    dir = Directory.systemTemp.createTempSync('quest_pdf_test');
    now = DateTime.now();
    adapter = ScriptedAdapter((o) => ResponseBody.fromBytes(Uint8List.fromList('%PDF-1.4 test'.codeUnits), 200,
        headers: {Headers.contentTypeHeader: ['application/pdf']}));
    final dio = Dio(BaseOptions(baseUrl: 'https://staging.loholearning.co.ke/api/app/v1'))..httpClientAdapter = adapter;
    cache = QuestPdfCache(
      dio: dio,
      allowedHosts: QuestPdfCache.hostsOf(['https://staging.loholearning.co.ke', 'https://staging.loholearning.co.ke/api/app/v1']),
      directory: Directory('${dir.path}/msafara_pdf'),
      now: () => now,
    );
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('hostsOf reads the host of a base URL', () {
    expect(QuestPdfCache.hostsOf(['https://a.example/api/v1', 'not a url', 'https://B.example']), {'a.example', 'b.example'});
  });

  group('host allowlist', () {
    test('the web and API host over https are allowed', () {
      expect(cache.isAllowed(pdf), isTrue);
      expect(cache.isAllowed('https://STAGING.loholearning.co.ke/a.pdf'), isTrue);
    });

    test('other hosts, http and odd addresses are refused before any request', () async {
      for (final url in [
        'https://evil.example/a.pdf',
        'http://staging.loholearning.co.ke/a.pdf',
        'https://staging.loholearning.co.ke.evil.example/a.pdf',
        'file:///etc/passwd',
        '//staging.loholearning.co.ke/a.pdf',
        '',
      ]) {
        await expectLater(cache.fetch(url), throwsA(isA<PdfHostRefused>()), reason: url);
      }
      expect(adapter.seen, isEmpty);
    });
  });

  group('fetch', () {
    test('downloads into the cache folder and reuses the file', () async {
      final f = await cache.fetch(pdf);
      expect(f.existsSync(), isTrue);
      expect(f.parent.path.replaceAll(r'\', '/'), cache.directory.path.replaceAll(r'\', '/'));
      expect(f.readAsStringSync(), startsWith('%PDF'));
      expect(File('${f.path}.part').existsSync(), isFalse);

      final again = await cache.fetch(pdf);
      expect(again.path, f.path);
      expect(adapter.seen, hasLength(1), reason: 'second call came from the cache');
    });

    test('a file older than 7 days is fetched again', () async {
      final f = await cache.fetch(pdf);
      now = now.add(const Duration(days: 8));
      await cache.fetch(pdf);
      expect(adapter.seen, hasLength(2));
      expect(f.existsSync(), isTrue);
    });

    test('a failed download leaves no partial file', () async {
      adapter.handler = (o) => ResponseBody.fromString('nope', 500);
      await expectLater(cache.fetch(pdf), throwsA(isA<DioException>()));
      final left = cache.directory.existsSync() ? cache.directory.listSync() : const <FileSystemEntity>[];
      expect(left, isEmpty);
    });
  });

  group('cleanup', () {
    test('removes PDFs older than 7 days and half-finished downloads, keeps fresh ones', () async {
      await cache.directory.create(recursive: true);
      File mk(String name, Duration age) {
        final f = File('${cache.directory.path}${Platform.pathSeparator}$name')..writeAsStringSync('x');
        f.setLastModifiedSync(DateTime.now().subtract(age));
        return f;
      }

      final old = mk('old.pdf', const Duration(days: 9));
      final fresh = mk('fresh.pdf', const Duration(days: 1));
      final part = mk('half.pdf.part', const Duration(minutes: 1));

      // The cache clock is fixed in 2026; clean against the real clock the files were stamped with.
      final removed = await QuestPdfCache.cleanDirectory(cache.directory);
      expect(removed, 2);
      expect(old.existsSync(), isFalse);
      expect(part.existsSync(), isFalse);
      expect(fresh.existsSync(), isTrue);
    });

    test('a missing folder is fine', () async {
      expect(await cache.cleanOld(), 0);
    });
  });
}
