import 'package:flutter/foundation.dart';
import 'package:elimupepe/models/ebook.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elimupepe/core/config/app_endpoints.dart';
import 'package:elimupepe/core/utils/image_url_resolver.dart';

/// Service to interact with Firebase Firestore for cloud book management
class FirestoreService {
  static final FirestoreService instance = FirestoreService._internal();
  factory FirestoreService() => instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _booksCollection = 'books';
  static const String _booksImageBaseUrl = AppEndpoints.ebooksApiBaseUrl;

  /// Get all books from Firestore
  Future<List<Ebook>> getCloudBooks() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_booksCollection)
          .orderBy('title')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Ebook(
          id: doc.id,
          title: data['title'] ?? '',
          author: data['author'] ?? '',
          serverUrl: data['pdfUrl'] ?? '', // Google Drive link
          fileSize: data['fileSize'] ?? 0,
          downloadedDate: data['addedDate'] != null
              ? (data['addedDate'] as Timestamp).toDate()
              : DateTime.now(),
          grade: data['grade'] ?? '',
          category: data['category'] ?? 'Textbooks',
          coverImagePath: ImageUrlResolver.normalize(
            data['coverUrl'],
            baseUrl: _booksImageBaseUrl,
          ),
          totalPages: 0,
          isDownloaded: false,
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching cloud books');
      return [];
    }
  }
}
