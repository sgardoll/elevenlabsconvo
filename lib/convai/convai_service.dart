/// FlutterFlow-facing singleton that hosts [ConvAiWebSocketClient] and keeps
/// `FFAppState` in sync, mirroring the conventions of `ElevenLabsSdkService`.
///
/// The thin custom actions in `lib/custom_code/actions/` call into this
/// service; the core client in `lib/convai/convai_websocket_client.dart`
/// stays Flutter-free.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '/flutter_flow/flutter_flow_util.dart';
import 'convai_config.dart';
import 'convai_events.dart';
import 'convai_websocket_client.dart';
import 'session_store.dart';
import 'typed_turn_tracker.dart';

/// Singleton bridge between the host app and the ConvAI WebSocket client.
class ConvAiService {
  static final ConvAiService _instance = ConvAiService._internal();

  factory ConvAiService() => _instance;

  ConvAiService._internal();

  ConvAiWebSocketClient? _client;
  StreamSubscription<ConvAiConnectionState>? _stateSubscription;
  StreamSubscription<ConvAiEvent>? _eventSubscription;

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

  /// Creates a client from explicit values (falling back to dart-defines) and
  /// opens a session.
  ///
  /// Signed-URL / short-lived-token credentials are preferred. Passing an
  /// [apiKey] additionally requires [allowInsecureApiKey]: true — a reusable
  /// key embedded in a distributed build can be extracted and replayed
  /// outside the app, so that mode is dev-only.
  ///
  /// Returns `'success'` on connection, or `'error: <reason>'` following the
  /// existing action convention. Missing credentials produce a descriptive
  /// error naming the required dart-defines.
  Future<String> initialize({
    required String agentId,
    String apiKey = '',
    String signedUrl = '',
    String token = '',
    bool allowInsecureApiKey = false,
  }) async {
    try {
      debugPrint('Initializing ConvAI WebSocket service');
      final config = ConvAiConfig.fromEnvironment(
        apiKey: _blankToNull(apiKey),
        signedUrl: _blankToNull(signedUrl),
        token: _blankToNull(token),
        agentId: _blankToNull(agentId),
        allowInsecureApiKey: allowInsecureApiKey,
      );

      await _teardownClient();

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

      FFAppState().update(() {
        FFAppState().elevenLabsAgentId = config.agentId;
      });

      debugPrint(
        'ConvAI session established (conversationId: '
        '${client.conversationId}, localSessionId: ${client.localSessionId})',
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
  /// `agent_response` / `user_transcript` event produces exactly one bubble
  /// instead of duplicating what this completion path used to add again.
  ///
  /// Typed turns are tracked per send with terminal settlement: whichever
  /// lands first — the server's `user_transcript` echo or the completed
  /// response — owns the single user bubble, and the other path becomes a
  /// no-op, so a late transcript can never duplicate the fallback append.
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
      return reply;
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

  Future<void> _teardownClient() async {
    _stateSubscription?.cancel();
    _eventSubscription?.cancel();
    _stateSubscription = null;
    _eventSubscription = null;
    final client = _client;
    _client = null;
    await client?.dispose();
  }

  static String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
