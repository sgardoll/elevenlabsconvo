import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:eleven_labs_conversational_a_i_library/convai/convai_config.dart';
import 'package:eleven_labs_conversational_a_i_library/convai/convai_websocket_client.dart';
import 'package:eleven_labs_conversational_a_i_library/convai/session_store.dart';
import 'package:eleven_labs_conversational_a_i_library/convai/turn_rate_limiter.dart';

/// Minimal ConvAI protocol server over a real loopback WebSocket, so client
/// lifecycle behavior (handshake, reconnect, drops) is exercised end-to-end.
class _TestConvAiServer {
  _TestConvAiServer();

  HttpServer? _httpServer;
  final List<WebSocket> _sockets = [];

  /// Total WebSocket connections accepted since start.
  int connections = 0;

  /// Peak number of simultaneously open sockets. More than one concurrent
  /// socket means the client spawned competing sessions.
  int peakConcurrent = 0;
  int _openSockets = 0;

  /// URIs of accepted upgrade requests, in order.
  final List<Uri> requestUris = [];

  /// Behavior for each new connection, keyed by its 1-based index. Defaults
  /// to completing the handshake and staying open.
  void Function(WebSocket socket, int index)? onConnection;

  /// Frame handler for every connection (after [onConnection] ran).
  void Function(WebSocket socket, dynamic data)? onMessage;

  Future<String> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _httpServer = server;
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      connections += 1;
      _openSockets += 1;
      if (_openSockets > peakConcurrent) peakConcurrent = _openSockets;
      requestUris.add(request.uri);
      final index = connections;
      _sockets.add(socket);
      final handler = onConnection;
      if (handler != null) handler(socket, index);
      socket.listen(
        (data) => onMessage?.call(socket, data),
        onDone: () => _openSockets -= 1,
      );
      if (handler == null) _completeHandshake(socket, 'conv_default');
    });
    return 'ws://localhost:${server.port}';
  }

  static void _completeHandshake(WebSocket socket, String conversationId) {
    socket.add(jsonEncode(<String, dynamic>{
      'type': 'conversation_initiation_metadata',
      'conversation_initiation_metadata_event': {
        'conversation_id': conversationId,
      },
    }));
  }

  Future<void> close() async {
    for (final socket in _sockets) {
      await socket.close().catchError((_) {});
    }
    await _httpServer?.close(force: true).catchError((_) {});
  }

  /// Closes every accepted socket while the HTTP listener stays up, so
  /// clients observe an unexpected mid-session drop.
  Future<void> closeSockets() async {
    for (final socket in List<WebSocket>.of(_sockets)) {
      await socket.close().catchError((_) {});
    }
  }
}

/// In-memory [ConvAiSessionStore] so budget persistence can be observed
/// across client instances without platform channels.
class _InMemorySessionStore implements ConvAiSessionStore {
  final Map<String, int> turnCounts = <String, int>{};
  String? sessionId;

  @override
  Future<String?> loadSessionId() async => sessionId;

  @override
  Future<void> saveSessionId(String sessionId) async => this.sessionId = sessionId;

  @override
  Future<void> clearSessionId() async => sessionId = null;

  @override
  Future<int> loadTurnCount(String conversationId) async =>
      turnCounts[conversationId] ?? 0;

  @override
  Future<void> saveTurnCount(String conversationId, int count) async =>
      turnCounts[conversationId] = count;
}

ConvAiWebSocketClient _clientFor(
  Uri endpoint, {
  String token = '',
  Duration connectTimeout = const Duration(seconds: 2),
  Duration initiationTimeout = const Duration(milliseconds: 300),
  Duration responseTimeout = const Duration(milliseconds: 200),
  Duration initialBackoff = const Duration(milliseconds: 10),
  Duration maxBackoff = const Duration(milliseconds: 40),
  int maxReconnectAttempts = 3,
  int? maxSessionTurns,
  ConvAiSessionStore? sessionStore,
}) {
  // Direct (xi-api-key) mode exists only through the test-only factory;
  // token mode uses the production constructor.
  final config = token.isEmpty
      ? ConvAiConfig.forTesting(
          apiKey: 'test-key',
          agentId: 'agent_test',
          endpoint: endpoint.toString(),
          // Loopback test sockets are plaintext ws://; opt in explicitly.
          allowInsecureTransport: true,
          connectTimeout: connectTimeout,
          initiationTimeout: initiationTimeout,
          responseTimeout: responseTimeout,
          initialBackoff: initialBackoff,
          maxBackoff: maxBackoff,
          maxReconnectAttempts: maxReconnectAttempts,
          maxSessionTurns: maxSessionTurns ?? 50,
        )
      : ConvAiConfig(
          token: token,
          agentId: 'agent_test',
          endpoint: endpoint.toString(),
          allowInsecureTransport: true,
          connectTimeout: connectTimeout,
          initiationTimeout: initiationTimeout,
          responseTimeout: responseTimeout,
          initialBackoff: initialBackoff,
          maxBackoff: maxBackoff,
          maxReconnectAttempts: maxReconnectAttempts,
          maxSessionTurns: maxSessionTurns ?? 50,
        );
  return ConvAiWebSocketClient(config: config, sessionStore: sessionStore);
}

Future<T> _waitFor<T>(
  FutureOr<T> Function() probe,
  bool Function(T) matches, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final value = await probe();
    if (matches(value)) return value;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Condition not met within ${timeout.inMilliseconds}ms');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _TestConvAiServer server;

  setUp(() async {
    server = _TestConvAiServer();
  });

  tearDown(() async {
    await server.close();
  });

  group('ConvAiWebSocketClient against a live loopback socket', () {
    test('completes a text round-trip in direct mode', () async {
      final endpoint = Uri.parse(await server.start());
      server.onConnection = (socket, index) {
        _TestConvAiServer._completeHandshake(socket, 'conv_$index');
      };
      server.onMessage = (socket, data) {
        final frame = jsonDecode(data as String) as Map<String, dynamic>;
        if (frame['type'] == 'user_message') {
          socket.add(jsonEncode(<String, dynamic>{
            'type': 'agent_response',
            'agent_response_event': {
              'agent_response': 'echo: ${frame['text']}',
              'event_id': 2,
            },
          }));
        }
      };

      final client = _clientFor(endpoint);
      addTearDown(client.dispose);

      await client.connect();
      expect(client.state, ConvAiConnectionState.connected);
      expect(client.conversationId, 'conv_1');

      final reply = await client.sendMessage('hello');
      expect(reply, 'echo: hello');
    });

    test('token mode attaches the short-lived token as a query parameter',
        () async {
      final endpoint = Uri.parse(await server.start());
      final client = _clientFor(endpoint, token: 'tok_short_lived');
      addTearDown(client.dispose);

      await client.connect();
      await _waitFor(
        () => server.requestUris.length,
        (count) => count >= 1,
      );

      expect(server.requestUris.first.queryParameters['token'],
          'tok_short_lived');
      expect(server.requestUris.first.queryParameters['agent_id'], 'agent_test');
    });

    test('a drop during a reconnect handshake schedules exactly one retry '
        '(no competing sessions, no double counting)', () async {
      final endpoint = Uri.parse(await server.start());
      const maxReconnects = 3;
      server.onConnection = (socket, index) {
        if (index == 1) {
          // First connection: full handshake, then drop while connected.
          _TestConvAiServer._completeHandshake(socket, 'conv_first');
          Future<void>.delayed(const Duration(milliseconds: 30)).then((_) {
            socket.close();
          });
          return;
        }
        // Reconnect attempts: die BEFORE the initiation handshake completes,
        // so both the unexpected-close path and the handshake-failure path
        // observe the same failure.
        Future<void>.delayed(const Duration(milliseconds: 5)).then((_) {
          socket.close();
        });
      };

      final client = _clientFor(endpoint, maxReconnectAttempts: maxReconnects);
      addTearDown(client.dispose);

      await client.connect();

      // Reconnect attempts exhaust -> terminal disconnected state.
      await _waitFor(
        () => client.state,
        (state) => state == ConvAiConnectionState.disconnected,
        timeout: const Duration(seconds: 10),
      );

      // Give any erroneously double-scheduled retry time to surface.
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(
        server.connections,
        1 + maxReconnects,
        reason:
            'Each dropped session must consume exactly one reconnect attempt; '
            'found ${server.connections} connections '
            '(initial + ${server.connections - 1} retries).',
      );
      // Competing sessions would show up as overlapping open sockets.
      expect(server.peakConcurrent, 1);
      // Terminal state must stick — no zombie session revived afterwards.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(client.state, ConvAiConnectionState.disconnected);
      expect(server.connections, 1 + maxReconnects);
    });

    test('a duplicate agent_response completes the turn once and never '
        'breaks the listener', () async {
      final endpoint = Uri.parse(await server.start());
      server.onConnection = (socket, index) {
        _TestConvAiServer._completeHandshake(socket, 'conv_$index');
      };
      server.onMessage = (socket, data) {
        final frame = jsonDecode(data as String) as Map<String, dynamic>;
        if (frame['type'] != 'user_message') return;
        // Two agent_response frames for one send: only the first may
        // complete the wait; the second must be ignored, not thrown on.
        socket.add(jsonEncode(<String, dynamic>{
          'type': 'agent_response',
          'agent_response_event': {'agent_response': 'first!', 'event_id': 2},
        }));
        socket.add(jsonEncode(<String, dynamic>{
          'type': 'agent_response',
          'agent_response_event': {'agent_response': 'second!', 'event_id': 3},
        }));
      };

      final client = _clientFor(endpoint);
      addTearDown(client.dispose);

      await client.connect();
      expect(await client.sendMessage('hello'), 'first!');

      // The socket listener survived the duplicate frame.
      expect(await client.sendMessage('again'), 'first!');
    });

    test('an unsolicited agent_response while idle never satisfies a later '
        'send', () async {
      final endpoint = Uri.parse(await server.start());
      server.onConnection = (socket, index) {
        _TestConvAiServer._completeHandshake(socket, 'conv_$index');
        // Stray reply pushed before any user message exists.
        socket.add(jsonEncode(<String, dynamic>{
          'type': 'agent_response',
          'agent_response_event': {'agent_response': 'STRAY', 'event_id': 1},
        }));
      };
      server.onMessage = (socket, data) {
        final frame = jsonDecode(data as String) as Map<String, dynamic>;
        if (frame['type'] == 'user_message') {
          socket.add(jsonEncode(<String, dynamic>{
            'type': 'agent_response',
            'agent_response_event': {
              'agent_response': 'echo: ${frame['text']}',
              'event_id': 2,
            },
          }));
        }
      };

      final client = _clientFor(endpoint);
      addTearDown(client.dispose);

      await client.connect();
      // Let the stray frame land while no turn is pending.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(await client.sendMessage('hello'), 'echo: hello');
    });

    test('a timed-out turn keeps its charge, never auto-resends, and the '
        'caller-driven retry hits the rate limit at cap', () async {
      final endpoint = Uri.parse(await server.start());
      var userMessages = 0;
      server.onConnection = (socket, index) {
        _TestConvAiServer._completeHandshake(socket, 'conv_$index');
      };
      server.onMessage = (socket, data) {
        final frame = jsonDecode(data as String) as Map<String, dynamic>;
        if (frame['type'] != 'user_message') return;
        userMessages += 1;
        // Only a SECOND dispatched frame would get an answer; the first
        // must time out.
        if (userMessages == 2) {
          socket.add(jsonEncode(<String, dynamic>{
            'type': 'agent_response',
            'agent_response_event': {
              'agent_response': 'echo: again',
              'event_id': 2,
            },
          }));
        }
      };

      final client = _clientFor(
        endpoint,
        responseTimeout: const Duration(milliseconds: 80),
        maxSessionTurns: 1,
      );
      addTearDown(client.dispose);

      await client.connect();

      // The turn fails immediately with a detailed TimeoutException carrying
      // the exact window and attempt count.
      await expectLater(
        client.sendMessage('hello'),
        throwsA(
          isA<TimeoutException>()
              .having((error) => error.message, 'message',
                  contains('1 attempt'))
              .having((error) => error.duration, 'duration',
                  const Duration(milliseconds: 80)),
        ),
      );
      // The detailed exception is also what the client records.
      expect(
        client.lastError,
        isA<TimeoutException>().having(
          (error) => error.message,
          'message',
          contains('1 attempt'),
        ),
      );

      // No in-client transparent resend: well past two timeout windows, the
      // server has seen exactly one user_message.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(userMessages, 1);

      // The turn WAS dispatched — the frame reached the socket and the
      // server counted it — so the budget charge STANDS despite the
      // timeout. With cap 1 the budget is now exhausted.
      expect(client.remainingTurns, 0,
          reason: 'A dispatched turn stays charged even on timeout.');

      // A caller-driven retry must pay a fresh turn; at the cap it is
      // refused BEFORE another frame can reach the wire.
      await expectLater(
        client.sendMessage('again'),
        throwsA(isA<ConvAiRateLimitException>()),
      );
      expect(userMessages, 1,
          reason: 'The rate-limited retry must not dispatch anything.');
    });

    test('only PRE-dispatch failures refund: dropped socket refunds the '
        'queued send while the dispatched one stays charged', () async {
      final endpoint = Uri.parse(await server.start());
      final firstFrameReceived = Completer<void>();
      server.onConnection = (socket, index) {
        _TestConvAiServer._completeHandshake(socket, 'conv_drop');
      };
      server.onMessage = (socket, data) {
        final frame = jsonDecode(data as String) as Map<String, dynamic>;
        if (frame['type'] == 'user_message' && !firstFrameReceived.isCompleted) {
          firstFrameReceived.complete();
        }
      };

      final client = _clientFor(endpoint, maxSessionTurns: 5);
      addTearDown(client.dispose);
      await client.connect();

      // Turn 1 dispatches and provably reaches the server...
      final dispatched = client.sendMessage('dispatched');
      // ...while turn 2 queues behind it while the connection is healthy.
      final queued = client.sendMessage('queued');

      await firstFrameReceived.future;

      // The server drops the connection: turn 1 fails POST-dispatch (its
      // charge stands), and the queued turn 2 then executes with no socket
      // left — a PRE-dispatch failure that refunds.
      await server.closeSockets();
      await expectLater(dispatched, throwsStateError);
      await expectLater(queued, throwsA(isA<ConvAiDispatchException>()));

      expect(client.remainingTurns, 4,
          reason: 'Exactly one of the two sends (the dispatched one) '
              'must stay charged.');
    });

    test('turn budget persists per conversation and resets for new ones',
        () async {
      final endpoint = Uri.parse(await server.start());
      const cap = 3;
      // Connections 1-2 resume the same conversation; connection 3 is new.
      server.onConnection = (socket, index) {
        _TestConvAiServer._completeHandshake(
          socket,
          index <= 2 ? 'conv_budget' : 'conv_fresh',
        );
      };
      server.onMessage = (socket, data) {
        final frame = jsonDecode(data as String) as Map<String, dynamic>;
        if (frame['type'] == 'user_message') {
          socket.add(jsonEncode(<String, dynamic>{
            'type': 'agent_response',
            'agent_response_event': {
              'agent_response': 'echo: ${frame['text']}',
              'event_id': 2,
            },
          }));
        }
      };

      final store = _InMemorySessionStore();

      // Session A burns two of three turns in conv_budget.
      final first = _clientFor(
        endpoint,
        maxSessionTurns: cap,
        sessionStore: store,
      );
      addTearDown(first.dispose);
      await first.connect();
      expect(first.conversationId, 'conv_budget');
      await first.sendMessage('one');
      await first.sendMessage('two');
      expect(first.remainingTurns, cap - 2);
      await first.disconnect();

      // App-restart simulation: a new client resuming conv_budget keeps its
      // spent budget.
      final resumed = _clientFor(
        endpoint,
        maxSessionTurns: cap,
        sessionStore: store,
      );
      addTearDown(resumed.dispose);
      await resumed.connect();
      expect(resumed.conversationId, 'conv_budget');
      expect(resumed.remainingTurns, cap - 2);
      await resumed.disconnect();

      // A NEW conversation must start with a full budget, not inherit
      // conv_budget's spent turns.
      final fresh = _clientFor(
        endpoint,
        maxSessionTurns: cap,
        sessionStore: store,
      );
      addTearDown(fresh.dispose);
      await fresh.connect();
      expect(fresh.conversationId, 'conv_fresh');
      expect(fresh.remainingTurns, cap);
    });
  });
}
