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
        apiKey: '',
        signedUrl: '',
        token: '  tok_123  ',
      );

      expect(config.token, 'tok_123');
    });
  });

  group('ConvAiConfig.fromEnvironment insecure API-key gate', () {
    test('refuses a reusable API key without explicit opt-in', () {
      expect(
        () => ConvAiConfig.fromEnvironment(
          apiKey: 'sk_dev_key',
          agentId: 'agent_1',
        ),
        throwsA(
          isA<ConvAiConfigException>().having(
            (error) => error.message,
            'message',
            contains('allowInsecureApiKey'),
          ),
        ),
      );
    });

    test('refuses a reusable API key even from dart-defines without opt-in',
        () {
      // ELEVENLABS_API_KEY is empty in tests; simulate an explicit value via
      // the parameter — the gate must behave identically.
      expect(
        () => ConvAiConfig.fromEnvironment(apiKey: 'sk_dev_key'),
        throwsA(isA<ConvAiConfigException>()),
      );
    });

    test('explicit opt-in activates dev-only direct mode', () {
      final config = ConvAiConfig.fromEnvironment(
        apiKey: 'sk_dev_key',
        agentId: 'agent_1',
        allowInsecureApiKey: true,
      );

      expect(config.apiKey, 'sk_dev_key');
      expect(config.agentId, 'agent_1');
      expect(config.usesSignedCredentials, isFalse);
    });

    test('direct mode still requires an agent id even when opted in', () {
      expect(
        () => ConvAiConfig.fromEnvironment(
          apiKey: 'sk_dev_key',
          allowInsecureApiKey: true,
        ),
        throwsA(
          isA<ConvAiConfigException>().having(
            (error) => error.message,
            'message',
            contains('ELEVENLABS_AGENT_ID'),
          ),
        ),
      );
    });

    test('opt-in alone without any credential still throws', () {
      expect(
        () => ConvAiConfig.fromEnvironment(allowInsecureApiKey: true),
        throwsA(isA<ConvAiConfigException>()),
      );
    });
  });
}
