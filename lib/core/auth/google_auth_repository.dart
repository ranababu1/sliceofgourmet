import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app_user.dart';
import 'auth_config.dart';
import 'auth_repository.dart';
import '../analytics/sheets_logger.dart';

class GoogleAuthRepository implements AuthRepository {
  GoogleAuthRepository(
      {GoogleSignIn? signIn, SheetsLogger? logger, bool? available})
      : isAvailable = available ?? googleSignInAvailable(),
        _signInOverride = signIn,
        _logger = logger ?? SheetsLogger();

  @override
  final bool isAvailable;

  final GoogleSignIn? _signInOverride;
  final SheetsLogger _logger;

  static const unavailableMessage =
      'Google sign-in is not available in this version yet.';

  // Created lazily so nothing touches the native SDK when sign-in is off.
  late final GoogleSignIn _signIn = _signInOverride ??
      GoogleSignIn(
        scopes: const <String>['email'],
        clientId: defaultTargetPlatform == TargetPlatform.iOS &&
                kGoogleIosClientId.isNotEmpty
            ? kGoogleIosClientId
            : null,
      );

  Future<String> _deviceName() async {
    final d = DeviceInfoPlugin();
    try {
      final a = await d.androidInfo;
      final combo = '${a.manufacturer} ${a.model}'.trim();
      return combo.isEmpty ? 'Android' : combo;
    } catch (_) {
      try {
        final m = (await d.iosInfo).utsname.machine.trim();
        return m.isEmpty ? 'iOS' : m;
      } catch (_) {
        return 'Unknown Device';
      }
    }
  }

  AppUser _toUser(GoogleSignInAccount acc) => AppUser(
        id: acc.id,
        displayName: acc.displayName ?? acc.email,
        email: acc.email,
        photoUrl: acc.photoUrl,
      );

  @override
  Future<AppUser?> getCurrentUser() async {
    if (!isAvailable) return null;
    try {
      final acc = await _signIn.signInSilently();
      return acc == null ? null : _toUser(acc);
    } catch (_) {
      return null;
    }
  }

  /// Maps google_sign_in errors to a friendly message, or null for cancel.
  static String? messageFor(PlatformException e) {
    switch (e.code) {
      case GoogleSignIn.kSignInCanceledError:
        return null;
      case GoogleSignIn.kNetworkError:
        return 'No internet connection. Please try again.';
      case GoogleSignIn.kSignInFailedError:
        // usually ApiException 10: OAuth client / SHA-1 not configured
        return 'Google sign-in is not available right now (configuration error).';
      default:
        return 'Sign-in failed. Please try again.';
    }
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    if (!isAvailable) throw const AuthException(unavailableMessage);
    GoogleSignInAccount? acc;
    try {
      acc = await _signIn.signIn();
    } on PlatformException catch (e) {
      final msg = messageFor(e);
      if (msg == null) return null;
      throw AuthException(msg);
    } catch (_) {
      throw const AuthException('Sign-in failed. Please try again.');
    }
    if (acc == null) return null;
    final user = _toUser(acc);
    try {
      await _logger.logSignupIfNeeded(user, await _deviceName());
    } catch (_) {}
    return user;
  }

  @override
  Future<void> signOut() async {
    if (!isAvailable) return;
    try {
      await _signIn.signOut();
    } catch (_) {}
  }
}
