import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kAnalyticsConsentKey = 'analytics_consent';

/// Whether the user agreed to share name/email/device for signup analytics.
/// Defaults to false; nothing is logged until the user opts in.
class AnalyticsConsentNotifier extends StateNotifier<bool> {
  AnalyticsConsentNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) state = prefs.getBool(kAnalyticsConsentKey) ?? false;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kAnalyticsConsentKey, value);
  }
}

final analyticsConsentProvider =
    StateNotifierProvider<AnalyticsConsentNotifier, bool>(
  (ref) => AnalyticsConsentNotifier(),
);
