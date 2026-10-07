/// Persistence for the local ConvAI session UUID and per-conversation turn
/// budgets.
///
/// The session id survives app restarts so a resumed conversation can be
/// correlated with its original session ("session ID persists" acceptance
/// criterion). Turn counts persist keyed by conversation id so resuming the
/// SAME conversation keeps its spent budget while starting any NEW
/// conversation begins with a fresh one. Implementations must be cheap to
/// construct and safe to call from the UI isolate.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Storage contract for session-scoped state: the local session id and the
/// number of turns already spent in each conversation. Injectable so hosts
/// can swap in their own persistence (secure storage, backend sync) without
/// touching the client.
abstract interface class ConvAiSessionStore {
  /// Returns the persisted session id, or `null` when none exists yet.
  Future<String?> loadSessionId();

  /// Persists [sessionId], replacing any previous value.
  Future<void> saveSessionId(String sessionId);

  /// Removes the persisted session id.
  Future<void> clearSessionId();

  /// Turns already dispatched in [conversationId] (0 when none).
  Future<int> loadTurnCount(String conversationId);

  /// Persists [count] turns for [conversationId].
  Future<void> saveTurnCount(String conversationId, int count);
}

/// [ConvAiSessionStore] backed by `shared_preferences`.
class SharedPreferencesConvAiSessionStore implements ConvAiSessionStore {
  static const String _storageKey = 'convai_session_id';
  static const String _turnCountKeyPrefix = 'convai_conversation_turn_count_';

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
  }

  @override
  Future<int> loadTurnCount(String conversationId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_turnCountKeyFor(conversationId)) ?? 0;
  }

  @override
  Future<void> saveTurnCount(String conversationId, int count) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_turnCountKeyFor(conversationId), count);
  }

  static String _turnCountKeyFor(String conversationId) =>
      '$_turnCountKeyPrefix$conversationId';
}
