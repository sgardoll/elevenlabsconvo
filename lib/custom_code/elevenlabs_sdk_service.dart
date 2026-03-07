import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart';

/// Conversation state enum matching the old service interface
enum ConversationState {
  idle,
  connecting,
  connected,
  recording,
  playing,
  error
}

/// Message class for conversation transcripts
class ConversationMessage {
  final String type;
  final String content;
  final DateTime timestamp;
  final String? conversationId;

  ConversationMessage({
    required this.type,
    required this.content,
    required this.timestamp,
    this.conversationId,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'content': content,
        'timestamp': timestamp.millisecondsSinceEpoch,
        if (conversationId != null) 'conversation_id': conversationId,
      };
}

/// ElevenLabs SDK Service Wrapper
/// Provides a simplified interface to the official ElevenLabs Flutter SDK
class ElevenLabsSdkService extends ChangeNotifier {
  static final ElevenLabsSdkService _instance =
      ElevenLabsSdkService._internal();
  factory ElevenLabsSdkService() => _instance;
  ElevenLabsSdkService._internal();

  // SDK client - created once and reused
  ConversationClient? _client;

  // Configuration
  String _agentId = '';
  String _endpoint = '';

  // State management
  bool _isDisposing = false;
  ConversationState _currentState = ConversationState.idle;
  bool _permissionGranted = false;

  // Reactive streams for UI
  final _conversationController =
      StreamController<ConversationMessage>.broadcast();
  final _stateController = StreamController<ConversationState>.broadcast();
  final _recordingController = StreamController<bool>.broadcast();
  final _connectionController = StreamController<String>.broadcast();

  // Public streams
  Stream<ConversationMessage> get conversationStream =>
      _conversationController.stream;
  Stream<ConversationState> get stateStream => _stateController.stream;
  Stream<bool> get recordingStream => _recordingController.stream;
  Stream<String> get connectionStream => _connectionController.stream;

  // Getters
  bool get isRecording =>
      _client?.isMuted == false && _currentState == ConversationState.recording;
  bool get isAgentSpeaking => _client?.isSpeaking ?? false;
  bool get isConnected => _client?.status == ConversationStatus.connected;
  bool get isDisposing => _isDisposing;
  ConversationState get currentState => _currentState;

  /// Request microphone permission
  Future<bool> _requestMicrophonePermission() async {
    if (_permissionGranted) return true;

    debugPrint('Requesting microphone permission...');
    final status = await Permission.microphone.request();
    _permissionGranted = status.isGranted;

    if (!_permissionGranted) {
      debugPrint('Microphone permission DENIED: $status');
    } else {
      debugPrint('Microphone permission GRANTED');
    }

    return _permissionGranted;
  }

  /// Get conversation token from the endpoint
  Future<String?> _getConversationToken() async {
    debugPrint('Getting conversation token from endpoint');
    final token = await getSignedUrl(_agentId, _endpoint);
    if (token != null) {
      debugPrint('Successfully obtained conversation token');
      return token;
    } else {
      debugPrint('Failed to obtain conversation token');
      return null;
    }
  }

  /// Initialize the client (create once)
  void _initializeClient() {
    if (_client != null) {
      debugPrint('Client already exists, reusing...');
      return;
    }

    debugPrint('Creating new ConversationClient...');
    _client = ConversationClient(
      callbacks: ConversationCallbacks(
        onConnect: ({required conversationId}) {
          debugPrint('>>> onConnect: $conversationId');
          _handleConnect(conversationId: conversationId);
        },
        onDisconnect: (details) {
          debugPrint('>>> onDisconnect: ${details.reason}');
          _handleDisconnect(details);
        },
        onMessage: ({required message, required source}) {
          debugPrint('>>> onMessage [$source]: $message');
          _handleMessage(message: message, source: source);
        },
        onError: (message, [context]) {
          debugPrint('>>> onError: $message, context: $context');
          _handleError(message, context);
        },
        onStatusChange: ({required status}) {
          debugPrint('>>> onStatusChange: ${status.name}');
          _handleStatusChange(status: status);
        },
        onModeChange: ({required mode}) {
          debugPrint('>>> onModeChange: ${mode.name}');
          _handleModeChange(mode: mode);
        },
        onVadScore: ({required vadScore}) {
          // Voice activity detection - useful for debugging
          if (vadScore > 0.5) {
            debugPrint('>>> VAD score: $vadScore');
          }
        },
        onInterruption: (event) {
          debugPrint('>>> onInterruption: eventId=${event.eventId}');
        },
        onTentativeUserTranscript: ({required transcript, required eventId}) {
          debugPrint('>>> User speaking (live): "$transcript"');
        },
        onUserTranscript: ({required transcript, required eventId}) {
          debugPrint('>>> User said: "$transcript"');
          // Add user transcript to conversation messages for UI display
          if (transcript.isNotEmpty && transcript != '...') {
            final userMessage = ConversationMessage(
              type: 'user',
              content: transcript,
              timestamp: DateTime.now(),
            );
            _conversationController.add(userMessage);
            _updateFFAppStateMessages(userMessage);
          }
        },
        onTentativeAgentResponse: ({required response}) {
          debugPrint('>>> Agent composing: "$response"');
        },
        onDebug: (data) {
          debugPrint('>>> Debug: $data');
        },
      ),
    );

    _client!.addListener(_onClientChanged);
    debugPrint('ConversationClient created successfully');
  }

  /// Initialize the service and connect to ElevenLabs
  Future<String> initialize({
    required String agentId,
    required String endpoint,
  }) async {
    // Check if running on iOS simulator
    if (Platform.isIOS && kDebugMode) {
      debugPrint('⚠️ WARNING: iOS Simulator does not support microphone input');
      debugPrint('⚠️ For voice conversations, test on a physical iOS device');
    }

    debugPrint('========================================');
    debugPrint('Initializing ElevenLabs SDK Service');
    debugPrint('  agentId: $agentId');
    debugPrint('  endpoint: $endpoint');
    debugPrint('========================================');

    // Check if already connected with same config
    if (_agentId == agentId && _endpoint == endpoint && isConnected) {
      debugPrint('Service already initialized and connected');
      return 'success';
    }

    _isDisposing = false;
    _agentId = agentId;
    _endpoint = endpoint;

    try {
      // Step 1: Request microphone permission
      final hasPermission = await _requestMicrophonePermission();
      if (!hasPermission) {
        throw Exception('Microphone permission denied');
      }

      _updateState(ConversationState.connecting);
      _connectionController.add('connecting');

      // Step 2: Get conversation token from backend
      final token = await _getConversationToken();
      if (token == null) {
        throw Exception('Failed to obtain conversation token');
      }
      debugPrint('Token obtained (length: ${token.length})');

      // Step 3: End any existing session
      if (_client != null &&
          _client!.status != ConversationStatus.disconnected) {
        debugPrint('Ending existing session...');
        await _client!.endSession();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Step 4: Initialize client if needed
      _initializeClient();

      // Step 5: Start session with token and userId
      debugPrint('Starting session with conversationToken...');
      final userId = 'user-${DateTime.now().millisecondsSinceEpoch}';
      await _client!.startSession(
        conversationToken: token,
        userId: userId,
      );

      debugPrint('Session started successfully for user: $userId');

      FFAppState().update(() {
        FFAppState().wsConnectionState = 'connected';
        FFAppState().elevenLabsAgentId = agentId;
        FFAppState().endpoint = endpoint;
      });

      return 'success';
    } catch (e, stackTrace) {
      debugPrint('========================================');
      debugPrint('ERROR initializing service: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('========================================');
      _updateState(ConversationState.error);
      _connectionController.add('error: ${e.toString()}');
      return 'error: ${e.toString()}';
    }
  }

  void _onClientChanged() {
    if (_client == null) return;

    // Update state based on client status
    final status = _client!.status;
    final isSpeaking = _client!.isSpeaking;
    final isMuted = _client!.isMuted;

    debugPrint(
        'Client changed: status=$status, isSpeaking=$isSpeaking, isMuted=$isMuted');

    ConversationState newState;
    if (status == ConversationStatus.disconnected) {
      newState = ConversationState.idle;
    } else if (status == ConversationStatus.connecting) {
      newState = ConversationState.connecting;
    } else if (status == ConversationStatus.connected) {
      if (isSpeaking) {
        newState = ConversationState.playing;
      } else if (!isMuted) {
        newState = ConversationState.recording;
      } else {
        newState = ConversationState.connected;
      }
    } else {
      newState = ConversationState.idle;
    }

    if (newState != _currentState) {
      _updateState(newState);
    }

    // Update recording stream
    _recordingController
        .add(!isMuted && status == ConversationStatus.connected);

    notifyListeners();
  }

  void _handleConnect({required String conversationId}) {
    debugPrint('Connected to conversation: $conversationId');
    _updateState(ConversationState.connected);
    _connectionController.add('connected');

    final message = ConversationMessage(
      type: 'system',
      content: 'Connected to ElevenLabs conversation',
      timestamp: DateTime.now(),
      conversationId: conversationId,
    );
    _conversationController.add(message);
    _updateFFAppStateMessages(message);
  }

  void _handleDisconnect(DisconnectionDetails details) {
    debugPrint('Disconnected from conversation: ${details.reason}');
    _updateState(ConversationState.idle);
    _connectionController.add('disconnected');

    FFAppState().update(() {
      FFAppState().wsConnectionState = 'disconnected';
    });
  }

  void _handleMessage({required String message, required Role source}) {
    debugPrint('Message from $source: $message');

    // Only add agent messages here - user messages are handled by onUserTranscript
    if (source == Role.ai) {
      final conversationMessage = ConversationMessage(
        type: 'agent',
        content: message,
        timestamp: DateTime.now(),
      );
      _conversationController.add(conversationMessage);
      _updateFFAppStateMessages(conversationMessage);
    }
  }

  void _handleError(String message, [dynamic context]) {
    debugPrint('SDK Error: $message, context: $context');
    // Don't transition to error state for all errors - some are recoverable
    _connectionController.add('error: $message');
  }

  void _handleStatusChange({required ConversationStatus status}) {
    debugPrint('Status changed: $status');
    _onClientChanged();
  }

  void _handleModeChange({required ConversationMode mode}) {
    debugPrint('Mode changed: $mode');
    _onClientChanged();
  }

  void _updateState(ConversationState state) {
    debugPrint('State: $_currentState -> $state');
    _currentState = state;
    _stateController.add(state);
  }

  void _updateFFAppStateMessages(ConversationMessage message) {
    FFAppState().update(() {
      FFAppState().conversationMessages = [
        ...FFAppState().conversationMessages,
        message.toJson()
      ];
    });
  }

  /// Toggle recording (mute/unmute in SDK terms)
  Future<String> toggleRecording() async {
    if (_client == null || !isConnected) {
      return 'error: Not connected';
    }

    try {
      await _client!.toggleMute();
      final isMuted = _client!.isMuted;
      debugPrint(
          'Recording ${isMuted ? 'stopped (muted)' : 'started (unmuted)'}');

      FFAppState().update(() {
        FFAppState().isRecording = !isMuted;
      });

      return 'success';
    } catch (e) {
      debugPrint('Error toggling recording: $e');
      return 'error: ${e.toString()}';
    }
  }

  /// Start recording (unmute)
  Future<String> startRecording() async {
    if (_client == null || !isConnected) {
      return 'error: Not connected';
    }

    if (!_client!.isMuted) {
      return 'error: Already recording';
    }

    try {
      await _client!.setMicMuted(false);
      debugPrint('Recording started (unmuted)');

      FFAppState().update(() {
        FFAppState().isRecording = true;
      });

      return 'success';
    } catch (e) {
      debugPrint('Error starting recording: $e');
      return 'error: ${e.toString()}';
    }
  }

  /// Stop recording (mute)
  Future<String> stopRecording() async {
    if (_client == null || !isConnected) {
      return 'error: Not connected';
    }

    if (_client!.isMuted) {
      return 'error: Not recording';
    }

    try {
      await _client!.setMicMuted(true);
      debugPrint('Recording stopped (muted)');

      FFAppState().update(() {
        FFAppState().isRecording = false;
      });

      return 'success';
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      return 'error: ${e.toString()}';
    }
  }

  /// Trigger interruption (stop agent speaking)
  /// This ends the current conversation session completely
  Future<void> triggerInterruption() async {
    debugPrint('Manual interruption triggered - ending conversation session');

    // End the session to stop the agent completely
    // This is the only reliable way to stop the agent from speaking
    // and prevent it from responding again
    if (_client != null) {
      try {
        _client!.removeListener(_onClientChanged);
        await _client!.endSession();
        _client!.dispose();
        _client = null;
        debugPrint('Conversation session ended and client disposed');

        // Update state
        _updateState(ConversationState.idle);
        _connectionController.add('disconnected');

        // Update FFAppState
        FFAppState().update(() {
          FFAppState().wsConnectionState = 'disconnected';
          FFAppState().isRecording = false;
        });
      } catch (e) {
        debugPrint('Error ending session during interruption: $e');
      }
    }
  }

  /// Send a text message
  Future<String> sendTextMessage(String text) async {
    if (_client == null || !isConnected) {
      return 'error: Not connected';
    }

    try {
      _client!.sendUserMessage(text);
      debugPrint('Text message sent: $text');
      return 'success';
    } catch (e) {
      debugPrint('Error sending text message: $e');
      return 'error: ${e.toString()}';
    }
  }

  /// Dispose the service
  Future<void> dispose() async {
    debugPrint('Disposing ElevenLabs SDK Service');
    _isDisposing = true;

    try {
      if (_client != null) {
        _client!.removeListener(_onClientChanged);
        await _client!.endSession();
        _client!.dispose();
        _client = null;
      }
    } catch (e) {
      debugPrint('Error during disposal: $e');
    }

    _updateState(ConversationState.idle);
    _connectionController.add('disconnected');

    debugPrint('ElevenLabs SDK Service disposed');
  }
}
