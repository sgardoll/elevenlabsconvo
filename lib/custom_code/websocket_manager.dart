import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:flutter/foundation.dart';

enum WebSocketConnectionState {
  connecting,
  connected,
  disconnected,
  reconnecting,
  error
}

class WebSocketManager {
  static final WebSocketManager _instance = WebSocketManager._internal();
  factory WebSocketManager() => _instance;
  WebSocketManager._internal();

  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _audioController = StreamController<Uint8List>.broadcast();
  final _stateController =
      StreamController<WebSocketConnectionState>.broadcast();

  // Configuration
  static const _baseUrl = 'wss://api.elevenlabs.io/v1/convai/conversation';
  String _apiKey = '';
  String _agentId = '';
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  bool _initialized = false;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Uint8List> get audioStream => _audioController.stream;
  Stream<WebSocketConnectionState> get stateStream => _stateController.stream;

  WebSocketConnectionState get currentState => _channel?.closeCode != null
      ? WebSocketConnectionState.disconnected
      : _initialized
          ? WebSocketConnectionState.connected
          : WebSocketConnectionState.disconnected;

  Future<void> initialize(
      {required String apiKey, required String agentId}) async {
    if (_apiKey == apiKey &&
        _agentId == agentId &&
        _initialized &&
        _channel?.closeCode == null) {
      debugPrint('🔌 WebSocket already initialized and connected');
      return;
    }

    debugPrint(
        '🔌 Initializing WebSocket with apiKey: ${apiKey.substring(0, 10)}... and agentId: $agentId');
    _apiKey = apiKey;
    _agentId = agentId;
    await _connect();
    _initialized = true;
  }

  Future<void> _connect() async {
    debugPrint('🔌 Connecting to WebSocket...');
    _stateController.add(WebSocketConnectionState.connecting);

    try {
      final uri =
          Uri.parse('$_baseUrl?xi-api-key=${Uri.encodeComponent(_apiKey)}');
      _channel = IOWebSocketChannel.connect(
        uri,
        protocols: ['json'],
      );

      debugPrint('🔌 WebSocket connected, setting up listeners');
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      debugPrint('🔌 Sending initialization message');
      _sendInitialization();
      _stateController.add(WebSocketConnectionState.connected);
      _reconnectAttempts = 0;
    } catch (e) {
      debugPrint('🔌 Error connecting to WebSocket: $e');
      _handleError(e);
    }
  }

  void _sendInitialization() {
    final initMessage = jsonEncode({
      'agent_id': _agentId,
      'model': 'eleven_monolingual_v2',
      'voice_settings': {'stability': 0.5, 'similarity_boost': 0.8}
    });
    debugPrint('🔌 Sending initialization message: $initMessage');
    _channel!.sink.add(initMessage);
  }

  void _handleMessage(dynamic message) {
    try {
      debugPrint('🔌 Received message from WebSocket');
      final jsonData = jsonDecode(message);

      if (jsonData['audio'] != null) {
        debugPrint('🔌 Received audio data from WebSocket');
        final audioBytes = base64Decode(jsonData['audio']);
        _audioController.add(Uint8List.fromList(audioBytes));
      }

      _messageController.add(jsonData);
    } catch (e) {
      debugPrint('🔌 Error handling WebSocket message: $e');
      _handleError(e);
    }
  }

  Future<void> sendAudioChunk(Uint8List audioData) async {
    if (_channel?.closeCode != null) {
      debugPrint(
          '🔌 WebSocket is closed, attempting to reconnect before sending audio');
      await _connect();
      if (_channel?.closeCode != null) {
        debugPrint('🔌 Failed to reconnect WebSocket, cannot send audio');
        return;
      }
    }

    try {
      final base64Audio = base64Encode(audioData);
      debugPrint('🔌 Sending audio chunk: ${audioData.length} bytes');
      final audioMessage = jsonEncode({
        'type': 'user_audio_chunk',
        'audio': base64Audio,
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });

      _channel!.sink.add(audioMessage);
      debugPrint('🔌 Audio chunk sent successfully');
    } catch (e) {
      debugPrint('🔌 Error sending audio chunk: $e');
      _handleError(e);
    }
  }

  void _handleError(dynamic error) {
    debugPrint('🔌 WebSocket error: $error');
    _stateController.add(WebSocketConnectionState.error);
    _scheduleReconnect();
    _messageController.addError(error);
  }

  void _handleDisconnect() {
    debugPrint('🔌 WebSocket disconnected');
    _stateController.add(WebSocketConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= 5) {
      debugPrint('🔌 Maximum reconnect attempts reached, giving up');
      return;
    }

    debugPrint('🔌 Scheduling reconnect attempt ${_reconnectAttempts + 1}/5');
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: math.pow(2, _reconnectAttempts).toInt());
    debugPrint('🔌 Will attempt to reconnect in ${delay.inSeconds} seconds');
    _reconnectTimer = Timer(delay, () => _connect());
    _reconnectAttempts++;
  }

  Future<void> close() async {
    debugPrint('🔌 Closing WebSocket connection');
    await _channel?.sink.close(1000, 'Normal closure');
    await _messageController.close();
    await _audioController.close();
    await _stateController.close();
    _reconnectTimer?.cancel();
  }
}
