import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';

class ThumbnailService {
  static const String _thumbnailDir = 'pdf_thumbnails';
  static final ThumbnailService _instance = ThumbnailService._internal();

  factory ThumbnailService() {
    return _instance;
  }

  ThumbnailService._internal();

  /// Get thumbnail for a PDF file
  /// First checks for matching image file (PNG/JPG)
  /// Then generates from PDF if no image found
  /// Returns null if generation fails
  Future<Uint8List?> getThumbnail(
    String pdfPath, {
    int pageNumber = 1,
    String? coverImagePath,
  }) async {
    try {
      // If coverImagePath is provided, try to load it first
      if (coverImagePath != null && coverImagePath.isNotEmpty) {
        try {
          final imageFile = File(coverImagePath);
          if (await imageFile.exists()) {
            return await imageFile.readAsBytes();
          }
        } catch (e) {
          // Fall through to other methods
        }
      }

      // Extract base name without extension
      final baseName = _generateBaseName(pdfPath);

      // Check for matching image files (PNG/JPG)
      final imageBytes = await _getImageThumbnail(baseName);
      if (imageBytes != null) {
        return imageBytes;
      }

      // Fall back to PDF thumbnail generation
      final thumbnailDir = await _getThumbnailDirectory();
      final fileName = _generateThumbnailFileName(pdfPath, pageNumber);
      final cachedFile = File('${thumbnailDir.path}/$fileName');

      // Return cached thumbnail if exists
      if (await cachedFile.exists()) {
        return await cachedFile.readAsBytes();
      }

      // Generate new thumbnail from PDF
      final document = await PdfDocument.openFile(pdfPath);
      final page = await document.getPage(pageNumber);

      // Render page to image (200x300 for thumbnail)
      final image = await page.render(
        width: 200,
        height: 300,
        backgroundColor: '#ffffff',
        cropRect: null,
      );

      page.close();
      document.close();

      if (image == null) return null;

      // Cache the thumbnail
      final thumbnail = await cachedFile.create(recursive: true);
      await thumbnail.writeAsBytes(image.bytes);

      return image.bytes;
    } catch (e) {
      if (kDebugMode) debugPrint('Error generating thumbnail');
      return null;
    }
  }

  /// Try to load custom image thumbnail (PNG/JPG with same name as PDF)
  Future<Uint8List?> _getImageThumbnail(String baseName) async {
    try {
      final pdfDir = await _getEbooksDirectory();

      // Try PNG first
      final pngFile = File('${pdfDir.path}/$baseName.png');
      if (await pngFile.exists()) {
        return await pngFile.readAsBytes();
      }

      // Try JPG
      final jpgFile = File('${pdfDir.path}/$baseName.jpg');
      if (await jpgFile.exists()) {
        return await jpgFile.readAsBytes();
      }

      // Try JPEG
      final jpegFile = File('${pdfDir.path}/$baseName.jpeg');
      if (await jpegFile.exists()) {
        return await jpegFile.readAsBytes();
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get base name without extension
  String _generateBaseName(String filePath) {
    final fileName = File(filePath).path.split('/').last;
    return fileName.replaceAll(RegExp(r'\.[^/.]+$'), '');
  }

  /// Get ebooks directory
  Future<Directory> _getEbooksDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    return Directory('${docDir.path}/ebooks');
  }

  /// Clear all cached thumbnails
  Future<void> clearCache() async {
    try {
      final dir = await _getThumbnailDirectory();
      if (await dir.exists()) {
        dir.deleteSync(recursive: true);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error clearing thumbnail cache');
    }
  }

  Future<Directory> _getThumbnailDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final thumbnailDir = Directory('${docDir.path}/$_thumbnailDir');
    if (!await thumbnailDir.exists()) {
      await thumbnailDir.create(recursive: true);
    }
    return thumbnailDir;
  }

  String _generateThumbnailFileName(String pdfPath, int pageNumber) {
    return '${pdfPath.hashCode}_page_$pageNumber.png';
  }
}
