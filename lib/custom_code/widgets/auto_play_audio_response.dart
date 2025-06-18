// Automatic FlutterFlow imports
import '/actions/actions.dart' as action_blocks;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:just_audio/just_audio.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:math' as math;
import '../websocket_manager.dart';
import 'package:flutter/foundation.dart';

// Global audio manager to prevent multiple AudioPlayer conflicts
class GlobalAudioManager {
  static final GlobalAudioManager _instance = GlobalAudioManager._internal();
  factory GlobalAudioManager() => _instance;
  GlobalAudioManager._internal();

  AudioPlayer? _player;
  File? _currentTempFile;

  // Audio streaming buffer for concatenating chunks from Conversational AI 2.0
  final List<Uint8List> _audioBuffer = [];
  bool _isPlaying = false;
  bool _isInterrupted = false;
  Timer? _playbackTimer;
  bool _hasStartedPlayback = false;

  // Buffer management
  static const int _maxBufferChunks =
      10; // Start playback after this many chunks
  static const int _playbackDelayMs = 1500; // Delay before starting playback
  bool _isResponseComplete = false; // Track if agent response is complete
  bool _playbackBlocked = false; // Block all playback until reset
  bool _processingInterruption =
      false; // Flag to prevent concurrent interruption handling

  // Global tracking of played audio to prevent duplicates across widgets
  final Set<String> _playedAudioHashes = <String>{};

  // Enhanced error handling
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 3;
  final _errorController = StreamController<String>.broadcast();
  Timer? _errorRecoveryTimer;
  bool _errorRecoveryMode = false;

  Stream<String> get errorStream => _errorController.stream;

  Future<void> playAudio(String base64Audio) async {
    // Skip incoming audio if we're in an interrupted state or error recovery mode
    if (_isInterrupted || _playbackBlocked || _errorRecoveryMode) {
      debugPrint(
          '🔊 Skipping audio chunk - interrupted: $_isInterrupted, blocked: $_playbackBlocked, errorRecovery: $_errorRecoveryMode');
      return;
    }

    try {
      // Validate base64 audio input
      if (base64Audio.isEmpty) {
        debugPrint('🔊 Warning: Empty base64 audio provided');
        return;
      }

      // Decode and validate audio chunk
      final audioBytes = base64Decode(base64Audio);
      if (audioBytes.isEmpty) {
        debugPrint('🔊 Warning: Decoded audio is empty');
        return;
      }

      _audioBuffer.add(audioBytes);

      debugPrint(
          '🔊 Added audio chunk to buffer: ${audioBytes.length} bytes (total chunks: ${_audioBuffer.length})');

      // Reset consecutive errors on successful audio processing
      if (_consecutiveErrors > 0) {
        debugPrint('🔊 Resetting consecutive error count (was $_consecutiveErrors)');
        _consecutiveErrors = 0;
        _errorRecoveryMode = false;
        _errorRecoveryTimer?.cancel();
      }

      // Start playback after collecting enough chunks or after a delay
      if (!_hasStartedPlayback && !_isPlaying) {
        _schedulePlayback();
      }
    } catch (e) {
      debugPrint('❌ Error processing audio chunk: $e');
      _handleAudioError('Failed to process audio chunk', e);
    }
  }

  void _handleAudioError(String message, dynamic error) {
    _consecutiveErrors++;
    final errorMessage = '$message: $error (Consecutive errors: $_consecutiveErrors)';
    debugPrint('❌ Audio Error: $errorMessage');
    
    _errorController.add(errorMessage);

    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      debugPrint('❌ Too many consecutive errors ($_consecutiveErrors), entering recovery mode');
      _enterErrorRecoveryMode();
    }
  }

  void _enterErrorRecoveryMode() {
    _errorRecoveryMode = true;
    _playbackBlocked = true;
    
    // Stop current playback and cleanup
    _stopCurrentPlayback();
    
    // Clear buffer to prevent further issues
    _audioBuffer.clear();
    
    // Schedule recovery attempt
    _errorRecoveryTimer?.cancel();
    _errorRecoveryTimer = Timer(Duration(seconds: 5), () {
      debugPrint('🔊 Attempting error recovery...');
      _attemptErrorRecovery();
    });

    // Notify WebSocket manager of audio issues
    final wsManager = WebSocketManager();
    wsManager.notifyAgentPlaybackEnded();
    
    _errorController.add('Audio system entering recovery mode due to repeated errors');
  }

  Future<void> _attemptErrorRecovery() async {
    try {
      debugPrint('🔊 Performing error recovery...');
      
      // Cleanup any existing resources
      await _cleanup();
      
      // Reset state
      _isPlaying = false;
      _hasStartedPlayback = false;
      _isResponseComplete = false;
      _processingInterruption = false;
      _audioBuffer.clear();
      
      // Exit recovery mode
      _errorRecoveryMode = false;
      _playbackBlocked = false;
      _consecutiveErrors = 0;
      
      debugPrint('🔊 Error recovery completed');
      _errorController.add('Audio system recovered');
      
    } catch (e) {
      debugPrint('❌ Error recovery failed: $e');
      _errorController.add('Audio system recovery failed: $e');
      
      // If recovery fails, stay in error mode longer
      _errorRecoveryTimer = Timer(Duration(seconds: 15), () {
        _attemptErrorRecovery();
      });
    }
  }

  void _schedulePlayback() {
    // Don't schedule playback if interrupted, blocked, processing interruption, or in error recovery
    if (_isInterrupted || _playbackBlocked || _processingInterruption || _errorRecoveryMode) {
      debugPrint(
          '🔊 Skipping playback scheduling - interrupted, blocked, processing interruption, or in error recovery');
      return;
    }

    _playbackTimer?.cancel();

    // Start playback immediately if we have enough chunks, or if response is complete
    if (_audioBuffer.length >= _maxBufferChunks || _isResponseComplete) {
      _startPlayback();
    } else {
      _playbackTimer = Timer(Duration(milliseconds: _playbackDelayMs), () {
        if (_audioBuffer.isNotEmpty &&
            !_isPlaying &&
            !_isInterrupted &&
            !_playbackBlocked &&
            !_errorRecoveryMode) {
          _startPlayback();
        }
      });
    }
  }

  // Signal that the agent response is complete and ready for playback
  void markResponseComplete() {
    // Don't mark complete if interrupted, blocked, processing interruption, or in error recovery
    if (_isInterrupted || _playbackBlocked || _processingInterruption || _errorRecoveryMode) {
      debugPrint(
          '🔊 Skipping response complete - interrupted, blocked, processing interruption, or in error recovery');
      return;
    }

    _isResponseComplete = true;
    debugPrint('🔊 Agent response marked complete - triggering playback');
    if (!_hasStartedPlayback &&
        !_isPlaying &&
        _audioBuffer.isNotEmpty &&
        !_isInterrupted &&
        !_playbackBlocked &&
        !_errorRecoveryMode) {
      _startPlayback();
    }
  }

  Future<void> _startPlayback() async {
    if (_isPlaying ||
        _audioBuffer.isEmpty ||
        _isInterrupted ||
        _playbackBlocked ||
        _processingInterruption ||
        _errorRecoveryMode) {
      debugPrint(
          '🔊 Skipping playback - isPlaying: $_isPlaying, bufferEmpty: ${_audioBuffer.isEmpty}, interrupted: $_isInterrupted, blocked: $_playbackBlocked, processingInterruption: $_processingInterruption, errorRecovery: $_errorRecoveryMode');
      return;
    }

    // Double-check WebSocket manager state before starting playback
    final wsManager = WebSocketManager();
    if (!wsManager.isAgentSpeaking) {
      debugPrint(
          '🔊 Skipping playback - agent not supposed to be speaking according to WebSocket manager');
      return;
    }

    // Additional safety check - ensure we have valid audio chunks
    if (_audioBuffer.isEmpty) {
      debugPrint('🔊 No audio chunks in buffer - aborting playback');
      return;
    }

    _hasStartedPlayback = true;
    _playbackTimer?.cancel();
    _isResponseComplete = false; // Reset for next response

    try {
      // Concatenate all buffered audio chunks
      final concatenatedAudio = _concatenateAudioChunks();
      if (concatenatedAudio.isEmpty) {
        debugPrint('🔊 No audio data to play');
        return;
      }

      // Clean up previous resources
      await _cleanup();

      // Notify WebSocket manager that agent playback is starting
      wsManager.notifyAgentPlaybackStarted();

      _player = AudioPlayer();

      debugPrint(
          '🔊 Playing concatenated audio: ${concatenatedAudio.length} bytes from ${_audioBuffer.length} chunks');

      // Create temporary file with concatenated audio
      final tempDir = await getTemporaryDirectory();
      _currentTempFile = File(
          '${tempDir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.wav');

      // Write concatenated PCM data to WAV file with error handling
      try {
        final wavHeader = _createWavHeader(concatenatedAudio.length);
        final wavData = Uint8List.fromList([...wavHeader, ...concatenatedAudio]);
        await _currentTempFile!.writeAsBytes(wavData);

        // Validate file was created successfully
        if (!await _currentTempFile!.exists()) {
          throw Exception('Failed to create temporary audio file');
        }

        final fileSize = await _currentTempFile!.length();
        if (fileSize < 44) { // WAV header is 44 bytes minimum
          throw Exception('Created audio file is too small (${fileSize} bytes)');
        }

        debugPrint('🔊 Created temp audio file: ${_currentTempFile!.path} (${fileSize} bytes)');
      } catch (e) {
        throw Exception('Failed to create audio file: $e');
      }

      // Set up completion and error listeners before playing
      late StreamSubscription playerStateSubscription;
      playerStateSubscription = _player!.playerStateStream.listen(
        (state) {
          if (state.processingState == ProcessingState.completed) {
            debugPrint('🔊 Audio playback completed');
            // Notify WebSocket manager that agent playback ended
            wsManager.notifyAgentPlaybackEnded();
            _isPlaying = false;
            _hasStartedPlayback = false;

            // Clear the buffer since this audio is done
            _audioBuffer.clear();
            
            // Cancel the subscription
            playerStateSubscription.cancel();
          }
        },
        onError: (error) {
          debugPrint('❌ Audio player state error: $error');
          _handleAudioError('Audio player state error', error);
          playerStateSubscription.cancel();
        }
      );

      // Play the audio file with timeout
      try {
        await _player!.setFilePath(_currentTempFile!.path);
        _isPlaying = true;
        await _player!.play();

        debugPrint('🔊 Audio playback started successfully');
      } catch (e) {
        playerStateSubscription.cancel();
        throw Exception('Failed to play audio: $e');
      }

    } catch (e) {
      debugPrint('❌ Error in audio playback: $e');
      _handleAudioError('Audio playback failed', e);

      // Ensure we notify that playback ended even on error
      final wsManager = WebSocketManager();
      wsManager.notifyAgentPlaybackEnded();
      _isPlaying = false;
      _hasStartedPlayback = false;

      await _cleanup();
    }
  }

  Uint8List _concatenateAudioChunks() {
    if (_audioBuffer.isEmpty) return Uint8List(0);

    // Calculate total length
    int totalLength = 0;
    for (final chunk in _audioBuffer) {
      totalLength += chunk.length;
    }

    // Concatenate all chunks
    final concatenated = Uint8List(totalLength);
    int offset = 0;
    for (final chunk in _audioBuffer) {
      concatenated.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    return concatenated;
  }

  // Create WAV header for raw PCM data
  List<int> _createWavHeader(int dataLength) {
    final sampleRate = 16000;
    final numChannels = 1;
    final bitsPerSample = 16;
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;
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
      if (_player != null) {
        await _player!.stop();
        await _player!.dispose();
        _player = null;
      }

      if (_currentTempFile != null && await _currentTempFile!.exists()) {
        await _currentTempFile!.delete();
        _currentTempFile = null;
      }
    } catch (e) {
      debugPrint('🔊 Error during cleanup: $e');
      // Don't rethrow cleanup errors to prevent cascading failures
    }
  }

  // Stop current playback without cleanup (for error recovery)
  void _stopCurrentPlayback() {
    try {
      if (_player != null && _isPlaying) {
        _player!.stop();
        _isPlaying = false;
      }
      _playbackTimer?.cancel();
    } catch (e) {
      debugPrint('🔊 Error stopping current playback: $e');
    }
  }

  // Stop audio playback immediately (for interruptions)
  Future<void> stopAudio() async {
    // Prevent concurrent interruption handling
    if (_processingInterruption) {
      debugPrint('🔊 Already processing interruption, skipping duplicate call');
      return;
    }

    _processingInterruption = true;
    debugPrint('🔊 Stopping audio playback due to interruption');

    try {
      // Set all blocking flags immediately
      _isInterrupted = true; // Set interrupted flag to reject new audio
      _playbackBlocked = true; // Block any future playback attempts
      _isResponseComplete =
          false; // Reset response state to prevent completion triggers
      _hasStartedPlayback = false;

      // Cancel any pending operations
      _playbackTimer?.cancel(); // Cancel any pending playback timers

      // Clear the buffer to prevent further playback
      _audioBuffer.clear();

      if (_player != null && _isPlaying) {
        await _player!.stop();
        _isPlaying = false;

        // Notify that playback ended
        final wsManager = WebSocketManager();
        wsManager.notifyAgentPlaybackEnded();
      }

      await _cleanup();

      debugPrint('🔊 Interruption processing completed');
    } catch (e) {
      debugPrint('❌ Error during audio interruption: $e');
      _handleAudioError('Failed to stop audio during interruption', e);
    } finally {
      // Always reset the processing flag
      _processingInterruption = false;
    }
  }

  bool get isPlaying => _isPlaying;

  // Reset interrupted state to allow new audio (called when ready for new conversation)
  void resetInterruptedState() {
    if (_isInterrupted || _playbackBlocked || _processingInterruption) {
      debugPrint('🔊 Resetting interrupted state - ready for new audio');
      _isInterrupted = false;
      _playbackBlocked = false;
      _processingInterruption = false; // Reset interruption processing flag
      _hasStartedPlayback = false;
      _isResponseComplete = false; // Ensure response complete is also reset
      _audioBuffer.clear();
      _playbackTimer?.cancel();
      
      // Also reset error recovery state if active
      if (_errorRecoveryMode) {
        _errorRecoveryMode = false;
        _consecutiveErrors = 0;
        _errorRecoveryTimer?.cancel();
        debugPrint('🔊 Also reset error recovery mode');
      }
    }
  }

  // Get current audio system status
  String get statusText {
    if (_errorRecoveryMode) {
      return 'Audio system recovering...';
    } else if (_isPlaying) {
      return 'Playing audio';
    } else if (_playbackBlocked) {
      return 'Audio playback blocked';
    } else if (_audioBuffer.isNotEmpty) {
      return 'Audio buffering (${_audioBuffer.length} chunks)';
    } else {
      return 'Audio ready';
    }
  }

  Future<void> dispose() async {
    try {
      _audioBuffer.clear();
      _playedAudioHashes.clear();
      _playbackTimer?.cancel();
      _errorRecoveryTimer?.cancel();
      await _errorController.close();
      await _cleanup();
      debugPrint('🔊 GlobalAudioManager disposed successfully');
    } catch (e) {
      debugPrint('❌ Error during GlobalAudioManager disposal: $e');
    }
  }
}

// Utility functions for FlutterFlow integration
Future<void> playAudioChunk(String base64Audio) async {
  await GlobalAudioManager().playAudio(base64Audio);
}

Future<void> stopAudioPlayback() async {
  await GlobalAudioManager().stopAudio();
}

bool isAudioPlaying() {
  return GlobalAudioManager().isPlaying;
}

class AutoPlayAudioResponse extends StatefulWidget {
  const AutoPlayAudioResponse({
    Key? key,
    this.width,
    this.height,
    this.debug = false,
  }) : super(key: key);

  final double? width;
  final double? height;
  final bool debug;

  @override
  _AutoPlayAudioResponseState createState() => _AutoPlayAudioResponseState();
}

class _AutoPlayAudioResponseState extends State<AutoPlayAudioResponse> {
  final GlobalAudioManager _audioManager = GlobalAudioManager();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      child: widget.debug
          ? Center(
              child: Text(
                'Audio Player\n(Debug Mode)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            )
          : SizedBox.shrink(), // Hidden in production
    );
  }

  @override
  void dispose() {
    // Don't dispose the global audio manager here as it's shared
    super.dispose();
  }
}
