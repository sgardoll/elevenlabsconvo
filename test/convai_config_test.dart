import 'package:flutter_test/flutter_test.dart';

import 'package:eleven_labs_conversational_a_i_library/convai/convai_config.dart';

void main() {
  group('ConvAiConfig.fromEnvironment credential modes', () {
    test('short-lived token activates token mode', () {
      final config = ConvAiConfig.fromEnvironment(token: 'tok_123');

      expect(config.token, 'tok_123');
      expect(config.apiKey, isEmpty);
      expect(config.signedUrl, isEmpty);
      expect(config.usesSignedCredentials, isTrue);
    });

    test('signed URL takes precedence over token', () {
      final config = ConvAiConfig.fromEnvironment(
        signedUrl: 'wss://backend.example/signed?token=abc',
        token: 'tok_123',
      );

      expect(config.signedUrl, 'wss://backend.example/signed?token=abc');
      expect(config.token, isEmpty);
      expect(config.usesSignedUrl, isTrue);
    });

    test('blank values fall back to other modes', () {
      final config = ConvAiConfig.fromEnvironment(
        signedUrl: '',
        token: '  tok_123  ',
      );

      expect(config.token, 'tok_123');
    });

    test('token mode leaves no reusable key anywhere', () {
      final config = ConvAiConfig.fromEnvironment(
        signedUrl: '',
        token: 'tok_123',
      );

      expect(config.apiKey, isEmpty);
      expect(config.signedUrl, isEmpty);
      expect(config.usesSignedCredentials, isTrue);
    });
  });

  group('ConvAiConfig runtime surface rejects reusable keys', () {
    test('fromEnvironment accepts only temporary credentials and names '
        'them in its error', () {
      expect(
        () => ConvAiConfig.fromEnvironment(),
        throwsA(
          isA<ConvAiConfigException>().having(
            (error) => error.message,
            'message',
            contains('Reusable API keys are not accepted at runtime'),
          ),
        ),
      );
    });

    test('the reusable key is reachable ONLY through the @visibleForTesting '
        'constructor', () {
      final config = ConvAiConfig.forTesting(
        apiKey: 'sk_test_key',
        agentId: 'agent_1',
      );

      expect(config.apiKey, 'sk_test_key');
      expect(config.agentId, 'agent_1');
      expect(config.usesSignedCredentials, isFalse);
    });

    test('production constructors never carry a key', () {
      final tokenMode = ConvAiConfig(token: 'tok_123', agentId: 'agent_1');
      final signedMode = ConvAiConfig(
        signedUrl: 'wss://backend.example/signed?token=abc',
        agentId: 'agent_1',
      );

      expect(tokenMode.apiKey, isEmpty);
      expect(signedMode.apiKey, isEmpty);
    });
  });
}
