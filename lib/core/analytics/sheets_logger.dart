import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/app_user.dart';
import '../constants.dart';
import 'consent.dart';

/// Logs a user's first signup to a Google Sheets Apps Script webhook.
/// No-op unless: a webhook URL is configured, the user consented, and this
/// user has not been logged before on this device.
class SheetsLogger {
  SheetsLogger({
    http.Client? client,
    this.url = kSheetsWebhookUrl,
    this.secret = kSheetsWebhookSecret,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String url;
  final String secret;

  static String loggedFlagKey(String userId) => 'signup_logged_$userId';

  /// Returns true if a log was successfully sent.
  Future<bool> logSignupIfNeeded(AppUser user, String deviceName) async {
    if (url.trim().isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(kAnalyticsConsentKey) ?? false)) return false;
    final flag = loggedFlagKey(user.id);
    if (prefs.getBool(flag) ?? false) return false;

    final body = {
      'secret': secret,
      'name': user.displayName,
      'email': user.email,
      'date': DateTime.now().toIso8601String(),
      'device': deviceName,
      'event': 'signup',
    };
    try {
      final res = await _client
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              if (secret.isNotEmpty) 'X-Webhook-Secret': secret,
            },
            body: jsonEncode(body),
          )
          .timeout(kHttpTimeout);
      // Apps Script answers POST with a 302 to the result page; treat <400 as ok.
      if (res.statusCode < 400) {
        await prefs.setBool(flag, true);
        return true;
      }
    } catch (_) {
      // never crash the app because logging failed; retried on next sign-in
    }
    return false;
  }
}
