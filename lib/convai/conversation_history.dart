/// Local conversation history for the ElevenLabs ConvAI text slice.
///
/// Persists finished exchanges so past conversations survive app restarts and
/// can be listed, reopened, searched, and deleted ("display past
/// conversations", "delete conversation", "search within conversation"
/// acceptance criteria). Hive is deliberately avoided: the template already
/// ships `shared_preferences`, which is sufficient for per-conversation JSON
/// documents and introduces no new dependency.
///
/// Storage layout (one key per conversation plus a recency index):
///
/// ```text
/// convai_conversation_index          -> ["<newest id>", "<older id>", ...]
/// convai_conversation_<id>           -> {"id":..., "messages":[...], ...}
/// ```
///
/// Parsing happens only at this storage boundary: wire bytes become typed
/// [ConvAiConversation]s once and are trusted everywhere else. Malformed
/// documents throw [ConvAiHistoryException] on write paths; on read paths a
/// corrupt or missing entry is skipped so one bad key cannot brick listing.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thrown when conversation data violates its documented shape. The message
/// names the offending field so corruption is immediately diagnosable.
class ConvAiHistoryException implements Exception {
  final String message;

  const ConvAiHistoryException(this.message);

  @override
  String toString() => 'ConvAiHistoryException: $message';
}

/// Who authored a stored message.
enum ConvAiMessageRole { user, agent }

/// One immutable transcript entry: author, text, and when it happened.
class ConvAiMessage {
  const ConvAiMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  final ConvAiMessageRole role;
  final String content;
  final DateTime timestamp;

  /// True when [query] (case-insensitive) appears in the message text.
  bool containsQuery(String query) =>
      content.toLowerCase().contains(query.toLowerCase());

  Map<String, dynamic> toJson() => <String, dynamic>{
        'role': role.name,
        'content': content,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  /// Parses one stored message. Throws [ConvAiHistoryException] naming the
  /// first missing/mistyped field.
  factory ConvAiMessage.fromJson(Map<String, dynamic> json) {
    final roleName = json['role'];
    if (roleName is! String) {
      throw ConvAiHistoryException(
        'Message requires string "role", got ${roleName.runtimeType}.',
      );
    }
    final role = ConvAiMessageRole.values
        .where((value) => value.name == roleName)
        .firstOrNull;
    if (role == null) {
      throw ConvAiHistoryException(
        'Message "role" must be one of '
        '${ConvAiMessageRole.values.map((value) => value.name).toList()}, '
        'got "$roleName".',
      );
    }
    final content = json['content'];
    if (content is! String) {
      throw ConvAiHistoryException(
        'Message requires string "content", got ${content.runtimeType}.',
      );
    }
    final millis = json['timestamp'];
    if (millis is! int) {
      throw ConvAiHistoryException(
        'Message requires int "timestamp", got ${millis.runtimeType}.',
      );
    }
    return ConvAiMessage(
      role: role,
      content: content,
      timestamp: DateTime.fromMillisecondsSinceEpoch(millis),
    );
  }
}

/// One stored conversation: identity, session linkage, and ordered messages.
class ConvAiConversation {
  ConvAiConversation({
    required this.id,
    required this.sessionId,
    required this.startedAt,
    required this.updatedAt,
    List<ConvAiMessage> messages = const [],
  })  : assert(id.isNotEmpty, 'Conversation id must not be empty.'),
        messages = List<ConvAiMessage>.unmodifiable(messages);

  /// Stable identifier. Prefers the server `conversation_id`; falls back to
  /// the local session UUID when the handshake metadata is unavailable.
  final String id;

  /// Local session UUID this conversation belongs to.
  final String sessionId;
  final DateTime startedAt;
  final DateTime updatedAt;
  final List<ConvAiMessage> messages;

  /// Human-readable list title: the first user message, trimmed to
  /// [titleMaxLength]; falls back to the start date.
  String get title {
    final firstUserMessage =
        messages.where((message) => message.role == ConvAiMessageRole.user);
    final source = firstUserMessage.isEmpty ? null : firstUserMessage.first.content.trim();
    if (source == null || source.isEmpty) {
      return 'Conversation ${startedAt.toIso8601String().substring(0, 10)}';
    }
    if (source.length <= titleMaxLength) return source;
    return '${source.substring(0, titleMaxLength)}…';
  }

  static const int titleMaxLength = 60;

  /// Returns a copy with [message] appended and `updatedAt` advanced.
  ConvAiConversation withMessage(ConvAiMessage message) => ConvAiConversation(
        id: id,
        sessionId: sessionId,
        startedAt: startedAt,
        updatedAt: message.timestamp,
        messages: [...messages, message],
      );

  /// True when [query] (case-insensitive) matches the title or any message.
  /// Blank queries match nothing — searching for nothing finds nothing.
  bool matchesQuery(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return false;
    if (title.toLowerCase().contains(needle)) return true;
    return messages.any((message) => message.containsQuery(needle));
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'session_id': sessionId,
        'started_at': startedAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'messages': messages.map((message) => message.toJson()).toList(),
      };

  /// Parses one stored conversation. Throws [ConvAiHistoryException] naming
  /// the first missing/mistyped field.
  factory ConvAiConversation.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const ConvAiHistoryException(
        'Conversation requires non-empty string "id".',
      );
    }
    final sessionId = json['session_id'];
    if (sessionId is! String) {
      throw ConvAiHistoryException(
        'Conversation "$id" requires string "session_id", '
        'got ${sessionId.runtimeType}.',
      );
    }
    final startedMillis = json['started_at'];
    if (startedMillis is! int) {
      throw ConvAiHistoryException(
        'Conversation "$id" requires int "started_at", '
        'got ${startedMillis.runtimeType}.',
      );
    }
    final updatedMillis = json['updated_at'] ?? startedMillis;
    if (updatedMillis is! int) {
      throw ConvAiHistoryException(
        'Conversation "$id" requires int "updated_at", '
        'got ${updatedMillis.runtimeType}.',
      );
    }
    final rawMessages = json['messages'];
    if (rawMessages is! List) {
      throw ConvAiHistoryException(
        'Conversation "$id" requires list "messages", '
        'got ${rawMessages.runtimeType}.',
      );
    }
    final messages = rawMessages.map((raw) {
      if (raw is! Map) {
        throw ConvAiHistoryException(
          'Conversation "$id" message must be an object, '
          'got ${raw.runtimeType}.',
        );
      }
      return ConvAiMessage.fromJson(Map<String, dynamic>.from(raw));
    }).toList();
    return ConvAiConversation(
      id: id,
      sessionId: sessionId,
      startedAt: DateTime.fromMillisecondsSinceEpoch(startedMillis),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedMillis),
      messages: messages,
    );
  }
}

/// Storage contract for past conversations. Injectable so hosts can swap in
/// another backend (Firestore sync stays out of scope for this slice)
/// without touching the service or client.
abstract interface class ConvAiConversationHistoryStore {
  /// Inserts or updates [conversation], moving it to the front of the
  /// recency index.
  Future<void> save(ConvAiConversation conversation);

  /// All stored conversations, newest-updated first.
  Future<List<ConvAiConversation>> loadAll();

  /// One conversation by id, or `null` when absent.
  Future<ConvAiConversation?> load(String id);

  /// Removes one conversation. Absent ids complete normally (idempotent).
  Future<void> delete(String id);

  /// Conversations whose title or messages contain [query]
  /// (case-insensitive), newest-updated first. Blank queries return empty.
  Future<List<ConvAiConversation>> search(String query);

  /// Messages within one conversation containing [query]
  /// (case-insensitive), oldest first. Blank queries return empty.
  Future<List<ConvAiMessage>> searchMessages(String conversationId, String query);

  /// Removes every stored conversation.
  Future<void> clear();
}

/// [ConvAiConversationHistoryStore] backed by `shared_preferences`: one JSON
/// document per conversation under `convai_conversation_<id>` plus a
/// recency-ordered id index under `convai_conversation_index`.
class SharedPreferencesConvAiConversationHistoryStore
    implements ConvAiConversationHistoryStore {
  static const String _indexKey = 'convai_conversation_index';
  static const String _entryKeyPrefix = 'convai_conversation_';

  const SharedPreferencesConvAiConversationHistoryStore();

  @override
  Future<void> save(ConvAiConversation conversation) async {
    final preferences = await SharedPreferences.getInstance();
    final index = await _loadIndex(preferences);
    final nextIndex = <String>[
      conversation.id,
      ...index.where((id) => id != conversation.id),
    ];
    await preferences.setString(
      _entryKeyFor(conversation.id),
      jsonEncode(conversation.toJson()),
    );
    await preferences.setString(_indexKey, jsonEncode(nextIndex));
  }

  @override
  Future<List<ConvAiConversation>> loadAll() async {
    final preferences = await SharedPreferences.getInstance();
    final index = await _loadIndex(preferences);
    final conversations = <ConvAiConversation>[];
    for (final id in index) {
      final conversation = await _loadEntry(preferences, id);
      if (conversation != null) conversations.add(conversation);
    }
    return conversations;
  }

  @override
  Future<ConvAiConversation?> load(String id) async {
    if (id.isEmpty) return null;
    final preferences = await SharedPreferences.getInstance();
    return _loadEntry(preferences, id);
  }

  @override
  Future<void> delete(String id) async {
    if (id.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    final index = await _loadIndex(preferences);
    await preferences.remove(_entryKeyFor(id));
    await preferences.setString(
      _indexKey,
      jsonEncode(index.where((entryId) => entryId != id).toList()),
    );
  }

  @override
  Future<List<ConvAiConversation>> search(String query) async {
    if (query.trim().isEmpty) return const [];
    final conversations = await loadAll();
    return conversations
        .where((conversation) => conversation.matchesQuery(query))
        .toList();
  }

  @override
  Future<List<ConvAiMessage>> searchMessages(
    String conversationId,
    String query,
  ) async {
    if (query.trim().isEmpty) return const [];
    final conversation = await load(conversationId);
    if (conversation == null) return const [];
    return conversation.messages
        .where((message) => message.containsQuery(query))
        .toList();
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    final index = await _loadIndex(preferences);
    for (final id in index) {
      await preferences.remove(_entryKeyFor(id));
    }
    await preferences.remove(_indexKey);
  }

  static String _entryKeyFor(String id) => '$_entryKeyPrefix$id';

  /// Reads the recency index; a missing or malformed index reads as empty so
  /// the store degrades to "no history" instead of throwing.
  static Future<List<String>> _loadIndex(SharedPreferences preferences) async {
    final raw = preferences.getString(_indexKey);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.whereType<String>().toList();
  }

  /// Reads and parses one entry. Corrupt or missing entries are skipped
  /// (returned as `null`): a single bad key must not take down the whole
  /// history list. Write paths still fail fast via the model parsers.
  static Future<ConvAiConversation?> _loadEntry(
    SharedPreferences preferences,
    String id,
  ) async {
    final raw = preferences.getString(_entryKeyFor(id));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return ConvAiConversation.fromJson(Map<String, dynamic>.from(decoded));
    } on ConvAiHistoryException {
      return null;
    } on FormatException {
      return null;
    } on TypeError {
      // A shape the parsers could not even cast (e.g. a nested value of an
      // unexpected runtime type) is corruption like any other: skip it so
      // bulk reads survive.
      return null;
    }
  }
}
