import 'package:elimupepe/core/config/app_endpoints.dart';

class ImageUrlResolver {
  static String get _defaultBaseUrl => AppEndpoints.webBaseUrl;

  static const List<String> _imageKeys = [
    'avatar',
    'avatar_url',
    'avatarUrl',
    'image',
    'image_url',
    'imageUrl',
    'photo',
    'photo_url',
    'photoUrl',
    'cover',
    'book_cover',
    'bookCover',
    'cover_image',
    'coverImage',
    'cover_url',
    'coverUrl',
    'cover_path',
    'coverPath',
    'thumbnail',
    'thumbnail_image',
    'thumbnailImage',
    'thumbnail_url',
    'thumbnailUrl',
    'image_path',
    'imagePath',
    'book_image',
    'bookImage',
    'icon',
    'icon_url',
    'iconUrl',
    'banner',
    'banner_url',
    'bannerUrl',
  ];

  static String? fromMap(
    Map<String, dynamic>? data, {
    String? baseUrl,
  }) {
    if (data == null) return null;

    for (final key in _imageKeys) {
      final normalized = normalize(data[key], baseUrl: baseUrl);
      if (normalized != null) return normalized;
    }

    final nestedCandidates = [data['media'], data['images'], data['image']];
    for (final candidate in nestedCandidates) {
      if (candidate is Map<String, dynamic>) {
        final nested = fromMap(candidate, baseUrl: baseUrl);
        if (nested != null) return nested;
      }

      if (candidate is List) {
        for (final item in candidate) {
          if (item is Map<String, dynamic>) {
            final nested = fromMap(item, baseUrl: baseUrl);
            if (nested != null) return nested;
          } else {
            final normalized = normalize(item, baseUrl: baseUrl);
            if (normalized != null) return normalized;
          }
        }
      }
    }

    return null;
  }

  static String? normalize(dynamic raw, {String? baseUrl}) {
    baseUrl ??= _defaultBaseUrl;
    if (raw == null) return null;

    final value = raw.toString().trim();
    if (value.isEmpty) return null;

    // 1. Check if it's already a valid absolute URI (already encoded)
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) {
      // If it has spaces, tryParse might still succeed on some platforms but the URI is invalid.
      // But usually if tryParse succeeds and hasScheme is true, it's mostly okay.
      // However, to be safe against double-encoding:
      if (!value.contains(' ')) {
        return value;
      }
    }

    // 2. Check if it's an absolute URL but with spaces (which makes tryParse return null or invalid)
    if (value.contains('://')) {
      // It's absolute but has spaces. Encode it.
      // Uri.encodeFull is safe to call on a full URL as it preserves scheme and host chars.
      return Uri.encodeFull(value);
    }

    // 3. Handle protocol-relative URLs
    if (value.startsWith('//')) {
      return Uri.encodeFull('https:$value');
    }

    // 4. Handle root-relative URLs
    if (value.startsWith('/')) {
      return Uri.encodeFull('$baseUrl$value');
    }

    // 5. Handle www. URLs
    if (value.startsWith('www.')) {
      return Uri.encodeFull('https://$value');
    }

    // 6. Handle relative paths
    if (value.contains('/')) {
      final cleanBase = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      final cleanValue = value.startsWith('/') ? value.substring(1) : value;
      return Uri.encodeFull('$cleanBase/$cleanValue');
    }

    return null;
  }

  static String? withCacheBuster(
    String? url, {
    String? cacheKey,
    String queryKey = 'v',
  }) {
    if (url == null) return null;

    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    final key = cacheKey?.trim();
    if (key == null || key.isEmpty) {
      return trimmed;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return trimmed;
    }

    final updatedParams = Map<String, String>.from(uri.queryParameters);
    updatedParams[queryKey] = key;

    return uri.replace(queryParameters: updatedParams).toString();
  }
}
