import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:flutter/foundation.dart';
import 'widgets/auto_play_audio_response.dart';

enum WebSocketConnectionState {
  connecting,
  connected,
  disconnected,
  reconnecting,
  error,
  retryExhausted
}

enum ConversationState { idle, userSpeaking, agentSpeaking, processing }

// Enhanced error class for better error reporting
class WebSocketError {
  final String message;
  final String? details;
  final DateTime timestamp;
  final String errorType;
  
  WebSocketError({
    required this.message,
    this.details,
    required this.errorType,
  }) : timestamp = DateTime.now();
  
  @override
  String toString() => '$errorType: $message${details != null ? ' ($details)' : ''}';
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
  final _errorController = StreamController<WebSocketError>.broadcast();

  // Configuration - Using Conversational AI 2.0 endpoint
  static const _baseUrl = 'wss://api.elevenlabs.io/v1/convai/conversation';
  String _apiKey = '';
  String _agentId = '';
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _connectionTimeoutTimer;
  bool _initialized = false;
  String? _conversationId;
  WebSocketError? _lastError;

  // Enhanced retry configuration
  static const int _maxReconnectAttempts = 5;
  static const int _baseRetryDelaySeconds = 2;
  static const int _maxRetryDelaySeconds = 60;
  static const int _connectionTimeoutSeconds = 30;

  // Audio feedback prevention and turn management
  bool _isAgentSpeaking = false;
  bool _isUserSpeaking = false;
  bool _isRecordingPaused = false;
  ConversationState _conversationState = ConversationState.idle;
  Timer? _speechActivityTimer;
  bool _agentRecentlySpeaking = false;
  Timer? _agentGracePeriodTimer;

  final _feedbackController = StreamController<bool>.broadcast();
  final _userSpeakingController = StreamController<bool>.broadcast();
  final _conversationStateController =
      StreamController<ConversationState>.broadcast();

  // Voice activity detection
  double _audioThreshold = 0.01; // Threshold for detecting voice activity
  int _consecutiveSilentChunks = 0;
  int _consecutiveActiveChunks = 0;
  static const int _silenceThreshold = 15; // ~1.5 seconds at 10 chunks/sec
  static const int _speechThreshold = 3; // ~0.3 seconds to start speech

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Uint8List> get audioStream => _audioController.stream;
  Stream<WebSocketConnectionState> get stateStream => _stateController.stream;
  Stream<WebSocketError> get errorStream => _errorController.stream;
  Stream<bool> get agentSpeakingStream => _feedbackController.stream;
  Stream<bool> get userSpeakingStream => _userSpeakingController.stream;
  Stream<ConversationState> get conversationStateStream =>
      _conversationStateController.stream;

  bool get isAgentSpeaking => _isAgentSpeaking;
  bool get isUserSpeaking => _isUserSpeaking;
  bool get shouldPauseRecording => _isAgentSpeaking || _isRecordingPaused;
  ConversationState get conversationState => _conversationState;
  WebSocketError? get lastError => _lastError;

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
    _reconnectAttempts = 0; // Reset reconnect attempts on new initialization
    _lastError = null; // Clear any previous errors
    await _connect();
    _initialized = true;
  }

  Future<void> _connect() async {
    debugPrint('🔌 Connecting to Conversational AI 2.0 WebSocket...');
    _stateController.add(WebSocketConnectionState.connecting);

    // Set connection timeout
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = Timer(Duration(seconds: _connectionTimeoutSeconds), () {
      if (_channel?.closeCode == null) {
        debugPrint('🔌 Connection timeout after $_connectionTimeoutSeconds seconds');
        _handleError(WebSocketError(
          message: 'Connection timeout after $_connectionTimeoutSeconds seconds',
          errorType: 'ConnectionTimeout',
          details: 'Failed to establish connection within timeout period'
        ));
      }
    });

    try {
      // Validate inputs before attempting connection
      if (_apiKey.isEmpty || _agentId.isEmpty) {
        throw WebSocketError(
          message: 'Missing API key or agent ID',
          errorType: 'InvalidConfiguration',
          details: 'API key and agent ID are required for connection'
        );
      }

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
      _lastError = null; // Clear error on successful connection
      _connectionTimeoutTimer?.cancel(); // Cancel timeout timer on success
    } catch (e) {
      _connectionTimeoutTimer?.cancel();
      debugPrint('🔌 Error connecting to Conversational AI 2.0 WebSocket: $e');
      
      WebSocketError wsError;
      if (e is WebSocketError) {
        wsError = e;
      } else {
        wsError = WebSocketError(
          message: 'Failed to connect to WebSocket',
          errorType: 'ConnectionError',
          details: e.toString()
        );
      }
      _handleError(wsError);
    }
  }

  void _sendInitialization() {
    // Conversational AI 2.0 initialization with enhanced features
    final initMessage = jsonEncode({
      'type': 'conversation_initiation_client_data',
      'conversation_config_override': {
        'agent': {
          'language': 'en',
          // Use client-side VAD for better feedback control
          'turn_detection': {
            'type':
                'client_vad', // Switch to client_vad for manual turn control
            'threshold': 0.6, // Adjust sensitivity
            'silence_duration_ms':
                800 // Shorter silence duration for faster interruption
          }
        },
        'tts': {
          // Leverage improved voice synthesis in v2.0
          'model':
              'eleven_turbo_v2_5', // Use latest v2.5 model for better performance
        },
        // Explicitly set audio formats to ensure compatibility
        'audio': {'input_format': 'pcm_16000', 'output_format': 'pcm_16000'}
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
            try {
              final base64Audio = jsonData['audio_event']['audio_base_64'];

              // Validate base64 audio data before processing
              if (base64Audio == null || base64Audio.isEmpty) {
                debugPrint('🔌 Received empty audio data, skipping');
                break;
              }

              // For Conversational AI 2.0 streaming, even small chunks are valid
              // Lower threshold to handle real-time audio streaming
              if (base64Audio.length < 4) {
                debugPrint(
                    '🔌 Audio data too short (${base64Audio.length} chars), likely corrupted - skipping');
                break;
              }

              final audioBytes = base64Decode(base64Audio);

              // For Conversational AI 2.0, very small audio chunks are normal in streaming
              // Only skip if completely empty
              if (audioBytes.length < 2) {
                debugPrint(
                    '🔌 Decoded audio too small (${audioBytes.length} bytes), likely corrupted - skipping');
                break;
              }

              debugPrint(
                  '🔌 Received valid audio data from Conversational AI 2.0');
              debugPrint('🔌 Audio data size: ${audioBytes.length} bytes');

              // Mark agent as speaking when receiving audio
              if (!_isAgentSpeaking) {
                _setAgentSpeaking(true);
              }

              _audioController.add(Uint8List.fromList(audioBytes));
            } catch (e) {
              debugPrint('🔌 Error processing audio data: $e');
            }
          }
          break;

        case 'user_transcript':
          debugPrint(
              '🔌 User transcript: ${jsonData['user_transcription_event']?['user_transcript']}');
          break;

        case 'agent_response':
          debugPrint(
              '🔌 Agent response: ${jsonData['agent_response_event']?['agent_response']}');
          // Mark agent as speaking when receiving text response
          if (!_isAgentSpeaking) {
            _setAgentSpeaking(true);
          }
          break;

        case 'agent_response_corrected':
          debugPrint(
              '🔌 Agent response corrected: ${jsonData['agent_response_corrected_event']?['agent_response_corrected']}');
          break;

        case 'agent_response_complete':
          debugPrint('🔌 Agent response complete');
          // Signal audio manager that response is complete and ready for playback
          GlobalAudioManager().markResponseComplete();
          // Mark agent as finished speaking
          _setAgentSpeaking(false);
          break;

        case 'vad_score':
          // Voice Activity Detection score from Conversational AI 2.0
          final vadScore = jsonData['vad_score_event']?['vad_score'];
          debugPrint('🔌 VAD Score: $vadScore');
          break;

        case 'ping':
          // Handle ping-pong for connection health
          final pongMessage = jsonEncode(
              {'type': 'pong', 'event_id': jsonData['ping_event']['event_id']});
          _channel!.sink.add(pongMessage);
          break;

        case 'interruption':
          debugPrint(
              '🔌 Conversation interrupted: ${jsonData['interruption_event']?['reason']}');
          // Only reset agent speaking state if it's still true (might already be reset)
          if (_isAgentSpeaking) {
            _setAgentSpeaking(false);
          }
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

  void _setAgentSpeaking(bool speaking) {
    if (_isAgentSpeaking != speaking) {
      _isAgentSpeaking = speaking;
      _feedbackController.add(speaking);

      if (speaking) {
        _conversationState = ConversationState.agentSpeaking;
        _agentRecentlySpeaking = true;
        _agentGracePeriodTimer?.cancel(); // Cancel any existing timer
        debugPrint('🔊 Agent started speaking - pausing recording');
      } else {
        _conversationState = ConversationState.idle;
        debugPrint('🔊 Agent finished speaking - starting grace period');

        // Start grace period timer to prevent immediate voice detection
        _agentGracePeriodTimer?.cancel();
        _agentGracePeriodTimer = Timer(Duration(milliseconds: 2000), () {
          _agentRecentlySpeaking = false;
          debugPrint(
              '🔊 Agent grace period ended - normal voice detection resumed');
        });
      }

      _conversationStateController.add(_conversationState);
    }
  }

  void _setUserSpeaking(bool speaking) {
    if (_isUserSpeaking != speaking) {
      _isUserSpeaking = speaking;
      _userSpeakingController.add(speaking);

      if (speaking) {
        _conversationState = ConversationState.userSpeaking;
        debugPrint('🎙️ User started speaking');

        // If agent is speaking, interrupt it
        if (_isAgentSpeaking) {
          debugPrint(
              '🎙️ User interrupted agent - sending interruption signal');
          _sendInterruption();
          // Stop audio playback immediately
          GlobalAudioManager().stopAudio();
          // Immediately reset agent speaking state to allow user audio through
          _isAgentSpeaking = false;
          _feedbackController.add(false);
          debugPrint(
              '🎙️ Agent speaking state immediately reset for interruption');
        }
      } else {
        _conversationState = ConversationState.idle;
        debugPrint('🎙️ User stopped speaking');

        // Reset interrupted state when user finishes speaking to allow new agent responses
        GlobalAudioManager().resetInterruptedState();

        // Send end of turn signal after user stops speaking
        _speechActivityTimer?.cancel();
        _speechActivityTimer = Timer(Duration(milliseconds: 500), () {
          if (!_isUserSpeaking) {
            sendEndOfTurn();
          }
        });
      }

      _conversationStateController.add(_conversationState);
    }
  }

  // Voice activity detection based on audio amplitude
  void _detectVoiceActivity(Uint8List audioData) {
    if (audioData.isEmpty) return;

    // Skip voice activity detection if agent is speaking to prevent feedback loops
    if (_isAgentSpeaking) {
      debugPrint('🔌 Skipping voice activity detection - agent is speaking');
      return;
    }

    // Calculate RMS (Root Mean Square) for amplitude detection
    double sum = 0.0;
    for (int i = 0; i < audioData.length; i += 2) {
      if (i + 1 < audioData.length) {
        // Combine two bytes to form a 16-bit sample
        int sample = (audioData[i + 1] << 8) | audioData[i];
        if (sample > 32767) sample -= 65536; // Convert to signed
        sum += sample * sample;
      }
    }

    double rms = math.sqrt(sum / (audioData.length / 2));
    double normalizedRms = rms / 32768.0; // Normalize to 0-1 range

    // Use higher threshold if we recently had agent speaking to account for echo/feedback
    double currentThreshold = _audioThreshold;
    if (_agentRecentlySpeaking) {
      currentThreshold =
          _audioThreshold * 3.0; // 3x higher threshold after agent speaks
      debugPrint(
          '🔌 Using elevated threshold due to recent agent speech: $currentThreshold');
    }

    // Voice activity detection logic
    if (normalizedRms > currentThreshold) {
      _consecutiveActiveChunks++;
      _consecutiveSilentChunks = 0;

      // Start speaking detection - require more consecutive chunks after agent speech
      int requiredChunks =
          _agentRecentlySpeaking ? _speechThreshold * 2 : _speechThreshold;
      if (!_isUserSpeaking && _consecutiveActiveChunks >= requiredChunks) {
        _setUserSpeaking(true);
      }
    } else {
      _consecutiveSilentChunks++;
      _consecutiveActiveChunks = 0;

      // Stop speaking detection
      if (_isUserSpeaking && _consecutiveSilentChunks >= _silenceThreshold) {
        _setUserSpeaking(false);
      }
    }
  }

  Future<void> sendAudioChunk(Uint8List audioData) async {
    // Voice activity detection
    _detectVoiceActivity(audioData);

    // Prevent sending audio while agent is speaking to avoid feedback
    if (_isAgentSpeaking || _isRecordingPaused) {
      debugPrint(
          '🔌 Skipping audio chunk - agent is speaking or recording paused');
      return;
    }

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

      // Correct Conversational AI 2.0 audio format - user_audio_chunk as key, base64 data as value
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

  // Send interruption signal to stop agent
  Future<void> _sendInterruption() async {
    if (_channel?.closeCode != null) {
      debugPrint('🔌 WebSocket is closed, cannot send interruption');
      return;
    }

    try {
      final interruptMessage = jsonEncode({
        'type': 'user_interrupt',
      });
      _channel!.sink.add(interruptMessage);
      debugPrint('🔌 Interruption signal sent');
    } catch (e) {
      debugPrint('🔌 Error sending interruption: $e');
      _handleError(e);
    }
  }

  // Manual interruption method (can be called by UI)
  Future<void> interruptAgent() async {
    if (_isAgentSpeaking) {
      debugPrint('🔌 Manual agent interruption requested');
      await _sendInterruption();
      // Stop audio playback immediately
      await GlobalAudioManager().stopAudio();
      _setAgentSpeaking(false);
    }
  }

  // Manual turn control methods for client-side VAD
  void pauseRecording() {
    _isRecordingPaused = true;
    debugPrint('🔌 Recording manually paused');
  }

  void resumeRecording() {
    _isRecordingPaused = false;
    debugPrint('🔌 Recording manually resumed');
  }

  // Notify agent speaking state change (called by audio manager)
  void notifyAgentPlaybackStarted() {
    _setAgentSpeaking(true);
  }

  void notifyAgentPlaybackEnded() {
    _setAgentSpeaking(false);
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

  // Send end-of-turn signal for client-side VAD (Conversational AI 2.0 feature)
  Future<void> sendEndOfTurn() async {
    if (_channel?.closeCode != null) {
      debugPrint('🔌 WebSocket is closed, cannot send end-of-turn signal');
      return;
    }

    try {
      // Signal that the user has finished speaking for client-side VAD
      final endOfTurnMessage = jsonEncode({
        'type': 'user_turn_ended',
      });
      _channel!.sink.add(endOfTurnMessage);
      debugPrint('🔌 End-of-turn signal sent for client-side VAD');
    } catch (e) {
      debugPrint('🔌 Error sending end-of-turn signal: $e');
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
    WebSocketError wsError;
    if (error is WebSocketError) {
      wsError = error;
    } else {
      wsError = WebSocketError(
        message: 'WebSocket error occurred',
        errorType: 'UnknownError',
        details: error.toString()
      );
    }
    
    _lastError = wsError;
    debugPrint('🔌 Conversational AI 2.0 WebSocket error: $wsError');
    _stateController.add(WebSocketConnectionState.error);
    _errorController.add(wsError);
    _scheduleReconnect();
    _messageController.addError(wsError);
  }

  void _handleDisconnect() {
    debugPrint('🔌 Conversational AI 2.0 WebSocket disconnected');
    _stateController.add(WebSocketConnectionState.disconnected);
    
    // Only schedule reconnect if not manually closed
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _scheduleReconnect();
    } else {
      debugPrint('🔌 Maximum reconnect attempts reached, not scheduling reconnect');
      _stateController.add(WebSocketConnectionState.retryExhausted);
      _errorController.add(WebSocketError(
        message: 'Connection lost and retry attempts exhausted',
        errorType: 'ReconnectFailed',
        details: 'Failed to reconnect after $_maxReconnectAttempts attempts'
      ));
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('🔌 Maximum reconnect attempts ($_maxReconnectAttempts) reached, giving up');
      _stateController.add(WebSocketConnectionState.retryExhausted);
      _errorController.add(WebSocketError(
        message: 'Maximum reconnection attempts reached',
        errorType: 'ReconnectFailed',
        details: 'Failed to reconnect after $_maxReconnectAttempts attempts'
      ));
      return;
    }

    _stateController.add(WebSocketConnectionState.reconnecting);
    debugPrint('🔌 Scheduling reconnect attempt ${_reconnectAttempts + 1}/$_maxReconnectAttempts');
    _reconnectTimer?.cancel();
    
    // Exponential backoff with jitter
    final baseDelay = math.min(
      _baseRetryDelaySeconds * math.pow(2, _reconnectAttempts).toInt(),
      _maxRetryDelaySeconds
    );
    final jitter = math.Random().nextInt(1000); // Add up to 1 second jitter
    final delay = Duration(milliseconds: baseDelay * 1000 + jitter);
    
    debugPrint('🔌 Will attempt to reconnect in ${delay.inSeconds} seconds');
    _reconnectTimer = Timer(delay, () async {
      _reconnectAttempts++;
      await _connect();
    });
  }

  // Manual retry method for UI
  Future<void> retryConnection() async {
    debugPrint('🔌 Manual reconnection attempt requested');
    _reconnectAttempts = 0; // Reset counter for manual retry
    _lastError = null;
    _reconnectTimer?.cancel();
    await _connect();
  }

  // Enhanced connection health check
  bool get isHealthy {
    return _channel?.closeCode == null && 
           currentState == WebSocketConnectionState.connected &&
           _lastError == null;
  }

  // Get human-readable connection status
  String get connectionStatusText {
    switch (currentState) {
      case WebSocketConnectionState.connecting:
        return 'Connecting...';
      case WebSocketConnectionState.connected:
        return 'Connected';
      case WebSocketConnectionState.disconnected:
        return 'Disconnected';
      case WebSocketConnectionState.reconnecting:
        return 'Reconnecting... (${_reconnectAttempts}/$_maxReconnectAttempts)';
      case WebSocketConnectionState.error:
        return 'Error: ${_lastError?.message ?? 'Unknown error'}';
      case WebSocketConnectionState.retryExhausted:
        return 'Connection failed - Tap to retry';
    }
  }

  Future<void> close() async {
    debugPrint('🔌 Closing Conversational AI 2.0 WebSocket connection');
    _speechActivityTimer?.cancel();
    _agentGracePeriodTimer?.cancel();
    await _channel?.sink.close(1000, 'Normal closure');
    await _messageController.close();
    await _audioController.close();
    await _stateController.close();
    await _errorController.close();
    await _feedbackController.close();
    await _userSpeakingController.close();
    await _conversationStateController.close();
    _reconnectTimer?.cancel();
    _conversationId = null;
  }
}
