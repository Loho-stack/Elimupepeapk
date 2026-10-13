import 'package:dio/dio.dart';
import 'package:elimupepe/app/app_services.dart';
import 'package:elimupepe/core/auth/token_store.dart';
import 'package:elimupepe/core/utils/error_feedback.dart';

class LoginResult {
  final bool success;
  final String message;
  final int? roleId;
  final String? roleName;
  final String? studentId;
  final String? name;

  const LoginResult({
    required this.success,
    required this.message,
    this.roleId,
    this.roleName,
    this.studentId,
    this.name,
  });
}

class AuthService {
  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;
  AuthService._internal();

  /// Tokens live in [TokenStore] (secure storage only).
  TokenStore get _tokens => AppServices.instance.tokenStore;

  static const String _studentIdKey = 'auth_student_id';
  static const String _legacyEmailKey = 'auth_email';
  static const String _userIdKey = 'auth_user_id';
  static const String _roleIdKey = 'auth_role_id';
  static const String _roleNameKey = 'auth_role_name';
  static const Set<int> _allowedRoleIds = {2, 3, 7};
  static const Set<String> _allowedRoleNames = {
    'student',
    'teacher',
    'educator',
    'parent',
    'guardian',
  };

  /// The shared client: bearer token, 401 and 429 handling, offline check.
  Dio get _dio => AppServices.instance.apiClient.api;

  /// Same secure store as the tokens, so logout wipes everything at once.
  _SessionKv get _secureStorage => _SessionKv(AppServices.instance.kv);

  Future<LoginResult> login({
    required String studentId,
    required String password,
  }) async {
    try {
      final normalizedStudentId = _normalizeStudentId(studentId);
      if (_looksLikeEmail(normalizedStudentId)) {
        return const LoginResult(
          success: false,
          message: 'Email login is not supported. Use your Student ID.',
        );
      }

      if (!_isValidStudentId(normalizedStudentId)) {
        return const LoginResult(
          success: false,
          message: 'Invalid Student ID format. Expected: LO-XXXXXXXX',
        );
      }

      if (AppServices.instance.config.appApiV1Login) {
        return await loginWithAppApi(
          role: 'student',
          identifier: normalizedStudentId,
          password: password,
        );
      }

      final Response<dynamic> response = await _dio.post(
        '/v1/auth/login',
        data: {'student_id': normalizedStudentId, 'password': password},
        options: Options(
          validateStatus: (_) => true,
          extra: const {'noAuth': true},
        ),
      );

      if (response.statusCode != 200) {
        final message =
            _extractErrorMessage(response.data) ??
            'Login failed. Please check your credentials.';
        return LoginResult(success: false, message: message);
      }

      final data = response.data;
      final token = _extractToken(data);

      if (token == null || token.isEmpty) {
        return const LoginResult(
          success: false,
          message: 'Login response missing token.',
        );
      }

      var user = _extractUser(data);
      if (_extractRoleId(user) == null) {
        final fetchedUser = await _fetchCurrentUser(token);
        if (fetchedUser.isNotEmpty) {
          user = fetchedUser;
        }
      }

      final roleId = _extractRoleId(user);
      final roleName = _extractRoleName(user);
      final resolvedName = _extractUserName(user);
      final resolvedStudentId = _extractStudentId(user) ?? normalizedStudentId;

      if (!_isAllowedRole(roleId: roleId, roleName: roleName)) {
        return const LoginResult(success: false, message: 'Unauthorized.');
      }

      await _tokens.save(AuthTokens(accessToken: token));
      await _secureStorage.write(key: _studentIdKey, value: resolvedStudentId);
      await _secureStorage.write(
        key: _userIdKey,
        value: user['id']?.toString() ?? '',
      );
      if (roleId != null) {
        await _secureStorage.write(key: _roleIdKey, value: roleId.toString());
      }
      if (roleName != null && roleName.isNotEmpty) {
        await _secureStorage.write(key: _roleNameKey, value: roleName);
      }

      return LoginResult(
        success: true,
        message: 'Login successful',
        roleId: roleId,
        roleName: roleName,
        studentId: resolvedStudentId,
        name: resolvedName,
      );
    } on DioException catch (e) {
      final serverMessage = _extractErrorMessage(e.response?.data);
      final friendlyMessage = ErrorFeedback.userMessage(
        e,
        fallback: 'Could not connect to login server.',
      );

      if (ErrorFeedback.isNetworkError(e) || ErrorFeedback.isServerError(e)) {
        return LoginResult(success: false, message: friendlyMessage);
      }

      return LoginResult(
        success: false,
        message: serverMessage ?? friendlyMessage,
      );
    } catch (_) {
      return const LoginResult(
        success: false,
        message: 'Unexpected login error. Please try again.',
      );
    }
  }

  Future<void> logout() async {
    final tokens = await _tokens.read();

    if (tokens != null) {
      try {
        if (tokens.canRefresh) {
          // Logged in through the App API v1: revoke this device only.
          await AppServices.instance.apiClient.appV1.post(
            '/auth/logout',
            data: const <String, dynamic>{},
          );
        } else {
          await _dio.post(
            '/v1/auth/logout',
            data: const <String, dynamic>{},
            options: Options(
              headers: {'Authorization': 'Bearer ${tokens.accessToken}'},
            ),
          );
        }
      } catch (_) {
        // Ignore remote logout errors and proceed with local cleanup.
      }
    }

    // Secure storage, preferences (except accessibility), webview cookies,
    // cache and storage. Keeps the Student ID only if "Remember me" is on.
    await AppServices.instance.endSession();
  }

  Future<bool> deleteAccount() async {
    final token = await getToken();

    if (token != null && token.isNotEmpty) {
      try {
        final response = await _dio.delete(
          '/v1/auth/delete-account',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        if (response.statusCode == 200 || response.statusCode == 204) {
          await AppServices.instance.endSession(keepRemembered: false);
          return true;
        }
      } catch (_) {
        // If the API call fails, we still want to clear local data and return false
        // to indicate the remote deletion might not have completed.
      }
    }

    await AppServices.instance.endSession(keepRemembered: false);
    return false;
  }

  Future<void> persistParentSession({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    final roleId = _extractRoleId(user) ?? 7;
    final roleName = _extractRoleName(user) ?? 'parent';

    await _tokens.save(AuthTokens(accessToken: token));
    await _secureStorage.write(key: _roleIdKey, value: roleId.toString());
    await _secureStorage.write(key: _roleNameKey, value: roleName);

    final userId = user['id'];
    if (userId != null) {
      await _secureStorage.write(
        key: _userIdKey,
        value: userId.toString(),
      );
    }
    final studentId = user['student_id'] ?? user['loho_id'];
    if (studentId != null) {
      await _secureStorage.write(
        key: _studentIdKey,
        value: studentId.toString(),
      );
    }
    final name = user['name'] ?? user['full_name'] ?? user['first_name'];
    if (name is String && name.trim().isNotEmpty) {
      await AppServices.instance.profile.update(name: name);
    }
  }

  /// The signed-in learner's Student ID (secure storage).
  Future<String?> getSavedStudentId() async {
    final v = await _readSecureValue(_studentIdKey);
    return (v == null || v.isEmpty) ? null : v;
  }

  /// Login through the App API v1 (`/api/app/v1/auth/{role}/login`), used
  /// when `AppConfig.appApiV1Login` is on. [role] is `student`, `parent` or
  /// `teacher`; [identifier] is the Student ID or the account email.
  ///
  /// Contract: 200 `{success, data:{access_token, refresh_token, token_type,
  /// expires_in, expires_at, refresh_expires_at, user:{id,name,role,role_id,
  /// avatar_url,language,student_id?,grade?,email?,school_id?,...}}}`;
  /// 401 same message for unknown user, wrong password and wrong role; 403
  /// disabled account; 422 validation; 429 rate limit (10/min).
  Future<LoginResult> loginWithAppApi({
    required String role,
    required String identifier,
    required String password,
  }) async {
    assert(const {'student', 'parent', 'teacher'}.contains(role));
    try {
      final response = await AppServices.instance.apiClient.appV1.post(
        '/auth/$role/login',
        data: role == 'student'
            ? {'student_id': identifier, 'password': password}
            : {'identifier': identifier.trim(), 'password': password},
        options: Options(
          validateStatus: (_) => true,
          extra: const {'noAuth': true},
        ),
      );

      final body = response.data;
      if (response.statusCode != 200 || body is! Map<String, dynamic>) {
        final message = switch (response.statusCode) {
          403 => 'This account is not active. Please contact support.',
          429 => 'Too many attempts. Please wait a minute and try again.',
          _ => _extractErrorMessage(body) ??
              'Login failed. Please check your credentials.',
        };
        return LoginResult(success: false, message: message);
      }

      final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? {};
      final access = data['access_token'];
      if (access is! String || access.isEmpty) {
        return const LoginResult(
          success: false,
          message: 'Login response missing token.',
        );
      }
      final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? {};
      final roleId = _extractRoleId(user);
      final roleName = _extractRoleName(user);
      if (!_isAllowedRole(roleId: roleId, roleName: roleName)) {
        return const LoginResult(success: false, message: 'Unauthorized.');
      }

      await _tokens.save(AuthTokens(
        accessToken: access,
        refreshToken: data['refresh_token'] as String?,
        accessExpiresAt: DateTime.tryParse('${data['expires_at']}'),
        refreshExpiresAt: DateTime.tryParse('${data['refresh_expires_at']}'),
      ));
      final studentId = _extractStudentId(user);
      if (studentId != null) {
        await _secureStorage.write(key: _studentIdKey, value: studentId);
      }
      await _secureStorage.write(
          key: _userIdKey, value: user['id']?.toString() ?? '');
      if (roleId != null) {
        await _secureStorage.write(key: _roleIdKey, value: roleId.toString());
      }
      if (roleName != null && roleName.isNotEmpty) {
        await _secureStorage.write(key: _roleNameKey, value: roleName);
      }
      final avatar = user['avatar_url'];
      await AppServices.instance.profile.update(
        name: _extractUserName(user),
        avatarUrl: avatar is String ? avatar : null,
      );

      return LoginResult(
        success: true,
        message: 'Login successful',
        roleId: roleId,
        roleName: roleName,
        studentId: studentId,
        name: _extractUserName(user),
      );
    } on DioException catch (e) {
      return LoginResult(
        success: false,
        message: ErrorFeedback.userMessage(
          e,
          fallback: 'Could not connect to login server.',
        ),
      );
    } catch (_) {
      return const LoginResult(
        success: false,
        message: 'Unexpected login error. Please try again.',
      );
    }
  }

  Future<bool> isParentSession() async {
    final roleId = await getSavedRoleId();
    final roleName = await getSavedRoleName();
    return roleId == 7 ||
        roleName == 'parent' ||
        roleName == 'guardian';
  }

  Future<String?> getToken() async {
    try {
      return await _tokens.accessToken();
    } catch (_) {
      await _clearSavedSession();
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<int?> getSavedRoleId() async {
    final raw = await _readSecureValue(_roleIdKey);
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  Future<int?> getSavedUserId() async {
    final raw = await _readSecureValue(_userIdKey);
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  Future<String?> getSavedRoleName() async {
    final raw = await _readSecureValue(_roleNameKey);
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  Future<bool> validateSession() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      final response = await _dio.post(
        '/v1/auth/me',
        data: const <String, dynamic>{},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        await logout();
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      final fetchedUser = await _fetchCurrentUser(token);
      if (fetchedUser.isNotEmpty) {
        return fetchedUser;
      }
    }

    final studentId = await _readSecureValue(_studentIdKey);
    final userId = await _readSecureValue(_userIdKey);

    if ((studentId != null && studentId.isNotEmpty) ||
        (userId != null && userId.isNotEmpty)) {
      final parsedId = userId != null && userId.isNotEmpty
          ? int.tryParse(userId) ?? userId
          : null;
      return {
        if (studentId != null && studentId.isNotEmpty) 'student_id': studentId,
        if (parsedId != null) 'id': parsedId,
      };
    }

    return {};
  }

  String? _extractToken(dynamic payload) {
    if (payload is! Map<String, dynamic>) {
      return null;
    }

    final directToken = payload['token'] ?? payload['access_token'];
    if (directToken is String && directToken.isNotEmpty) {
      return directToken;
    }

    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      final nestedToken = data['token'] ?? data['access_token'];
      if (nestedToken is String && nestedToken.isNotEmpty) {
        return nestedToken;
      }
    }

    return null;
  }

  Map<String, dynamic> _extractUser(dynamic payload) {
    if (payload is! Map<String, dynamic>) {
      return {};
    }

    final user = payload['user'];
    if (user is Map<String, dynamic>) {
      return user;
    }

    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      if (data.containsKey('role_id')) {
        return data;
      }

      final nestedUser = data['user'];
      if (nestedUser is Map<String, dynamic>) {
        return nestedUser;
      }
    }

    return {};
  }

  String? _extractErrorMessage(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final message = payload['message'] ?? payload['error'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
    return null;
  }

  int? _extractRoleId(Map<String, dynamic> user) {
    final roleRaw = user['role_id'] ?? user['roleId'];
    if (roleRaw is int) {
      return roleRaw;
    }
    if (roleRaw is String) {
      return int.tryParse(roleRaw);
    }
    return null;
  }

  String? _extractRoleName(Map<String, dynamic> user) {
    final direct = user['role_name'] ?? user['roleName'] ?? user['role'];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct.trim().toLowerCase();
    }

    if (direct is Map<String, dynamic>) {
      final nested =
          direct['name'] ??
          direct['slug'] ??
          direct['title'] ??
          direct['label'];
      if (nested is String && nested.trim().isNotEmpty) {
        return nested.trim().toLowerCase();
      }
    }

    final type = user['role_type'] ?? user['roleType'];
    if (type is String && type.trim().isNotEmpty) {
      return type.trim().toLowerCase();
    }

    return null;
  }

  bool _isAllowedRole({int? roleId, String? roleName}) {
    if (roleId == null && (roleName == null || roleName.isEmpty)) {
      return true;
    }

    if (roleId != null && _allowedRoleIds.contains(roleId)) {
      return true;
    }

    if (roleName != null && _allowedRoleNames.contains(roleName)) {
      return true;
    }

    return false;
  }

  Future<Map<String, dynamic>> _fetchCurrentUser(String token) async {
    try {
      final response = await _dio.post(
        '/v1/auth/me',
        data: const <String, dynamic>{},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      final payload = response.data;
      final user = _extractUser(payload);
      if (user.isNotEmpty) {
        return user;
      }
    } catch (_) {
      // If profile fetch fails, return empty map and let role validation fail safely.
    }

    return {};
  }

  bool _looksLikeEmail(String value) {
    return value.contains('@');
  }

  String _normalizeStudentId(String value) {
    return value.trim().toUpperCase();
  }

  bool _isValidStudentId(String value) {
    return RegExp(r'^LO-[A-Z0-9]{8}$', caseSensitive: false).hasMatch(value);
  }

  String? _extractStudentId(Map<String, dynamic> user) {
    final raw = user['student_id'] ?? user['studentId'] ?? user['loho_id'];
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    return text.toUpperCase();
  }

  String? _extractUserName(Map<String, dynamic> user) {
    final raw = user['name'] ?? user['full_name'] ?? user['first_name'];
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }

  Future<String?> _readSecureValue(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (_) {
      await _clearSavedSession();
      return null;
    }
  }

  Future<void> _clearSavedSession() async {
    try {
      await _tokens.clear();
    } catch (_) {
      // Ignore cleanup failures so corrupted secure storage never crashes auth.
    }
    for (final key in const [
      _studentIdKey,
      _legacyEmailKey,
      _userIdKey,
      _roleIdKey,
      _roleNameKey,
    ]) {
      try {
        await _secureStorage.delete(key: key);
      } catch (_) {
        // Ignore cleanup failures so corrupted secure storage never crashes auth.
      }
    }
  }

}

/// Keeps the call style of the old FlutterSecureStorage field while using
/// the shared [SecureKv].
class _SessionKv {
  const _SessionKv(this._kv);
  final SecureKv _kv;

  Future<String?> read({required String key}) => _kv.read(key);
  Future<void> write({required String key, required String value}) =>
      _kv.write(key, value);
  Future<void> delete({required String key}) => _kv.delete(key);
}
