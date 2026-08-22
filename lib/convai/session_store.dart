/// Persistence for the local ConvAI session UUID and its turn budget.
///
/// The session id survives app restarts so a resumed conversation can be
/// correlated with its original session ("session ID persists" acceptance
/// criterion). The turn count persists alongside it so the per-session rate
/// limit (max 50 turns) holds across restarts too. Implementations must be
/// cheap to construct and safe to call from the UI isolate.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Storage contract for session-scoped state: the local session id and the
/// number of turns already spent in that logical session. Injectable so hosts
/// can swap in their own persistence (secure storage, backend sync) without
/// touching the client.
abstract interface class ConvAiSessionStore {
  /// Returns the persisted session id, or `null` when none exists yet.
  Future<String?> loadSessionId();

  /// Persists [sessionId], replacing any previous value.
  Future<void> saveSessionId(String sessionId);

  /// Removes the persisted session id AND resets the stored turn count —
  /// clearing a session starts a fresh budget.
  Future<void> clearSessionId();

  /// Turns already dispatched in the current logical session (0 when none).
  Future<int> loadTurnCount();

  /// Persists [count] turns for the current logical session.
  Future<void> saveTurnCount(int count);
}

/// [ConvAiSessionStore] backed by `shared_preferences`.
class SharedPreferencesConvAiSessionStore implements ConvAiSessionStore {
  static const String _storageKey = 'convai_session_id';
  static const String _turnCountKey = 'convai_session_turn_count';

  const SharedPreferencesConvAiSessionStore();

  @override
  Future<String?> loadSessionId() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_storageKey);
  }

  @override
  Future<void> saveSessionId(String sessionId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, sessionId);
  }

  @override
  Future<void> clearSessionId() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
    await preferences.remove(_turnCountKey);
  }

  @override
  Future<int> loadTurnCount() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_turnCountKey) ?? 0;
  }

  @override
  Future<void> saveTurnCount(int count) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_turnCountKey, count);
  }
}
