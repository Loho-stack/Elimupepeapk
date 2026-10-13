import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../core/services/auth_service.dart';
import 'app_services.dart';

enum AppRole { student, parent, teacher }

enum SessionStatus { unknown, signedOut, signedIn }

/// Who is signed in, for the router. It is the only thing the redirect reads,
/// so every sign-in, sign-out and expired session goes through here.
class SessionController extends ChangeNotifier {
  SessionController({
    Future<bool> Function()? isLoggedIn,
    Future<int?> Function()? roleId,
    Future<String?> Function()? roleName,
    Future<void> Function()? endSession,
  })  : _isLoggedIn = isLoggedIn ?? AuthService.instance.isLoggedIn,
        _roleId = roleId ?? AuthService.instance.getSavedRoleId,
        _roleName = roleName ?? AuthService.instance.getSavedRoleName,
        _endSession = endSession ?? AppServices.instance.endSession;

  final Future<bool> Function() _isLoggedIn;
  final Future<int?> Function() _roleId;
  final Future<String?> Function() _roleName;
  final Future<void> Function() _endSession;

  SessionStatus _status = SessionStatus.unknown;
  AppRole _role = AppRole.student;

  SessionStatus get status => _status;
  AppRole get role => _role;
  bool get isSignedIn => _status == SessionStatus.signedIn;

  /// Where this role lands after sign-in.
  String get homeLocation => switch (_role) {
        AppRole.student => '/student/home',
        AppRole.parent => '/parent',
        AppRole.teacher => '/teacher',
      };

  /// Reads the stored session. Call at start-up and after every login.
  Future<void> refresh() async {
    final loggedIn = await _isLoggedIn();
    if (!loggedIn) {
      _set(SessionStatus.signedOut, _role);
      return;
    }
    _set(SessionStatus.signedIn,
        roleFor(roleId: await _roleId(), roleName: await _roleName()));
  }

  /// After a successful login screen.
  Future<void> signedIn() => refresh();

  /// After logout, account deletion or an expired session. The local data
  /// is already wiped by the caller; this only moves the router.
  void signedOut() => _set(SessionStatus.signedOut, _role);

  /// A 401 that could not be refreshed: wipe the device and go to welcome.
  Future<void> expire() async {
    if (_status == SessionStatus.signedOut) return;
    await _endSession();
    signedOut();
  }

  /// Role ids from the server: 2 teacher, 7 parent, anything else student
  /// (3). Names are the fallback when the id was not saved.
  static AppRole roleFor({int? roleId, String? roleName}) {
    final name = (roleName ?? '').toLowerCase();
    if (roleId == 2 || name == 'teacher' || name == 'educator') {
      return AppRole.teacher;
    }
    if (roleId == 7 || name == 'parent' || name == 'guardian') {
      return AppRole.parent;
    }
    return AppRole.student;
  }

  void _set(SessionStatus status, AppRole role) {
    if (_status == status && _role == role) return;
    _status = status;
    _role = role;
    notifyListeners();
  }
}

/// Screens that were pushed with Navigator.push (login, profile, ...) end the
/// session through these, so the router stays the single owner of where the
/// user is.
extension SessionNavigation on BuildContext {
  /// After a successful login: close the login screens, record the session;
  /// the router redirect then opens the role's home.
  Future<void> enterSession() async {
    final session = read<SessionController>();
    Navigator.of(this, rootNavigator: true).popUntil((r) => r.isFirst);
    await session.signedIn();
  }

  /// After logout or account deletion: close every pushed screen; the router
  /// redirect then opens the welcome flow.
  void leaveSession() {
    final session = read<SessionController>();
    Navigator.of(this, rootNavigator: true).popUntil((r) => r.isFirst);
    session.signedOut();
  }
}
