import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'conversation_state_manager.dart';
import 'websocket_service.dart';
import 'audio_service.dart';

class RecordingService {
  static final RecordingService _instance = RecordingService._internal();
  factory RecordingService() => _instance;
  RecordingService._internal();

  final _recorder = AudioRecorder();
  final _stateManager = ConversationStateManager();
  final _webSocketService = WebSocketService();
  final _audioService = AudioService();

  StreamSubscription<Uint8List>? _audioStreamSubscription;
  StreamSubscription<RecordingState>? _recordingStateSubscription;
  bool _isStopping = false;
  bool _isRecording = false;

  // Audio processing configuration
  static const int _targetSampleRate = 16000;
  static const int _targetChannels = 1;
  static const int _targetBitsPerSample = 16;

  Future<bool> initialize() async {
    debugPrint('🎙️ Initializing RecordingService');

    _recordingStateSubscription =
        _stateManager.recordingStateStream.listen((state) async {
      await _handleRecordingStateChange(state);
    });

    return await checkPermission();
  }

  Future<void> _handleRecordingStateChange(RecordingState state) async {
    debugPrint('🎙️ Recording state changed to: $state');

    switch (state) {
      case RecordingState.paused:
        if (_isRecording) {
          debugPrint('🎙️ Pausing recorder for agent playback');
          await _pauseRecording();
          // Notify audio service that recording is paused and buffered audio can play
          _audioService.playBufferedAudio();
        }
        break;

      case RecordingState.recording:
        if (!_isRecording) {
          debugPrint('🎙️ Resuming recorder to listen for user');
          await _startRecording();
        }
        break;

      case RecordingState.stopping:
      case RecordingState.idle:
        if (_isRecording) {
          debugPrint('🎙️ Stopping recorder');
          await _stopRecording();
        }
        break;
    }
  }

  Future<bool> checkPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;

    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  Future<void> startRecording() async {
    if (await checkPermission()) {
      _stateManager.updateRecordingState(RecordingState.recording);
    } else {
      _stateManager.reportError('Microphone permission not granted');
    }
  }

  Future<void> stopRecording() async {
    _stateManager.updateRecordingState(RecordingState.stopping);
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    try {
      debugPrint('🎙️ Starting audio recording stream');

      final recordingStream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _targetSampleRate,
          numChannels: _targetChannels,
          autoGain: false, // Disable AGC for consistent audio levels
          echoCancel: true, // Enable echo cancellation
          noiseSuppress: true, // Enable noise suppression
        ),
      );

      _isRecording = true;

      _audioStreamSubscription =
          recordingStream.listen(_processAudioChunk, onError: (error) {
        debugPrint('❌ Recording stream error: $error');
        _stateManager.reportError('Recording error: $error');
      }, onDone: () {
        debugPrint('🎙️ Recording stream ended');
        _isRecording = false;
      });
    } catch (e) {
      debugPrint('❌ Failed to start recording: $e');
      _stateManager.reportError('Failed to start recording: $e');
      _isRecording = false;
    }
  }

  Future<void> _pauseRecording() async {
    if (!_isRecording) return;

    _isStopping = true;

    try {
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;

      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }

      _isRecording = false;
      debugPrint('🎙️ Recording paused successfully');
    } catch (e) {
      debugPrint('❌ Error pausing recording: $e');
    } finally {
      _isStopping = false;
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording && _audioStreamSubscription == null) return;

    debugPrint('🎙️ Stopping recording stream');
    _isStopping = true;

    try {
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;

      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }

      _isRecording = false;
      _stateManager.updateRecordingState(RecordingState.idle);
    } catch (e) {
      debugPrint('❌ Error stopping recording: $e');
    } finally {
      _isStopping = false;
    }
  }

  void _processAudioChunk(Uint8List audioChunk) {
    // Guard against sending audio when not in recording state or when stopping
    if (_stateManager.recordingState != RecordingState.recording ||
        _isStopping) {
      return;
    }

    // Additional validation to ensure we're actually supposed to be recording
    if (!_isRecording) {
      debugPrint('⚠️ Received audio chunk but not in recording state');
      return;
    }

    try {
      // Ensure audio chunk is in the correct format
      final processedChunk = _ensureCorrectAudioFormat(audioChunk);

      debugPrint(
          '🎙️ Processing audio chunk. Size: ${processedChunk.length} bytes');

      // Send to WebSocket service which handles the actual transmission
      _webSocketService.sendAudio(processedChunk);
    } catch (e) {
      debugPrint('❌ Error processing audio chunk: $e');
    }
  }

  Uint8List _ensureCorrectAudioFormat(Uint8List audioData) {
    // Ensure the audio data meets ElevenLabs requirements:
    // - 16kHz sample rate (handled by RecordConfig)
    // - 16-bit PCM (handled by RecordConfig)
    // - Mono channel (handled by RecordConfig)
    // - Even number of bytes for 16-bit data

    if (audioData.length % 2 != 0) {
      // Pad with zero byte if odd length (shouldn't happen with 16-bit PCM)
      final paddedData = Uint8List(audioData.length + 1);
      paddedData.setRange(0, audioData.length, audioData);
      paddedData[audioData.length] = 0;
      debugPrint('⚠️ Padded odd-length audio chunk');
      return paddedData;
    }

    return audioData;
  }

  // Method to temporarily suspend audio transmission (e.g., during agent speech)
  void suspendAudioTransmission() {
    debugPrint('🎙️ Suspending audio transmission');
    // Note: We don't stop the recorder, just prevent transmission
    // The WebSocket service will handle sending silence chunks
  }

  void resumeAudioTransmission() {
    debugPrint('🎙️ Resuming audio transmission');
    // Audio transmission resumes automatically when recording state changes
  }

  // Get current recording status
  bool get isRecording => _isRecording;
  bool get isStopping => _isStopping;

  void dispose() {
    debugPrint('🎙️ Disposing RecordingService');

    _recordingStateSubscription?.cancel();
    _stopRecording();
    _recorder.dispose();
  }
}
