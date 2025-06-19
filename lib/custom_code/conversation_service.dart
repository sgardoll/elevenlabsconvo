import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'websocket_manager.dart';
import 'audio_service.dart';

// App state models
class AppState {
  final ConnectionStatus connectionStatus;
  final ConversationState conversationState;
  final List<ChatMessage> chatHistory;
  final bool isRecording;
  final bool isBotSpeaking;
  final bool isUserSpeaking;
  final bool isPlayingAudio;
  final bool isBufferingAudio;
  final double? vadScore;
  final String? errorMessage;

  const AppState({
    required this.connectionStatus,
    required this.conversationState,
    required this.chatHistory,
    required this.isRecording,
    required this.isBotSpeaking,
    required this.isUserSpeaking,
    required this.isPlayingAudio,
    required this.isBufferingAudio,
    this.vadScore,
    this.errorMessage,
  });

  AppState copyWith({
    ConnectionStatus? connectionStatus,
    ConversationState? conversationState,
    List<ChatMessage>? chatHistory,
    bool? isRecording,
    bool? isBotSpeaking,
    bool? isUserSpeaking,
    bool? isPlayingAudio,
    bool? isBufferingAudio,
    double? vadScore,
    String? errorMessage,
  }) {
    return AppState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      conversationState: conversationState ?? this.conversationState,
      chatHistory: chatHistory ?? this.chatHistory,
      isRecording: isRecording ?? this.isRecording,
      isBotSpeaking: isBotSpeaking ?? this.isBotSpeaking,
      isUserSpeaking: isUserSpeaking ?? this.isUserSpeaking,
      isPlayingAudio: isPlayingAudio ?? this.isPlayingAudio,
      isBufferingAudio: isBufferingAudio ?? this.isBufferingAudio,
      vadScore: vadScore ?? this.vadScore,
      errorMessage: errorMessage,
    );
  }
}

class ConversationService {
  // Singleton instance
  static final ConversationService instance = ConversationService._privateConstructor();

  ConversationService._privateConstructor() {
    _webSocketManager = WebSocketManager.instance;
    _audioService = AudioService.instance;
    _initializeStreamListeners();
  }

  // Dependencies
  late final WebSocketManager _webSocketManager;
  late final AudioService _audioService;

  // State stream
  final StreamController<AppState> _stateController = StreamController<AppState>.broadcast();
  Stream<AppState> get stateStream => _stateController.stream;

  // Current state
  AppState _currentState = const AppState(
    connectionStatus: ConnectionStatus.disconnected,
    conversationState: ConversationState.idle,
    chatHistory: [],
    isRecording: false,
    isBotSpeaking: false,
    isUserSpeaking: false,
    isPlayingAudio: false,
    isBufferingAudio: false,
  );

  // State subscriptions
  late StreamSubscription _connectionStatusSubscription;
  late StreamSubscription _conversationStateSubscription;
  late StreamSubscription _chatHistorySubscription;
  late StreamSubscription _isBotSpeakingSubscription;
  late StreamSubscription _isUserSpeakingSubscription;
  late StreamSubscription _isPlayingAudioSubscription;
  late StreamSubscription _isBufferingAudioSubscription;
  late StreamSubscription _vadScoreSubscription;

  // Getters for current state
  AppState get currentState => _currentState;
  ConnectionStatus get connectionStatus => _currentState.connectionStatus;
  ConversationState get conversationState => _currentState.conversationState;
  List<ChatMessage> get chatHistory => _currentState.chatHistory;
  bool get isRecording => _currentState.isRecording;
  bool get isBotSpeaking => _currentState.isBotSpeaking;
  bool get isUserSpeaking => _currentState.isUserSpeaking;
  bool get isPlayingAudio => _currentState.isPlayingAudio;
  bool get isBufferingAudio => _currentState.isBufferingAudio;

  void _initializeStreamListeners() {
    // Listen to WebSocket connection status
    _connectionStatusSubscription = _webSocketManager.connectionStatusStream.listen((status) {
      _updateState(_currentState.copyWith(connectionStatus: status));
    });

    // Listen to conversation state
    _conversationStateSubscription = _webSocketManager.conversationStateStream.listen((state) {
      _updateState(_currentState.copyWith(conversationState: state));
    });

    // Listen to chat history
    _chatHistorySubscription = _webSocketManager.chatHistoryStream.listen((history) {
      _updateState(_currentState.copyWith(chatHistory: history));
    });

    // Listen to bot speaking status
    _isBotSpeakingSubscription = _webSocketManager.isBotSpeakingStream.listen((speaking) {
      _updateState(_currentState.copyWith(isBotSpeaking: speaking));
    });

    // Listen to user speaking status
    _isUserSpeakingSubscription = _webSocketManager.isUserSpeakingStream.listen((speaking) {
      _updateState(_currentState.copyWith(isUserSpeaking: speaking));
    });

    // Listen to audio playback status
    _isPlayingAudioSubscription = _audioService.isPlayingStream.listen((playing) {
      _updateState(_currentState.copyWith(isPlayingAudio: playing));
    });

    // Listen to audio buffering status
    _isBufferingAudioSubscription = _audioService.isBufferingStream.listen((buffering) {
      _updateState(_currentState.copyWith(isBufferingAudio: buffering));
    });

    // Listen to VAD scores
    _vadScoreSubscription = _webSocketManager.vadScoreStream.listen((score) {
      _updateState(_currentState.copyWith(vadScore: score));
    });
  }

  void _updateState(AppState newState) {
    if (newState != _currentState) {
      _currentState = newState;
      _stateController.add(_currentState);

      if (kDebugMode) {
        print('🔄 State updated: '
            'connection=${newState.connectionStatus.name}, '
            'conversation=${newState.conversationState.name}, '
            'messages=${newState.chatHistory.length}, '
            'recording=${newState.isRecording}, '
            'botSpeaking=${newState.isBotSpeaking}, '
            'userSpeaking=${newState.isUserSpeaking}, '
            'audioPlaying=${newState.isPlayingAudio}');
      }
    }
  }

  // Service methods
  Future<void> initialize({required String apiKey, required String agentId}) async {
    try {
      await _webSocketManager.initialize(apiKey: apiKey, agentId: agentId);
    } catch (e) {
      _updateState(_currentState.copyWith(
        errorMessage: 'Failed to initialize: $e',
        connectionStatus: ConnectionStatus.error,
      ));
      rethrow;
    }
  }

  Future<void> connect() async {
    try {
      await _webSocketManager.connect();
    } catch (e) {
      _updateState(_currentState.copyWith(
        errorMessage: 'Failed to connect: $e',
        connectionStatus: ConnectionStatus.error,
      ));
      rethrow;
    }
  }

  void disconnect() {
    _webSocketManager.disconnect();
    setRecording(false);
  }

  void sendMessage(String text) {
    _webSocketManager.sendMessage(text);
  }

  void sendAudioChunk(Uint8List audioData) {
    _webSocketManager.sendAudioChunk(audioData);
  }

  void interruptAgent() {
    _webSocketManager.interruptAgent();
  }

  void setRecording(bool recording) {
    _updateState(_currentState.copyWith(isRecording: recording));
  }

  void clearError() {
    _updateState(_currentState.copyWith(errorMessage: null));
  }

  void clearChatHistory() {
    // Note: This would need to be implemented in WebSocketManager if needed
    // For now, we can only clear the local state
    _updateState(_currentState.copyWith(chatHistory: []));
  }

  // Convenience getters for UI
  String get connectionStatusText {
    switch (_currentState.connectionStatus) {
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.connecting:
        return 'Connecting...';
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.error:
        return 'Error';
    }
  }

  String get conversationStateText {
    switch (_currentState.conversationState) {
      case ConversationState.idle:
        return 'Ready';
      case ConversationState.userSpeaking:
        return 'Listening...';
      case ConversationState.agentSpeaking:
        return 'Speaking...';
      case ConversationState.processing:
        return 'Processing...';
    }
  }

  bool get canRecord => 
    _currentState.connectionStatus == ConnectionStatus.connected &&
    !_currentState.isBotSpeaking;

  bool get shouldShowError => _currentState.errorMessage != null;

  void dispose() {
    _connectionStatusSubscription.cancel();
    _conversationStateSubscription.cancel();
    _chatHistorySubscription.cancel();
    _isBotSpeakingSubscription.cancel();
    _isUserSpeakingSubscription.cancel();
    _isPlayingAudioSubscription.cancel();
    _isBufferingAudioSubscription.cancel();
    _vadScoreSubscription.cancel();
    _stateController.close();
    _webSocketManager.dispose();
    _audioService.dispose();
  }
}