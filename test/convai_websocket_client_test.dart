import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:eleven_labs_conversational_a_i_library/convai/convai_config.dart';
import 'package:eleven_labs_conversational_a_i_library/convai/convai_websocket_client.dart';

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
        );
  return ConvAiWebSocketClient(config: config);
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
  });
}
