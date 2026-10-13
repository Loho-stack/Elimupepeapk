import 'token_store.dart';

/// "Remember me": keeps only the Student ID, only when the learner opted in.
/// Passwords are never stored anywhere, and tokens do the work of staying
/// signed in.
class RememberedLogin {
  RememberedLogin(this._kv);
  final SecureKv _kv;

  static const studentIdKey = 'remembered_student_id';

  Future<String?> studentId() async {
    final v = await _kv.read(studentIdKey);
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> remember(String studentId) =>
      _kv.write(studentIdKey, studentId.trim().toUpperCase());

  Future<void> forget() => _kv.delete(studentIdKey);
}
