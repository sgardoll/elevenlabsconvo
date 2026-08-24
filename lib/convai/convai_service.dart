/// FlutterFlow-facing singleton that hosts [ConvAiWebSocketClient] and keeps
/// `FFAppState` in sync, mirroring the conventions of `ElevenLabsSdkService`.
///
/// The thin custom actions in `lib/custom_code/actions/` call into this
/// service; the core client in `lib/convai/convai_websocket_client.dart`
/// stays Flutter-free.
///
/// Week 2-3 additions: finished exchanges persist to local conversation
/// history (list / reopen / delete / search), each send is capped by a
/// per-session turn budget (only PRE-dispatch failures refund; a timed-out
/// turn stays charged, matching the server's own counting of dispatched
/// frames), and a text-only fallback flag records graceful degradation when
/// the voice path fails.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '/flutter_flow/flutter_flow_util.dart';
import 'convai_config.dart';
import 'convai_events.dart';
import 'convai_websocket_client.dart';
import 'conversation_history.dart';
import 'session_store.dart';
import 'turn_rate_limiter.dart';
import 'typed_turn_tracker.dart';

/// Singleton bridge between the host app and the ConvAI WebSocket client.
class ConvAiService {
  static final ConvAiService _instance = ConvAiService._internal();

  factory ConvAiService() => _instance;

  ConvAiService._internal();

  ConvAiWebSocketClient? _client;
  StreamSubscription<ConvAiConnectionState>? _stateSubscription;
  StreamSubscription<ConvAiEvent>? _eventSubscription;

  final ConvAiConversationHistoryStore _historyStore =
      const SharedPreferencesConvAiConversationHistoryStore();
  ConvAiConversation? _activeConversation;
  bool _textOnlyFallbackActive = false;
  String? _textOnlyFallbackReason;

  final StreamController<ConvAiConnectionState> _stateController =
      StreamController<ConvAiConnectionState>.broadcast();
  final StreamController<ConvAiEvent> _eventController =
      StreamController<ConvAiEvent>.broadcast();

  /// Connection lifecycle transitions for UI bindings.
  Stream<ConvAiConnectionState> get stateStream => _stateController.stream;

  /// Decoded protocol events for UI bindings (transcripts, responses, pings).
  Stream<ConvAiEvent> get eventStream => _eventController.stream;

  /// True while a session is fully established.
  bool get isConnected => _client?.isConnected ?? false;

  /// Server-assigned conversation id from the latest handshake.
  String? get conversationId => _client?.conversationId;

  /// Persisted local session UUID for this conversation.
  String? get localSessionId => _client?.localSessionId;

  /// Turns still available in the active session's budget.
  int? get remainingTurns => _client?.remainingTurns;

  /// True once the host marked the voice path as unavailable and the app is
  /// deliberately running text-only (graceful degradation).
  bool get isTextOnlyFallbackActive => _textOnlyFallbackActive;

  /// Why text-only mode was entered, when it is active.
  String? get textOnlyFallbackReason => _textOnlyFallbackReason;

  /// Marks the voice path as unavailable; the app keeps working over the
  /// WebSocket text channel. Idempotent — the first reason wins.
  void enableTextOnlyFallback({String reason = 'Voice path unavailable'}) {
    if (_textOnlyFallbackActive) return;
    _textOnlyFallbackActive = true;
    _textOnlyFallbackReason = reason;
    debugPrint('ConvAI degraded to text-only mode: $reason');
  }

  /// Creates a client from explicit values (falling back to dart-defines) and
  /// opens a session.
  ///
  /// ONLY backend-provisioned temporary credentials are accepted: a
  /// short-lived [token] or a backend [signedUrl]. Reusable API keys are
  /// never accepted here — they can be extracted from a distributed build
  /// and replayed outside the app.
  ///
  /// Returns `'success'` on connection, or `'error: <reason>'` following the
  /// existing action convention. Missing credentials produce a descriptive
  /// error naming the required dart-defines.
  Future<String> initialize({
    required String agentId,
    String signedUrl = '',
    String token = '',
  }) async {
    try {
      debugPrint('Initializing ConvAI WebSocket service');
      final config = ConvAiConfig.fromEnvironment(
        signedUrl: _blankToNull(signedUrl),
        token: _blankToNull(token),
        agentId: _blankToNull(agentId),
      );

      await _teardownClient();
      // New conversation: no typed-turn state from any previous session may
      // survive into it.
      _typedTurns.clear();

      final client = ConvAiWebSocketClient(
        config: config,
        sessionStore: const SharedPreferencesConvAiSessionStore(),
      );
      _stateSubscription = client.stateStream.listen((state) {
        _stateController.add(state);
        FFAppState().update(() {
          FFAppState().wsConnectionState = state.name;
        });
      });
      _eventSubscription = client.eventStream.listen(_onProtocolEvent);
      _client = client;

      await client.connect();
      await _startOrResumeConversation(client);

      FFAppState().update(() {
        FFAppState().elevenLabsAgentId = config.agentId;
      });

      debugPrint(
        'ConvAI session established (conversationId: '
        '${client.conversationId}, localSessionId: ${client.localSessionId}, '
        'remainingTurns: ${client.remainingTurns})',
      );
      return 'success';
    } on ConvAiConfigException catch (error) {
      debugPrint('ConvAI configuration error: ${error.message}');
      FFAppState().update(() {
        FFAppState().wsConnectionState = 'error: ${error.message}';
      });
      return 'error: ${error.message}';
    } on Object catch (error) {
      debugPrint('Error initializing ConvAI service: $error');
      return 'error: $error';
    }
  }

  /// Sends a text message and completes with the agent's reply text, or
  /// `'error: <reason>'` when the exchange fails.
  ///
  /// This path only awaits the turn; it does NOT append chat bubbles. The
  /// protocol-event handler is the single owner of message appending, so each
  /// `agent_response` / `user_transcript` event produces exactly one bubble.
  ///
  /// Typed turns are tracked per send with terminal settlement: whichever
  /// lands first — the server's `user_transcript` echo or the completed
  /// response — owns the single user bubble, and the other path becomes a
  /// no-op, so a late transcript can never duplicate the fallback append.
  ///
  /// Rate-limit exhaustion returns a clear budget error; an unanswered send
  /// returns a timeout error (resending is the caller's choice via a fresh
  /// send). Successful exchanges persist both messages to local conversation
  /// history.
  Future<String> sendTextMessage(String text) async {
    final client = _client;
    if (client == null || !client.isConnected) {
      return 'error: Not connected';
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return 'error: Message must not be empty.';
    }
    final turn = _typedTurns.registerTypedTurn(trimmed);
    try {
      final reply = await client.sendMessage(text);
      // Server answered: append the typed text iff no user_transcript echo
      // settled this turn first. Trimmed content matches what the echo path
      // appends, so either settlement produces an identical bubble.
      if (_typedTurns.settleTypedTurn(turn)) {
        _appendMessage(type: 'user', content: trimmed);
      }
      await _recordExchange(userText: text, agentReply: reply);
      return reply;
    } on ConvAiRateLimitException catch (error) {
      _typedTurns.discardTypedTurn(turn);
      debugPrint('ConvAI rate limit reached: ${error.message}');
      return 'error: ${error.message}';
    } on TimeoutException catch (error) {
      _typedTurns.discardTypedTurn(turn);
      debugPrint('ConvAI response timeout: ${error.message}');
      return 'error: Agent did not respond in time (${error.message}).';
    } on Object catch (error) {
      // Unanswered turn: no transcript entry — the server may never have
      // received the text.
      _typedTurns.discardTypedTurn(turn);
      debugPrint('Error sending text message: $error');
      return 'error: $error';
    }
  }

  /// Closes the active session and stops the client. Returns `'success'`.
  Future<String> stop() async {
    await _teardownClient();
    FFAppState().update(() {
      FFAppState().wsConnectionState = 'disconnected';
    });
    debugPrint('ConvAI WebSocket service stopped');
    return 'success';
  }

  // ---------------------------------------------------------------------------
  // Conversation history
  // ---------------------------------------------------------------------------

  /// Past conversations, newest-updated first.
  Future<List<ConvAiConversation>> listConversations() =>
      _historyStore.loadAll();

  /// One past conversation by id, or `null` when absent.
  Future<ConvAiConversation?> loadConversation(String id) =>
      _historyStore.load(id);

  /// Deletes one past conversation. Returns `'success'` (idempotent) or
  /// `'error: <reason>'`.
  Future<String> deleteConversation(String id) async {
    try {
      await _historyStore.delete(id);
      if (_activeConversation?.id == id) _activeConversation = null;
      return 'success';
    } on Object catch (error) {
      debugPrint('Error deleting conversation "$id": $error');
      return 'error: $error';
    }
  }

  /// Conversations whose title or messages contain [query]
  /// (case-insensitive), newest-updated first.
  Future<List<ConvAiConversation>> searchConversations(String query) =>
      _historyStore.search(query);

  /// Messages within one conversation containing [query]
  /// (case-insensitive), oldest first.
  Future<List<ConvAiMessage>> searchConversationMessages(
    String conversationId,
    String query,
  ) =>
      _historyStore.searchMessages(conversationId, query);

  /// Removes every stored conversation. Returns `'success'` or
  /// `'error: <reason>'`.
  Future<String> clearConversationHistory() async {
    try {
      await _historyStore.clear();
      _activeConversation = null;
      return 'success';
    } on Object catch (error) {
      debugPrint('Error clearing conversation history: $error');
      return 'error: $error';
    }
  }

  /// Releases the service entirely (streams included). For host-app teardown.
  Future<void> dispose() async {
    await _teardownClient();
    await _stateController.close();
    await _eventController.close();
  }

  /// Single owner of chat-bubble appending: every protocol event appends at
  /// most one message, and completion paths never do — except the typed-turn
  /// fallback for sends the server never echoed. A late transcript matching
  /// a fallback-settled turn is suppressed, keeping one bubble per turn.
  void _onProtocolEvent(ConvAiEvent event) {
    _eventController.add(event);
    switch (event) {
      case final AgentResponse response:
        _appendMessage(type: 'agent', content: response.text);
      case final UserTranscript transcript:
        if (_typedTurns.noteUserTranscript(transcript.text)) {
          _appendMessage(type: 'user', content: transcript.text);
        }
      default:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Typed-turn settlement
  // ---------------------------------------------------------------------------

  final TypedTurnTracker _typedTurns = TypedTurnTracker();

  void _appendMessage({required String type, required String content}) {
    FFAppState().update(() {
      FFAppState().conversationMessages = <dynamic>[
        ...FFAppState().conversationMessages,
        <String, dynamic>{
          'type': type,
          'content': content,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          if (_client?.conversationId != null)
            'conversation_id': _client!.conversationId,
        },
      ];
    });
  }

  /// Opens (or resumes) the durable conversation record for a freshly
  /// connected session, keyed by the server conversation id.
  Future<void> _startOrResumeConversation(ConvAiWebSocketClient client) async {
    final sessionId = client.localSessionId;
    final conversationId = client.conversationId ?? sessionId;
    // Post-handshake both ids exist; an absent one means history cannot be
    // attributed, so this session simply runs without persistence.
    if (sessionId == null || conversationId == null) return;

    final existing = await _historyStore.load(conversationId);
    _activeConversation = existing ??
        ConvAiConversation(
          id: conversationId,
          sessionId: sessionId,
          startedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
    await _historyStore.save(_activeConversation!);
  }

  /// Persists one finished user/agent exchange into the active conversation.
  Future<void> _recordExchange({
    required String userText,
    required String agentReply,
  }) async {
    final conversation = _activeConversation;
    if (conversation == null) return;

    final now = DateTime.now();
    var updated = conversation.withMessage(
      ConvAiMessage(
        role: ConvAiMessageRole.user,
        content: userText,
        timestamp: now,
      ),
    );
    updated = updated.withMessage(
      ConvAiMessage(
        role: ConvAiMessageRole.agent,
        content: agentReply,
        timestamp: now,
      ),
    );

    _activeConversation = updated;
    try {
      await _historyStore.save(updated);
    } on Object catch (error) {
      // The chat turn already succeeded; history durability must not fail
      // it. The in-memory record stays current for the rest of the session.
      debugPrint('Error persisting conversation history: $error');
    }
  }

  Future<void> _teardownClient() async {
    _stateSubscription?.cancel();
    _eventSubscription?.cancel();
    _stateSubscription = null;
    _eventSubscription = null;
    // Teardown ends the turn cycle: suppression records must never outlive
    // their session, or a later identical phrase would be swallowed.
    _typedTurns.clear();
    final client = _client;
    _client = null;
    await client?.dispose();
  }

  static String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
