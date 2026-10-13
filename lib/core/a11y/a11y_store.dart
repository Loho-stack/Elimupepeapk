import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'a11y_settings.dart';

/// Local persistence for accessibility settings. Nothing here identifies a
/// person, so SharedPreferences is fine. The queue of unsynced changes and
/// the ETag belong to the signed-in account and are cleared on logout.
abstract class A11yStore {
  Future<A11ySettings?> load();
  Future<void> save(A11ySettings settings);
  Future<Map<String, dynamic>> loadPending();
  Future<void> savePending(Map<String, dynamic> pending);
  Future<String?> loadEtag();
  Future<void> saveEtag(String? etag);

  /// Forget account-bound state (pending queue, ETag). Keeps the settings:
  /// they are a device preference.
  Future<void> clearAccountState();
}

class SharedPreferencesA11yStore implements A11yStore {
  SharedPreferencesA11yStore([SharedPreferences? prefs]) : _prefs = prefs;

  static const settingsKey = 'a11y.settings';
  static const pendingKey = 'a11y.pending';
  static const etagKey = 'a11y.etag';

  SharedPreferences? _prefs;
  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<A11ySettings?> load() async {
    final raw = (await _p).getString(settingsKey);
    if (raw == null) return null;
    try {
      return A11ySettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(A11ySettings settings) async =>
      (await _p).setString(settingsKey, jsonEncode(settings.toJson()));

  @override
  Future<Map<String, dynamic>> loadPending() async {
    final raw = (await _p).getString(pendingKey);
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> savePending(Map<String, dynamic> pending) async {
    final p = await _p;
    if (pending.isEmpty) {
      await p.remove(pendingKey);
    } else {
      await p.setString(pendingKey, jsonEncode(pending));
    }
  }

  @override
  Future<String?> loadEtag() async => (await _p).getString(etagKey);

  @override
  Future<void> saveEtag(String? etag) async {
    final p = await _p;
    if (etag == null) {
      await p.remove(etagKey);
    } else {
      await p.setString(etagKey, etag);
    }
  }

  @override
  Future<void> clearAccountState() async {
    final p = await _p;
    await p.remove(pendingKey);
    await p.remove(etagKey);
  }
}
