import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:elimupepe/models/ebook.dart';
import 'package:elimupepe/core/services/database_service.dart';
import 'package:elimupepe/core/services/firestore_service.dart';

/// Service to sync cloud books and download them locally
class CloudSyncService {
  static final CloudSyncService instance = CloudSyncService._internal();
  factory CloudSyncService() => instance;
  CloudSyncService._internal();

  final FirestoreService _firestoreService = FirestoreService.instance;
  final DatabaseService _databaseService = DatabaseService.instance;
  final Dio _dio = Dio();

  /// Check if a book is already downloaded locally
  Future<bool> isBookDownloaded(String bookId) async {
    final localBooks = await _databaseService.getAllEbooks();
    return localBooks.any((book) => book.id == bookId);
  }

  /// Sync categories and grades from Firebase for downloaded books
  Future<void> syncDownloadedBookMetadata() async {
    try {
      final cloudBooks = await _firestoreService.getCloudBooks();
      final localBooks = await _databaseService.getAllEbooks();

      // Create a map of cloud books by ID for quick lookup
      final cloudBooksMap = {for (var book in cloudBooks) book.id: book};

      // Update local books with latest cloud metadata
      for (final localBook in localBooks) {
        final cloudBook = cloudBooksMap[localBook.id];
        if (cloudBook != null) {
          // Check if category or grade changed
          if (localBook.category != cloudBook.category ||
              localBook.grade != cloudBook.grade) {
            // Update local book with cloud metadata
            final updatedBook = localBook.copyWith(
              category: cloudBook.category,
              grade: cloudBook.grade,
            );
            await _databaseService.updateEbook(updatedBook);
            if (kDebugMode) {
              debugPrint('Synced metadata for: ${localBook.title}');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error syncing downloaded book metadata: $e');
      }
    }
  }

  /// Remove bundled books from local storage (offline-safe)
  Future<void> removeBundledBooks() async {
    try {
      final localBooks = await _databaseService.getAllEbooks();
      for (final localBook in localBooks) {
        final isBundledBook = localBook.id.toLowerCase().endsWith('.pdf');
        if (isBundledBook) {
          await _deleteBookRecord(localBook);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error removing bundled books: $e');
      }
    }
  }

  /// Get all cloud books that are not yet downloaded
  Future<List<Ebook>> getAvailableCloudBooks() async {
    try {
      final cloudBooks = await _firestoreService.getCloudBooks();
      final localBooks = await _databaseService.getAllEbooks();
      final localBookIds = localBooks.map((book) => book.id).toSet();

      // Return only books not yet downloaded
      return cloudBooks
          .where((book) => !localBookIds.contains(book.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting available cloud books (offline?): $e');
      }
      // Return empty list if offline - don't break the app
      return [];
    }
  }

  /// Download a book from Google Drive link
  Future<bool> downloadBook(
    Ebook cloudBook, {
    Function(double)? onProgress,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('Starting download for: ${cloudBook.title}');
      }

      // Get app's private storage directory
      final directory = await getApplicationDocumentsDirectory();
      final ebooksDir = Directory('${directory.path}/ebooks');
      if (!ebooksDir.existsSync()) {
        ebooksDir.createSync(recursive: true);
      }

      // Convert Google Drive link to direct download link
      final downloadUrl = _convertToDirectDownloadLink(
        cloudBook.serverUrl ?? '',
      );
      if (kDebugMode) {
        debugPrint('Prepared download URL for: ${cloudBook.title}');
      }

      // Sanitize filename
      final safeFileName = cloudBook.title
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .trim();
      final pdfPath = '${ebooksDir.path}/$safeFileName.pdf';
      String? thumbnailPath;

      if (kDebugMode) {
        debugPrint('Saving book locally: ${cloudBook.title}');
      }

      // Download PDF with progress tracking and longer timeout
      await _dio
          .download(
            downloadUrl,
            pdfPath,
            onReceiveProgress: (received, total) {
              if (kDebugMode) {
                debugPrint('Book download progress: $received / $total bytes');
              }
              if (total != -1 && onProgress != null) {
                final progress = received / total;
                onProgress(progress);
              }
            },
            options: Options(
              headers: {HttpHeaders.userAgentHeader: 'Mozilla/5.0'},
              receiveTimeout: const Duration(seconds: 120),
              sendTimeout: const Duration(seconds: 60),
            ),
          )
          .timeout(
            const Duration(minutes: 5),
            onTimeout: () {
              throw Exception('Download took too long');
            },
          );

      if (kDebugMode) {
        debugPrint('PDF downloaded successfully');
      }

      // Download thumbnail if available
      if (cloudBook.coverImagePath != null &&
          cloudBook.coverImagePath!.isNotEmpty) {
        try {
          if (kDebugMode) {
            debugPrint('Downloading thumbnail for: ${cloudBook.title}');
          }
          final thumbnailUrl = _convertToDirectDownloadLink(
            cloudBook.coverImagePath!,
          );
          thumbnailPath = '${ebooksDir.path}/$safeFileName.jpg';
          await _dio
              .download(
                thumbnailUrl,
                thumbnailPath,
                options: Options(
                  headers: {HttpHeaders.userAgentHeader: 'Mozilla/5.0'},
                  receiveTimeout: const Duration(seconds: 60),
                ),
              )
              .timeout(const Duration(minutes: 2));
          if (kDebugMode) {
            debugPrint('Thumbnail downloaded successfully');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error downloading thumbnail: $e');
          }
          thumbnailPath = null;
        }
      }

      // Get file size
      final file = File(pdfPath);
      final fileSize = await file.length();
      if (kDebugMode) {
        debugPrint('Downloaded file size: ${fileSize ~/ (1024 * 1024)} MB');
      }

      // Save to local database
      final localBook = Ebook(
        id: cloudBook.id,
        title: cloudBook.title,
        author: cloudBook.author,
        localPath: pdfPath,
        fileSize: fileSize,
        downloadedDate: DateTime.now(),
        grade: cloudBook.grade,
        category: cloudBook.category,
        coverImagePath: thumbnailPath,
        totalPages: 0,
        isDownloaded: true,
        serverUrl: cloudBook.serverUrl,
      );

      await _databaseService.insertEbook(localBook);
      if (kDebugMode) {
        debugPrint('Book saved to database: ${cloudBook.title}');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error downloading book: $e');
      }
      return false;
    }
  }

  /// Convert Google Drive sharing link to direct download link
  String _convertToDirectDownloadLink(String shareLink) {
    // Handle various Google Drive link formats
    if (shareLink.contains('drive.google.com')) {
      // Extract file ID from different link formats
      RegExp regExp = RegExp(r'/d/([a-zA-Z0-9_-]+)');
      Match? match = regExp.firstMatch(shareLink);

      if (match != null) {
        final fileId = match.group(1);
        return 'https://drive.google.com/uc?export=download&id=$fileId';
      }

      // Try alternative format
      regExp = RegExp(r'id=([a-zA-Z0-9_-]+)');
      match = regExp.firstMatch(shareLink);

      if (match != null) {
        final fileId = match.group(1);
        return 'https://drive.google.com/uc?export=download&id=$fileId';
      }
    }

    // Return original link if not a Google Drive link
    return shareLink;
  }

  /// Delete a downloaded book
  Future<bool> deleteDownloadedBook(String bookId) async {
    try {
      final localBooks = await _databaseService.getAllEbooks();
      final bookIndex = localBooks.indexWhere((b) => b.id == bookId);

      if (bookIndex == -1) {
        if (kDebugMode) {
          debugPrint('Book not found in database: $bookId');
        }
        return false;
      }

      final book = localBooks[bookIndex];
      return await _deleteBookRecord(book);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting book: $e');
      }
      // Try to at least remove from database
      try {
        await _databaseService.deleteEbook(bookId);
        if (kDebugMode) {
          debugPrint('Removed orphaned database entry: $bookId');
        }
        return true;
      } catch (dbError) {
        if (kDebugMode) {
          debugPrint('Failed to remove from database: $dbError');
        }
        return false;
      }
    }
  }

  Future<bool> _deleteBookRecord(Ebook book) async {
    // Delete PDF file if present.
    if (book.localPath != null && book.localPath!.isNotEmpty) {
      try {
        final pdfFile = File(book.localPath!);
        if (await pdfFile.exists()) {
          await pdfFile.delete();
          if (kDebugMode) {
            debugPrint('Deleted PDF: ${book.localPath}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error deleting PDF file: $e');
        }
      }
    }

    // Delete thumbnail if present.
    if (book.coverImagePath != null && book.coverImagePath!.isNotEmpty) {
      try {
        final thumbnailFile = File(book.coverImagePath!);
        if (await thumbnailFile.exists()) {
          await thumbnailFile.delete();
          if (kDebugMode) {
            debugPrint('Deleted thumbnail: ${book.coverImagePath}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error deleting thumbnail: $e');
        }
      }
    }

    await _databaseService.deleteEbook(book.id);
    if (kDebugMode) {
      debugPrint('Removed from database: ${book.id}');
    }
    return true;
  }

  /// Get download status of a specific book
  Future<Map<String, dynamic>> getBookStatus(String bookId) async {
    final isDownloaded = await isBookDownloaded(bookId);

    if (isDownloaded) {
      final localBooks = await _databaseService.getAllEbooks();
      final bookIndex = localBooks.indexWhere((b) => b.id == bookId);
      if (bookIndex < 0) {
        return {'downloaded': false};
      }
      final book = localBooks[bookIndex];
      return {
        'downloaded': true,
        'localPath': book.localPath,
        'fileSize': book.fileSize,
      };
    }

    return {'downloaded': false};
  }

  /// Sync all cloud books metadata (without downloading)
  Future<void> syncMetadata() async {
    try {
      // This just fetches fresh data from Firestore
      // Actual download happens when user taps download button
      await _firestoreService.getCloudBooks();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error syncing metadata: $e');
      }
    }
  }
}
