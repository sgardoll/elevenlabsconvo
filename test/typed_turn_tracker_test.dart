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

  group('TypedTurnTracker suppression lifetime (age-bounded)', () {
    test('late transcript stays suppressed across an intervening turn '
        '(Greptile round-5 repro)', () {
      final tracker = TypedTurnTracker();
      final first = tracker.registerTypedTurn('hello');
      // Response-first ordering leaves a suppression record behind.
      expect(tracker.settleTypedTurn(first), isTrue);
      expect(tracker.retainedFallbackTextCount, 1);

      // The user sends a DIFFERENT message before turn one's transcript
      // lands. Registering it must not drop turn one's record.
      final second = tracker.registerTypedTurn('how are you');
      expect(tracker.retainedFallbackTextCount, 1,
          reason: 'Registration ages records; it must not wipe them.');

      // Turn one's late transcript arrives: suppressed (bubble already
      // exists), and turn two settles normally via its own echo.
      expect(tracker.noteUserTranscript('hello'), isFalse,
          reason: 'Late echo of a fallback-settled turn must not duplicate.');
      expect(tracker.noteUserTranscript('how are you'), isTrue);
      expect(tracker.settleTypedTurn(second), isFalse,
          reason: 'Echo path already settled turn two.');
    });

    test('a genuinely new identical send still gets its own bubble', () {
      final tracker = TypedTurnTracker();
      final first = tracker.registerTypedTurn('hello');
      expect(tracker.settleTypedTurn(first), isTrue);

      // Same text sent again while the old record lives: the live pending
      // turn wins over suppression, so its echo appends normally.
      final second = tracker.registerTypedTurn('hello');
      expect(tracker.noteUserTranscript('hello'), isTrue);
      expect(tracker.settleTypedTurn(second), isFalse,
          reason: 'Echo path already settled the new send.');
      expect(tracker.noteUserTranscript('hello'), isFalse,
          reason: 'First fallback record suppresses its own late echo.');
      expect(tracker.retainedFallbackTextCount, 0);
    });

    test('suppression never crosses teardown / new-conversation boundaries',
        () {
      final tracker = TypedTurnTracker();
      final turn = tracker.registerTypedTurn('hello');
      expect(tracker.settleTypedTurn(turn), isTrue);
      expect(tracker.retainedFallbackTextCount, 1);

      // ConvAiService calls clear() on teardown/disconnect and on
      // new-conversation initialization.
      tracker.clear();

      expect(tracker.pendingCount, 0);
      expect(tracker.retainedFallbackTextCount, 0);
      expect(tracker.noteUserTranscript('hello'), isTrue,
          reason: 'A fresh session must never inherit suppression.');
    });

    test('records expire once older than maxSuppressionAgeTicks', () {
      final tracker = TypedTurnTracker(maxSuppressionAgeTicks: 2);
      final turn = tracker.registerTypedTurn('hello');
      expect(tracker.settleTypedTurn(turn), isTrue);
      // Same tick as registration: the late echo is still suppressed.
      expect(tracker.noteUserTranscript('hello'), isFalse);

      // Re-arm a record, then age it out with subsequent registrations.
      final armed = tracker.registerTypedTurn('stale');
      expect(tracker.settleTypedTurn(armed), isTrue);
      tracker.registerTypedTurn('intervening 1');
      tracker.registerTypedTurn('intervening 2');
      expect(tracker.noteUserTranscript('stale'), isTrue,
          reason: 'Aged-out records must stop suppressing phrases.');
    });
  });

  group('TypedTurnTracker long-session pruning', () {
    test('settled turns drain from the pending set and suppression drains '
        'every turn cycle', () {
      final tracker = TypedTurnTracker();

      const sessionLength = 500;
      var peakPending = 0;
      for (var i = 0; i < sessionLength; i++) {
        final turn = tracker.registerTypedTurn('turn $i');
        // Measured before settlement: accumulation across iterations would
        // push this above 1.
        peakPending =
            peakPending > tracker.pendingCount ? peakPending : tracker
                .pendingCount;
        // Registration ages records instead of wiping them: retained texts
        // stay within the burst cap until their ticks run out.
        expect(tracker.retainedFallbackTextCount <= 2, isTrue,
            reason: 'Aging + the retention cap bound retained records.');
        if (i.isEven) {
          // Response-first ordering leaves one suppression record behind...
          expect(tracker.settleTypedTurn(turn), isTrue);
          expect(tracker.retainedFallbackTextCount <= 2, isTrue,
              reason: 'Records from the last two turns may still be alive.');
        } else {
          // ...and transcript-first ordering creates none. The record from
          // the previous even turn is still within its age window here.
          expect(tracker.noteUserTranscript('turn $i'), isTrue);
          expect(tracker.settleTypedTurn(turn), isFalse);
        }
      }

      expect(peakPending, 1,
          reason: 'Each turn must be pruned as soon as it settles.');
      expect(tracker.pendingCount, 0);
      // Records from the final turns are still inside their age window.
      expect(tracker.retainedFallbackTextCount <= 2, isTrue);
      // A few more registrations age every record out without clear().
      for (var i = 0; i < 5; i++) {
        tracker.registerTypedTurn('drain $i');
      }
      expect(tracker.retainedFallbackTextCount, 0,
          reason: 'Aged records drain without explicit clearing.');
    });

    test('same-cycle settlement bursts stay capped, then age out', () {
      const retentionCap = 3;
      final tracker = TypedTurnTracker(
        maxRetainedFallbackTexts: retentionCap,
        maxSuppressionAgeTicks: 1,
      );

      // Concurrent sends all register before any settles: their records
      // accumulate within ONE turn cycle and hit the cap.
      final turns = List.generate(
        retentionCap + 2,
        (i) => tracker.registerTypedTurn('burst $i'),
      );
      for (final turn in turns) {
        expect(tracker.settleTypedTurn(turn), isTrue);
      }
      expect(tracker.retainedFallbackTextCount, retentionCap,
          reason: 'Bursts must stay bounded by the retention cap.');

      // Records age out once they outlive their tick window.
      tracker.registerTypedTurn('after the burst');
      expect(tracker.retainedFallbackTextCount, 0);
    });
  });
}
