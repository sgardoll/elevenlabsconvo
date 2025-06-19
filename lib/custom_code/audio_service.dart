import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'conversation_state_manager.dart';

// Custom StreamAudioSource for continuous audio streaming
class PersistentAudioSource extends StreamAudioSource {
  final StreamController<List<int>> _controller =
      StreamController<List<int>>.broadcast();
  final List<int> _audioBuffer = [];
  bool _isFirstChunk = true;
  bool _isDisposed = false;

  PersistentAudioSource() {
    _controller.stream.listen((chunk) {
      if (!_isDisposed) {
        _audioBuffer.addAll(chunk);
      }
    });
  }

  void addAudioChunk(String base64Audio) {
    if (_isDisposed || _controller.isClosed) return;

    try {
      final audioBytes = base64Decode(base64Audio);
      debugPrint('🔊 Adding audio chunk: ${audioBytes.length} bytes');

      if (audioBytes.isNotEmpty) {
        _controller.add(audioBytes);

        // Start playback only once when first chunk arrives
        if (_isFirstChunk) {
          _isFirstChunk = false;
          debugPrint('🔊 First audio chunk received, triggering playback');
        }
      }
    } catch (e) {
      debugPrint('❌ Error decoding audio chunk: $e');
    }
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _audioBuffer.length;

    if (start >= _audioBuffer.length) {
      // Return empty stream if requesting beyond available data
      return StreamAudioResponse(
        sourceLength: null,
        contentLength: 0,
        offset: start,
        stream: Stream.empty(),
        contentType: 'audio/wav',
      );
    }

    end = end > _audioBuffer.length ? _audioBuffer.length : end;

    return StreamAudioResponse(
      sourceLength: null, // Dynamic content length
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_audioBuffer.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }

  void reset() {
    _audioBuffer.clear();
    _isFirstChunk = true;
    debugPrint('🔊 Audio source reset');
  }

  void dispose() {
    _isDisposed = true;
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    _stateManager.setOnUserFinishedSpeaking(_onUserFinishedSpeaking);
    _player.playerStateStream.listen(_onPlayerStateChanged);
  }

  final _stateManager = ConversationStateManager();
  final _player = AudioPlayer();

  PersistentAudioSource? _audioSource;
  bool _isInitialized = false;
  bool _isPlaying = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('🔊 Initializing AudioService with persistent audio source');

    try {
      _audioSource = PersistentAudioSource();
      await _player.setAudioSource(_audioSource!);
      _isInitialized = true;
      debugPrint('🔊 AudioService initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize AudioService: $e');
      _stateManager.reportError('Audio initialization failed: $e');
    }
  }

  void addAudioChunk(Uint8List audioData) {
    if (!_isInitialized || _stateManager.isInterrupting) return;

    try {
      final base64Audio = base64Encode(audioData);
      _audioSource?.addAudioChunk(base64Audio);

      // Start playback if not already playing
      if (!_isPlaying && !_player.playing) {
        _startPlayback();
      }
    } catch (e) {
      debugPrint('❌ Error adding audio chunk: $e');
    }
  }

  void markResponseComplete() {
    debugPrint('✅ Agent response complete - audio streaming finished');
    // No action needed for persistent source, it continues streaming
  }

  // Called from RecordingService AFTER the recorder is confirmed to be stopped.
  void playBufferedAudio() {
    if (_isInitialized && !_isPlaying && !_player.playing) {
      _startPlayback();
    }
  }

  Future<void> _startPlayback() async {
    if (!_isInitialized || _isPlaying) return;

    try {
      _isPlaying = true;
      _stateManager.agentPlaybackStarted();

      debugPrint('🔊 Starting audio playback');
      await _player.play();
    } catch (e) {
      debugPrint('❌ Audio playback failed: $e');
      _stateManager.reportError('Audio playback failed: $e');
      _onPlaybackComplete();
    }
  }

  void _onPlayerStateChanged(PlayerState state) {
    debugPrint('🔊 Player state changed: ${state.processingState}');

    if (state.processingState == ProcessingState.completed) {
      _onPlaybackComplete();
    } else if (state.processingState == ProcessingState.idle) {
      _isPlaying = false;
    }
  }

  Future<void> _onPlaybackComplete() async {
    debugPrint('🔊 Playback complete');
    _isPlaying = false;

    // Only transition state if we were the ones playing
    if (_stateManager.conversationState == ConversationState.agentSpeaking) {
      _stateManager.agentPlaybackFinished();
    }
  }

  Future<void> stopPlayback({bool clearBuffer = false}) async {
    debugPrint('🛑 Stopping audio playback. Clear buffer: $clearBuffer');

    _isPlaying = false;

    if (clearBuffer && _audioSource != null) {
      _audioSource!.reset();
    }

    if (_player.playing) {
      await _player.stop();
    }
  }

  Future<void> resetForNewConversation() async {
    debugPrint('🔄 Resetting audio service for new conversation');

    await stopPlayback(clearBuffer: true);

    if (_audioSource != null) {
      _audioSource!.dispose();
    }

    // Reinitialize for new conversation
    _isInitialized = false;
    await initialize();
  }

  void _onUserFinishedSpeaking() {
    debugPrint('🎙️ User finished speaking - checking for pending audio');
    if (_isInitialized && !_isPlaying && !_player.playing) {
      _startPlayback();
    }
  }

  void dispose() {
    _isPlaying = false;
    _player.dispose();
    _audioSource?.dispose();
    _isInitialized = false;
  }
}
