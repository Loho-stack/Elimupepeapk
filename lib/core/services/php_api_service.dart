import 'package:dio/dio.dart';
import 'package:elimupepe/app/app_services.dart';
import 'package:elimupepe/models/ebook.dart';
import 'package:elimupepe/core/config/app_endpoints.dart';
import 'package:elimupepe/core/utils/image_url_resolver.dart';

class PhpApiService {
  static final PhpApiService instance = PhpApiService._internal();
  factory PhpApiService() => instance;
  PhpApiService._internal();

  /// Same interceptor stack, but no auth: this is a different deployment.
  late final Dio _dio = AppServices.instance.apiClient.ebooks(_baseUrl);
  static const String _baseUrl = AppEndpoints.ebooksApiBaseUrl;

  Ebook _mapBook(Map<String, dynamic> json) {
    String? rawCover = json['cover_url'] ?? json['coverUrl'];
    String? coverUrl = ImageUrlResolver.normalize(rawCover, baseUrl: _baseUrl);

    String? rawPdf = json['pdf_url'] ?? json['pdfUrl'];
    if (rawPdf != null && rawPdf.contains(' ') && !rawPdf.contains('%20')) {
      rawPdf = rawPdf.replaceAll(' ', '%20');
    }

    return Ebook(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? json['publisher'] ?? '',
      coverUrl: coverUrl,
      coverImagePath: coverUrl,
      serverUrl: rawPdf ?? '',
      fileSize: json['file_size'] ?? json['fileSize'] ?? 0,
      downloadedDate: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : (json['addedDate'] != null
                ? DateTime.tryParse(json['addedDate'])
                : DateTime.now()),
      grade: json['grade'] ?? '',
      category: json['category'] ?? 'Textbooks',
      totalPages: 0,
      isDownloaded: false,
    );
  }

  Future<List<Ebook>> getCloudBooks() async {
    try {
      final response = await _dio.get('$_baseUrl/books');
      if (response.statusCode == 200) {
        final List<dynamic> booksJson = response.data is List
            ? response.data
            : response.data['data'] ?? response.data['books'] ?? [];
        return booksJson
            .whereType<Map<String, dynamic>>()
            .map(_mapBook)
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching cloud books: $e');
      return [];
    }
  }

  Future<List<Ebook>> getBooksByGrade(String grade) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/books',
        queryParameters: {'grade': grade},
      );
      if (response.statusCode == 200) {
        final List<dynamic> booksJson = response.data is List
            ? response.data
            : response.data['data'] ?? response.data['books'] ?? [];
        return booksJson
            .whereType<Map<String, dynamic>>()
            .map(_mapBook)
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching books by grade: $e');
      return [];
    }
  }

  Future<List<Ebook>> getBooksByCategory(String category) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/books',
        queryParameters: {'category': category},
      );

      if (response.statusCode == 200) {
        final List<dynamic> booksJson = response.data is List
            ? response.data
            : response.data['data'] ?? response.data['books'] ?? [];
        return booksJson
            .whereType<Map<String, dynamic>>()
            .map(_mapBook)
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching books by category: $e');
      return [];
    }
  }

  Future<List<Ebook>> searchBooks(String query) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/books',
        queryParameters: {'search': query},
      );
      if (response.statusCode == 200) {
        final List<dynamic> booksJson = response.data is List
            ? response.data
            : response.data['data'] ?? response.data['books'] ?? [];
        return booksJson
            .whereType<Map<String, dynamic>>()
            .map(_mapBook)
            .toList();
      }
      return [];
    } catch (e) {
      print('Error searching books: $e');
      return [];
    }
  }

  Future<bool> deleteBook(String bookId) async {
    try {
      final response = await _dio.delete('$_baseUrl/books/$bookId');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Error deleting book: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    try {
      final response = await _dio.get('$_baseUrl/quizzes');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List
            ? response.data
            : response.data['data'] ?? response.data['leaderboard'] ?? [];
        return data.whereType<Map<String, dynamic>>().toList();
      }
      return [];
    } catch (e) {
      print('Error fetching leaderboard: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getLatestAppVersion() async {
    try {
      // Adjust the endpoint path to match your PHP server's actual route
      final response = await _dio.get('$_baseUrl/api/app-version.php');

      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'version': data['version']?.toString() ?? '',
          'url': data['url']?.toString() ?? '',
          'release_notes': data['release_notes']?.toString() ?? '',
          'force_update':
              data['force_update'] == true || data['force_update'] == 'true',
        };
      }
    } catch (e) {
      print('Error fetching app version: $e');
    }
    return {};
  }
}
