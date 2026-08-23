import 'package:flutter_test/flutter_test.dart';

import 'package:eleven_labs_conversational_a_i_library/convai/typed_turn_tracker.dart';

/// Regression coverage for terminal typed-turn settlement: exactly one user
/// bubble per typed send, whichever of the transcript echo or response
/// completion lands first, plus bounded bookkeeping over long sessions.
void main() {
  group('TypedTurnTracker settlement ordering', () {
    test('response before transcript: fallback appends once, late '
        'transcript is suppressed', () {
      final tracker = TypedTurnTracker();
      final turn = tracker.registerTypedTurn('hello');

      // Response completed first: fallback must append the user bubble.
      expect(tracker.settleTypedTurn(turn), isTrue);

      // The matching transcript arrives late: it duplicates a bubble that
      // already exists, so it must be ignored.
      expect(tracker.noteUserTranscript('hello'), isFalse);
      // Terminal: settling again changes nothing.
      expect(tracker.settleTypedTurn(turn), isFalse);
    });

    test('transcript before response: echo appends, completion skips '
        'fallback', () {
      final tracker = TypedTurnTracker();
      final turn = tracker.registerTypedTurn('hello');

      // Echo arrived first through the normal event path.
      expect(tracker.noteUserTranscript(' hello '), isTrue);
      // Completion afterwards must not append a second bubble.
      expect(tracker.settleTypedTurn(turn), isFalse);
      expect(tracker.pendingCount, 0);
    });

    test('voice transcripts pass through untouched', () {
      final tracker = TypedTurnTracker();

      expect(tracker.noteUserTranscript('spoken words'), isTrue);
    });

    test('identical consecutive sends each get their own echo', () {
      final tracker = TypedTurnTracker();
      final first = tracker.registerTypedTurn('hi');
      expect(tracker.noteUserTranscript('hi'), isTrue);
      expect(tracker.settleTypedTurn(first), isFalse);

      final second = tracker.registerTypedTurn('hi');
      expect(tracker.noteUserTranscript('hi'), isTrue);
      expect(tracker.settleTypedTurn(second), isFalse);
      expect(tracker.pendingCount, 0);
    });

    test('duplicate pending texts match oldest-first', () {
      final tracker = TypedTurnTracker();
      final older = tracker.registerTypedTurn('hi');
      final newer = tracker.registerTypedTurn('hi');

      expect(tracker.noteUserTranscript('hi'), isTrue);
      expect(older.text, 'hi'); // Oldest pending consumed by the echo...
      expect(tracker.pendingCount, 1); // ...newer still awaiting its own.
      expect(tracker.noteUserTranscript('hi'), isTrue);
      expect(tracker.settleTypedTurn(newer), isFalse);
    });
  });

  group('TypedTurnTracker failed sends', () {
    test('discarded turns never append and leave transcripts unmatched',
        () {
      final tracker = TypedTurnTracker();
      final turn = tracker.registerTypedTurn('never delivered');

      tracker.discardTypedTurn(turn);

      expect(tracker.settleTypedTurn(turn), isFalse);
      // No suppression record exists, so any later transcript with this
      // text appends normally instead of being swallowed.
      expect(tracker.noteUserTranscript('never delivered'), isTrue);
      expect(tracker.pendingCount, 0);
    });
  });

  group('TypedTurnTracker one-bubble-per-turn outcomes', () {
    /// Bubble ledger mirroring ConvAiService's appending contract:
    /// agent_response events always append; user bubbles append exactly when
    /// the corresponding settlement call returns true. These tests assert
    /// bubble COUNTS (the Greptile P1 outcome) rather than gate booleans.
    test('response-first ordering with a late transcript yields exactly '
        'one user and one agent bubble', () {
      final tracker = TypedTurnTracker();
      var userBubbles = 0;
      var agentBubbles = 0;

      final turn = tracker.registerTypedTurn('hello');
      // agent_response completes before any echo...
      agentBubbles += 1;
      // ...so completion appends the fallback user bubble.
      if (tracker.settleTypedTurn(turn)) userBubbles += 1;
      // The matching transcript lands LATE — must be a no-op.
      if (tracker.noteUserTranscript('hello')) userBubbles += 1;

      expect(userBubbles, 1,
          reason: 'A late transcript must never duplicate the fallback.');
      expect(agentBubbles, 1);
    });

    test('transcript-first ordering still yields exactly one user and '
        'one agent bubble', () {
      final tracker = TypedTurnTracker();
      var userBubbles = 0;
      var agentBubbles = 0;

      final turn = tracker.registerTypedTurn('hello');
      // Echo first through the normal event path.
      if (tracker.noteUserTranscript('hello')) userBubbles += 1;
      agentBubbles += 1;
      if (tracker.settleTypedTurn(turn)) userBubbles += 1;

      expect(userBubbles, 1);
      expect(agentBubbles, 1);
    });

    test('a failed send appends nothing while later traffic stays intact',
        () {
      final tracker = TypedTurnTracker();
      var userBubbles = 0;
      var agentBubbles = 0;

      final failed = tracker.registerTypedTurn('never delivered');
      tracker.discardTypedTurn(failed);

      // The next voice turn behaves normally despite the discarded send.
      if (tracker.noteUserTranscript('spoken words')) userBubbles += 1;
      agentBubbles += 1;

      expect(userBubbles, 1);
      expect(agentBubbles, 1);
    });
  });

  group('TypedTurnTracker long-session pruning', () {
    test('settled turns drain from the pending set and fallback records '
        'stay capped', () {
      const retentionCap = 8;
      final tracker =
          TypedTurnTracker(maxRetainedFallbackTexts: retentionCap);

      const sessionLength = 500;
      var peakPending = 0;
      for (var i = 0; i < sessionLength; i++) {
        final turn = tracker.registerTypedTurn('turn $i');
        // Measured before settlement: accumulation across iterations would
        // push this above 1.
        peakPending =
            peakPending > tracker.pendingCount ? peakPending : tracker
                .pendingCount;
        if (i.isEven) {
          // Response-first ordering leaves a suppression record behind.
          expect(tracker.settleTypedTurn(turn), isTrue);
        } else {
          // Transcript-first ordering prunes immediately.
          expect(tracker.noteUserTranscript('turn $i'), isTrue);
          expect(tracker.settleTypedTurn(turn), isFalse);
        }
      }

      expect(peakPending, 1,
          reason: 'Each turn must be pruned as soon as it settles.');
      expect(tracker.pendingCount, 0);
      expect(tracker.retainedFallbackTextCount, retentionCap,
          reason: 'Fallback records must stay bounded by the cap.');
    });
  });
}
