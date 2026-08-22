/// WebSocket lifecycle manager for the ElevenLabs ConvAI text protocol.
///
/// Responsibilities of this slice:
/// - Connect and authenticate (`xi-api-key` header in direct mode, signed URL
///   query token on web) using credentials from [ConvAiConfig] — never from
///   hardcoded values.
/// - Perform the initiation handshake and capture the server `conversation_id`.
/// - Maintain a persisted local session UUID per conversation.
/// - Encode user text messages and complete round-trips when the matching
///   `agent_response` arrives, retrying an unanswered send exactly
///   [ConvAiConfig.maxResponseRetries] times before failing the turn.
/// - Auto-reconnect an established session with exponential backoff + jitter,
/// - Enforce connect / handshake / response timeouts.
/// - Enforce the per-conversation turn budget ([ConvAiConfig.maxSessionTurns]),
///   persisting spent turns under the conversation id so resuming the same
///   conversation keeps its budget while new conversations start fresh.
/// - Answer server pings automatically to keep the socket open across long
///   exchanges.
///
/// Reconnection policy: a failed *initial* connect surfaces the error to the
/// caller immediately (bad credentials should not loop silently). Once a
/// session has been established, unexpected drops trigger up to
/// [ConvAiConfig.maxReconnectAttempts] background retries; exhausting them
/// transitions to [ConvAiConnectionState.disconnected] with [lastError] set.
library;

import 'dart:async';
import 'dart:math';

import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'convai_config.dart';
import 'convai_events.dart';
import 'session_store.dart';
import 'socket_channel_factory.dart';
import 'turn_rate_limiter.dart';

/// Connection lifecycle states surfaced on [ConvAiWebSocketClient.stateStream].
enum ConvAiConnectionState {
  /// No active session. Terminal after reconnect attempts are exhausted.
  disconnected,

  /// Opening the socket or completing the initiation handshake.
  connecting,

  /// Handshake completed; messages can be exchanged.
  connected,

  /// An established session dropped; retrying with backoff.
  reconnecting,
}

/// Thrown when a session cannot be opened against the configured endpoint.
class ConvAiConnectionException implements Exception {
  final String message;

  const ConvAiConnectionException(this.message);

  @override
  String toString() => 'ConvAiConnectionException: $message';
}

/// Manages one ConvAI WebSocket conversation end-to-end.
class ConvAiWebSocketClient {
  ConvAiWebSocketClient({
    required ConvAiConfig config,
    ConvAiSessionStore? sessionStore,
  })  : _config = config,
        _sessionStore = sessionStore,
        _turnLimiter = ConvAiTurnRateLimiter(maxTurns: config.maxSessionTurns);

  final ConvAiConfig _config;
  final ConvAiSessionStore? _sessionStore;
  final Uuid _uuid = const Uuid();
  final Random _random = Random();
  ConvAiTurnRateLimiter _turnLimiter;

  final StreamController<ConvAiConnectionState> _stateController =
      StreamController<ConvAiConnectionState>.broadcast();
  final StreamController<ConvAiEvent> _eventController =
      StreamController<ConvAiEvent>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _reconnectTimer;
  Completer<ConversationInitiationMetadata>? _initiationCompleter;

  /// Reply wait for the active send. Paired with [_responseGeneration]: each
  /// physical send registers a fresh generation, so a reply is attributed to
  /// exactly one wait and late replies to superseded sends are ignored.
  Completer<AgentResponse>? _responseCompleter;
  int? _responseGeneration;
  int _sendGeneration = 0;
  Future<void> _sendQueue = Future<void>.value();

  String? _localSessionId;
  String? _serverConversationId;
  int _reconnectAttempt = 0;
  bool _shouldStayConnected = false;
  bool _disposed = false;
  bool _openingSession = false;
  ConvAiConnectionState _state = ConvAiConnectionState.disconnected;
  Object? _lastError;

  /// Broadcast of every lifecycle transition.
  Stream<ConvAiConnectionState> get stateStream => _stateController.stream;

  /// Broadcast of every decoded protocol event (including pings answered
  /// automatically).
  Stream<ConvAiEvent> get eventStream => _eventController.stream;

  /// Current lifecycle state.
  ConvAiConnectionState get state => _state;

  /// True only while a session is fully established (handshake done).
  bool get isConnected => _state == ConvAiConnectionState.connected;

  /// Persisted UUID for this conversation. Stable across app restarts while
  /// [resetSession] is not called.
  String? get localSessionId => _localSessionId;

  /// Server-assigned conversation id from the latest successful handshake.
  String? get conversationId => _serverConversationId;

  /// Last error observed by this client, if any.
  Object? get lastError => _lastError;

  /// Turns still available in this session's budget.
  int get remainingTurns => _turnLimiter.remainingTurns;

  /// Configured per-session turn cap.
  int get maxSessionTurns => _config.maxSessionTurns;

  /// Opens a session: connects, authenticates, completes the handshake, and
  /// returns the server metadata.
  ///
  /// Reuses the persisted session UUID so repeated calls correlate to the same
  /// logical session. Throws on failure without auto-retrying — callers decide
  /// whether to surface or retry.
  Future<ConversationInitiationMetadata> connect() async {
    _ensureNotDisposed();
    if (_state != ConvAiConnectionState.disconnected) {
      throw StateError(
        'Cannot connect while state is ${_state.name}; call disconnect() first.',
      );
    }

    _shouldStayConnected = true;
    await _ensureLocalSessionId();
    return _openSession(isReconnectAttempt: false);
  }

  /// Sends a user text message and completes with the agent's reply text once
  /// the matching `agent_response` event arrives.
  ///
  /// Concurrent calls are serialized; each resolves against its own turn.
  /// An unanswered send is retried automatically up to
  /// [ConvAiConfig.maxResponseRetries] times before the turn fails with
  /// [TimeoutException]. Throws [ConvAiRateLimitException] once the session's
  /// turn budget is exhausted, and [StateError] when the connection drops
  /// before the exchange completes.
  Future<String> sendMessage(String text) {
    if (!_shouldStayConnected) {
      throw StateError('sendMessage called before connect().');
    }
    if (!isConnected) {
      throw StateError(
        'Cannot send while state is ${_state.name}; wait for connected.',
      );
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Message must not be empty.');
    }

    // Serialize turns so responses never interleave between callers.
    final result = _sendQueue.then(
      (_) => _guardedRoundTrip(trimmed),
    );
    // Keep the queue alive even when a turn fails.
    _sendQueue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  /// Drops the current session and stops reconnection. Safe to call from any
  /// state; safe to call repeatedly. The persisted session id survives unless
  /// [resetSession] is called.
  Future<void> disconnect() async {
    _shouldStayConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _failPendingTurns('client disconnected');
    await _teardownSocket();
    _setState(ConvAiConnectionState.disconnected);
  }

  /// Clears the persisted session UUID and resets the in-memory budget so
  /// the next [connect] starts a brand new logical session. Persisted turn
  /// counts stay keyed by their own conversations.
  Future<void> resetSession() async {
    _localSessionId = null;
    _turnLimiter = ConvAiTurnRateLimiter(maxTurns: _config.maxSessionTurns);
    await _sessionStore?.clearSessionId();
  }

  /// Disconnects (if needed) and releases all streams. The client is unusable
  /// afterwards.
  Future<void> dispose() async {
    if (_disposed) return;
    await disconnect();
    _disposed = true;
    await _stateController.close();
    await _eventController.close();
  }

  // ---------------------------------------------------------------------------
  // Session open / teardown / reconnect
  // ---------------------------------------------------------------------------

  Future<ConversationInitiationMetadata> _openSession({
    required bool isReconnectAttempt,
  }) async {
    _openingSession = true;
    Object? failure;
    try {
      _setState(
        isReconnectAttempt
            ? ConvAiConnectionState.reconnecting
            : ConvAiConnectionState.connecting,
      );

      final uri = _buildSocketUri();
      final channel = openConvAiSocket(
        uri,
        _config.usesSignedCredentials ? null : <String, String>{
          'xi-api-key': _config.apiKey,
        },
      );
      await channel.ready.timeout(_config.connectTimeout);

      _channel = channel;
      _listen(channel);
      channel.sink.add(ConvAiEventCodec.encodeInitiationData());

      final handshake = Completer<ConversationInitiationMetadata>();
      _initiationCompleter = handshake;
      final metadata = await handshake.future
          .timeout(_config.initiationTimeout)
          .whenComplete(() {
        if (identical(_initiationCompleter, handshake)) {
          _initiationCompleter = null;
        }
      });

      _serverConversationId = metadata.conversationId;
      _reconnectAttempt = 0;
      // Budget scope is only known after the handshake pins the conversation
      // id, so restore here — resuming the same conversation keeps its spent
      // turns; any other conversation starts fresh.
      await _restoreTurnBudget();
      _setState(ConvAiConnectionState.connected);
      return metadata;
    } on ConvAiConfigException catch (error) {
      // Configuration mistakes surface typed and terminal: wrapping them as
      // a connection failure would misclassify a setup problem and invite
      // pointless reconnect loops against an endpoint that can never succeed.
      _shouldStayConnected = false;
      failure = error;
      _lastError = error;
      await _teardownSocket();
      rethrow;
    } on Object catch (error) {
      failure = error;
      _lastError = error;
      await _teardownSocket();
      throw ConvAiConnectionException('Failed to open ConvAI session: $error');
    } finally {
      // Clear the in-flight flag BEFORE recovery bookkeeping: a failed
      // reconnect attempt must be able to schedule its own successor, while
      // the unexpected-close handler that observed the same drop was already
      // suppressed by this flag — so the failure is counted exactly once.
      _openingSession = false;
      if (failure != null) {
        if (_shouldStayConnected && isReconnectAttempt) {
          _scheduleReconnect();
        } else {
          _setState(ConvAiConnectionState.disconnected);
        }
      }
    }
  }

  Uri _buildSocketUri() {
    final Uri uri;
    if (_config.usesSignedUrl) {
      uri = Uri.parse(_config.signedUrl);
    } else if (_config.token.isNotEmpty) {
      final parsed = Uri.parse(_config.endpoint);
      uri = parsed.replace(
        queryParameters: <String, dynamic>{
          ...parsed.queryParameters,
          'token': _config.token,
          if (_config.agentId.isNotEmpty) 'agent_id': _config.agentId,
        },
      );
    } else {
      final rawUri = _config.endpoint;
      final parsed = Uri.parse(rawUri);
      if (parsed.scheme != 'wss' && parsed.scheme != 'ws') {
        throw ArgumentError.value(
          rawUri,
          'endpoint',
          'Expected a ws:// or wss:// WebSocket URI.',
        );
      }
      uri = parsed.replace(
        queryParameters: <String, dynamic>{
          ...parsed.queryParameters,
          'agent_id': _config.agentId,
        },
      );
    }
    // Every mode puts credentials on the wire — token/signed-URL in the query
    // or the reusable key in the xi-api-key header — so the transport is
    // guarded exactly once, on the URI actually opened.
    _config.ensureSecureTransport(uri);
    return uri;
  }

  void _listen(WebSocketChannel channel) {
    _socketSubscription = channel.stream.listen(
      _onFrame,
      onError: (Object error) {
        _lastError = error;
        _handleUnexpectedClose();
      },
      onDone: () => _handleUnexpectedClose(),
      cancelOnError: true,
    );
  }

  Future<void> _handleUnexpectedClose() async {
    if (_disposed || !_shouldStayConnected) return;
    if (_state != ConvAiConnectionState.connected &&
        _state != ConvAiConnectionState.reconnecting) {
      // The initial handshake owns its own error path via _openSession.
      return;
    }
    _failPendingTurns('connection closed${_lastError == null ? '' : ': $_lastError'}');
    await _teardownSocket();
    _scheduleReconnect();
  }

  /// Schedules the next reconnect attempt with exponential backoff.
  ///
  /// Idempotent: an unexpected close and the handshake-failure path can both
  /// observe the same drop (a socket dying before the initiation handshake
  /// completes), but only the first call wins — any later call while a retry
  /// is already pending is ignored. While a session open is still in flight
  /// it owns recovery entirely, so the same failure is counted exactly once,
  /// competing sessions are never spawned, and retries cannot exhaust early.
  void _scheduleReconnect() {
    if (_disposed || !_shouldStayConnected) return;
    if (_openingSession) return; // In-flight open schedules the next attempt.
    final pending = _reconnectTimer;
    if (pending != null && pending.isActive) return;
    if (_reconnectAttempt >= _config.maxReconnectAttempts) {
      _shouldStayConnected = false;
      _setState(ConvAiConnectionState.disconnected);
      return;
    }

    final delay = _backoffDelay(_reconnectAttempt);
    _reconnectAttempt += 1;
    _setState(ConvAiConnectionState.reconnecting);

    _reconnectTimer = Timer(delay, () async {
      _reconnectTimer = null;
      if (_disposed || !_shouldStayConnected) return;
      // Never overlap session opens: an in-flight attempt (still awaiting
      // its connect/handshake timeout) owns recovery and will schedule the
      // next retry itself.
      if (_openingSession) return;
      try {
        await _openSession(isReconnectAttempt: true);
      } on ConvAiConnectionException {
        // _openSession already scheduled the next attempt or gave up.
      }
    });
  }

  Duration _backoffDelay(int attempt) {
    final cappedShift = min(attempt, 16);
    final exponential =
        _config.initialBackoff.inMilliseconds * (1 << cappedShift);
    final bounded = min(exponential, _config.maxBackoff.inMilliseconds);
    // Jitter spreads retry storms across clients (25% ceiling).
    final jitterFactor = 1.0 + _random.nextDouble() * 0.25;
    return Duration(milliseconds: (bounded * jitterFactor).round());
  }

  Future<void> _teardownSocket() async {
    _socketSubscription?.cancel();
    _socketSubscription = null;
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        // normalClosure (1000) is the only standard code every backend
        // accepts; goingAway (1001) is rejected by web_socket_channel.
        await channel.sink.close(ws_status.normalClosure);
      } on Object {
        // Socket may already be dead; teardown must never throw.
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Frame routing
  // ---------------------------------------------------------------------------

  void _onFrame(dynamic data) {
    if (data is! String) return; // Text-protocol slice ignores binary frames.

    final ConvAiEvent event;
    try {
      event = ConvAiEventCodec.decode(data);
    } on ConvAiProtocolException catch (error) {
      // A frame we cannot parse means the transport is no longer trustworthy.
      _lastError = error;
      _handleUnexpectedClose();
      return;
    }

    switch (event) {
      case final PingReceived ping:
        _sendOrDrop(ConvAiEventCodec.encodePong(ping.eventId));
      case final ConversationInitiationMetadata metadata:
        _initiationCompleter?.complete(metadata);
      case final AgentResponse response:
        _completeResponseTurn(response);
      case AgentResponseCorrection():
      case UserTranscript():
      case AudioChunkReceived():
      case InterruptionReceived():
      case VadScoreReceived():
      case UnknownConvAiEvent():
        break;
    }

    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Completes the active send's reply wait.
  ///
  /// Per-send correlation rules:
  /// - Only a reply observed while the matching send generation is still the
  ///   active slot counts; replies belonging to superseded sends (or arriving
  ///   while nobody waits) are ignored as stale.
  /// - Complete-once: an already-resolved slot — failed by
  ///   [_failPendingTurns] on disconnect, or satisfied by a duplicate frame —
  ///   is never completed again. Completing twice would throw inside the
  ///   socket listener and tear down the stream subscription.
  void _completeResponseTurn(AgentResponse response) {
    final completer = _responseCompleter;
    if (completer == null || _responseGeneration != _sendGeneration) {
      return; // No active wait, or a reply from a superseded send.
    }
    if (completer.isCompleted) return;
    completer.complete(response);
  }

  void _sendOrDrop(String payload) {
    try {
      _channel?.sink.add(payload);
    } on Object catch (error) {
      _lastError = error;
    }
  }

  // ---------------------------------------------------------------------------
  // Round-trip plumbing
  // ---------------------------------------------------------------------------

  /// Enforces the turn budget, consumes one turn, persists the count, then
  /// performs the exchange (with timeout retries).
  Future<String> _guardedRoundTrip(String text) async {
    _turnLimiter.ensureCanSend();
    _turnLimiter.recordTurn();
    await _persistTurnCount();
    return _roundTrip(text);
  }

  /// Conversation whose budget this client is tracking: the server
  /// conversation id once known, else the local session UUID pre-handshake.
  String? get _budgetScopeId => _serverConversationId ?? _localSessionId;

  Future<void> _persistTurnCount() async {
    final scopeId = _budgetScopeId;
    final store = _sessionStore;
    if (scopeId == null || store == null) return;
    await store.saveTurnCount(scopeId, _turnLimiter.turnsUsed);
  }

  Future<String> _roundTrip(String text) async {
    var attempt = 0;
    while (true) {
      final completer = Completer<AgentResponse>();
      // Each physical send owns a fresh generation, so replies are attributed
      // to exactly one wait and a resend can never inherit the timed-out
      // attempt's pending state.
      final generation = ++_sendGeneration;
      _responseCompleter = completer;
      _responseGeneration = generation;
      try {
        _sendOrDrop(ConvAiEventCodec.encodeUserMessage(text));
        final response =
            await completer.future.timeout(_config.responseTimeout);
        return response.text;
      } on TimeoutException {
        // Detach BEFORE retry bookkeeping: a late reply to this timed-out
        // send must never satisfy the next wait nor re-complete a resolved
        // slot inside the socket listener.
        _detachResponseSlot(completer);
        attempt += 1;
        if (attempt > _config.maxResponseRetries) {
          final attempts = attempt;
          final detailed = TimeoutException(
            'No agent_response within '
            '${_config.responseTimeout.inSeconds}s '
            '($attempts ${attempts == 1 ? 'attempt' : 'attempts'}).',
            _config.responseTimeout,
          );
          _lastError = detailed;
          throw detailed;
        }
        // One identical resend of the same turn; the budget was already
        // consumed once and a retry is not a new turn.
      } finally {
        _detachResponseSlot(completer);
      }
    }
  }

  void _detachResponseSlot(Completer<AgentResponse> completer) {
    if (!identical(_responseCompleter, completer)) return;
    _responseCompleter = null;
    _responseGeneration = null;
  }

  void _failPendingTurns(String reason) {
    final initiation = _initiationCompleter;
    if (initiation != null && !initiation.isCompleted) {
      initiation.completeError(StateError(reason));
    }
    final response = _responseCompleter;
    if (response != null && !response.isCompleted) {
      response.completeError(StateError(reason));
    }
  }

  // ---------------------------------------------------------------------------
  // Guards & helpers
  // ---------------------------------------------------------------------------

  Future<void> _ensureLocalSessionId() async {
    if (_localSessionId != null) return;
    final store = _sessionStore;
    final persisted = store == null ? null : await store.loadSessionId();
    _localSessionId =
        (persisted == null || persisted.isEmpty) ? _uuid.v4() : persisted;
    await store?.saveSessionId(_localSessionId!);
  }

  /// Re-seeds the turn budget from persisted storage for THIS conversation,
  /// so resuming the same conversation keeps its spent turns while starting
  /// any other conversation begins with a full budget. Called after the
  /// handshake has pinned the conversation-scoped budget id.
  Future<void> _restoreTurnBudget() async {
    final scopeId = _budgetScopeId;
    final store = _sessionStore;
    if (scopeId == null || store == null) return;
    final persisted = await store.loadTurnCount(scopeId);
    if (persisted <= 0) return;
    // Clamp so a lowered config cap cannot resurrect a negative remaining
    // count; an already-exhausted budget stays exhausted.
    _turnLimiter = ConvAiTurnRateLimiter(
      maxTurns: _config.maxSessionTurns,
      turnsUsed: min(persisted, _config.maxSessionTurns),
    );
  }

  void _setState(ConvAiConnectionState next) {
    if (_state == next) return;
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('ConvAiWebSocketClient has been disposed.');
    }
  }
}
