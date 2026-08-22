/// Persistence for the local ConvAI session UUID.
///
/// The session id survives app restarts so a resumed conversation can be
/// correlated with its original session ("session ID persists" acceptance
/// criterion). Implementations must be cheap to construct and safe to call
/// from the UI isolate.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Storage contract for the local session id. Injectable so hosts can swap in
/// their own persistence (secure storage, backend sync) without touching the
/// client.
abstract interface class ConvAiSessionStore {
  /// Returns the persisted session id, or `null` when none exists yet.
  Future<String?> loadSessionId();

  /// Persists [sessionId], replacing any previous value.
  Future<void> saveSessionId(String sessionId);

  /// Removes the persisted session id.
  Future<void> clearSessionId();
}

/// [ConvAiSessionStore] backed by `shared_preferences`.
class SharedPreferencesConvAiSessionStore implements ConvAiSessionStore {
  static const String _storageKey = 'convai_session_id';

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
}
