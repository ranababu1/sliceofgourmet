import 'package:flutter/foundation.dart';

/// iOS OAuth client ID, e.g. 1234-abcd.apps.googleusercontent.com.
/// Supplied at build time, never hardcoded:
///   --dart-define=GOOGLE_IOS_CLIENT_ID=...
/// The reversed form must also be set as GOOGLE_REVERSED_CLIENT_ID in
/// ios/Flutter/GoogleSignIn.xcconfig (see RELEASE.md).
const String kGoogleIosClientId =
    String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

/// Whether Google sign-in can run on this platform.
///
/// Android needs no client ID in code; Google matches the package name and
/// signing SHA-1 against an Android OAuth client. On iOS the Google SDK
/// crashes the app when no client ID or URL scheme is set, so sign-in stays
/// off until [kGoogleIosClientId] is provided. When it is off, nothing in the
/// app is gated behind sign-in.
bool googleSignInAvailable({TargetPlatform? platform, String? iosClientId}) {
  if (kIsWeb) return false;
  switch (platform ?? defaultTargetPlatform) {
    case TargetPlatform.android:
      return true;
    case TargetPlatform.iOS:
      return (iosClientId ?? kGoogleIosClientId).trim().isNotEmpty;
    default:
      return false;
  }
}
