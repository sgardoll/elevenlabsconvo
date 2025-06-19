import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:collection';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:flutter/foundation.dart';
import 'widgets/auto_play_audio_response.dart';
import 'package:audioplayers/audioplayers.dart';
import 'audio_service.dart';

// Enum for connection status
enum ConnectionStatus { disconnected, connecting, connected, error }

// Enum for conversation state
enum ConversationState { idle, userSpeaking, agentSpeaking, processing }

// Data models for better type safety
class ChatMessage {
  final String id;
  final bool isUser;
  final String text;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    required this.isUser,
    required this.text,
    required this.timestamp,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'isUser': isUser,
    'text': text,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'metadata': metadata,
  };
}

class WebSocketManager {
  // Private constructor
  WebSocketManager._privateConstructor() {
    // Initialize audio service
    _audioService = AudioService.instance;
  }

  // Singleton instance
  static final WebSocketManager instance = WebSocketManager._privateConstructor();

  // Public state streams
  final StreamController<List<ChatMessage>> _chatHistoryController = 
      StreamController<List<ChatMessage>>.broadcast();
  Stream<List<ChatMessage>> get chatHistoryStream => _chatHistoryController.stream;

  final StreamController<ConnectionStatus> _connectionStatusController = 
      StreamController<ConnectionStatus>.broadcast();
  Stream<ConnectionStatus> get connectionStatusStream => _connectionStatusController.stream;

  final StreamController<ConversationState> _conversationStateController = 
      StreamController<ConversationState>.broadcast();
  Stream<ConversationState> get conversationStateStream => _conversationStateController.stream;

  final StreamController<bool> _isBotSpeakingController = 
      StreamController<bool>.broadcast();
  Stream<bool> get isBotSpeakingStream => _isBotSpeakingController.stream;

  final StreamController<bool> _isUserSpeakingController = 
      StreamController<bool>.broadcast();
  Stream<bool> get isUserSpeakingStream => _isUserSpeakingController.stream;

  final StreamController<double> _vadScoreController = 
      StreamController<double>.broadcast();
  Stream<double> get vadScoreStream => _vadScoreController.stream;

  // Internal state
  IOWebSocketChannel? _channel;
  late final AudioService _audioService;
  List<ChatMessage> _currentChatHistory = [];
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  ConversationState _conversationState = ConversationState.idle;
  bool _isBotSpeaking = false;
  bool _isUserSpeaking = false;

  // Configuration
  static const _baseUrl = 'wss://api.elevenlabs.io/v1/convai/conversation';
  String _apiKey = '';
  String _agentId = '';
  String? _conversationId;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  // Voice activity detection
  double _audioThreshold = 0.01;
  int _consecutiveSilentChunks = 0;
  int _consecutiveActiveChunks = 0;
  static const int _silenceThreshold = 15; // ~1.5 seconds at 10 chunks/sec
  static const int _speechThreshold = 3; // ~0.3 seconds to start speech
  bool _agentRecentlySpeaking = false;
  Timer? _agentGracePeriodTimer;

  // Getters for current state
  ConnectionStatus get connectionStatus => _connectionStatus;
  ConversationState get conversationState => _conversationState;
  bool get isBotSpeaking => _isBotSpeaking;
  bool get isUserSpeaking => _isUserSpeaking;
  List<ChatMessage> get chatHistory => List.unmodifiable(_currentChatHistory);

  // Audio service getters
  Stream<bool> get isPlayingAudioStream => _audioService.isPlayingStream;
  Stream<bool> get isBufferingAudioStream => _audioService.isBufferingStream;

  Future<void> initialize({required String apiKey, required String agentId}) async {
    if (kDebugMode) print('🔌 Initializing WebSocket with API key: ${apiKey.substring(0, 10)}... and agent ID: $agentId');
    
    _apiKey = apiKey;
    _agentId = agentId;
    
    // Initialize audio service
    await _audioService.initialize();
    
    await connect();
  }

  Future<void> connect() async {
    if (_channel?.closeCode == null) {
      if (kDebugMode) print('Already connected.');
      return;
    }
    
    _updateConnectionStatus(ConnectionStatus.connecting);
    
    try {
      final uri = Uri.parse('$_baseUrl?agent_id=${Uri.encodeComponent(_agentId)}');
      
      _channel = IOWebSocketChannel.connect(
        uri,
        headers: {
          'xi-api-key': _apiKey,
          'User-Agent': 'ElevenLabs-Flutter-SDK/2.0',
        },
      );
      
      _updateConnectionStatus(ConnectionStatus.connected);
      if (kDebugMode) print('WebSocket Connected');

      _channel!.stream.listen(
        _onMessageReceived,
        onError: (error) {
          if (kDebugMode) print('WebSocket Error: $error');
          _updateConnectionStatus(ConnectionStatus.error);
          _handleDisconnect();
        },
        onDone: () {
          if (kDebugMode) print('WebSocket Disconnected');
          _updateConnectionStatus(ConnectionStatus.disconnected);
        },
      );

      _sendInitialization();
    } catch (e) {
      if (kDebugMode) print('WebSocket connection error: $e');
      _updateConnectionStatus(ConnectionStatus.error);
      _scheduleReconnect();
    }
  }

  void _sendInitialization() {
    final initMessage = jsonEncode({
      'type': 'conversation_initiation_client_data',
      'conversation_config_override': {
        'agent': {
          'language': 'en',
          'turn_detection': {
            'type': 'client_vad',
            'threshold': 0.6,
            'silence_duration_ms': 800
          }
        },
        'tts': {
          'model': 'eleven_turbo_v2_5',
        },
        'audio': {'input_format': 'pcm_16000', 'output_format': 'pcm_16000'}
      },
      'conversation_config': {
        'modalities': ['audio']
      }
    });
    
    if (kDebugMode) print('🔌 Sending initialization: $initMessage');
    _channel?.sink.add(initMessage);
  }

  void _onMessageReceived(dynamic message) {
    try {
      final messageJson = jsonDecode(message);
      final messageType = messageJson['type'] ?? 'unknown';
      
      if (kDebugMode) print('🔌 Received message type: $messageType');

      switch (messageType) {
        case 'conversation_initiation_metadata':
          _conversationId = messageJson['conversation_initiation_metadata_event']?['conversation_id'];
          if (kDebugMode) print('🔌 Conversation ID: $_conversationId');
          _addSystemMessage('Conversation started');
          break;

        case 'user_transcript':
          final transcript = messageJson['user_transcription_event']?['user_transcript'];
          if (transcript != null && transcript.isNotEmpty) {
            _addUserMessage(transcript);
          }
          break;

        case 'agent_response':
          final response = messageJson['agent_response_event']?['agent_response'];
          if (response != null && response.isNotEmpty) {
            _addAgentMessage(response);
            _updateBotSpeaking(true);
          }
          break;

        case 'agent_response_complete':
          if (kDebugMode) print('🔌 Agent response complete');
          _audioService.markResponseComplete();
          _updateBotSpeaking(false);
          break;

        case 'audio':
          if (messageJson['audio_event'] != null) {
            _handleAudioData(messageJson['audio_event']['audio_base_64']);
          }
          break;

        case 'vad_score':
          final vadScore = messageJson['vad_score_event']?['vad_score'];
          if (vadScore != null) {
            _vadScoreController.add(vadScore.toDouble());
          }
          break;

        case 'interruption':
          if (kDebugMode) print('🔌 Conversation interrupted');
          _updateBotSpeaking(false);
          _audioService.stop();
          break;

        case 'ping':
          final pongMessage = jsonEncode({
            'type': 'pong', 
            'event_id': messageJson['ping_event']['event_id']
          });
          _channel?.sink.add(pongMessage);
          break;
      }
    } catch (e) {
      if (kDebugMode) print('🔌 Error handling message: $e');
    }
  }

  void _handleAudioData(String? base64Audio) {
    if (base64Audio == null || base64Audio.isEmpty) return;
    
    try {
      // Queue audio data with the audio service
      _audioService.queueAudioChunk(base64Audio);
    } catch (e) {
      if (kDebugMode) print('🔌 Error processing audio data: $e');
    }
  }

  void sendMessage(String text) {
    if (_channel?.closeCode != null) {
      if (kDebugMode) print("Not connected.");
      return;
    }
    
    final message = jsonEncode({'text': text});
    _channel!.sink.add(message);
    _addUserMessage(text);
  }

  void sendAudioChunk(Uint8List audioData) {
    if (_channel?.closeCode != null) return;
    
    // Voice activity detection
    _detectVoiceActivity(audioData);
    
    // Skip if bot is speaking to avoid feedback
    if (_isBotSpeaking) return;
    
    try {
      final base64Audio = base64Encode(audioData);
      final audioMessage = jsonEncode({'user_audio_chunk': base64Audio});
      _channel!.sink.add(audioMessage);
    } catch (e) {
      if (kDebugMode) print('🔌 Error sending audio chunk: $e');
    }
  }

  void _detectVoiceActivity(Uint8List audioData) {
    if (audioData.isEmpty || _isBotSpeaking) return;

    // Calculate RMS for amplitude detection
    double sum = 0.0;
    for (int i = 0; i < audioData.length; i += 2) {
      if (i + 1 < audioData.length) {
        int sample = (audioData[i + 1] << 8) | audioData[i];
        if (sample > 32767) sample -= 65536;
        sum += sample * sample;
      }
    }

    double rms = math.sqrt(sum / (audioData.length / 2));
    double normalizedRms = rms / 32768.0;

    double currentThreshold = _agentRecentlySpeaking ? _audioThreshold * 3.0 : _audioThreshold;

    if (normalizedRms > currentThreshold) {
      _consecutiveActiveChunks++;
      _consecutiveSilentChunks = 0;

      int requiredChunks = _agentRecentlySpeaking ? _speechThreshold * 2 : _speechThreshold;
      if (!_isUserSpeaking && _consecutiveActiveChunks >= requiredChunks) {
        _updateUserSpeaking(true);
      }
    } else {
      _consecutiveSilentChunks++;
      _consecutiveActiveChunks = 0;

      if (_isUserSpeaking && _consecutiveSilentChunks >= _silenceThreshold) {
        _updateUserSpeaking(false);
      }
    }
  }

  void interruptAgent() {
    if (_isBotSpeaking) {
      if (kDebugMode) print('🔌 Manual agent interruption');
      final interruptMessage = jsonEncode({'type': 'user_interrupt'});
      _channel?.sink.add(interruptMessage);
      _updateBotSpeaking(false);
      _audioService.stop();
    }
  }

  void sendEndOfTurn() {
    if (_channel?.closeCode != null) return;
    
    final endTurnMessage = jsonEncode({'type': 'end_of_turn'});
    _channel?.sink.add(endTurnMessage);
  }

  // Private state update methods
  void _updateConnectionStatus(ConnectionStatus status) {
    if (_connectionStatus != status) {
      _connectionStatus = status;
      _connectionStatusController.add(status);
    }
  }

  void _updateConversationState(ConversationState state) {
    if (_conversationState != state) {
      _conversationState = state;
      _conversationStateController.add(state);
    }
  }

  void _updateBotSpeaking(bool speaking) {
    if (_isBotSpeaking != speaking) {
      _isBotSpeaking = speaking;
      _isBotSpeakingController.add(speaking);
      
      if (speaking) {
        _updateConversationState(ConversationState.agentSpeaking);
        _agentRecentlySpeaking = true;
        _agentGracePeriodTimer?.cancel();
      } else {
        _updateConversationState(ConversationState.idle);
        _agentGracePeriodTimer?.cancel();
        _agentGracePeriodTimer = Timer(Duration(milliseconds: 2000), () {
          _agentRecentlySpeaking = false;
        });
      }
    }
  }

  void _updateUserSpeaking(bool speaking) {
    if (_isUserSpeaking != speaking) {
      _isUserSpeaking = speaking;
      _isUserSpeakingController.add(speaking);
      
      if (speaking) {
        _updateConversationState(ConversationState.userSpeaking);
        if (_isBotSpeaking) {
          interruptAgent();
        }
      } else {
        _updateConversationState(ConversationState.idle);
        _audioService.resetInterruptedState();
        Timer(Duration(milliseconds: 500), () {
          if (!_isUserSpeaking) {
            sendEndOfTurn();
          }
        });
      }
    }
  }

  void _addUserMessage(String text) {
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      isUser: true,
      text: text,
      timestamp: DateTime.now(),
    );
    _currentChatHistory.add(message);
    _chatHistoryController.add(List.from(_currentChatHistory));
  }

  void _addAgentMessage(String text) {
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      isUser: false,
      text: text,
      timestamp: DateTime.now(),
    );
    _currentChatHistory.add(message);
    _chatHistoryController.add(List.from(_currentChatHistory));
  }

  void _addSystemMessage(String text) {
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      isUser: false,
      text: text,
      timestamp: DateTime.now(),
      metadata: {'type': 'system'},
    );
    _currentChatHistory.add(message);
    _chatHistoryController.add(List.from(_currentChatHistory));
  }

  void _handleDisconnect() {
    _audioService.stop();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts < 5) {
      _reconnectAttempts++;
      final delay = Duration(seconds: math.pow(2, _reconnectAttempts).toInt());
      
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(delay, () {
        if (kDebugMode) print('🔌 Attempting to reconnect...');
        connect();
      });
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _audioService.stop();
    _updateConnectionStatus(ConnectionStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _chatHistoryController.close();
    _connectionStatusController.close();
    _conversationStateController.close();
    _isBotSpeakingController.close();
    _isUserSpeakingController.close();
    _vadScoreController.close();
    _audioService.dispose();
    _agentGracePeriodTimer?.cancel();
  }
}

// Re-export the original enums for backward compatibility
export 'websocket_manager.dart' show WebSocketConnectionState, ConversationState;

// Legacy compatibility - these can be removed once all references are updated
typedef WebSocketConnectionState = ConnectionStatus;
