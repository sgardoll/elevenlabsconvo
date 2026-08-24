import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eleven_labs_conversational_a_i_library/convai/session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesConvAiSessionStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('returns null when no session id was persisted', () async {
      final store = const SharedPreferencesConvAiSessionStore();

      expect(await store.loadSessionId(), isNull);
    });

    test('persists and reloads a session id', () async {
      final store = const SharedPreferencesConvAiSessionStore();

      await store.saveSessionId('session-abc-123');

      expect(await store.loadSessionId(), 'session-abc-123');
    });

    test('overwrites a previous session id', () async {
      final store = const SharedPreferencesConvAiSessionStore();

      await store.saveSessionId('first');
      await store.saveSessionId('second');

      expect(await store.loadSessionId(), 'second');
    });

    test('clear removes the persisted session id', () async {
      final store = const SharedPreferencesConvAiSessionStore();

      await store.saveSessionId('session-abc-123');
      await store.clearSessionId();

      expect(await store.loadSessionId(), isNull);
    });
  });
}
