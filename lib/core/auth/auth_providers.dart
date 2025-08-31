import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_user.dart';
import 'auth_repository.dart';
import 'google_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => GoogleAuthRepository(),
);

class AuthController extends StateNotifier<AppUser?> {
  AuthController(this._repo) : super(null) {
    _init();
  }

  final AuthRepository _repo;

  Future<void> _init() async {
    final u = await _repo.getCurrentUser();
    state = u;
  }

  Future<void> signInGoogle() async {
    final u = await _repo.signInWithGoogle();
    if (u != null) state = u;
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = null;
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AppUser?>(
  (ref) => AuthController(ref.read(authRepositoryProvider)),
);

final isSignedInProvider = Provider<bool>(
  (ref) => ref.watch(authControllerProvider) != null,
);
