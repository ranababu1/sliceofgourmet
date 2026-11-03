import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliceofgourmet/core/analytics/consent.dart';
import 'package:sliceofgourmet/core/analytics/sheets_logger.dart';
import 'package:sliceofgourmet/core/auth/app_user.dart';

const user = AppUser(id: 'u1', displayName: 'Imran', email: 'i@example.com');

void main() {
  late List<http.Request> calls;
  late MockClient client;

  setUp(() {
    calls = [];
    client = MockClient((req) async {
      calls.add(req);
      return http.Response('ok', 200);
    });
  });

  test('no-op when webhook url is empty', () async {
    SharedPreferences.setMockInitialValues({kAnalyticsConsentKey: true});
    final logger = SheetsLogger(client: client, url: '', secret: 's');
    expect(await logger.logSignupIfNeeded(user, 'Pixel'), isFalse);
    expect(calls, isEmpty);
  });

  test('no-op without consent', () async {
    SharedPreferences.setMockInitialValues({});
    final logger =
        SheetsLogger(client: client, url: 'https://hook.test/exec', secret: 's');
    expect(await logger.logSignupIfNeeded(user, 'Pixel'), isFalse);
    expect(calls, isEmpty);
  });

  test('logs first signup once, with secret', () async {
    SharedPreferences.setMockInitialValues({kAnalyticsConsentKey: true});
    final logger = SheetsLogger(
        client: client, url: 'https://hook.test/exec', secret: 'shh');
    expect(await logger.logSignupIfNeeded(user, 'Pixel'), isTrue);
    expect(await logger.logSignupIfNeeded(user, 'Pixel'), isFalse);
    expect(calls, hasLength(1));
    final body = jsonDecode(calls.single.body) as Map;
    expect(body['secret'], 'shh');
    expect(body['email'], 'i@example.com');
    expect(calls.single.headers['X-Webhook-Secret'], 'shh');
  });

  test('failed post is retried next time', () async {
    SharedPreferences.setMockInitialValues({kAnalyticsConsentKey: true});
    var fail = true;
    final c = MockClient((req) async =>
        http.Response('', fail ? 500 : 200));
    final logger =
        SheetsLogger(client: c, url: 'https://hook.test/exec', secret: '');
    expect(await logger.logSignupIfNeeded(user, 'Pixel'), isFalse);
    fail = false;
    expect(await logger.logSignupIfNeeded(user, 'Pixel'), isTrue);
  });
}
