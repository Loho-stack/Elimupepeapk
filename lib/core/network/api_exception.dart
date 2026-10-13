/// Thrown (as the `error` of a connection DioException) when the device has
/// no network, before any request is sent.
class OfflineException implements Exception {
  const OfflineException();
  @override
  String toString() => 'OfflineException: no network connection';
}

/// The session ended (401 that could not be refreshed). The app returns to
/// the login screen.
class SessionExpiredException implements Exception {
  const SessionExpiredException();
  @override
  String toString() => 'SessionExpiredException';
}
