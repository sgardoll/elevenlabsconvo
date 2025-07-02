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
  AudioPlayer? _player;

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

  // Audio feedback prevention
  bool _recordingPaused = false;

  // Timer to reset speaking state
  Timer? _speakingResetTimer;

  // Audio queue management
  final List<String> _audioQueue = [];
  bool _isPlayingQueue = false;
  int _audioChunkCounter = 0;

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
  ConversationState get currentState => _getCurrentState();

  // =============================================================================
  // 1. CONNECTION MANAGEMENT
  // =============================================================================

  Future<String> initialize(
      {required String apiKey, required String agentId}) async {
    if (_apiKey == apiKey && _agentId == agentId && _isConnected) {
      debugPrint('🔌 Service already initialized and connected');
      return 'success';
    }

    debugPrint('🔌 Initializing Conversational AI Service v2.0');
    _apiKey = apiKey;
    _agentId = agentId;

    try {
      await _connect();

      // Update FFAppState
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

  Future<void> _connect() async {
    _stateController.add(ConversationState.connecting);
    _connectionController.add('connecting');

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

      debugPrint('🔌 Conversational AI Service connected successfully');
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
            'type': 'client_vad',
            'threshold': 0.6,
            'silence_duration_ms': 1000
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
    debugPrint('🔌 Initialization message sent');
  }

  // =============================================================================
  // 2. RECORDING MANAGEMENT
  // =============================================================================

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

      // Update FFAppState
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

      // Send end-of-turn signal
      if (_isConnected) {
        _channel!.sink.add(jsonEncode({'type': 'user_turn_ended'}));
        await _sendUserActivity();
      }

      _isRecording = false;
      _recordingController.add(false);
      _stateController.add(
          _isConnected ? ConversationState.connected : ConversationState.idle);

      // Update FFAppState
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

  void _handleAudioChunk(Uint8List audioChunk) {
    if (!_isConnected || _isAgentSpeaking || _recordingPaused) {
      return;
    }

    try {
      final base64Audio = base64Encode(audioChunk);
      final audioMessage = jsonEncode({'user_audio_chunk': base64Audio});
      _channel!.sink.add(audioMessage);
    } catch (e) {
      debugPrint('❌ Error sending audio chunk: $e');
    }
  }

  // =============================================================================
  // 3. MESSAGE HANDLING (consolidates WebSocket message processing)
  // =============================================================================

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

  void _handleVadScore(Map<String, dynamic> data) {
    final vadScore = data['vad_score_event']?['vad_score'];
    // Could be used for UI feedback if needed
  }

  void _handleInterruption(Map<String, dynamic> data) {
    final reason = data['interruption_event']?['reason'];
    debugPrint('🔌 Conversation interrupted: $reason');

    final message = ConversationMessage(
      type: 'system',
      content: 'Conversation interrupted: $reason',
      timestamp: DateTime.now(),
    );

    _conversationController.add(message);
    _updateFFAppStateMessages(message);
  }

  // =============================================================================
  // 4. AUDIO PLAYBACK
  // =============================================================================

  Future<void> _playAudio(String base64Audio) async {
    // Add to queue instead of playing immediately
    _audioQueue.add(base64Audio);
    debugPrint(
        '🔊 Added audio chunk to queue. Queue length: ${_audioQueue.length}');

    // Set agent speaking state on first chunk
    if (!_isAgentSpeaking) {
      _isAgentSpeaking = true;
      _recordingPaused = true;
      _stateController.add(ConversationState.playing);
    }

    // Start processing queue if not already processing
    if (!_isPlayingQueue) {
      _processAudioQueue();
    }
  }

  Future<void> _processAudioQueue() async {
    if (_isPlayingQueue || _audioQueue.isEmpty) {
      return;
    }

    _isPlayingQueue = true;
    debugPrint('🔊 Starting audio queue processing');

    while (_audioQueue.isNotEmpty) {
      final base64Audio = _audioQueue.removeAt(0);
      await _playAudioChunk(base64Audio);
    }

    _isPlayingQueue = false;
    debugPrint('🔊 Audio queue processing completed');

    // Reset speaking state after queue is done
    _resetAgentSpeakingState();
  }

  Future<void> _playAudioChunk(String base64Audio) async {
    final chunkId = ++_audioChunkCounter;

    try {
      final audioBytes = base64Decode(base64Audio);
      if (audioBytes.length < 10) {
        debugPrint('🔊 Chunk $chunkId: Audio data too small, skipping');
        return;
      }

      debugPrint(
          '🔊 Chunk $chunkId: Playing audio: ${audioBytes.length} bytes');

      // Create WAV file from PCM data
      final wavBytes = _createWavFile(audioBytes);
      final tempFile = await _createTempFile(wavBytes);

      // Create a new player for this audio chunk
      final player = AudioPlayer();

      try {
        // Set audio source
        await player.setAudioSource(AudioSource.uri(Uri.file(tempFile.path)));
        debugPrint('🔊 Chunk $chunkId: Audio source set: ${tempFile.path}');

        final duration = player.duration;
        debugPrint('🔊 Chunk $chunkId: Audio duration: $duration');

        // Set volume and play
        await player.setVolume(1.0);
        await player.play();
        debugPrint('🔊 Chunk $chunkId: Audio play() started');

        // Wait for playback to complete
        bool completed = false;

        final stateSubscription = player.playerStateStream.listen((state) {
          debugPrint(
              '🔊 Chunk $chunkId: State ${state.processingState}, playing: ${state.playing}');

          if (state.processingState == ProcessingState.completed) {
            completed = true;
          }
        });

        // Wait for completion with timeout
        final startTime = DateTime.now();
        while (
            !completed && DateTime.now().difference(startTime).inSeconds < 15) {
          await Future.delayed(Duration(milliseconds: 100));
        }

        if (!completed) {
          debugPrint('⚠️ Chunk $chunkId: Audio playback timeout');
        } else {
          debugPrint('🔊 Chunk $chunkId: Audio playback completed');
        }

        await stateSubscription.cancel();
      } finally {
        // Always dispose the player and cleanup
        await player.dispose();
        try {
          await tempFile.delete();
        } catch (e) {
          debugPrint('⚠️ Chunk $chunkId: Could not delete temp file: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Chunk $chunkId: Error playing audio: $e');
    }
  }

  void _resetAgentSpeakingState() {
    debugPrint('🔊 Resetting agent speaking state');
    _isAgentSpeaking = false;
    _recordingPaused = false;
    _stateController.add(
        _isConnected ? ConversationState.connected : ConversationState.idle);
  }

  Uint8List _createWavFile(Uint8List pcmData) {
    const int sampleRate = 16000;
    const int bitsPerSample = 16;
    const int channels = 1;
    final int dataSize = pcmData.length;
    final int fileSize = 44 + dataSize;

    final ByteData wavHeader = ByteData(44);

    // RIFF header
    wavHeader.setUint8(0, 0x52); // 'R'
    wavHeader.setUint8(1, 0x49); // 'I'
    wavHeader.setUint8(2, 0x46); // 'F'
    wavHeader.setUint8(3, 0x46); // 'F'
    wavHeader.setUint32(4, fileSize - 8, Endian.little);

    // WAVE header
    wavHeader.setUint8(8, 0x57); // 'W'
    wavHeader.setUint8(9, 0x41); // 'A'
    wavHeader.setUint8(10, 0x56); // 'V'
    wavHeader.setUint8(11, 0x45); // 'E'

    // fmt chunk
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

    // data chunk
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
    final file = File(
        '${dir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.wav');
    await file.writeAsBytes(data);
    return file;
  }

  // =============================================================================
  // 5. TEXT MESSAGING (implements sendTextToWebSocket)
  // =============================================================================

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

  // =============================================================================
  // 6. UTILITY METHODS
  // =============================================================================

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

  // =============================================================================
  // 7. CLEANUP
  // =============================================================================

  Future<void> dispose() async {
    debugPrint('🔌 Disposing Conversational AI Service');

    if (_isRecording) {
      await stopRecording();
    }

    // Clear audio queue
    _audioQueue.clear();
    _isPlayingQueue = false;

    await _channel?.sink.close();
    await _recorder.dispose();
    await _player?.dispose();
    await _audioStreamSubscription?.cancel();
    _reconnectTimer?.cancel();
    _speakingResetTimer?.cancel();

    await _conversationController.close();
    await _stateController.close();
    await _recordingController.close();
    await _connectionController.close();
  }
}
