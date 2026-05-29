import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;
import 'package:synchronized/synchronized.dart';
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

  static const _tokenRequestTimeout = Duration(seconds: 12);
  static const _sessionOperationTimeout = Duration(seconds: 12);
  static const _maxConversationMessages = 100;

  // SDK client - created once and reused
  ConversationClient? _client;

  // Configuration
  String _agentId = '';
  String _endpoint = '';

  // State management
  bool _isDisposing = false;
  ConversationState _currentState = ConversationState.idle;
  bool _permissionGranted = false;
  Future<String>? _initializeFuture;
  final _lifecycleLock = Lock();
  final _micLock = Lock();

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

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  /// Request microphone permission
  Future<bool> _requestMicrophonePermission() async {
    if (_permissionGranted) return true;

    _debugLog('Requesting microphone permission...');
    final status = await Permission.microphone.request();
    _permissionGranted = status.isGranted;

    if (!_permissionGranted) {
      _debugLog('Microphone permission DENIED: $status');
    } else {
      _debugLog('Microphone permission GRANTED');
    }

    return _permissionGranted;
  }

  /// Get conversation token from the endpoint
  Future<String?> _getConversationToken() async {
    _debugLog('Getting conversation token from endpoint');
    final token =
        await getSignedUrl(_agentId, _endpoint).timeout(_tokenRequestTimeout);
    if (token != null) {
      _debugLog('Successfully obtained conversation token');
      return token;
    } else {
      _debugLog('Failed to obtain conversation token');
      return null;
    }
  }

  /// Initialize the client (create once)
  void _initializeClient() {
    if (_client != null) {
      _debugLog('Client already exists, reusing...');
      return;
    }

    _debugLog('Creating new ConversationClient...');
    _client = ConversationClient(
      callbacks: ConversationCallbacks(
        onConnect: ({required conversationId}) {
          _debugLog('>>> onConnect: $conversationId');
          _handleConnect(conversationId: conversationId);
        },
        onDisconnect: (details) {
          _debugLog('>>> onDisconnect: ${details.reason}');
          _handleDisconnect(details);
        },
        onMessage: ({required message, required source}) {
          _debugLog('>>> onMessage [$source]: $message');
          _handleMessage(message: message, source: source);
        },
        onError: (message, [context]) {
          _debugLog('>>> onError: $message, context: $context');
          _handleError(message, context);
        },
        onStatusChange: ({required status}) {
          _debugLog('>>> onStatusChange: ${status.name}');
          _handleStatusChange(status: status);
        },
        onModeChange: ({required mode}) {
          _debugLog('>>> onModeChange: ${mode.name}');
          _handleModeChange(mode: mode);
        },
        onVadScore: ({required vadScore}) {
          // Voice activity detection - useful for debugging
          if (vadScore > 0.5) {
            _debugLog('>>> VAD score: $vadScore');
          }
        },
        onInterruption: (event) {
          _debugLog('>>> onInterruption: eventId=${event.eventId}');
        },
        onTentativeUserTranscript: ({required transcript, required eventId}) {
          _debugLog('>>> User speaking (live): "$transcript"');
        },
        onUserTranscript: ({required transcript, required eventId}) {
          _debugLog('>>> User said: "$transcript"');
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
          _debugLog('>>> Agent composing: "$response"');
        },
        onDebug: (data) {
          _debugLog('>>> Debug: $data');
        },
      ),
    );

    _client!.addListener(_onClientChanged);
    _debugLog('ConversationClient created successfully');
  }

  /// Initialize the service and connect to ElevenLabs
  Future<String> initialize({
    required String agentId,
    required String endpoint,
  }) {
    final existingInitialize = _initializeFuture;
    if (existingInitialize != null) {
      return existingInitialize;
    }

    final initializeFuture = _lifecycleLock.synchronized(
      () => _initializeLocked(agentId: agentId, endpoint: endpoint),
    );
    _initializeFuture = initializeFuture;
    return initializeFuture.whenComplete(() {
      if (identical(_initializeFuture, initializeFuture)) {
        _initializeFuture = null;
      }
    });
  }

  Future<String> _initializeLocked({
    required String agentId,
    required String endpoint,
  }) async {
    // Check if running on iOS simulator
    if (Platform.isIOS && kDebugMode) {
      _debugLog('⚠️ WARNING: iOS Simulator does not support microphone input');
      _debugLog('⚠️ For voice conversations, test on a physical iOS device');
    }

    _debugLog('========================================');
    _debugLog('Initializing ElevenLabs SDK Service');
    _debugLog('  agentId: $agentId');
    _debugLog('  endpoint: $endpoint');
    _debugLog('========================================');

    // Check if already connected with same config
    if (_agentId == agentId && _endpoint == endpoint && isConnected) {
      _debugLog('Service already initialized and connected');
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
      _debugLog('Token obtained (length: ${token.length})');

      // Step 3: End any existing session
      if (_client != null &&
          _client!.status != ConversationStatus.disconnected) {
        _debugLog('Ending existing session...');
        await _disposeClient(endSession: true);
      }

      // Step 4: Initialize client if needed
      _initializeClient();

      // Step 5: Start session with token and userId
      _debugLog('Starting session with conversationToken...');
      final userId = 'user-${DateTime.now().millisecondsSinceEpoch}';
      await _client!
          .startSession(
            conversationToken: token,
            userId: userId,
          )
          .timeout(_sessionOperationTimeout);

      _debugLog('Session started successfully for user: $userId');

      FFAppState().update(() {
        FFAppState().wsConnectionState = 'connected';
        FFAppState().elevenLabsAgentId = agentId;
        FFAppState().endpoint = endpoint;
      });

      return 'success';
    } catch (e, stackTrace) {
      _debugLog('========================================');
      _debugLog('ERROR initializing service: $e');
      _debugLog('Stack trace: $stackTrace');
      _debugLog('========================================');
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

    _debugLog(
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
    _debugLog('Connected to conversation: $conversationId');
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
    _debugLog('Disconnected from conversation: ${details.reason}');
    _updateState(ConversationState.idle);
    _connectionController.add('disconnected');

    FFAppState().update(() {
      FFAppState().wsConnectionState = 'disconnected';
    });
  }

  void _handleMessage({required String message, required Role source}) {
    _debugLog('Message from $source: $message');

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
    _debugLog('SDK Error: $message, context: $context');
    // Don't transition to error state for all errors - some are recoverable
    _connectionController.add('error: $message');
    if (_isFatalSdkError(message)) {
      _updateState(ConversationState.error);
      FFAppState().update(() {
        FFAppState().wsConnectionState = 'error: $message';
        FFAppState().isRecording = false;
      });
    }
  }

  void _handleStatusChange({required ConversationStatus status}) {
    _debugLog('Status changed: $status');
    _onClientChanged();
  }

  void _handleModeChange({required ConversationMode mode}) {
    _debugLog('Mode changed: $mode');
    _onClientChanged();
  }

  void _updateState(ConversationState state) {
    _debugLog('State: $_currentState -> $state');
    _currentState = state;
    _stateController.add(state);
  }

  void _updateFFAppStateMessages(ConversationMessage message) {
    FFAppState().update(() {
      FFAppState().addToConversationMessages(message.toJson());
      final overflow =
          FFAppState().conversationMessages.length - _maxConversationMessages;
      if (overflow > 0) {
        FFAppState().conversationMessages.removeRange(0, overflow);
      }
    });
  }

  bool _isFatalSdkError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('session') ||
        normalized.contains('connection') ||
        normalized.contains('token') ||
        normalized.contains('unauthorized') ||
        normalized.contains('permission');
  }

  /// Toggle recording (mute/unmute in SDK terms)
  Future<String> toggleRecording() => _micLock.synchronized(() async {
        if (_client == null || !isConnected) {
          return 'error: Not connected';
        }

        try {
          await _client!.toggleMute().timeout(_sessionOperationTimeout);
          final isMuted = _client!.isMuted;
          _debugLog(
              'Recording ${isMuted ? 'stopped (muted)' : 'started (unmuted)'}');

          FFAppState().update(() {
            FFAppState().isRecording = !isMuted;
          });

          return 'success';
        } catch (e) {
          _debugLog('Error toggling recording: $e');
          return 'error: ${e.toString()}';
        }
      });

  /// Start recording (unmute)
  Future<String> startRecording() => _micLock.synchronized(() async {
        if (_client == null || !isConnected) {
          return 'error: Not connected';
        }

        if (!_client!.isMuted) {
          return 'error: Already recording';
        }

        try {
          await _client!.setMicMuted(false).timeout(_sessionOperationTimeout);
          _debugLog('Recording started (unmuted)');

          FFAppState().update(() {
            FFAppState().isRecording = true;
          });

          return 'success';
        } catch (e) {
          _debugLog('Error starting recording: $e');
          return 'error: ${e.toString()}';
        }
      });

  /// Stop recording (mute)
  Future<String> stopRecording() => _micLock.synchronized(() async {
        if (_client == null || !isConnected) {
          return 'error: Not connected';
        }

        if (_client!.isMuted) {
          return 'error: Not recording';
        }

        try {
          await _client!.setMicMuted(true).timeout(_sessionOperationTimeout);
          _debugLog('Recording stopped (muted)');

          FFAppState().update(() {
            FFAppState().isRecording = false;
          });

          return 'success';
        } catch (e) {
          _debugLog('Error stopping recording: $e');
          return 'error: ${e.toString()}';
        }
      });

  /// Trigger interruption (stop agent speaking)
  /// This ends the current conversation session completely
  Future<void> triggerInterruption() => _lifecycleLock.synchronized(() async {
        _debugLog(
            'Manual interruption triggered - ending conversation session');
        await _disposeClient(endSession: true);
        _updateDisconnectedState();
      });

  /// Send a text message
  Future<String> sendTextMessage(String text) async {
    if (_client == null || !isConnected) {
      return 'error: Not connected';
    }

    try {
      _client!.sendUserMessage(text);
      _debugLog('Text message sent');
      return 'success';
    } catch (e) {
      _debugLog('Error sending text message: $e');
      return 'error: ${e.toString()}';
    }
  }

  /// Dispose the service
  Future<void> dispose() => _lifecycleLock.synchronized(() async {
        _debugLog('Disposing ElevenLabs SDK Service');
        _isDisposing = true;
        await _disposeClient(endSession: true);
        _updateDisconnectedState();
        _debugLog('ElevenLabs SDK Service disposed');
      });

  Future<void> _disposeClient({required bool endSession}) async {
    final client = _client;
    if (client == null) {
      return;
    }

    _client = null;
    client.removeListener(_onClientChanged);

    try {
      if (endSession && client.status != ConversationStatus.disconnected) {
        await client.endSession().timeout(_sessionOperationTimeout);
      }
    } catch (e) {
      _debugLog('Error ending session during cleanup: $e');
    } finally {
      try {
        client.dispose();
      } catch (e) {
        _debugLog('Error disposing conversation client: $e');
      }
    }
  }

  void _updateDisconnectedState() {
    _updateState(ConversationState.idle);
    _connectionController.add('disconnected');
    FFAppState().update(() {
      FFAppState().wsConnectionState = 'disconnected';
      FFAppState().isRecording = false;
    });
  }
}
