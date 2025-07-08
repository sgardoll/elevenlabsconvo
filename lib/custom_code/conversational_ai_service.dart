import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:math' as math;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '/flutter_flow/flutter_flow_util.dart';

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

  // Core components
  WebSocketChannel? _channel;
  final AudioRecorder _recorder = AudioRecorder();

  // --- REFACTORED AUDIO COMPONENTS ---
  final AudioPlayer _player = AudioPlayer();
  late ConcatenatingAudioSource _playlist;
  final List<String> _tempFilePaths = []; // Track file paths
  // --- END REFACTORED AUDIO COMPONENTS ---

  // Configuration
  String _apiKey = '';
  String _agentId = '';
  String? _conversationId;

  // State management
  bool _isRecording = false;
  bool _isAgentSpeaking = false;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  bool _recordingPaused = false;
  int _tempFileCounter = 0;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _currentIndexSubscription;

  // Enhanced interruption state management
  bool _isInterrupted = false;
  DateTime? _lastInterruptionTime;
  String _currentAudioSessionId = '';
  static const int _audioChunkGracePeriodMs =
      500; // Grace period for late chunks

  // Enhanced turn detection
  double _lastVadScore = 0.0;
  double _vadThreshold = 0.4;
  int _consecutiveHighVadCount = 0;
  Timer? _vadMonitorTimer;

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
  bool get isRecording => _isRecording;
  bool get isAgentSpeaking => _isAgentSpeaking;
  bool get isConnected => _isConnected;
  bool get isInterrupted => _isInterrupted;
  String get currentAudioSessionId => _currentAudioSessionId;
  ConversationState get currentState => _getCurrentState();

  Future<String> initialize(
      {required String apiKey, required String agentId}) async {
    if (_apiKey == apiKey && _agentId == agentId && _isConnected) {
      debugPrint('🔌 Service already initialized and connected');
      return 'success';
    }

    debugPrint('🔌 Initializing Conversational AI Service v2.0');
    _apiKey = apiKey;
    _agentId = agentId;

    _playlist = ConcatenatingAudioSource(children: []);

    // Cancel previous subscriptions if they exist
    await _playerStateSubscription?.cancel();
    await _currentIndexSubscription?.cancel();

    // Listen for when the entire playlist completes
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _resetAgentSpeakingState();
      }
    });

    // Listen for when the player moves to the next track to clean up the previous one
    _currentIndexSubscription = _player.currentIndexStream.listen((index) {
      if (index != null && index > 0) {
        // We've moved to a new track, so the previous one (at index - 1) can be deleted
        final fileToDelete = _tempFilePaths[index - 1];
        _deleteTempFile(fileToDelete);
      }
    });

    try {
      await _connect();
      FFAppState().update(() {
        FFAppState().wsConnectionState = 'connected';
        FFAppState().elevenLabsApiKey = apiKey;
        FFAppState().elevenLabsAgentId = agentId;
      });
      return 'success';
    } catch (e) {
      debugPrint('❌ Error initializing service: $e');
      return 'error: ${e.toString()}';
    }
  }

  Future<void> _playAudio(String base64Audio) async {
    try {
      // Check for interruption state - reject stale audio chunks
      if (_isInterrupted && _lastInterruptionTime != null) {
        final timeSinceInterruption =
            DateTime.now().difference(_lastInterruptionTime!).inMilliseconds;
        if (timeSinceInterruption < _audioChunkGracePeriodMs) {
          debugPrint(
              '🔊 Ignoring stale audio chunk (${timeSinceInterruption}ms since interruption)');
          return;
        }
      }

      if (!_isAgentSpeaking) {
        // Start new audio session
        _currentAudioSessionId = _generateAudioSessionId();
        _isAgentSpeaking = true;
        _isInterrupted = false; // Reset interruption flag for new session
        _lastInterruptionTime = null;

        // Don't pause recording - allow continuous audio for turn detection
        _recordingPaused = false;
        _stateController.add(ConversationState.playing);
        // Ensure old playlist and files are cleared before starting a new one
        await _clearPlaylistAndFiles();
        await _player.setAudioSource(_playlist);
        debugPrint(
            '🔊 Started new audio session ${_currentAudioSessionId} (recording continues for turn detection)');
      }

      final audioBytes = base64Decode(base64Audio);
      if (audioBytes.length < 10) return;

      final wavBytes = _createWavFile(audioBytes);
      final tempFile = await _createTempFile(wavBytes);

      _tempFilePaths.add(tempFile.path);
      await _playlist.add(AudioSource.uri(Uri.file(tempFile.path)));
      debugPrint(
          '🔊 Added audio chunk to playlist. Session: ${_currentAudioSessionId}, Total chunks: ${_playlist.length}');

      if (!_player.playing) {
        _player.play();
        debugPrint('🔊 Started playlist playback');
      }
    } catch (e) {
      debugPrint('❌ Error playing audio: $e');
    }
  }

  void _resetAgentSpeakingState() async {
    debugPrint(
        '🔊 Resetting agent speaking state (Session: $_currentAudioSessionId)');
    _isAgentSpeaking = false;
    _recordingPaused = false;

    // Reset interruption state when audio naturally completes
    _isInterrupted = false;
    _lastInterruptionTime = null;
    _currentAudioSessionId = '';

    _stateController.add(
        _isConnected ? ConversationState.connected : ConversationState.idle);
    await _clearPlaylistAndFiles();
  }

  // Public method to manually trigger interruption (for user-initiated interruption)
  Future<void> triggerInterruption() async {
    debugPrint('🔊 Manual interruption triggered by user');
    _handleUserInterruption();
  }

  // Generate unique audio session ID
  String _generateAudioSessionId() {
    return 'audio_session_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}';
  }

  // Handle user interruption by immediately stopping agent audio
  Future<void> _handleUserInterruption() async {
    debugPrint(
        '🔊 User interrupted agent - stopping audio immediately (Session: $_currentAudioSessionId)');

    // Set interruption state immediately
    _isInterrupted = true;
    _lastInterruptionTime = DateTime.now();

    if (_isAgentSpeaking) {
      // Stop audio playback immediately
      await _player.stop();

      // Clear the playlist to prevent further playback
      await _playlist.clear();

      // Reset speaking state
      _isAgentSpeaking = false;
      _recordingPaused = false;

      // Update UI state
      _stateController.add(
          _isConnected ? ConversationState.connected : ConversationState.idle);

      // Clean up temp files
      for (final path in _tempFilePaths) {
        _deleteTempFile(path);
      }
      _tempFilePaths.clear();
      _tempFileCounter = 0;

      // Invalidate current audio session
      _currentAudioSessionId = '';

      debugPrint('🔊 Audio session interrupted and cleaned up');
    }
  }

  // Handle VAD scores for enhanced turn detection
  void _handleVadScore(Map<String, dynamic> data) {
    final vadScore = data['vad_score_event']?['score'];
    if (vadScore != null) {
      _lastVadScore = vadScore.toDouble();

      // Monitor for user speech during agent speaking
      if (_isAgentSpeaking &&
          !_isInterrupted &&
          _lastVadScore > _vadThreshold) {
        _consecutiveHighVadCount++;
        debugPrint(
            '🎤 High VAD score detected during agent speech: $_lastVadScore (count: $_consecutiveHighVadCount)');

        // If we detect sustained user speech, trigger interruption
        // Reduced threshold for faster response (was 2, now 1 for immediate response)
        if (_consecutiveHighVadCount >= 1) {
          debugPrint(
              '🎤 Sustained user speech detected - triggering interruption');
          _handleUserInterruption();
          _consecutiveHighVadCount = 0;
        }
      } else if (_lastVadScore <= _vadThreshold) {
        _consecutiveHighVadCount = 0;
      }
    }
  }

  // Enhanced audio level monitoring
  double _calculateAudioLevel(Uint8List audioChunk) {
    if (audioChunk.isEmpty) return 0.0;

    double sum = 0.0;
    for (int i = 0; i < audioChunk.length; i += 2) {
      if (i + 1 < audioChunk.length) {
        // Convert 16-bit PCM to amplitude
        int sample = (audioChunk[i + 1] << 8) | audioChunk[i];
        if (sample > 32767) sample -= 65536;
        sum += sample.abs();
      }
    }

    double average = sum / (audioChunk.length / 2);
    return average / 32767.0; // Normalize to 0-1 range
  }

  Future<void> _clearPlaylistAndFiles() async {
    await _player.stop();
    await _playlist.clear();
    for (final path in _tempFilePaths) {
      _deleteTempFile(path);
    }
    _tempFilePaths.clear();
    _tempFileCounter = 0;
  }

  void _deleteTempFile(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
        debugPrint('🗑️ Deleted temp file: $path');
      }
    } catch (e) {
      debugPrint('⚠️ Could not delete temp file $path: $e');
    }
  }

  Uint8List _createWavFile(Uint8List pcmData) {
    const int sampleRate = 16000;
    const int bitsPerSample = 16;
    const int channels = 1;
    final int dataSize = pcmData.length;
    final int fileSize = 44 + dataSize;
    final ByteData wavHeader = ByteData(44);
    wavHeader.setUint8(0, 0x52); // 'R'
    wavHeader.setUint8(1, 0x49); // 'I'
    wavHeader.setUint8(2, 0x46); // 'F'
    wavHeader.setUint8(3, 0x46); // 'F'
    wavHeader.setUint32(4, fileSize - 8, Endian.little);
    wavHeader.setUint8(8, 0x57); // 'W'
    wavHeader.setUint8(9, 0x41); // 'A'
    wavHeader.setUint8(10, 0x56); // 'V'
    wavHeader.setUint8(11, 0x45); // 'E'
    wavHeader.setUint8(12, 0x66); // 'f'
    wavHeader.setUint8(13, 0x6d); // 'm'
    wavHeader.setUint8(14, 0x74); // 't'
    wavHeader.setUint8(15, 0x20); // ' '
    wavHeader.setUint32(16, 16, Endian.little);
    wavHeader.setUint16(20, 1, Endian.little);
    wavHeader.setUint16(22, channels, Endian.little);
    wavHeader.setUint32(24, sampleRate, Endian.little);
    wavHeader.setUint32(
        28, sampleRate * channels * bitsPerSample ~/ 8, Endian.little);
    wavHeader.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
    wavHeader.setUint16(34, bitsPerSample, Endian.little);
    wavHeader.setUint8(36, 0x64); // 'd'
    wavHeader.setUint8(37, 0x61); // 'a'
    wavHeader.setUint8(38, 0x74); // 't'
    wavHeader.setUint8(39, 0x61); // 'a'
    wavHeader.setUint32(40, dataSize, Endian.little);
    final Uint8List wavFile = Uint8List(fileSize);
    wavFile.setRange(0, 44, wavHeader.buffer.asUint8List());
    wavFile.setRange(44, fileSize, pcmData);
    return wavFile;
  }

  Future<File> _createTempFile(Uint8List data) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/temp_audio_${_tempFileCounter++}.wav');
    await file.writeAsBytes(data);
    return file;
  }

  Future<void> _connect() async {
    _stateController.add(ConversationState.connecting);
    _connectionController.add('connecting');

    // Reset interruption state on new connection
    _isInterrupted = false;
    _lastInterruptionTime = null;
    _currentAudioSessionId = '';

    try {
      final uri = Uri.parse(
          'wss://api.elevenlabs.io/v1/convai/conversation?agent_id=${Uri.encodeComponent(_agentId)}');
      _channel = IOWebSocketChannel.connect(
        uri,
        headers: {
          'xi-api-key': _apiKey,
          'User-Agent': 'ElevenLabs-Flutter-Consolidated/2.0',
        },
      );
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );
      _sendInitialization();
      _isConnected = true;
      _reconnectAttempts = 0;
      _stateController.add(ConversationState.connected);
      _connectionController.add('connected');
      debugPrint(
          '🔌 Conversational AI Service connected successfully with clean state');
    } catch (e) {
      debugPrint('❌ Connection error: $e');
      _handleError(e);
    }
  }

  void _sendInitialization() {
    final initMessage = jsonEncode({
      'type': 'conversation_initiation_client_data',
      'conversation_config_override': {
        'agent': {
          'language': 'en',
          'turn_detection': {
            'type': 'server_vad',
            'threshold': 0.4,
            'silence_duration_ms': 500,
            'prefix_padding_ms': 300,
            'suffix_padding_ms': 200
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
    _channel!.sink.add(initMessage);
    debugPrint(
        '🔌 Initialization message sent with server-side turn detection');
  }

  Future<String> toggleRecording() async {
    if (_isRecording) {
      return await stopRecording();
    } else {
      return await startRecording();
    }
  }

  Future<String> startRecording() async {
    if (_isRecording || _isAgentSpeaking) {
      debugPrint(
          '⚠️ Cannot start recording - already recording or agent speaking');
      return 'error: Cannot start recording';
    }
    if (!_isConnected) {
      debugPrint('❌ Cannot start recording - not connected');
      return 'error: Not connected';
    }
    try {
      debugPrint('🎙️ Starting real-time recording...');
      final recordingStream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );
      _audioStreamSubscription = recordingStream.listen(
        _handleAudioChunk,
        onError: (error) => debugPrint('❌ Audio stream error: $error'),
        onDone: () => debugPrint('🎙️ Audio stream ended'),
      );
      _isRecording = true;
      _recordingController.add(true);
      _stateController.add(ConversationState.recording);
      FFAppState().update(() {
        FFAppState().isRecording = true;
      });
      debugPrint('🎙️ Recording started successfully');
      return 'success';
    } catch (e) {
      debugPrint('❌ Error starting recording: $e');
      return 'error: ${e.toString()}';
    }
  }

  Future<String> stopRecording() async {
    if (!_isRecording) {
      debugPrint('⚠️ Not currently recording');
      return 'error: Not recording';
    }
    try {
      debugPrint('🎙️ Stopping recording...');
      await _recorder.stop();
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      if (_isConnected) {
        _channel!.sink.add(jsonEncode({'type': 'user_turn_ended'}));
        await _sendUserActivity();
      }
      _isRecording = false;
      _recordingController.add(false);
      _stateController.add(
          _isConnected ? ConversationState.connected : ConversationState.idle);
      FFAppState().update(() {
        FFAppState().isRecording = false;
      });
      debugPrint('🎙️ Recording stopped successfully');
      return 'success';
    } catch (e) {
      debugPrint('❌ Error stopping recording: $e');
      return 'error: ${e.toString()}';
    }
  }

  Future<void> _handleAudioChunk(Uint8List audioChunk) async {
    if (!_isConnected) {
      return;
    }

    // Calculate audio level for local monitoring
    double audioLevel = _calculateAudioLevel(audioChunk);

    // Enhanced local interruption detection
    if (_isAgentSpeaking && !_isInterrupted && audioLevel > 0.15) {
      debugPrint(
          '🎤 High local audio level detected during agent speech: ${audioLevel.toStringAsFixed(3)}');

      // Trigger immediate interruption on strong local audio signal
      if (audioLevel > 0.3) {
        debugPrint(
            '🎤 Strong user audio detected - triggering immediate interruption');
        await _handleUserInterruption();
        return; // Don't send this chunk if we're interrupting
      }
    }

    // Continue sending audio chunks even when agent is speaking
    // This allows server-side turn detection and interruption handling
    try {
      final base64Audio = base64Encode(audioChunk);
      final audioMessage = jsonEncode({'user_audio_chunk': base64Audio});
      _channel!.sink.add(audioMessage);

      // Log high audio levels during agent speech for debugging
      if (_isAgentSpeaking && audioLevel > 0.1) {
        debugPrint(
            '🎤 User audio level during agent speech: ${audioLevel.toStringAsFixed(3)}');
      }
    } catch (e) {
      debugPrint('❌ Error sending audio chunk: $e');
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final jsonData = jsonDecode(message);
      final messageType = jsonData['type'] ?? 'unknown';
      switch (messageType) {
        case 'conversation_initiation_metadata':
          _handleConversationInit(jsonData);
          break;
        case 'user_transcript':
          _handleUserTranscript(jsonData);
          break;
        case 'agent_response':
          _handleAgentResponse(jsonData);
          break;
        case 'audio':
          _handleAudioResponse(jsonData);
          break;
        case 'vad_score':
          _handleVadScore(jsonData);
          break;
        case 'interruption':
          _handleInterruption(jsonData);
          break;
        default:
          debugPrint('🔌 Received message type: $messageType');
      }
    } catch (e) {
      debugPrint('❌ Error handling message: $e');
    }
  }

  void _handleConversationInit(Map<String, dynamic> data) {
    _conversationId =
        data['conversation_initiation_metadata_event']?['conversation_id'];
    debugPrint('🔌 Conversation ID: $_conversationId');
    final message = ConversationMessage(
      type: 'system',
      content: 'Conversational AI 2.0 session started',
      timestamp: DateTime.now(),
      conversationId: _conversationId,
    );
    _conversationController.add(message);
    _updateFFAppStateMessages(message);
  }

  void _handleUserTranscript(Map<String, dynamic> data) {
    final transcript = data['user_transcription_event']?['user_transcript'];
    if (transcript != null) {
      final message = ConversationMessage(
        type: 'user',
        content: transcript,
        timestamp: DateTime.now(),
      );
      _conversationController.add(message);
      _updateFFAppStateMessages(message);
      debugPrint('👤 User: $transcript');
    }
  }

  void _handleAgentResponse(Map<String, dynamic> data) {
    final response = data['agent_response_event']?['agent_response'];
    if (response != null) {
      final message = ConversationMessage(
        type: 'agent',
        content: response,
        timestamp: DateTime.now(),
      );
      _conversationController.add(message);
      _updateFFAppStateMessages(message);
      debugPrint('🤖 Agent: $response');
    }
  }

  void _handleAudioResponse(Map<String, dynamic> data) {
    final base64Audio = data['audio_event']?['audio_base_64'];
    if (base64Audio != null && base64Audio.isNotEmpty) {
      _playAudio(base64Audio);
    }
  }

  void _handleInterruption(Map<String, dynamic> data) {
    final reason = data['interruption_event']?['reason'];
    debugPrint('🔌 Conversation interrupted: $reason');

    // Immediately stop agent audio when user interrupts
    _handleUserInterruption();

    final message = ConversationMessage(
      type: 'system',
      content: 'Conversation interrupted: $reason',
      timestamp: DateTime.now(),
    );
    _conversationController.add(message);
    _updateFFAppStateMessages(message);
  }

  Future<String> sendTextMessage(String text) async {
    if (!_isConnected) {
      return 'error: Not connected';
    }
    try {
      final textMessage = jsonEncode({'type': 'user_message', 'text': text});
      _channel!.sink.add(textMessage);
      debugPrint('💬 Text message sent: $text');
      return 'success';
    } catch (e) {
      debugPrint('❌ Error sending text message: $e');
      return 'error: ${e.toString()}';
    }
  }

  Future<void> _sendUserActivity() async {
    if (_isConnected) {
      try {
        _channel!.sink.add(jsonEncode({'type': 'user_activity'}));
      } catch (e) {
        debugPrint('❌ Error sending user activity: $e');
      }
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
    if (!_isConnected) return ConversationState.idle;
    if (_isRecording) return ConversationState.recording;
    if (_isAgentSpeaking) return ConversationState.playing;
    return ConversationState.connected;
  }

  void _handleError(dynamic error) {
    debugPrint('❌ Service error: $error');
    _stateController.add(ConversationState.error);
    _connectionController.add('error: ${error.toString()}');
    FFAppState().update(() {
      FFAppState().wsConnectionState =
          'error: ${error.toString().substring(0, math.min(50, error.toString().length))}';
    });
    _scheduleReconnect();
  }

  void _handleDisconnect() {
    debugPrint('🔌 Service disconnected');
    _isConnected = false;
    _stateController.add(ConversationState.idle);
    _connectionController.add('disconnected');
    FFAppState().update(() {
      FFAppState().wsConnectionState = 'disconnected';
    });
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= 5) {
      debugPrint('🔌 Maximum reconnect attempts reached');
      return;
    }
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: math.pow(2, _reconnectAttempts).toInt());
    _reconnectTimer = Timer(delay, () => _connect());
    _reconnectAttempts++;
  }

  Future<void> dispose() async {
    debugPrint('🔌 Disposing Conversational AI Service');
    if (_isRecording) {
      await stopRecording();
    }

    // Handle any active audio interruption
    if (_isAgentSpeaking) {
      await _handleUserInterruption();
    }

    // Reset interruption state
    _isInterrupted = false;
    _lastInterruptionTime = null;
    _currentAudioSessionId = '';

    // Cancel VAD monitoring
    _vadMonitorTimer?.cancel();

    // Clean up audio components
    await _player.dispose();
    await _playerStateSubscription?.cancel();
    await _currentIndexSubscription?.cancel();

    // Close connection
    await _channel?.sink.close();
    await _recorder.dispose();
    await _audioStreamSubscription?.cancel();

    // Cancel timers
    _reconnectTimer?.cancel();

    // Close streams
    await _conversationController.close();
    await _stateController.close();
    await _recordingController.close();
    await _connectionController.close();

    // Clean up temporary files
    for (final path in _tempFilePaths) {
      _deleteTempFile(path);
    }
    _tempFilePaths.clear();

    debugPrint('🔌 Conversational AI Service disposed with enhanced cleanup');
  }
}
