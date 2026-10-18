import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Thrown when a PDF address is not one this app may fetch with the learner's session.
class PdfHostRefused implements Exception {
  const PdfHostRefused(this.url);
  final String url;
  @override
  String toString() => 'PdfHostRefused';
}

/// Downloads Elimu Quest book PDFs into the app cache with the session's Dio (so the bearer token and
/// the 401 refresh apply) and never hands them to another app. Only `https` addresses on the hosts of
/// the web base URL and the App API base URL are fetched; anything else is refused before a request.
class QuestPdfCache {
  QuestPdfCache({
    required this.dio,
    required this.allowedHosts,
    required this.directory,
    this.maxAge = const Duration(days: 7),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// The one `ApiClient.appV1` Dio.
  final Dio dio;
  final Set<String> allowedHosts;

  /// `<cache dir>/msafara_pdf`, created on demand.
  final Directory directory;
  final Duration maxAge;
  final DateTime Function() _now;

  /// The cache folder under the app's temporary directory.
  static Future<Directory> defaultDirectory() async {
    final base = await getTemporaryDirectory();
    return Directory('${base.path}${Platform.pathSeparator}msafara_pdf');
  }

  /// Hosts of [urls] (a base URL such as `https://host/api/app/v1` gives `host`).
  static Set<String> hostsOf(Iterable<String> urls) => {
        for (final u in urls)
          if (Uri.tryParse(u)?.host.isNotEmpty ?? false) Uri.parse(u).host.toLowerCase(),
      };

  bool isAllowed(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
    return allowedHosts.contains(uri.host.toLowerCase());
  }

  File fileFor(String url) =>
      File('${directory.path}${Platform.pathSeparator}${sha256.convert(url.codeUnits).toString()}.pdf');

  /// The cached file for [url], downloading it first when it is missing or older than [maxAge].
  /// Throws [PdfHostRefused] for a host that is not allowed, or a [DioException] when the download fails.
  Future<File> fetch(String url, {void Function(int received, int total)? onProgress}) async {
    if (!isAllowed(url)) throw PdfHostRefused(url);
    final file = fileFor(url);
    if (await file.exists() && _now().difference(await file.lastModified()) < maxAge) {
      if (await file.length() > 0) return file;
    }
    await directory.create(recursive: true);
    final partial = File('${file.path}.part');
    try {
      await dio.download(url, partial.path, onReceiveProgress: onProgress);
      if (await file.exists()) await file.delete();
      return await partial.rename(file.path);
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }

  /// Deletes cached PDFs older than [maxAge] and any half-finished download. Never throws.
  Future<int> cleanOld() => cleanDirectory(directory, maxAge: maxAge, now: _now);

  /// App start: tidies the default cache folder. Needs no session.
  static Future<int> cleanStale({Duration maxAge = const Duration(days: 7)}) async {
    try {
      return await cleanDirectory(await defaultDirectory(), maxAge: maxAge);
    } catch (_) {
      return 0;
    }
  }

  static Future<int> cleanDirectory(
    Directory directory, {
    Duration maxAge = const Duration(days: 7),
    DateTime Function()? now,
  }) async {
    final clock = now ?? DateTime.now;
    var removed = 0;
    try {
      if (!await directory.exists()) return 0;
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        final stale = clock().difference(await entity.lastModified()) >= maxAge;
        if (stale || entity.path.endsWith('.part')) {
          await entity.delete();
          removed++;
        }
      }
    } catch (_) {
      // A cache that cannot be tidied is not worth a crash.
    }
    return removed;
  }
}
