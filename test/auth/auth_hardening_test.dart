import 'dart:io';

import 'package:elimupepe/core/auth/legacy_migration.dart';
import 'package:elimupepe/core/auth/remembered_login.dart';
import 'package:elimupepe/core/auth/session_cleaner.dart';
import 'package:elimupepe/core/auth/token_store.dart';
import 'package:elimupepe/core/auth/user_profile_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

/// What version 1.2.8 left on a phone where the learner used "Remember me".
Map<String, Object> oldPrefs({bool remember = true}) => {
      'remember_me': remember,
      'saved_student_id': 'LO-ABCD1234',
      'saved_password': 'hunter2-plain',
      'saved_email': 'kid@example.test',
      'user_name': 'Amina Wanjiru',
      'user_email': 'kid@example.test',
      'loho_id': 'LO-ABCD1234',
      'profile_image_url': 'https://cdn.example.test/a.png',
      'user_avatar': 'https://cdn.example.test/a.png',
      'profile_image_cache_key': '12345',
      'parent_remember_me': true,
      'grade': 'Grade 6',
      'last_dashboard_tab_index': 2,
      'a11y.settings': '{"text_size":2}',
    };

MemoryKv oldSecure() => MemoryKv()
  ..data.addAll({
    'auth_token': 'tok-legacy',
    'passport_token': 'tok-legacy',
    'auth_student_id': 'LO-ABCD1234',
    'auth_user_id': '42',
    'auth_role_id': '3',
    'saved_student_id': 'LO-ABCD1234',
    'saved_password': 'hunter2-secure',
    'parent_saved_email': 'parent@example.test',
    'parent_saved_password': 'parent-pass',
    'auth_email': 'old@example.test',
  });

void main() {
  late SharedPreferences prefs;

  Future<LegacyMigration> migration(MemoryKv kv,
      {Map<String, Object>? values}) async {
    SharedPreferences.setMockInitialValues(values ?? oldPrefs());
    prefs = await SharedPreferences.getInstance();
    return LegacyMigration(kv: kv, prefs: prefs);
  }

  group('LegacyMigration', () {
    test('deletes every saved password, in secure storage and preferences',
        () async {
      final kv = oldSecure();
      await (await migration(kv)).run();

      expect(kv.data.containsKey('saved_password'), isFalse);
      expect(kv.data.containsKey('parent_saved_password'), isFalse);
      expect(prefs.containsKey('saved_password'), isFalse);
      expect(kv.data.values.any((v) => v.contains('hunter2')), isFalse);
      expect(kv.data.values.any((v) => v.contains('parent-pass')), isFalse);
    });

    test('no SharedPreferences key holds PII after migration', () async {
      final kv = oldSecure();
      await (await migration(kv)).run();

      const pii = [
        'user_name',
        'user_email',
        'saved_student_id',
        'saved_email',
        'saved_password',
        'loho_id',
        'profile_image_url',
        'user_avatar',
        'profile_image_cache_key',
        'remember_me',
        'parent_remember_me',
      ];
      for (final k in pii) {
        expect(prefs.containsKey(k), isFalse, reason: k);
      }
      // And no remaining value looks like an email, Student ID, name or URL.
      for (final k in prefs.getKeys()) {
        final v = '${prefs.get(k)}';
        expect(v.contains('@'), isFalse, reason: k);
        expect(RegExp(r'LO-[A-Z0-9]{8}').hasMatch(v), isFalse, reason: k);
        expect(v.contains('Amina'), isFalse, reason: k);
        expect(v.contains('http'), isFalse, reason: k);
      }
    });

    test('keeps non-personal and accessibility preferences', () async {
      await (await migration(oldSecure())).run();
      expect(prefs.getString('a11y.settings'), isNotNull);
      expect(prefs.getInt('last_dashboard_tab_index'), 2);
      expect(prefs.getString('grade'), 'Grade 6');
    });

    test('remember me carries only the Student ID into secure storage',
        () async {
      final kv = oldSecure();
      await (await migration(kv)).run();
      expect(await RememberedLogin(kv).studentId(), 'LO-ABCD1234');
      expect(kv.data.containsKey('saved_student_id'), isFalse);
    });

    test('without remember me nothing about the login is kept', () async {
      final kv = oldSecure();
      await (await migration(kv, values: oldPrefs(remember: false))).run();
      expect(await RememberedLogin(kv).studentId(), isNull);
    });

    test('display name and avatar move to secure storage', () async {
      final kv = oldSecure();
      await (await migration(kv)).run();
      final p = await UserProfileStore(kv).read();
      expect(p.name, 'Amina Wanjiru');
      expect(p.avatarUrl, 'https://cdn.example.test/a.png');
    });

    test('tokens move to the single access_token key and old keys go',
        () async {
      final kv = oldSecure();
      await (await migration(kv)).run();
      expect(kv.data['access_token'], 'tok-legacy');
      expect(kv.data.containsKey('auth_token'), isFalse);
      expect(kv.data.containsKey('passport_token'), isFalse);
      expect(await TokenStore(kv).accessToken(), 'tok-legacy');
      // The session itself survives the upgrade.
      expect(kv.data['auth_student_id'], 'LO-ABCD1234');
    });

    test('an existing access_token wins over legacy ones', () async {
      final kv = oldSecure()..data['access_token'] = 'tok-new';
      await (await migration(kv)).run();
      expect(kv.data['access_token'], 'tok-new');
    });

    test('is idempotent and runs once', () async {
      final kv = oldSecure();
      final m = await migration(kv);
      await m.run();
      expect(kv.data[LegacyMigration.doneKey], 'true');

      // Old data reappearing (e.g. a restored backup) is not re-imported.
      kv.data['saved_password'] = 'again';
      await prefs.setString('user_name', 'Someone');
      await m.run();
      expect(kv.data['saved_password'], 'again');
      expect(prefs.getString('user_name'), 'Someone');
    });

    test('fresh install: runs cleanly and only sets the flag', () async {
      final kv = MemoryKv();
      await (await migration(kv, values: {})).run();
      expect(kv.data.keys, [LegacyMigration.doneKey]);
    });

    test('never throws if secure storage is broken', () async {
      final m = LegacyMigration(
          kv: _ThrowingKv(), prefs: await _prefs(oldPrefs()));
      await m.run();
    });
  });

  group('RememberedLogin', () {
    test('stores only the upper-cased Student ID', () async {
      final kv = MemoryKv();
      final r = RememberedLogin(kv);
      await r.remember(' lo-abcd1234 ');
      expect(await r.studentId(), 'LO-ABCD1234');
      expect(kv.data.keys, ['remembered_student_id']);
      await r.forget();
      expect(await r.studentId(), isNull);
    });
  });

  group('UserProfileStore', () {
    test('persists only name and avatar; partial updates keep the rest',
        () async {
      final kv = MemoryKv();
      final s = UserProfileStore(kv);
      expect((await s.read()).isEmpty, isTrue);
      await s.update(name: ' Amina ', avatarUrl: 'https://a.test/x.png');
      await s.update(name: 'Amina W');
      final p = await s.read();
      expect(p.name, 'Amina W');
      expect(p.avatarUrl, 'https://a.test/x.png');
      expect(kv.data.keys.toSet(), {'profile_display_name', 'profile_avatar_url'});
    });

    test('clear wipes storage and the memory cache', () async {
      final kv = MemoryKv();
      final s = UserProfileStore(kv);
      await s.update(name: 'A', avatarUrl: 'u');
      await s.clear();
      expect((await s.read()).isEmpty, isTrue);
      expect(kv.data, isEmpty);
    });
  });

  group('SessionCleaner (logout)', () {
    Future<(SessionCleaner, MemoryKv, SharedPreferences, List<String>)> setup(
        {Map<String, Object>? values}) async {
      SharedPreferences.setMockInitialValues(values ?? oldPrefs());
      final p = await SharedPreferences.getInstance();
      final kv = oldSecure()
        ..data['access_token'] = 'tok'
        ..data['refresh_token'] = 'ref'
        ..data['profile_display_name'] = 'Amina'
        ..data['remembered_student_id'] = 'LO-ABCD1234';
      final calls = <String>[];
      return (
        SessionCleaner(
          kv: kv,
          prefs: () async => p,
          clearWebview: () async => calls.add('webview'),
        ),
        kv,
        p,
        calls
      );
    }

    test('wipes secure storage, tokens included', () async {
      final (c, kv, _, _) = await setup();
      await c.clear();
      expect(kv.data.containsKey('access_token'), isFalse);
      expect(kv.data.containsKey('refresh_token'), isFalse);
      expect(kv.data.containsKey('profile_display_name'), isFalse);
      expect(kv.data.containsKey('remembered_student_id'), isFalse);
      expect(kv.data.keys, [LegacyMigration.doneKey]);
    });

    test('keeps only accessibility preferences', () async {
      final (c, _, p, _) = await setup();
      await c.clear();
      expect(p.getKeys(), {'a11y.settings'});
    });

    test('clears webview cookies, cache and storage', () async {
      final (c, _, _, calls) = await setup();
      await c.clear();
      expect(calls, ['webview']);
    });

    test('keepRemembered keeps the opted-in Student ID and nothing else',
        () async {
      final (c, kv, _, _) = await setup();
      await c.clear(keepRemembered: true);
      expect(kv.data.keys.toSet(),
          {LegacyMigration.doneKey, 'remembered_student_id'});
      expect(kv.data['remembered_student_id'], 'LO-ABCD1234');
    });

    test('a webview failure does not stop the rest', () async {
      SharedPreferences.setMockInitialValues(oldPrefs());
      final p = await SharedPreferences.getInstance();
      final kv = oldSecure();
      await SessionCleaner(
        kv: kv,
        prefs: () async => p,
        clearWebview: () async => throw StateError('webview gone'),
      ).clear();
      expect(kv.data.containsKey('access_token'), isFalse);
      expect(p.getKeys(), {'a11y.settings'});
    });
  });

  group('source guards', () {
    final lib = Directory('lib');
    Iterable<File> dartFiles() => lib
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    test('no code stores a password: saved_password only appears in the '
        'migration that deletes it', () {
      for (final f in dartFiles()) {
        final p = f.path.replaceAll('\\', '/');
        if (p.endsWith('core/auth/legacy_migration.dart')) continue;
        expect(f.readAsStringSync().contains('saved_password'), isFalse,
            reason: p);
      }
    });

    test('no analytics user identifiers or user properties are set', () {
      for (final f in dartFiles()) {
        final s = f.readAsStringSync();
        for (final banned in [
          'setUserId',
          'setUserProperty',
          'setUserIdentifier',
          'setCustomKey',
        ]) {
          expect(s.contains(banned), isFalse, reason: '$banned in ${f.path}');
        }
      }
    });

    test('no code reads or writes PII keys in SharedPreferences', () {
      const piiKeys = [
        'user_name',
        'user_email',
        'saved_student_id',
        'saved_email',
        'loho_id',
        'profile_image_url',
        'user_avatar',
        'profile_image_cache_key',
      ];
      final accessor = RegExp(
          r"\.(getString|setString|getBool|setBool|remove|containsKey)\(\s*'(" +
              piiKeys.join('|') +
              r")'");
      for (final f in dartFiles()) {
        final p = f.path.replaceAll('\\', '/');
        if (p.endsWith('core/auth/legacy_migration.dart')) continue;
        expect(accessor.hasMatch(f.readAsStringSync()), isFalse, reason: p);
      }
    });

    test('release code does not print without a debug guard', () {
      final banned = RegExp(r'(^|[^\w.])print\(');
      for (final f in dartFiles()) {
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          expect(banned.hasMatch(lines[i]), isFalse,
              reason: '${f.path}:${i + 1}');
        }
      }
    });
  });
}

Future<SharedPreferences> _prefs(Map<String, Object> v) async {
  SharedPreferences.setMockInitialValues(v);
  return SharedPreferences.getInstance();
}

class _ThrowingKv implements SecureKv {
  @override
  Future<String?> read(String key) async => throw StateError('broken');
  @override
  Future<void> write(String key, String value) async =>
      throw StateError('broken');
  @override
  Future<void> delete(String key) async => throw StateError('broken');
  @override
  Future<Map<String, String>> readAll() async => throw StateError('broken');
  @override
  Future<void> deleteAll() async => throw StateError('broken');
}
