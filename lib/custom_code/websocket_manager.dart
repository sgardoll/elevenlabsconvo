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

  // Configuration - Using Conversational AI 2.0 endpoint
  static const _baseUrl = 'wss://api.elevenlabs.io/v1/convai/conversation';
  String _apiKey = '';
  String _agentId = '';
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  bool _initialized = false;
  String? _conversationId;

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
        '🔌 Initializing WebSocket with Conversational AI 2.0 - apiKey: ${apiKey.substring(0, 10)}... and agentId: $agentId');
    _apiKey = apiKey;
    _agentId = agentId;
    await _connect();
    _initialized = true;
  }

  Future<void> _connect() async {
    debugPrint('🔌 Connecting to Conversational AI 2.0 WebSocket...');
    _stateController.add(WebSocketConnectionState.connecting);

    try {
      // Conversational AI 2.0 endpoint with agent_id parameter
      final uri =
          Uri.parse('$_baseUrl?agent_id=${Uri.encodeComponent(_agentId)}');

      debugPrint('🔌 Connecting to: $uri');

      // API key in headers for secure authentication
      _channel = IOWebSocketChannel.connect(
        uri,
        headers: {
          'xi-api-key': _apiKey,
          'User-Agent': 'ElevenLabs-Flutter-SDK/2.0',
        },
      );

      debugPrint(
          '🔌 WebSocket connected, setting up listeners for Conversational AI 2.0');
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      debugPrint('🔌 Sending Conversational AI 2.0 initialization message');
      _sendInitialization();
      _stateController.add(WebSocketConnectionState.connected);
      _reconnectAttempts = 0;
    } catch (e) {
      debugPrint('🔌 Error connecting to Conversational AI 2.0 WebSocket: $e');
      _handleError(e);
    }
  }

  void _sendInitialization() {
    // Conversational AI 2.0 initialization with enhanced features
    final initMessage = jsonEncode({
      'type': 'conversation_initiation_client_data',
      'conversation_config_override': {
        'agent': {
          'language': 'en',
          // Enable Conversational AI 2.0 features
          'turn_detection': {
            'type':
                'server_vad', // Use server-side voice activity detection for better turn-taking
          }
        },
        'tts': {
          // Leverage improved voice synthesis in v2.0
          'model':
              'eleven_turbo_v2_5', // Use latest v2.5 model for better performance
        }
      },
      // Enable multimodal capabilities (Conversational AI 2.0 feature)
      'conversation_config': {
        'modalities': [
          'audio'
        ], // Can be extended to ['audio', 'text'] for multimodal
      }
    });
    debugPrint('🔌 Sending Conversational AI 2.0 initialization: $initMessage');
    _channel!.sink.add(initMessage);
  }

  void _handleMessage(dynamic message) {
    try {
      debugPrint(
          '🔌 Received Conversational AI 2.0 message: ${message.toString().substring(0, math.min(200, message.toString().length))}...');
      final jsonData = jsonDecode(message);

      // Handle Conversational AI 2.0 message types
      switch (jsonData['type']) {
        case 'conversation_initiation_metadata':
          // Store conversation ID for advanced v2.0 features
          _conversationId = jsonData['conversation_initiation_metadata_event']
              ?['conversation_id'];
          debugPrint('🔌 Conversation ID: $_conversationId');
          break;

        case 'audio':
          if (jsonData['audio_event'] != null) {
            debugPrint(
                '🔌 Received enhanced audio data from Conversational AI 2.0');
            final audioBytes =
                base64Decode(jsonData['audio_event']['audio_base_64']);
            _audioController.add(Uint8List.fromList(audioBytes));
          }
          break;

        case 'user_transcript':
          debugPrint(
              '🔌 User transcript: ${jsonData['user_transcription_event']?['user_transcript']}');
          break;

        case 'agent_response':
          debugPrint(
              '🔌 Agent response: ${jsonData['agent_response_event']?['agent_response']}');
          break;

        case 'vad_score':
          // Voice Activity Detection score from Conversational AI 2.0
          final vadScore = jsonData['vad_score_event']?['vad_score'];
          debugPrint('🔌 VAD Score: $vadScore');
          break;

        case 'ping':
          // Handle ping-pong for connection health
          debugPrint('🔌 Received ping, sending pong');
          final pongMessage = jsonEncode(
              {'type': 'pong', 'event_id': jsonData['ping_event']['event_id']});
          _channel!.sink.add(pongMessage);
          break;

        case 'interruption':
          debugPrint(
              '🔌 Conversation interrupted: ${jsonData['interruption_event']?['reason']}');
          break;

        case 'client_tool_call':
          // Advanced Conversational AI 2.0 feature for tool integration
          debugPrint(
              '🔌 Tool call received: ${jsonData['client_tool_call']?['tool_name']}');
          break;

        default:
          debugPrint('🔌 Unknown message type: ${jsonData['type']}');
      }

      _messageController.add(jsonData);
    } catch (e) {
      debugPrint(
          '🔌 Error handling Conversational AI 2.0 WebSocket message: $e');
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
      debugPrint(
          '🔌 Sending audio chunk to Conversational AI 2.0: ${audioData.length} bytes');

      // Conversational AI 2.0 audio format
      final audioMessage = jsonEncode({
        'user_audio_chunk': base64Audio,
      });

      _channel!.sink.add(audioMessage);
      debugPrint('🔌 Audio chunk sent successfully to Conversational AI 2.0');
    } catch (e) {
      debugPrint('🔌 Error sending audio chunk to Conversational AI 2.0: $e');
      _handleError(e);
    }
  }

  // Send text message (Conversational AI 2.0 multimodal feature)
  Future<void> sendTextMessage(String text) async {
    if (_channel?.closeCode != null) {
      debugPrint('🔌 WebSocket is closed, cannot send text message');
      return;
    }

    try {
      final textMessage = jsonEncode({'type': 'user_message', 'text': text});
      _channel!.sink.add(textMessage);
      debugPrint('🔌 Text message sent: $text');
    } catch (e) {
      debugPrint('🔌 Error sending text message: $e');
      _handleError(e);
    }
  }

  // Conversational AI 2.0 contextual updates for better conversation flow
  Future<void> sendContextualUpdate(String text) async {
    if (_channel?.closeCode != null) {
      debugPrint('🔌 WebSocket is closed, cannot send contextual update');
      return;
    }

    try {
      final updateMessage =
          jsonEncode({'type': 'contextual_update', 'text': text});
      _channel!.sink.add(updateMessage);
      debugPrint('🔌 Contextual update sent: $text');
    } catch (e) {
      debugPrint('🔌 Error sending contextual update: $e');
      _handleError(e);
    }
  }

  // Send user activity signal (Conversational AI 2.0 feature)
  Future<void> sendUserActivity() async {
    if (_channel?.closeCode != null) {
      debugPrint('🔌 WebSocket is closed, cannot send user activity');
      return;
    }

    try {
      final activityMessage = jsonEncode({
        'type': 'user_activity',
      });
      _channel!.sink.add(activityMessage);
      debugPrint('🔌 User activity signal sent');
    } catch (e) {
      debugPrint('🔌 Error sending user activity: $e');
      _handleError(e);
    }
  }

  // Tool result response (Conversational AI 2.0 advanced feature)
  Future<void> sendToolResult(String toolCallId, Map<String, dynamic> result,
      {bool isError = false}) async {
    if (_channel?.closeCode != null) {
      debugPrint('🔌 WebSocket is closed, cannot send tool result');
      return;
    }

    try {
      final toolResultMessage = jsonEncode({
        'type': 'client_tool_result',
        'tool_call_id': toolCallId,
        'result': result,
        'is_error': isError
      });
      _channel!.sink.add(toolResultMessage);
      debugPrint('🔌 Tool result sent for call ID: $toolCallId');
    } catch (e) {
      debugPrint('🔌 Error sending tool result: $e');
      _handleError(e);
    }
  }

  void _handleError(dynamic error) {
    debugPrint('🔌 Conversational AI 2.0 WebSocket error: $error');
    _stateController.add(WebSocketConnectionState.error);
    _scheduleReconnect();
    _messageController.addError(error);
  }

  void _handleDisconnect() {
    debugPrint('🔌 Conversational AI 2.0 WebSocket disconnected');
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
    debugPrint('🔌 Closing Conversational AI 2.0 WebSocket connection');
    await _channel?.sink.close(1000, 'Normal closure');
    await _messageController.close();
    await _audioController.close();
    await _stateController.close();
    _reconnectTimer?.cancel();
    _conversationId = null;
  }
}
