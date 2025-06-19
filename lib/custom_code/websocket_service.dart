import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:flutter/foundation.dart';
import 'conversation_state_manager.dart';
import 'audio_service.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  final _stateManager = ConversationStateManager();
  final _audioService = AudioService();

  // Configuration
  static const _baseUrl = 'wss://api.elevenlabs.io/v1/convai/conversation';
  String _apiKey = '';
  String _agentId = '';
  String? _conversationId;

  // Reconnection logic
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;
  bool _isManuallyClosing = false;

  // Continuous audio streaming
  Timer? _continuousAudioTimer;
  bool _userCurrentlySpeaking = false;
  DateTime? _lastInterruptionTime;
  DateTime? _lastAudioSent;

  // Audio format constants
  static const int _sampleRate = 16000;
  static const int _bytesPerSample = 2; // 16-bit
  static const int _silenceDurationMs = 250;
  static const int _silenceChunkSize =
      (_sampleRate * _silenceDurationMs * _bytesPerSample) ~/ 1000;

  // Initialize and connect
  Future<void> initialize({
    required String apiKey,
    required String agentId,
  }) async {
    debugPrint('🔌 Initializing WebSocket service');
    _apiKey = apiKey;
    _agentId = agentId;

    // Initialize audio service first
    await _audioService.initialize();
    await connect();
  }

  Future<void> connect() async {
    if (_channel != null && _channel!.closeCode == null) return;

    _isManuallyClosing = false;
    _stateManager.updateConversationState(ConversationState.connecting);

    try {
      // Add extended timeout to prevent premature disconnection
      final uri = Uri.parse(
          '$_baseUrl?agent_id=${Uri.encodeComponent(_agentId)}&inactivity_timeout=180');

      _channel = IOWebSocketChannel.connect(
        uri,
        headers: {'xi-api-key': _apiKey},
      );

      _channel!.stream.listen(_handleMessage,
          onError: _handleError, onDone: _handleDisconnect);

      _sendInitialization();
      _stateManager.updateConnectionStatus(true);
      _reconnectAttempts = 0;

      // Start continuous audio streaming
      _startContinuousAudioStream();
    } catch (e) {
      _handleError(e);
    }
  }

  void _sendInitialization() {
    final initMessage = {
      'type': 'conversation_initiation_client_data',
      'conversation_config_override': {
        'agent': {
          'language': 'en',
          'turn_detection': {
            'type': 'server_vad',
            'threshold': 0.6, // Slightly lower threshold for better detection
            'silence_duration_ms':
                1000, // Reduced for more responsive detection
            'prefix_padding_ms': 200
          }
        },
        'tts': {
          'model': 'eleven_flash_v2_5', // Better for streaming than turbo
          'voice': {'stability': 0.5, 'similarity_boost': 0.75}
        },
        'audio': {'input_format': 'pcm_16000', 'output_format': 'pcm_16000'}
      }
    };
    _send(jsonEncode(initMessage));
  }

  void _startContinuousAudioStream() {
    debugPrint('🎙️ Starting continuous audio stream');

    // Send audio or silence every 250ms to maintain connection
    _continuousAudioTimer?.cancel();
    _continuousAudioTimer = Timer.periodic(
        Duration(milliseconds: _silenceDurationMs),
        (timer) => _maintainAudioStream());
  }

  void _maintainAudioStream() {
    final now = DateTime.now();

    // Send silence if no real audio was sent recently
    if (_lastAudioSent == null ||
        now.difference(_lastAudioSent!).inMilliseconds > _silenceDurationMs) {
      _sendSilenceChunk();
    }
  }

  void _sendSilenceChunk() {
    if (_channel == null || _channel!.closeCode != null) return;

    // Create silence chunk: 16kHz, 16-bit PCM, mono for 250ms
    final silenceData = Uint8List(_silenceChunkSize);
    final base64Silence = base64Encode(silenceData);

    _send(jsonEncode({
      'user_audio_chunk': base64Silence,
    }));

    _lastAudioSent = DateTime.now();
  }

  void _handleMessage(dynamic message) async {
    try {
      final data = jsonDecode(message);

      switch (data['type']) {
        case 'conversation_initiation_metadata':
          _conversationId = data['conversation_initiation_metadata_event']
              ?['conversation_id'];
          debugPrint('🔌 Conversation started: $_conversationId');
          _stateManager.updateConversationState(ConversationState.idle);
          break;

        case 'audio':
          final audioData = data['audio_event']?['audio_base_64'];
          if (audioData != null && audioData.isNotEmpty) {
            debugPrint('🔊 Received audio chunk: ${audioData.length} chars');
            final audioBytes = base64Decode(audioData);
            _audioService.addAudioChunk(audioBytes);
          }
          break;

        case 'agent_response_complete':
          debugPrint('✅ Agent response complete');
          _audioService.markResponseComplete();
          break;

        case 'interruption':
          debugPrint('🛑 Interruption acknowledged by server');
          _stateManager.interruptionAcknowledged();
          break;

        case 'vad_score':
          final vadScore = data['vad_score_event']?['vad_score'] ?? 0.0;
          _stateManager.updateVadScore(vadScore);

          // Use VAD score to determine speech state with hysteresis
          if (vadScore > 0.7 && !_userCurrentlySpeaking) {
            _userCurrentlySpeaking = true;
            debugPrint(
                '🎤 Server VAD: User started speaking (score: $vadScore)');

            if (_stateManager.conversationState ==
                ConversationState.agentSpeaking) {
              final now = DateTime.now();
              if (_lastInterruptionTime == null ||
                  now.difference(_lastInterruptionTime!).inMilliseconds >
                      1000) {
                debugPrint('🛑 Barge-in detected! Interrupting agent.');
                _lastInterruptionTime = now;
                await _audioService.stopPlayback(clearBuffer: true);
                _send(jsonEncode({'type': 'user_interrupt'}));
              }
            }
            _stateManager.userStartedSpeaking();
          } else if (vadScore < 0.3 && _userCurrentlySpeaking) {
            _userCurrentlySpeaking = false;
            debugPrint(
                '🎤 Server VAD: User finished speaking (score: $vadScore)');
            _stateManager.userFinishedSpeaking();
          }
          break;

        case 'user_transcript':
          final transcript = data['user_transcript_event']?['text'];
          if (transcript != null && transcript.isNotEmpty) {
            debugPrint('📝 User: $transcript');
          }
          break;

        case 'agent_response':
          final agentResponse = data['agent_response_event']?['agent_response'];
          if (agentResponse != null && agentResponse.isNotEmpty) {
            debugPrint('🤖 Agent: $agentResponse');
          }
          break;

        case 'ping':
          // CRITICAL: Respond to pings immediately to maintain connection
          final eventId = data['ping_event']?['event_id'];
          if (eventId != null) {
            _send(jsonEncode({'type': 'pong', 'event_id': eventId}));
            debugPrint('🏓 Responded to ping: $eventId');
          }
          break;

        case 'error':
          final error = data['error'] ?? 'Unknown WebSocket error';
          debugPrint('❌ Server error: $error');
          _stateManager.reportError('Server error: $error');
          break;

        default:
          debugPrint('ℹ️ Unhandled message type: ${data['type']}');
          break;
      }
    } catch (e) {
      debugPrint('❌ Error handling message: $e');
    }
  }

  void sendAudio(Uint8List data) {
    if (_channel != null && _channel!.closeCode == null) {
      // Ensure audio is in correct format (16kHz, 16-bit PCM)
      final formattedAudio = _ensureCorrectAudioFormat(data);
      final base64Audio = base64Encode(formattedAudio);

      _send(jsonEncode({
        'user_audio_chunk': base64Audio,
      }));

      _lastAudioSent = DateTime.now();
    }
  }

  Uint8List _ensureCorrectAudioFormat(Uint8List audioData) {
    // Ensure audio is 16-bit PCM (even number of bytes)
    if (audioData.length % 2 != 0) {
      // Pad with a zero byte if odd length
      final paddedData = Uint8List(audioData.length + 1);
      paddedData.setRange(0, audioData.length, audioData);
      paddedData[audioData.length] = 0;
      return paddedData;
    }
    return audioData;
  }

  Future<void> interruptAgent() async {
    if (!_stateManager.isConnected) return;
    debugPrint('🛑 Interrupting agent');

    await _audioService.stopPlayback(clearBuffer: true);
    _send(jsonEncode({'type': 'user_interrupt'}));
  }

  void _send(String message) {
    if (_channel != null && _channel!.closeCode == null) {
      try {
        _channel!.sink.add(message);
      } catch (e) {
        debugPrint('❌ Error sending message: $e');
      }
    }
  }

  void _handleError(dynamic error) {
    debugPrint('🔌 WebSocket error: $error');
    if (!_isManuallyClosing) {
      _stateManager.reportError(error.toString());
      _scheduleReconnect();
    }
  }

  void _handleDisconnect() {
    debugPrint('🔌 WebSocket disconnected');
    _stateManager.updateConnectionStatus(false);

    // Stop continuous audio streaming
    _continuousAudioTimer?.cancel();

    // Reset VAD state tracking
    _userCurrentlySpeaking = false;
    _lastInterruptionTime = null;
    _lastAudioSent = null;

    if (!_isManuallyClosing) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('❌ Max reconnection attempts reached');
      _stateManager.reportError(
          'Connection failed after $_maxReconnectAttempts attempts');
      return;
    }

    _reconnectTimer?.cancel();
    final delay = Duration(seconds: 1 + _reconnectAttempts);
    debugPrint(
        '🔄 Scheduling reconnect in ${delay.inSeconds} seconds (attempt ${_reconnectAttempts + 1})');

    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      connect();
    });
  }

  Future<void> disconnect() async {
    debugPrint('🔌 Disconnecting WebSocket');
    _isManuallyClosing = true;

    _reconnectTimer?.cancel();
    _continuousAudioTimer?.cancel();

    await _channel?.sink.close();
    _channel = null;

    _stateManager.updateConnectionStatus(false);

    // Reset state
    _userCurrentlySpeaking = false;
    _lastInterruptionTime = null;
    _lastAudioSent = null;
    _conversationId = null;
  }

  void dispose() {
    disconnect();
  }
}
