import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/recipes/providers.dart';
import '../cache/local_store.dart';
import 'recipe_sync.dart';

/// How often the user may ask for a refresh.
const kManualRefreshInterval = Duration(minutes: 15);

/// How stale the catalog may get before the app syncs on its own at launch
/// or resume. Nothing polls in the background.
const kAutoSyncInterval = Duration(hours: 6);

enum SyncPhase { idle, syncing, failed }

class SyncState {
  const SyncState({
    this.phase = SyncPhase.idle,
    this.done = 0,
    this.total = 0,
    this.hasCatalog = false,
    this.lastSyncedAt,
  });
  final SyncPhase phase;
  final int done;
  final int total;
  final bool hasCatalog;
  final DateTime? lastSyncedAt;

  bool get syncing => phase == SyncPhase.syncing;

  /// 0..1 for the first run progress bar, null when unknown.
  double? get progress => total > 0 ? (done / total).clamp(0.0, 1.0) : null;

  SyncState copyWith(
          {SyncPhase? phase,
          int? done,
          int? total,
          bool? hasCatalog,
          DateTime? lastSyncedAt}) =>
      SyncState(
        phase: phase ?? this.phase,
        done: done ?? this.done,
        total: total ?? this.total,
        hasCatalog: hasCatalog ?? this.hasCatalog,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      );
}

sealed class RefreshOutcome {
  const RefreshOutcome();
}

class RefreshDone extends RefreshOutcome {
  const RefreshDone(this.report);
  final SyncReport report;
}

class RefreshTooSoon extends RefreshOutcome {
  const RefreshTooSoon(this.wait);
  final Duration wait;
}

class RefreshFailed extends RefreshOutcome {
  const RefreshFailed();
}

class RefreshBusy extends RefreshOutcome {
  const RefreshBusy();
}

/// Friendly snackbar text for a refresh.
String refreshMessage(RefreshOutcome o) => switch (o) {
      RefreshDone(:final report) when !report.changed =>
        'You have the latest recipes.',
      RefreshDone(:final report) => _changes(report),
      RefreshTooSoon(:final wait) =>
        'You are up to date. You can refresh again in ${_mins(wait)}.',
      RefreshFailed() => 'Could not reach the site. Showing saved recipes.',
      RefreshBusy() => 'Already refreshing.',
    };

String _changes(SyncReport r) {
  final parts = <String>[
    if (r.added > 0) '${r.added} new',
    if (r.updated > 0) '${r.updated} updated',
    if (r.removed > 0) '${r.removed} removed',
  ];
  return 'Recipes refreshed: ${parts.join(', ')}.';
}

String _mins(Duration d) {
  final m = (d.inSeconds / 60).ceil();
  return m <= 1 ? '1 minute' : '$m minutes';
}

/// Backoff for automatic syncs after errors: 1, 2, 4 ... minutes, capped at
/// [kAutoSyncInterval], with +/-50% jitter so devices do not retry together.
Duration backoffFor(int failures, {Random? random}) {
  final base = Duration(minutes: 1 << min(failures, 9));
  final capped = base > kAutoSyncInterval ? kAutoSyncInterval : base;
  final jitter = 0.5 + (random ?? Random()).nextDouble();
  return Duration(seconds: (capped.inSeconds * jitter).round());
}

typedef Clock = DateTime Function();

final clockProvider = Provider<Clock>((ref) => DateTime.now);

final recipeSyncProvider = Provider<RecipeSync>((ref) =>
    RecipeSync(ref.read(sogApiProvider), ref.read(localStoreProvider)));

final syncControllerProvider =
    StateNotifierProvider<SyncController, SyncState>((ref) {
  return SyncController(ref);
});

class SyncController extends StateNotifier<SyncState> {
  SyncController(this._ref)
      : super(SyncState(
          hasCatalog: _ref.read(localStoreProvider).hasCatalog,
          lastSyncedAt: _ref.read(localStoreProvider).lastSyncedAt,
        ));

  final Ref _ref;
  Future<RefreshOutcome>? _running;

  LocalStore get _store => _ref.read(localStoreProvider);
  DateTime _now() => _ref.read(clockProvider)();

  /// Launch and resume: first run downloads the catalog, later launches do
  /// a cheap incremental sync at most every [kAutoSyncInterval].
  Future<void> autoSync() async {
    if (!_store.hasCatalog) {
      await _run();
      return;
    }
    final now = _now();
    final next = _store.nextAutoSyncAt;
    if (next != null && now.isBefore(next)) return;
    final last = _store.lastSyncedAt;
    if (last != null && now.difference(last) < kAutoSyncInterval) return;
    await _run(auto: true);
  }

  /// First run retry button. Not rate limited.
  Future<void> retryFirstRun() => _run();

  /// Refresh button and pull to refresh. At most once per
  /// [kManualRefreshInterval].
  Future<RefreshOutcome> refresh() async {
    if (_running != null) return const RefreshBusy();
    if (!_store.hasCatalog) return _run();
    final last = _store.lastManualRefreshAt;
    final now = _now();
    if (last != null) {
      final wait = kManualRefreshInterval - now.difference(last);
      if (wait > Duration.zero) return RefreshTooSoon(wait);
    }
    final out = await _run();
    if (out is RefreshDone) await _store.setLastManualRefreshAt(now);
    return out;
  }

  Future<RefreshOutcome> _run({bool auto = false}) {
    return _running ??= _sync(auto: auto).whenComplete(() => _running = null);
  }

  Future<RefreshOutcome> _sync({required bool auto}) async {
    final first = !_store.hasCatalog;
    state = state.copyWith(phase: SyncPhase.syncing, done: 0, total: 0);
    try {
      final report = await _ref.read(recipeSyncProvider).sync(
            onProgress: first
                ? (d, t) {
                    if (mounted) state = state.copyWith(done: d, total: t);
                  }
                : null,
          );
      final now = _now();
      await _store.setLastSyncedAt(now);
      await _store.setAutoSyncFailures(0);
      await _store.setNextAutoSyncAt(null);
      if (report.changed || first) _invalidate();
      if (mounted) {
        state = SyncState(hasCatalog: true, lastSyncedAt: now);
      }
      return RefreshDone(report);
    } catch (_) {
      final n = _store.autoSyncFailures + 1;
      await _store.setAutoSyncFailures(n);
      await _store.setNextAutoSyncAt(_now().add(backoffFor(n)));
      if (mounted) {
        state = state.copyWith(
            phase: SyncPhase.failed, hasCatalog: _store.hasCatalog);
      }
      return const RefreshFailed();
    }
  }

  void _invalidate() {
    for (final p in <ProviderBase<Object?>>[
      trendingRecipesProvider,
      latestRecipesProvider,
      categoriesProvider,
      bookmarkedRecipesProvider,
    ]) {
      if (_ref.exists(p)) _ref.invalidate(p);
    }
    // families: invalidate all members
    _ref.invalidate(categoryRecipesProvider);
    _ref.invalidate(recipeByIdProvider);
  }
}
