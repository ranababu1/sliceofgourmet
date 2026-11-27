import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'display_name.dart';

const String kDisplayNameKey = 'display_name';
const String kNamePromptShownKey = 'name_prompt_shown';

class NameState {
  const NameState({
    this.raw = '',
    this.loaded = false,
    this.promptShown = false,
  });

  final String raw;
  final bool loaded;
  final bool promptShown;

  String? get firstName => firstNameOf(raw);
  bool get hasName => firstName != null;

  NameState copyWith({String? raw, bool? loaded, bool? promptShown}) =>
      NameState(
        raw: raw ?? this.raw,
        loaded: loaded ?? this.loaded,
        promptShown: promptShown ?? this.promptShown,
      );
}

class NameController extends StateNotifier<NameState> {
  NameController() : super(const NameState()) {
    _load();
  }

  Future<void>? _loading;

  Future<void> ensureLoaded() => _loading ?? _load();

  Future<void> _load() {
    return _loading = () async {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      state = NameState(
        raw: prefs.getString(kDisplayNameKey) ?? '',
        loaded: true,
        promptShown: prefs.getBool(kNamePromptShownKey) ?? false,
      );
    }();
  }

  Future<void> setName(String raw) async {
    final value = raw.trim();
    final prefs = await SharedPreferences.getInstance();
    if (value.isEmpty) {
      await prefs.remove(kDisplayNameKey);
    } else {
      await prefs.setString(kDisplayNameKey, value);
    }
    await prefs.setBool(kNamePromptShownKey, true);
    if (!mounted) return;
    state = state.copyWith(raw: value, loaded: true, promptShown: true);
  }

  Future<void> clear() => setName('');

  Future<void> markPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kNamePromptShownKey, true);
    if (!mounted) return;
    state = state.copyWith(promptShown: true, loaded: true);
  }
}

final nameControllerProvider =
    StateNotifierProvider<NameController, NameState>((ref) => NameController());
