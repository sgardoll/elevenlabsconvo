/// Terminal typed-turn settlement state machine.
///
/// A typed send registers one [TypedTurn] so its user-side echo can be
/// reconciled with exactly one chat bubble, whichever of the two protocol
/// paths lands first:
///
/// - `pending -> settledByTranscript`: a `user_transcript` matched before
///   the response completed; the echo already appended the bubble, so the
///   completion path skips its fallback append.
/// - `pending -> settledWithFallback`: the response completed first and the
///   fallback bubble was appended; a LATE transcript must then be suppressed
///   instead of producing a duplicate bubble.
/// - any state -> `discarded`: the send failed (timeout / transport error);
///   no fallback is appended and the turn leaves the pending set.
///
/// Settlement is terminal by construction: once a turn leaves `pending`,
/// later events referencing it are no-ops.
///
/// SUPPRESSION IS TURN-CYCLE SCOPED, never session-scoped. A fallback-
/// settled text is retained only until the NEXT turn cycle begins
/// ([registerTypedTurn]), the tracker is cleared ([clear] — called on
/// teardown/disconnect and new-conversation initialization), or its record
/// ages past [maxSuppressionAgeTicks] turns (monotonic tick). A later
/// identical phrase — in the same session or a brand-new one — therefore
/// always appends its own bubble instead of being wrongly swallowed.
class TypedTurnTracker {
  TypedTurnTracker({
    this.maxRetainedFallbackTexts = 32,
    this.maxSuppressionAgeTicks = 4,
  });

  /// Upper bound on retained fallback-settled texts within a single turn
  /// cycle. Concurrent sends can settle before the next registration, so the
  /// cap keeps that burst bounded; normal cycles drain to zero anyway.
  final int maxRetainedFallbackTexts;

  /// How many turn registrations a suppression record may outlive before it
  /// expires. Belt-and-braces alongside cycle clearing: a record can never
  /// suppress a phrase sent more than this many turns after its own.
  final int maxSuppressionAgeTicks;

  /// Monotonic counter bumped by every [registerTypedTurn]; ages records
  /// deterministically without wall-clock dependence.
  int _tick = 0;

  final List<TypedTurn> _pending = <TypedTurn>[];
  final List<_SuppressionRecord> _suppressions = <_SuppressionRecord>[];

  /// Turns still awaiting either settlement path.
  int get pendingCount => _pending.length;

  /// Retained fallback-settled texts awaiting possible late transcripts.
  int get retainedFallbackTextCount => _suppressions.length;

  /// Registers a typed send and opens a fresh turn cycle.
  ///
  /// Opening a cycle discards every suppression record from earlier cycles:
  /// those phrases already have their bubbles, and letting their records
  /// persist would swallow a later identical phrase.
  TypedTurn registerTypedTurn(String text) {
    _suppressions.clear();
    _tick += 1;
    final turn = TypedTurn._(text, registeredAtTick: _tick);
    _pending.add(turn);
    return turn;
  }

  /// Reconciles an incoming `user_transcript` with registered turns.
  ///
  /// Returns true when the transcript should append its chat bubble through
  /// the normal event path, false when it duplicates a turn whose bubble the
  /// completion fallback already produced.
  bool noteUserTranscript(String transcriptText) {
    final echoedText = transcriptText.trim();
    // A live pending turn wins over suppression records: its echo settles it
    // normally even if an older fallback-settled turn shares the same text.
    for (var i = 0; i < _pending.length; i++) {
      final turn = _pending[i];
      if (turn.text == echoedText) {
        _pending.removeAt(i);
        turn._settlement = TypedTurnSettlement.settledByTranscript;
        return true;
      }
    }
    _expireAgedSuppressions();
    // Late transcript for a fallback-settled turn: the bubble already exists.
    final match = _suppressions.indexWhere((record) =>
        record.text == echoedText);
    if (match != -1) {
      _suppressions.removeAt(match);
      return false;
    }
    // Voice input or a transcript unrelated to any typed send.
    return true;
  }

  /// Settles [turn] when its send completed successfully.
  ///
  /// Returns true when the caller must append the fallback user bubble
  /// (no transcript echo settled the turn first), false otherwise. Terminal:
  /// settling an already-settled or discarded turn is a no-op returning
  /// false.
  bool settleTypedTurn(TypedTurn turn) {
    if (turn._settlement != TypedTurnSettlement.pending) return false;
    _pending.remove(turn);
    turn._settlement = TypedTurnSettlement.settledWithFallback;
    _suppressions.add(
      _SuppressionRecord(turn.text, registeredAtTick: turn.registeredAtTick),
    );
    while (_suppressions.length > maxRetainedFallbackTexts) {
      _suppressions.removeAt(0);
    }
    return true;
  }

  /// Marks [turn] as failed so neither settlement path can act on it.
  void discardTypedTurn(TypedTurn turn) {
    if (turn._settlement != TypedTurnSettlement.pending) return;
    _pending.remove(turn);
    turn._settlement = TypedTurnSettlement.discarded;
  }

  /// Drops ALL state — pending turns and suppression records alike.
  ///
  /// The owning service calls this on teardown/disconnect and on
  /// new-conversation initialization so suppression never crosses a session
  /// boundary.
  void clear() {
    _pending.clear();
    _suppressions.clear();
  }

  void _expireAgedSuppressions() {
    _suppressions.removeWhere(
      (record) => _tick - record.registeredAtTick >= maxSuppressionAgeTicks,
    );
  }
}

/// One typed send tracked from registration until terminal settlement.
class TypedTurn {
  TypedTurn._(this.text, {required this.registeredAtTick});

  /// The locally submitted text, as it should appear in the transcript.
  final String text;

  /// Monotonic tick at which this phrase was registered; ages any
  /// suppression record derived from it.
  final int registeredAtTick;

  TypedTurnSettlement _settlement = TypedTurnSettlement.pending;
}

/// A fallback-settled phrase kept briefly to recognize late transcripts.
class _SuppressionRecord {
  const _SuppressionRecord(this.text, {required this.registeredAtTick});

  final String text;
  final int registeredAtTick;
}

/// Lifecycle of a typed send's user-side reconciliation.
enum TypedTurnSettlement {
  /// Awaiting either the transcript echo or the completion fallback.
  pending,

  /// A matching `user_transcript` arrived first and appended the bubble.
  settledByTranscript,

  /// Completion landed first; the fallback appended the bubble.
  settledWithFallback,

  /// The send failed; neither path may append.
  discarded,
}
