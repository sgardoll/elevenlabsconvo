import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eleven_labs_conversational_a_i_library/convai/conversation_history.dart';

ConvAiMessage _message(
  ConvAiMessageRole role,
  String content, {
  int millis = 1700000000000,
}) =>
    ConvAiMessage(
      role: role,
      content: content,
      timestamp: DateTime.fromMillisecondsSinceEpoch(millis),
    );

ConvAiConversation _conversation({
  String id = 'conv_1',
  List<ConvAiMessage> messages = const [],
}) =>
    ConvAiConversation(
      id: id,
      sessionId: 'session-1',
      startedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1700000001000),
      messages: messages,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConvAiMessage', () {
    test('round-trips through JSON', () {
      final message =
          _message(ConvAiMessageRole.agent, 'Hello! How can I help?');

      final parsed =
          ConvAiMessage.fromJson(Map<String, dynamic>.from(jsonDecode(
        jsonEncode(message.toJson()),
      ) as Map));

      expect(parsed.role, ConvAiMessageRole.agent);
      expect(parsed.content, 'Hello! How can I help?');
      expect(parsed.timestamp, message.timestamp);
    });

    test('fromJson fails fast on a bad role', () {
      expect(
        () => ConvAiMessage.fromJson(<String, dynamic>{
          'role': 'system',
          'content': 'hi',
          'timestamp': 1,
        }),
        throwsA(isA<ConvAiHistoryException>()),
      );
    });

    test('fromJson fails fast on missing fields', () {
      expect(
        () => ConvAiMessage.fromJson(<String, dynamic>{'role': 'user'}),
        throwsA(isA<ConvAiHistoryException>()),
      );
    });
  });

  group('ConvAiConversation', () {
    test('title comes from the first user message', () {
      final conversation = _conversation(messages: [
        _message(ConvAiMessageRole.user, 'What grapes grow here?'),
        _message(ConvAiMessageRole.agent, 'Mostly Shiraz.'),
      ]);

      expect(conversation.title, 'What grapes grow here?');
    });

    test('long first user message truncates to 60 chars plus ellipsis',
        () {
      final conversation = _conversation(messages: [
        _message(ConvAiMessageRole.user, 'a' * 200),
      ]);

      expect(conversation.title.length, 61);
      expect(conversation.title.endsWith('…'), isTrue);
    });

    test('conversation without user messages falls back to the start date',
        () {
      expect(_conversation().title,
          'Conversation ${_conversation().startedAt.toIso8601String().substring(0, 10)}');
    });

    test('withMessage appends and advances updatedAt immutably', () {
      final original = _conversation();
      final appended = original.withMessage(_message(
        ConvAiMessageRole.user,
        'hello',
        millis: 1700000002000, // strictly after the fixture updatedAt
      ));

      expect(original.messages, isEmpty);
      expect(appended.messages, hasLength(1));
      expect(appended.updatedAt.isAfter(original.updatedAt), isTrue);
    });

    test('matchesQuery is case-insensitive across title and messages', () {
      final conversation = _conversation(messages: [
        _message(ConvAiMessageRole.user, 'Tell me about VINIFICATION'),
      ]);

      expect(conversation.matchesQuery('vinification'), isTrue);
      expect(conversation.matchesQuery('about'), isTrue); // in the title
      expect(conversation.matchesQuery('shiraz'), isFalse);
      expect(conversation.matchesQuery('   '), isFalse); // blank matches nothing
    });

    test('round-trips through JSON with nested messages', () {
      final conversation = _conversation(messages: [
        _message(ConvAiMessageRole.user, 'hello'),
        _message(ConvAiMessageRole.agent, 'greetings'),
      ]);

      final parsed = ConvAiConversation.fromJson(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(conversation.toJson()))
            as Map),
      );

      expect(parsed.id, conversation.id);
      expect(parsed.sessionId, conversation.sessionId);
      expect(parsed.startedAt, conversation.startedAt);
      expect(parsed.updatedAt, conversation.updatedAt);
      expect(parsed.messages.map((message) => message.content).toList(),
          <String>['hello', 'greetings']);
    });

    test('fromJson fails fast on an empty id', () {
      expect(
        () => ConvAiConversation.fromJson(<String, dynamic>{
          'id': '',
          'session_id': 's',
          'started_at': 1,
          'updated_at': 1,
          'messages': <Object>[],
        }),
        throwsA(isA<ConvAiHistoryException>()),
      );
    });

    test('fromJson fails fast on non-list messages', () {
      expect(
        () => ConvAiConversation.fromJson(<String, dynamic>{
          'id': 'conv_1',
          'session_id': 's',
          'started_at': 1,
          'updated_at': 1,
          'messages': 'nope',
        }),
        throwsA(isA<ConvAiHistoryException>()),
      );
    });

    test('fromJson fails fast with a typed error on a non-object message',
        () {
      expect(
        () => ConvAiConversation.fromJson(<String, dynamic>{
          'id': 'conv_1',
          'session_id': 's',
          'started_at': 1,
          'updated_at': 1,
          // A nested element that is not an object must surface as
          // ConvAiHistoryException, never as a raw TypeError.
          'messages': <Object>['not-an-object'],
        }),
        throwsA(isA<ConvAiHistoryException>()),
      );
    });
  });

  group('SharedPreferencesConvAiConversationHistoryStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('loadAll returns empty when nothing was saved', () async {
      final store = const SharedPreferencesConvAiConversationHistoryStore();

      expect(await store.loadAll(), isEmpty);
    });

    test('save then loadAll returns the conversation newest-first', () async {
      final store = const SharedPreferencesConvAiConversationHistoryStore();

      await store.save(_conversation(id: 'older').withMessage(
          _message(ConvAiMessageRole.user, 'first')));
      await store.save(_conversation(id: 'newer').withMessage(
          _message(ConvAiMessageRole.user, 'second')));

      final conversations = await store.loadAll();
      expect(conversations.map((c) => c.id).toList(),
          <String>['newer', 'older']);
    });

    test('saving an existing conversation moves it to the front', () async {
      final store = const SharedPreferencesConvAiConversationHistoryStore();

      await store.save(_conversation(id: 'a'));
      await store.save(_conversation(id: 'b'));
      await store.save(_conversation(id: 'a'));

      expect((await store.loadAll()).map((c) => c.id).toList(),
          <String>['a', 'b']);
    });

    test('load returns null for unknown ids', () async {
      final store = const SharedPreferencesConvAiConversationHistoryStore();

      expect(await store.load('missing'), isNull);
    });

    test('delete removes the conversation and keeps others', () async {
      final store = const SharedPreferencesConvAiConversationHistoryStore();
      await store.save(_conversation(id: 'keep'));
      await store.save(_conversation(id: 'drop'));

      await store.delete('drop');

      expect(await store.load('drop'), isNull);
      expect((await store.loadAll()).map((c) => c.id).toList(),
          <String>['keep']);
    });

    test('delete on an absent id completes normally', () async {
      final store = const SharedPreferencesConvAiConversationHistoryStore();

      await store.delete('never-existed');

      expect(await store.loadAll(), isEmpty);
    });

    test('search finds conversations by message text across all entries',
        () async {
      final store = const SharedPreferencesConvAiConversationHistoryStore();
      await store.save(_conversation(id: 'wine').withMessage(
          _message(ConvAiMessageRole.user, 'Tell me about shiraz')));
      await store.save(_conversation(id: 'weather').withMessage(
          _message(ConvAiMessageRole.user, 'Will it rain tomorrow?')));

      final hits = await store.search('SHIRAZ');

      expect(hits.map((c) => c.id).toList(), <String>['wine']);
    });

    test('search with a blank query returns empty without scanning',
        () async {
      final store = const SharedPreferencesConvAiConversationHistoryStore();
      await store.save(_conversation(id: 'wine'));

      expect(await store.search('   '), isEmpty);
    });

    test('searchMessages returns matching messages within one conversation',
        () async {
      final store = const SharedPreferencesConvAiConversationHistoryStore();
      await store.save(
        _conversation(id: 'conv_1').withMessage(
            _message(ConvAiMessageRole.user, 'hello there'))
            .withMessage(
            _message(ConvAiMessageRole.agent,
                'General Kenobi. You ARE a bold one.')),
      );

      final hits = await store.searchMessages('conv_1', 'bold');

      expect(hits, hasLength(1));
      expect(hits.first.content, contains('bold'));
    });

    test('searchMessages returns empty for unknown conversations', () async {
      final store = const SharedPreferencesConvAiConversationHistoryStore();

      expect(await store.searchMessages('missing', 'anything'), isEmpty);
    });

    test('corrupt entries are skipped by loadAll instead of failing it',
        () async {
      final store = const SharedPreferencesConvAiConversationHistoryStore();
      await store.save(_conversation(id: 'good'));
      // Simulate corruption directly under the store's key layout.
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('convai_conversation_bad', '{not json');

      final conversations = await store.loadAll();

      expect(conversations.map((c) => c.id).toList(), <String>['good']);
    });

    test('entries with non-object message elements are skipped by loadAll',
        () async {
      final store = const SharedPreferencesConvAiConversationHistoryStore();
      await store.save(_conversation(id: 'good').withMessage(
          _message(ConvAiMessageRole.user, 'hello')));
      final preferences = await SharedPreferences.getInstance();
      // Nested corruption: "messages" contains a bare string, which used to
      // escape the read guard as a raw TypeError before this fix.
      await preferences.setString(
        'convai_conversation_nested_bad',
        jsonEncode(<String, dynamic>{
          'id': 'nested_bad',
          'session_id': 's',
          'started_at': 1,
          'updated_at': 1,
          'messages': <Object>['not-an-object'],
        }),
      );

      final conversations = await store.loadAll();

      expect(conversations.map((c) => c.id).toList(), <String>['good']);
    });

    test('load returns null (not a throw) for an entry with corrupt messages',
        () async {
      final store = const SharedPreferencesConvAiConversationHistoryStore();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'convai_conversation_broken',
        jsonEncode(<String, dynamic>{
          'id': 'broken',
          'session_id': 's',
          'started_at': 1,
          'updated_at': 1,
          'messages': <Object>[42],
        }),
      );

      expect(await store.load('broken'), isNull);
    });

    test('clear removes every conversation and the index', () async {
      final store = const SharedPreferencesConvAiConversationHistoryStore();
      await store.save(_conversation(id: 'a'));
      await store.save(_conversation(id: 'b'));

      await store.clear();

      expect(await store.loadAll(), isEmpty);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getKeys().where((key) => key.startsWith('convai_')),
          isEmpty);
    });
  });
}
