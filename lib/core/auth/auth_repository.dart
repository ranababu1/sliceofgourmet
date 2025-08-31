import 'app_user.dart';

abstract class AuthRepository {
  Future<AppUser?> signInWithGoogle();
  Future<void> signOut();
  Future<AppUser?> getCurrentUser();
}
