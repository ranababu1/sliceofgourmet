import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../auth/app_user.dart';

class SheetsLogger {
  static Future<void> logSignup(AppUser user, String deviceName) async {
    if (kSheetsWebhookUrl
        .startsWith('https://script.google.com/macros/s/REPLACE')) {
      // developer has not configured webhook yet, skip silently
      return;
    }
    final nowIso = DateTime.now().toIso8601String();
    final body = {
      'name': user.displayName,
      'email': user.email,
      'date': nowIso,
      'device': deviceName,
      'event': 'signup',
    };
    try {
      await http.post(
        Uri.parse(kSheetsWebhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (_) {
      // do not crash app if logging fails
    }
  }
}
