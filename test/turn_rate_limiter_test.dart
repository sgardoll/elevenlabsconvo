import 'package:flutter_test/flutter_test.dart';

import 'package:eleven_labs_conversational_a_i_library/convai/turn_rate_limiter.dart';

void main() {
  group('ConvAiTurnRateLimiter', () {
    test('starts with the full budget available', () {
      final limiter = ConvAiTurnRateLimiter(maxTurns: 50);

      expect(limiter.turnsUsed, 0);
      expect(limiter.remainingTurns, 50);
      expect(limiter.isExhausted, isFalse);
    });

    test('recordTurn consumes budget one at a time', () {
      final limiter = ConvAiTurnRateLimiter(maxTurns: 3);
      limiter.recordTurn();

      expect(limiter.turnsUsed, 1);
      expect(limiter.remainingTurns, 2);
    });

    test('ensureCanSend passes until the budget is exhausted', () {
      final limiter = ConvAiTurnRateLimiter(maxTurns: 2);
      limiter.recordTurn();
      limiter.recordTurn();

      expect(limiter.isExhausted, isTrue);
      expect(
        limiter.ensureCanSend,
        throwsA(isA<ConvAiRateLimitException>()),
      );
    });

    test('the rate-limit error names both counters', () {
      final limiter =
          ConvAiTurnRateLimiter(maxTurns: 50, turnsUsed: 50);

      try {
        limiter.ensureCanSend();
        fail('Expected ConvAiRateLimitException.');
      } on ConvAiRateLimitException catch (error) {
        expect(error.turnsUsed, 50);
        expect(error.maxTurns, 50);
        expect(error.message, contains('50/50'));
      }
    });

    test('a pre-seeded count restores a partially spent budget', () {
      final limiter =
          ConvAiTurnRateLimiter(maxTurns: 50, turnsUsed: 48);

      expect(limiter.remainingTurns, 2);
      limiter.recordTurn();
      limiter.recordTurn();
      expect(limiter.isExhausted, isTrue);
      expect(
        () => limiter.ensureCanSend(),
        throwsA(isA<ConvAiRateLimitException>()),
      );
    });

    test('a persisted count above the configured cap stays exhausted',
        () {
      final limiter =
          ConvAiTurnRateLimiter(maxTurns: 10, turnsUsed: 25);

      expect(limiter.remainingTurns, -15); // negative = long exhausted
      expect(limiter.isExhausted, isTrue);
      expect(
        () => limiter.ensureCanSend(),
        throwsA(isA<ConvAiRateLimitException>()),
      );
    });

    test('reset restores a fresh budget', () {
      final limiter =
          ConvAiTurnRateLimiter(maxTurns: 50, turnsUsed: 50);

      limiter.reset();

      expect(limiter.turnsUsed, 0);
      expect(limiter.remainingTurns, 50);
      expect(limiter.isExhausted, isFalse);
      expect(() => limiter.ensureCanSend(), returnsNormally);
    });
  });
}
