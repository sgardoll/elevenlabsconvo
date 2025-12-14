import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data'; // Added for Uint8List
import 'package:flutter/foundation.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart';
import 'package:permission_handler/permission_handler.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart'; // Imports custom actions

enum ConversationState {
  idle,
  connecting,
  connected,
  recording,
  playing,
  error
}

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

class ConversationalAIService {
  static final ConversationalAIService _instance =
      ConversationalAIService._internal();
  factory ConversationalAIService() => _instance;
  ConversationalAIService._internal();

  // ElevenLabs SDK Client
  ConversationClient? _client;

  // Configuration
  String _agentId = '';
  String _endpoint = ''; // kept for compatibility
  String? _conversationId;

  // State management
  bool _isDisposing = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

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
      _client?.status == ConversationStatus.connected && !(_client?.isMuted ?? true);
  bool get isAgentSpeaking => _client?.isSpeaking ?? false;
  bool get isConnected => _client?.status == ConversationStatus.connected;
  bool get isDisposing => _isDisposing;
  bool get isInterrupted => false; // SDK handles interruptions internally
  String get currentAudioSessionId => _client?.conversationId ?? '';
  ConversationState get currentState => _getCurrentState();

  // Get or refresh conversation token
  Future<String?> _getConversationToken() async {
    // Check if we have a valid cached token
    if (!FFAppState().isSignedUrlExpired &&
        FFAppState().cachedSignedUrl.isNotEmpty) {
      debugPrint('🔐 Using cached conversation token');
      return FFAppState().cachedSignedUrl;
    }

    // Fetch new token
    debugPrint('🔐 Fetching new conversation token');
    final token = await getSignedUrl(_agentId, _endpoint);

    if (token != null) {
      // Cache the token with 15-minute expiration
      FFAppState().update(() {
        FFAppState().cachedSignedUrl = token;
        FFAppState().signedUrlExpirationTime =
            DateTime.now().add(Duration(minutes: 15));
      });
      debugPrint('🔐 Conversation token cached successfully');
      return token;
    } else {
      debugPrint('❌ Failed to obtain conversation token');
      return null;
    }
  }

  Future<String> initialize(
      {required String agentId, required String endpoint}) async {
    if (_agentId == agentId && _endpoint == endpoint && isConnected) {
      debugPrint('🔌 Service already initialized and connected');
      return 'success';
    }

    debugPrint('🔌 Initializing ElevenLabs Official SDK Service');
    _isDisposing = false;
    _agentId = agentId;
    _endpoint = endpoint;

    // Request permissions
    await _requestPermissions();

    try {
      await _connect();
      FFAppState().update(() {
        FFAppState().wsConnectionState = 'connected';
        FFAppState().elevenLabsAgentId = agentId;
        FFAppState().endpoint = endpoint;
      });
      return 'success';
    } catch (e) {
      debugPrint('❌ Error initializing service: $e');
      return 'error: ${e.toString()}';
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
  }

  Future<void> _connect() async {
    _stateController.add(ConversationState.connecting);
    _connectionController.add('connecting');

    // Clean up existing client if any
    _client?.dispose();

    // Initialize Client
    _client = ConversationClient(
      callbacks: ConversationCallbacks(
        onConnect: ({required conversationId}) {
          debugPrint('🔌 Connected with ID: $conversationId');
          _conversationId = conversationId;
          _isConnected = true;
          _reconnectAttempts = 0;
          _stateController.add(ConversationState.connected);
          _connectionController.add('connected');

           final message = ConversationMessage(
            type: 'system',
            content: 'Connected to ElevenLabs Agent',
            timestamp: DateTime.now(),
            conversationId: _conversationId,
          );
          _conversationController.add(message);
          _updateFFAppStateMessages(message);
        },
        onDisconnect: (details) {
           // Corrected based on documentation (assumed 'details' object has reason/source)
          debugPrint('🔌 Disconnected');
          _handleDisconnect();
        },
        onStatusChange: ({required status}) {
           debugPrint('🔌 Status changed: ${status.name}');
           _stateController.add(_getCurrentState());
        },
        onError: (error, [context]) {
          debugPrint('❌ Client Error: $error');
          _handleError(error);
        },
        onMessage: ({required message, required source}) {
           debugPrint('[${source.name}] $message');
           final msgType = source == Role.user ? 'user' : 'agent';
           final convMsg = ConversationMessage(
            type: msgType,
            content: message,
            timestamp: DateTime.now(),
          );
          _conversationController.add(convMsg);
          _updateFFAppStateMessages(convMsg);
        },
        onModeChange: ({required mode}) {
           debugPrint('Mode changed: ${mode.name}');
           _stateController.add(_getCurrentState());
        },
        onUserTranscript: ({required transcript, required eventId}) {
          debugPrint('User said: $transcript');
        },
        onInterruption: (event) {
          debugPrint('User interrupted agent');
           final message = ConversationMessage(
            type: 'system',
            content: 'Interruption detected',
            timestamp: DateTime.now(),
          );
          _conversationController.add(message);
        },
      ),
    );

    try {
      final token = await _getConversationToken();
      if (token == null) {
        throw Exception('Failed to obtain conversation token');
      }

      await _client?.startSession(
        conversationToken: token,
      );

      // Sync initial recording state (unmuted by default usually)
      if (!(_client?.isMuted ?? true)) {
         _recordingController.add(true);
         _stateController.add(ConversationState.recording);
         FFAppState().update(() {
            FFAppState().isRecording = true;
         });
      }

    } catch (e) {
      debugPrint('❌ Connection error: $e');
      _handleError(e);
    }
  }

  Future<String> toggleRecording() async {
    if (isRecording) {
      return await stopRecording();
    } else {
      return await startRecording();
    }
  }

  Future<String> startRecording() async {
    if (!_isConnected) {
       debugPrint('❌ Cannot start recording - not connected');
       return 'error: Not connected';
    }

    try {
      debugPrint('🎙️ Unmuting microphone...');
      await _client?.setMicMuted(false);

      _recordingController.add(true);
      _stateController.add(ConversationState.recording);
      FFAppState().update(() {
        FFAppState().isRecording = true;
      });
      return 'success';
    } catch (e) {
       debugPrint('❌ Error starting recording: $e');
       return 'error: $e';
    }
  }

  Future<String> stopRecording() async {
    if (!_isConnected) {
       debugPrint('❌ Cannot stop recording - not connected');
       return 'error: Not connected';
    }

    try {
      debugPrint('🎙️ Muting microphone...');
      await _client?.setMicMuted(true);

      _recordingController.add(false);
      _stateController.add(ConversationState.connected);
      FFAppState().update(() {
        FFAppState().isRecording = false;
      });
      return 'success';
    } catch (e) {
       debugPrint('❌ Error stopping recording: $e');
       return 'error: $e';
    }
  }

  Future<String> sendTextMessage(String text) async {
    if (!_isConnected) {
      return 'error: Not connected';
    }
    try {
      _client?.sendUserMessage(text);
      debugPrint('💬 Text message sent: $text');
      return 'success';
    } catch (e) {
      debugPrint('❌ Error sending text message: $e');
      return 'error: ${e.toString()}';
    }
  }

  void _updateFFAppStateMessages(ConversationMessage message) {
    FFAppState().update(() {
      FFAppState().conversationMessages = [
        ...FFAppState().conversationMessages,
        message.toJson()
      ];
    });
  }

  ConversationState _getCurrentState() {
    if (!isConnected) return ConversationState.idle;
    if (isRecording) return ConversationState.recording;
    if (isAgentSpeaking) return ConversationState.playing;
    return ConversationState.connected;
  }

  // Keep internal isConnected flag sync'd for logic that runs before/after client updates
  bool _isConnected = false;

  void _handleError(dynamic error) {
    debugPrint('❌ Service error: $error');
    _stateController.add(ConversationState.error);
    _connectionController.add('error: ${error.toString()}');
    FFAppState().update(() {
      FFAppState().wsConnectionState =
          'error: ${error.toString().substring(0, math.min(50, error.toString().length))}';
    });

    if (!_isDisposing) {
      _scheduleReconnect();
    }
  }

  void _handleDisconnect() {
    debugPrint('🔌 Service disconnected');
    _isConnected = false;
    _stateController.add(ConversationState.idle);
    _connectionController.add('disconnected');
    FFAppState().update(() {
      FFAppState().wsConnectionState = 'disconnected';
    });

    if (!_isDisposing) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= 5) {
      debugPrint('🔌 Maximum reconnect attempts reached');
      return;
    }
    if (_isDisposing) {
      debugPrint('🔌 Service is disposing, skipping reconnect');
      return;
    }
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: math.pow(2, _reconnectAttempts).toInt());
    _reconnectTimer = Timer(delay, () {
      if (!_isDisposing) {
        _connect();
      }
    });
    _reconnectAttempts++;
  }

  Future<void> dispose() async {
    debugPrint('🔌 Disposing Conversational AI Service');
    _isDisposing = true;
    _reconnectTimer?.cancel();

    if (_isConnected) {
        await _client?.endSession();
    }
    _client?.dispose();
    _client = null;

    await _conversationController.close();
    await _stateController.close();
    await _recordingController.close();
    await _connectionController.close();

    debugPrint('🔌 Conversational AI Service disposed');
  }

  Future<void> triggerInterruption() async {
      debugPrint('Trigger interruption called - handled by SDK automatically usually');
  }
}
