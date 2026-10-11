import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/db/app_database.dart';
import '../data/session_repository.dart';
import '../data/settings_repository.dart';
import '../domain/models/player.dart';
import '../domain/models/round.dart';
import '../domain/models/rule_set.dart';
import '../domain/models/session.dart';

/// Được override trong main() sau khi mở DB / prefs.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('override in main'),
);
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('override in main'),
);

final sessionRepoProvider = Provider(
  (ref) => SessionRepository(ref.watch(databaseProvider)),
);
final settingsRepoProvider = Provider(
  (ref) => SettingsRepository(
    ref.watch(databaseProvider),
    ref.watch(sharedPrefsProvider),
  ),
);

// ---------- Prefs ----------

class PrefsNotifier extends Notifier<AppPrefs> {
  @override
  AppPrefs build() => ref.watch(settingsRepoProvider).loadPrefs();

  Future<void> update(AppPrefs Function(AppPrefs p) change) async {
    state = change(state);
    await ref.read(settingsRepoProvider).savePrefs(state);
  }

  void reload() => state = ref.read(settingsRepoProvider).loadPrefs();
}

final prefsProvider = NotifierProvider<PrefsNotifier, AppPrefs>(
  PrefsNotifier.new,
);

/// Rung nhẹ nếu người dùng bật.
void haptic(WidgetRef ref) {
  if (ref.read(prefsProvider).haptics) HapticFeedback.lightImpact();
}

// ---------- Lists ----------

final sessionsProvider = FutureProvider<List<GameSession>>(
  (ref) => ref.watch(sessionRepoProvider).listSessions(),
);

final groupsProvider = FutureProvider<List<PlayerGroup>>(
  (ref) => ref.watch(settingsRepoProvider).listGroups(),
);

final rulesProvider = FutureProvider<List<RuleSet>>(
  (ref) => ref.watch(settingsRepoProvider).listRules(),
);

// ---------- One session ----------

class SessionData {
  const SessionData(this.session, this.rounds);
  final GameSession session;

  /// Sắp theo thứ tự tạo (idx tăng dần).
  final List<GameRound> rounds;

  /// Số thứ tự hiển thị "Ván N" (1-based theo vị trí hiện tại).
  int numberOf(GameRound r) => rounds.indexWhere((x) => x.id == r.id) + 1;
}

class SessionController extends AsyncNotifier<SessionData> {
  SessionController(this.sessionId);
  final int sessionId;

  SessionRepository get _repo => ref.read(sessionRepoProvider);

  @override
  Future<SessionData> build() => _load();

  Future<SessionData> _load() async {
    final s = await _repo.getSession(sessionId);
    if (s == null) throw StateError('Lần chơi không còn tồn tại');
    return SessionData(s, await _repo.getRounds(sessionId));
  }

  Future<void> _refresh() async {
    final data = await _load();
    if (ref.mounted) state = AsyncData(data);
    ref.invalidate(sessionsProvider);
  }

  Future<GameRound> addRound(GameRound r) async {
    final saved = await _repo.addRound(r);
    await _refresh();
    return saved;
  }

  Future<void> updateRound(GameRound r) async {
    await _repo.updateRound(r);
    await _refresh();
  }

  Future<void> deleteRound(GameRound r) async {
    await _repo.deleteRound(r);
    await _refresh();
  }

  Future<void> restoreRound(GameRound r) async {
    await _repo.restoreRound(r);
    await _refresh();
  }

  Future<void> updateSession(GameSession s) async {
    await _repo.updateSessionMeta(s);
    await _refresh();
  }
}

final sessionProvider = AsyncNotifierProvider.autoDispose
    .family<SessionController, SessionData, int>(SessionController.new);
