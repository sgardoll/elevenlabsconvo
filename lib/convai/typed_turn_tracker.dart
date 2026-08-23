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
///   fallback bubble was appended; a LATE matching transcript must then be
///   suppressed instead of producing a duplicate bubble.
/// - any state -> `discarded`: the send failed (timeout / transport error);
///   no fallback is appended and the turn leaves the pending set.
///
/// Settlement is terminal by construction: once a turn leaves `pending`,
/// later events referencing it are no-ops. Settled turns are pruned from the
/// pending set immediately; only the trimmed texts of fallback-settled turns
/// are briefly retained (bounded by [maxRetainedFallbackTexts]) to recognize
/// late transcripts, keeping memory flat over long sessions.
class TypedTurnTracker {
  TypedTurnTracker({this.maxRetainedFallbackTexts = 32});

  /// Upper bound on retained fallback-settled texts. Transcripts arrive
  /// within seconds of their responses in practice; the cap exists purely so
  /// a pathological session cannot grow this without bound.
  final int maxRetainedFallbackTexts;

  final List<TypedTurn> _pending = <TypedTurn>[];
  final List<String> _fallbackSettledTexts = <String>[];

  /// Turns still awaiting either settlement path.
  int get pendingCount => _pending.length;

  /// Retained fallback-settled texts awaiting possible late transcripts.
  int get retainedFallbackTextCount => _fallbackSettledTexts.length;

  /// Registers a typed send so its user-side echo can be matched against the
  /// locally submitted text.
  TypedTurn registerTypedTurn(String text) {
    final turn = TypedTurn._(text);
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
    // Late transcript for a fallback-settled turn: the bubble already exists.
    if (_fallbackSettledTexts.remove(echoedText)) {
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
    _fallbackSettledTexts.add(turn.text);
    while (_fallbackSettledTexts.length > maxRetainedFallbackTexts) {
      _fallbackSettledTexts.removeAt(0);
    }
    return true;
  }

  /// Marks [turn] as failed so neither settlement path can act on it.
  void discardTypedTurn(TypedTurn turn) {
    if (turn._settlement != TypedTurnSettlement.pending) return;
    _pending.remove(turn);
    turn._settlement = TypedTurnSettlement.discarded;
  }
}

/// One typed send tracked from registration until terminal settlement.
class TypedTurn {
  TypedTurn._(this.text);

  /// The locally submitted text, as it should appear in the transcript.
  final String text;

  TypedTurnSettlement _settlement = TypedTurnSettlement.pending;
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
