import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:collection';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  // Singleton instance
  static final AudioService instance = AudioService._privateConstructor();
  
  AudioService._privateConstructor();

  // State streams
  final StreamController<bool> _isPlayingController = StreamController<bool>.broadcast();
  Stream<bool> get isPlayingStream => _isPlayingController.stream;

  final StreamController<bool> _isBufferingController = StreamController<bool>.broadcast();
  Stream<bool> get isBufferingStream => _isBufferingController.stream;

  final StreamController<String> _currentTrackController = StreamController<String>.broadcast();
  Stream<String> get currentTrackStream => _currentTrackController.stream;

  // Internal state
  AudioPlayer? _player;
  File? _currentTempFile;
  final Queue<Uint8List> _audioBuffer = Queue<Uint8List>();
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isInterrupted = false;
  Timer? _playbackTimer;
  bool _hasStartedPlayback = false;
  bool _isResponseComplete = false;

  // Buffer management configuration
  static const int _maxBufferChunks = 10;
  static const int _playbackDelayMs = 1500;

  // Getters for current state
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  bool get isInterrupted => _isInterrupted;

  Future<void> initialize() async {
    if (_player != null) return;
    
    _player = AudioPlayer();
    
    // Listen to player state changes
    _player!.playerStateStream.listen((state) {
      final wasPlaying = _isPlaying;
      _isPlaying = state.playing;
      
      if (wasPlaying != _isPlaying) {
        _isPlayingController.add(_isPlaying);
      }

      if (state.processingState == ProcessingState.completed) {
        _onPlaybackCompleted();
      }
    });

    if (kDebugMode) print('🔊 AudioService initialized');
  }

  Future<void> queueAudioChunk(String base64Audio) async {
    if (_isInterrupted) {
      if (kDebugMode) print('🔊 Skipping audio chunk - interrupted');
      return;
    }

    try {
      final audioBytes = base64Decode(base64Audio);
      if (audioBytes.isEmpty) return;

      _audioBuffer.add(audioBytes);

      if (kDebugMode) print('🔊 Queued audio chunk: ${audioBytes.length} bytes (total chunks: ${_audioBuffer.length})');

      // Start playback if conditions are met
      if (!_hasStartedPlayback && !_isPlaying) {
        _schedulePlayback();
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error queuing audio chunk: $e');
    }
  }

  void markResponseComplete() {
    if (_isInterrupted) return;
    
    _isResponseComplete = true;
    if (kDebugMode) print('🔊 Audio response marked complete');
    
    if (!_hasStartedPlayback && !_isPlaying && _audioBuffer.isNotEmpty) {
      _startPlayback();
    }
  }

  void _schedulePlayback() {
    if (_isInterrupted || _playbackTimer != null) return;

    if (_audioBuffer.length >= _maxBufferChunks || _isResponseComplete) {
      _startPlayback();
    } else {
      _playbackTimer = Timer(Duration(milliseconds: _playbackDelayMs), () {
        if (_audioBuffer.isNotEmpty && !_isPlaying && !_isInterrupted) {
          _startPlayback();
        }
      });
    }
  }

  Future<void> _startPlayback() async {
    if (_isPlaying || _audioBuffer.isEmpty || _isInterrupted) return;

    await initialize(); // Ensure player is initialized

    _hasStartedPlayback = true;
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _isResponseComplete = false;

    try {
      _updateBuffering(true);
      
      // Concatenate all buffered audio chunks
      final concatenatedAudio = _concatenateAudioChunks();
      if (concatenatedAudio.isEmpty) {
        _updateBuffering(false);
        return;
      }

      // Clean up previous resources
      await _cleanup();

      // Create temporary WAV file
      final tempDir = await getTemporaryDirectory();
      _currentTempFile = File(
        '${tempDir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.wav'
      );

      final wavHeader = _createWavHeader(concatenatedAudio.length);
      final wavData = Uint8List.fromList([...wavHeader, ...concatenatedAudio]);
      await _currentTempFile!.writeAsBytes(wavData);

      if (kDebugMode) print('🔊 Playing audio: ${concatenatedAudio.length} bytes from ${_audioBuffer.length} chunks');

      // Start playback
      await _player!.setFilePath(_currentTempFile!.path);
      _updateBuffering(false);
      
      _currentTrackController.add(_currentTempFile!.path);
      await _player!.play();

      // Clear the buffer since this audio is now playing
      _audioBuffer.clear();

    } catch (e) {
      if (kDebugMode) print('❌ Error in audio playback: $e');
      _updateBuffering(false);
      await _cleanup();
    }
  }

  Uint8List _concatenateAudioChunks() {
    if (_audioBuffer.isEmpty) return Uint8List(0);

    int totalLength = _audioBuffer.fold(0, (sum, chunk) => sum + chunk.length);
    final concatenated = Uint8List(totalLength);
    
    int offset = 0;
    for (final chunk in _audioBuffer) {
      concatenated.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    return concatenated;
  }

  List<int> _createWavHeader(int dataLength) {
    const sampleRate = 16000;
    const numChannels = 1;
    const bitsPerSample = 16;
    const byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    const blockAlign = numChannels * bitsPerSample ~/ 8;
    final totalLength = 36 + dataLength;

    return [
      // "RIFF" chunk descriptor
      0x52, 0x49, 0x46, 0x46, // "RIFF"
      totalLength & 0xFF, (totalLength >> 8) & 0xFF,
      (totalLength >> 16) & 0xFF, (totalLength >> 24) & 0xFF,
      0x57, 0x41, 0x56, 0x45, // "WAVE"

      // "fmt " sub-chunk
      0x66, 0x6D, 0x74, 0x20, // "fmt "
      16, 0, 0, 0, // Sub-chunk size (16 for PCM)
      1, 0, // Audio format (1 for PCM)
      numChannels, 0, // Number of channels
      sampleRate & 0xFF, (sampleRate >> 8) & 0xFF,
      (sampleRate >> 16) & 0xFF, (sampleRate >> 24) & 0xFF,
      byteRate & 0xFF, (byteRate >> 8) & 0xFF,
      (byteRate >> 16) & 0xFF, (byteRate >> 24) & 0xFF,
      blockAlign, 0, // Block align
      bitsPerSample, 0, // Bits per sample

      // "data" sub-chunk
      0x64, 0x61, 0x74, 0x61, // "data"
      dataLength & 0xFF, (dataLength >> 8) & 0xFF,
      (dataLength >> 16) & 0xFF, (dataLength >> 24) & 0xFF,
    ];
  }

  Future<void> _cleanup() async {
    try {
      if (_currentTempFile != null && await _currentTempFile!.exists()) {
        await _currentTempFile!.delete();
        _currentTempFile = null;
      }
    } catch (e) {
      if (kDebugMode) print('🔊 Error during cleanup: $e');
    }
  }

  void _onPlaybackCompleted() {
    if (kDebugMode) print('🔊 Audio playback completed');
    _hasStartedPlayback = false;
    _cleanup();
  }

  Future<void> stop() async {
    if (kDebugMode) print('🔊 Stopping audio playback');
    
    _isInterrupted = true;
    _hasStartedPlayback = false;
    _isResponseComplete = false;
    
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _audioBuffer.clear();

    if (_player != null) {
      await _player!.stop();
    }

    await _cleanup();
    _updateBuffering(false);
  }

  void resetInterruptedState() {
    if (kDebugMode) print('🔊 Resetting interrupted state');
    _isInterrupted = false;
    _hasStartedPlayback = false;
    _isResponseComplete = false;
    _audioBuffer.clear();
    _playbackTimer?.cancel();
    _playbackTimer = null;
  }

  Future<void> pause() async {
    if (_player != null) {
      await _player!.pause();
    }
  }

  Future<void> resume() async {
    if (_player != null) {
      await _player!.play();
    }
  }

  void _updateBuffering(bool buffering) {
    if (_isBuffering != buffering) {
      _isBuffering = buffering;
      _isBufferingController.add(buffering);
    }
  }

  void dispose() {
    stop();
    _isPlayingController.close();
    _isBufferingController.close();
    _currentTrackController.close();
    _player?.dispose();
    _player = null;
  }
}