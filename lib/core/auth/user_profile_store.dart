import 'token_store.dart';

/// What the app shows about the signed-in person. Only the display name and
/// avatar URL are persisted (secure storage), so the home header renders
/// offline. Everything else (Student ID, grade, ...) is fetched again at
/// start-up and held in memory by whoever needs it.
class UserProfile {
  const UserProfile({this.name, this.avatarUrl});
  final String? name;
  final String? avatarUrl;

  bool get isEmpty =>
      (name == null || name!.isEmpty) &&
      (avatarUrl == null || avatarUrl!.isEmpty);
}

class UserProfileStore {
  UserProfileStore(this._kv);
  final SecureKv _kv;

  static const nameKey = 'profile_display_name';
  static const avatarKey = 'profile_avatar_url';

  UserProfile? _cache;

  /// Cache-buster for the avatar URL. Memory only, resets on restart.
  String? avatarCacheKey;

  Future<UserProfile> read() async {
    return _cache ??= UserProfile(
      name: await _kv.read(nameKey),
      avatarUrl: await _kv.read(avatarKey),
    );
  }

  /// Updates only the fields that are passed (null keeps the old value).
  Future<void> update({String? name, String? avatarUrl}) async {
    final current = await read();
    final next = UserProfile(
      name: name ?? current.name,
      avatarUrl: avatarUrl ?? current.avatarUrl,
    );
    if (name != null) await _write(nameKey, name.trim());
    if (avatarUrl != null) await _write(avatarKey, avatarUrl);
    _cache = next;
  }

  Future<void> clear() async {
    _cache = null;
    avatarCacheKey = null;
    await _kv.delete(nameKey);
    await _kv.delete(avatarKey);
  }

  Future<void> _write(String key, String value) =>
      value.isEmpty ? _kv.delete(key) : _kv.write(key, value);
}
