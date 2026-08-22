/// Turn budget for one ConvAI session: at most [ConvAiTurnRateLimiter.maxTurns]
/// user turns per logical session (default 50, per the "rate limiting
/// (max 50 turns/session)" acceptance criterion).
///
/// Pure and synchronous — the WebSocket client owns persistence of the count
/// via `ConvAiSessionStore`, so this class stays trivially unit-testable.
library;

/// Thrown when a send is attempted after the per-session turn budget is
/// exhausted. The message carries both counters so callers and users see
/// exactly where they stand.
class ConvAiRateLimitException implements Exception {
  final int turnsUsed;
  final int maxTurns;

  const ConvAiRateLimitException({required this.turnsUsed, required this.maxTurns});

  String get message =>
      'Session turn limit reached ($turnsUsed/$maxTurns turns). '
      'Start a new session to continue.';

  @override
  String toString() => 'ConvAiRateLimitException: $message';
}

/// Counts dispatched user turns against a fixed per-session budget.
///
/// A *turn* is one user-initiated exchange. Timeout retries of the same turn
/// do not consume extra budget — only new sends do.
class ConvAiTurnRateLimiter {
  ConvAiTurnRateLimiter({
    required this.maxTurns,
    int turnsUsed = 0,
  }) : _turnsUsed = turnsUsed;

  /// Hard cap on turns for the session.
  final int maxTurns;

  int _turnsUsed;

  /// Turns already consumed by this session.
  int get turnsUsed => _turnsUsed;

  /// Turns left before [ensureCanSend] starts throwing.
  int get remainingTurns => maxTurns - _turnsUsed;

  /// True once the budget is fully consumed.
  bool get isExhausted => remainingTurns <= 0;

  /// Throws [ConvAiRateLimitException] when no budget remains; returns
  /// silently otherwise.
  void ensureCanSend() {
    if (isExhausted) {
      throw ConvAiRateLimitException(turnsUsed: _turnsUsed, maxTurns: maxTurns);
    }
  }

  /// Consumes one turn. Call only after [ensureCanSend] passed.
  void recordTurn() {
    if (_turnsUsed < maxTurns) _turnsUsed += 1;
  }

  /// Restores a fresh budget (new logical session).
  void reset() {
    _turnsUsed = 0;
  }
}
