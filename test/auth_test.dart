import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliceofgourmet/core/auth/auth_config.dart';
import 'package:sliceofgourmet/core/auth/auth_repository.dart';
import 'package:sliceofgourmet/core/auth/google_auth_repository.dart';

void main() {
  test('iOS sign-in needs a client ID, Android does not', () {
    expect(googleSignInAvailable(platform: TargetPlatform.iOS, iosClientId: ''),
        isFalse);
    expect(
        googleSignInAvailable(
            platform: TargetPlatform.iOS,
            iosClientId: '123-abc.apps.googleusercontent.com'),
        isTrue);
    expect(googleSignInAvailable(platform: TargetPlatform.android), isTrue);
    expect(googleSignInAvailable(platform: TargetPlatform.linux), isFalse);
  });

  test('unavailable repository never calls the native SDK', () async {
    final repo = GoogleAuthRepository(available: false);
    expect(repo.isAvailable, isFalse);
    expect(await repo.getCurrentUser(), isNull);
    await repo.signOut();
    await expectLater(
        repo.signInWithGoogle(),
        throwsA(isA<AuthException>().having((e) => e.message, 'message',
            GoogleAuthRepository.unavailableMessage)));
  });
}
