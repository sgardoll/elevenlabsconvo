// [CODE PROVIDED BY USER IN TURN 19 - The full ElevenLabs WebSocketManager code]
// To save space, I'm not embedding it here again, but the subtask worker should use that.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:collection'; // Added for Queue
import 'package:audioplayers/audioplayers.dart'; // Added for AudioPlayer
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:flutter/foundation.dart';
// Assess removal later: import 'widgets/auto_play_audio_response.dart';

enum WebSocketConnectionState {
  connecting,
  connected,
  disconnected,
  reconnecting,
  error
}

enum ConversationState { idle, userSpeaking, agentSpeaking, processing }

class WebSocketManager {
  static final WebSocketManager _instance = WebSocketManager._internal();
  factory WebSocketManager() => _instance;
  WebSocketManager._internal() {
    // Initialize _audioPlayer and set up listener
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerComplete.listen((_) {
      _isAudioPlaying = false;
      // If agent is speaking and playback finishes, agent is no longer speaking.
      if (_isAgentSpeaking) {
        _setAgentSpeaking(false); // This method updates _feedbackController
      }
      _playAudioFromQueue(); // Attempt to play next audio in queue
    });
  }

  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _audioController = StreamController<Uint8List>.broadcast();
  final _stateController =
      StreamController<WebSocketConnectionState>.broadcast();
  // Added for Chat History
  final StreamController<List<Map<String, dynamic>>> _chatHistoryController = StreamController.broadcast();
  List<Map<String, dynamic>> _currentChatHistory = [];

  // Added for Internal Audio Playback
  late AudioPlayer _audioPlayer;
  final Queue<Uint8List> _audioQueue = Queue<Uint8List>();
  bool _isAudioPlaying = false;


  // Configuration - Using Conversational AI 2.0 endpoint
  static const _baseUrl = 'wss://api.elevenlabs.io/v1/convai/conversation';
  String _apiKey = '';
  String _agentId = '';
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  bool _initialized = false;
  String? _conversationId;

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
  Stream<bool> get agentSpeakingStream => _feedbackController.stream;
  Stream<bool> get userSpeakingStream => _userSpeakingController.stream;
  Stream<ConversationState> get conversationStateStream =>
      _conversationStateController.stream;
  // Added for Chat History
  Stream<List<Map<String, dynamic>>> get chatHistoryStream => _chatHistoryController.stream;

  bool get isAgentSpeaking => _isAgentSpeaking;
  bool get isUserSpeaking => _isUserSpeaking;
  bool get shouldPauseRecording => _isAgentSpeaking || _isRecordingPaused;
  ConversationState get conversationState => _conversationState;

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
              // Mark agent as speaking when receiving audio - This will be handled by _playAudioFromQueue
              // if (!_isAgentSpeaking) {
              //   _setAgentSpeaking(true);
              // }

              // Replace _audioController.add with internal queueing
              _audioQueue.add(audioBytes);
              _playAudioFromQueue();
            } catch (e) {
              debugPrint('🔌 Error processing audio data: $e');
            }
          }
          break;

        case 'user_transcript':
          debugPrint(
              '🔌 User transcript: ${jsonData['user_transcription_event']?['user_transcript']}');
          // User transcript could also be added to chat history if desired
          // Example:
          // final userText = jsonData['user_transcription_event']?['user_transcript'] as String?;
          // if (userText != null && userText.isNotEmpty) {
          //   _currentChatHistory.add({'isUser': true, 'text': userText, 'type': 'transcript'});
          //   _chatHistoryController.add(List.from(_currentChatHistory));
          // }
          break;

        case 'agent_response':
          debugPrint(
              '🔌 Agent response: ${jsonData['agent_response_event']?['agent_response']}');
          final agentText = jsonData['agent_response_event']?['agent_response'] as String?;
          if (agentText != null && agentText.isNotEmpty) {
            _currentChatHistory.add({'isUser': false, 'text': agentText});
            _chatHistoryController.add(List.from(_currentChatHistory));
          }
          // Mark agent as speaking when receiving text response
          if (!_isAgentSpeaking) {
            _setAgentSpeaking(true);
          }
          // Add agent text to chat history here - Done above
          break;

        case 'agent_response_corrected':
          debugPrint(
              '🔌 Agent response corrected: ${jsonData['agent_response_corrected_event']?['agent_response_corrected']}');
          final correctedText = jsonData['agent_response_corrected_event']?['agent_response_corrected'] as String?;
          if (correctedText != null && correctedText.isNotEmpty) {
            // Optional: You might want to find and update the previous agent message
            // or simply add this as a new entry. For simplicity, adding as new.
            _currentChatHistory.add({'isUser': false, 'text': correctedText, 'type': 'corrected'});
            _chatHistoryController.add(List.from(_currentChatHistory));
          }
          // Add corrected agent text to chat history here - Done above
          break;

        case 'agent_response_complete':
          debugPrint('🔌 Agent response complete');
          // GlobalAudioManager().markResponseComplete(); // REMOVE THIS
          if (_audioQueue.isEmpty && !_isAudioPlaying) {
            _setAgentSpeaking(false);
          }
          // If audio is still playing/queued, onPlayerComplete will handle _setAgentSpeaking(false)
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
          // Stop audio playback immediately (internal player)
          if (_isAudioPlaying) {
            // Using await here, so _setUserSpeaking should be async, or this part be a fire-and-forget.
            // For now, let's assume stop is quick. If not, _setUserSpeaking might need to be async.
            _audioPlayer.stop();
            _isAudioPlaying = false;
          }
          _audioQueue.clear();
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

  Future<void> sendAudio(Stream<List<int>> audioStream) async {
    if (_channel?.closeCode != null) {
      debugPrint('WebSocketManager: WebSocket is closed, cannot send audio stream.');
      return;
    }

    // Check if recording should be paused (e.g., agent speaking or recording manually paused)
    // This uses the existing 'shouldPauseRecording' getter which relies on _isAgentSpeaking or _isRecordingPaused
    if (shouldPauseRecording) {
      debugPrint('WebSocketManager: Condition shouldPauseRecording is true, not sending audio stream.');
      // It might be useful to consume the stream to prevent it from being buffered indefinitely
      // if it's a hot stream, but for file streams this might not be necessary.
      // For now, just returning. Consider implications if audioStream is not from a file.
      await audioStream.drain(); // Drain the stream if we are not processing it.
      return;
    }

    debugPrint('WebSocketManager: Starting to send audio stream...');
    await for (var chunkList in audioStream) {
      // Re-check shouldPauseRecording in case state changed during streaming
      if (shouldPauseRecording) {
        debugPrint('WebSocketManager: Condition shouldPauseRecording became true during streaming, stopping.');
        await audioStream.drain(); // Drain the rest of the stream
        break;
      }

      final Uint8List chunk = (chunkList is Uint8List) ? chunkList : Uint8List.fromList(chunkList);

      // No need to call _detectVoiceActivity(chunk) here as `sendAudioChunk` does that.
      // This new `sendAudio` method is for directly streaming pre-recorded/finalized audio.
      // If VAD is needed for this stream, it would have to be applied before calling this method,
      // or this method would need to incorporate VAD logic differently.
      // The existing `sendAudioChunk` is used by the recorder which does VAD.

      try {
        final base64Audio = base64Encode(chunk);
        // Using 'user_audio_chunk' as per existing `sendAudioChunk` method's formatting
        final audioMessage = jsonEncode({
          'user_audio_chunk': base64Audio,
        });
        _channel!.sink.add(audioMessage);
        // debugPrint('WebSocketManager: Sent audio chunk from stream (${chunk.length} bytes)');
      } catch (e) {
        debugPrint('WebSocketManager: Error sending audio chunk from stream: $e');
        // Consider using the class's _handleError method if appropriate, e.g., _handleError(e);
        // For now, just breaking the loop.
        break;
      }
      // A small delay can prevent overwhelming the sink or the network.
      // This value is taken from the original sendAudioToWebSocket action.
      await Future.delayed(const Duration(milliseconds: 10)); // Adjusted from 20ms in plan to 10ms from original action
    }
    debugPrint('WebSocketManager: Finished sending audio stream.');
    // After the stream is finished, you might want to send an explicit "end of user turn" signal
    // if your server expects it for streamed audio.
    // For example: await sendEndOfTurn();
    // This depends on the server protocol for streamed audio vs chunked VAD audio.
    // For now, this method focuses only on transmitting the stream content.
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
      // Stop audio playback immediately (internal player)
      if (_isAudioPlaying) {
        await _audioPlayer.stop();
        _isAudioPlaying = false; // Manually update as stop() doesn't trigger onPlayerComplete
      }
      _audioQueue.clear();
      _setAgentSpeaking(false); // This was already here and is correct.
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
      _currentChatHistory.add({'isUser': true, 'text': text});
      _chatHistoryController.add(List.from(_currentChatHistory));
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
    _speechActivityTimer?.cancel();
    _agentGracePeriodTimer?.cancel();
    await _channel?.sink.close(1000, 'Normal closure');
    await _messageController.close();
    await _audioController.close();
    await _stateController.close();
    await _feedbackController.close();
    await _userSpeakingController.close();
    await _conversationStateController.close();
    await _chatHistoryController.close();

    // Added for Internal Audio Playback
    if (_isAudioPlaying) {
      await _audioPlayer.stop();
      _isAudioPlaying = false;
    }
    await _audioPlayer.dispose();
    _audioQueue.clear();

    _reconnectTimer?.cancel();
    _conversationId = null;
  }

  // Added for Internal Audio Playback
  void _playAudioFromQueue() async {
    if (_isAudioPlaying || _audioQueue.isEmpty) {
      return;
    }
    _isAudioPlaying = true;
    if (!_isAgentSpeaking) {
      _setAgentSpeaking(true);
    }
    final audioData = _audioQueue.removeFirst();
    try {
      await _audioPlayer.play(BytesSource(audioData));
    } catch (e) {
      if (kDebugMode) print("WebSocketManager: Error playing audio: $e");
      _isAudioPlaying = false;
      if (_isAgentSpeaking) {
        _setAgentSpeaking(false);
      }
      Future.delayed(Duration(milliseconds: 100), () => _playAudioFromQueue());
    }
  }
}
