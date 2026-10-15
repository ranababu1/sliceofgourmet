import 'app_user.dart';

/// User-facing sign-in failure.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class AuthRepository {
  /// Returns null if the user cancelled. Throws [AuthException] on failure.
  Future<AppUser?> signInWithGoogle();
  Future<void> signOut();
  Future<AppUser?> getCurrentUser();
}
