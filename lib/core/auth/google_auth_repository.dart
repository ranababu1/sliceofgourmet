import 'package:device_info_plus/device_info_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app_user.dart';
import 'auth_repository.dart';
import '../analytics/sheets_logger.dart';

class GoogleAuthRepository implements AuthRepository {
  GoogleAuthRepository({GoogleSignIn? signIn})
      : _signIn = signIn ??
            GoogleSignIn(
              scopes: const <String>['email'],
            );

  final GoogleSignIn _signIn;

  Future<String> _deviceName() async {
    final d = DeviceInfoPlugin();
    try {
      final a = await d.androidInfo;
      final manuf = a.manufacturer;
      final model = a.model;
      final combo = '$manuf $model'.trim();
      return combo.isEmpty ? 'Android' : combo;
    } catch (_) {
      try {
        final i = await d.iosInfo;
        final machine = i.utsname.machine; // already a String
        return (machine?.trim().isEmpty ?? true) ? 'iOS' : machine!;
      } catch (_) {
        return 'Unknown Device';
      }
    }
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final acc = await _signIn.signInSilently();
    if (acc == null) return null;
    return AppUser(
      id: acc.id,
      displayName: acc.displayName ?? acc.email,
      email: acc.email,
    );
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    final acc = await _signIn.signIn();
    if (acc == null) return null;
    final user = AppUser(
      id: acc.id,
      displayName: acc.displayName ?? acc.email,
      email: acc.email,
    );
    final device = await _deviceName();
    await SheetsLogger.logSignup(user, device);
    return user;
  }

  @override
  Future<void> signOut() async {
    try {
      await _signIn.disconnect();
    } catch (_) {
      await _signIn.signOut();
    }
  }
}
