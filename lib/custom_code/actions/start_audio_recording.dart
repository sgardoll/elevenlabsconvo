// Automatic FlutterFlow imports
import '/actions/actions.dart' as action_blocks;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../websocket_manager.dart';
import 'dart:async';
import 'dart:typed_data';

// Global recorder instance to ensure we use the same instance for start and stop
final AudioRecorder _recorder = AudioRecorder();
String? _recordingPath;
StreamSubscription<Uint8List>? _audioStreamSubscription;
StreamSubscription<bool>? _agentSpeakingSubscription;

Future<String> startAudioRecording(BuildContext context) async {
  try {
    // Request microphone permission
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      debugPrint('❌ Microphone permission denied');
      return 'error: Microphone permission denied';
    }

    // Check if already recording
    final isRecording = await _recorder.isRecording();
    if (isRecording) {
      debugPrint('⚠️ Already recording, stopping previous recording first');
      await _recorder.stop();
      _audioStreamSubscription?.cancel();
      _agentSpeakingSubscription?.cancel();
    }

    debugPrint('🎙️ Starting real-time audio recording and streaming...');

    // Get WebSocket manager for real-time streaming
    final wsManager = WebSocketManager();

    // Start recording with real-time streaming
    final recordingStream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits, // Use raw PCM 16-bit format
        sampleRate: 16000,
        numChannels: 1,
        // Add echo cancellation and noise suppression for feedback prevention
        echoCancel: true,
        noiseSuppress: true,
      ),
    );

    // Listen to agent speaking state to pause/resume recording
    _agentSpeakingSubscription = wsManager.agentSpeakingStream.listen(
      (isAgentSpeaking) {
        debugPrint('🎙️ Agent speaking state changed: $isAgentSpeaking');
        if (isAgentSpeaking) {
          debugPrint('🎙️ Pausing audio capture while agent speaks');
        } else {
          debugPrint('🎙️ Resuming audio capture');
        }
      },
      onError: (error) {
        debugPrint('❌ Error in agent speaking stream: $error');
      },
    );

    // Listen to the audio stream and send chunks in real-time
    _audioStreamSubscription = recordingStream.listen(
      (audioChunk) {
        // Only send audio if agent is not speaking to prevent feedback
        if (!wsManager.shouldPauseRecording) {
          debugPrint(
              '🎙️ Received audio chunk: ${audioChunk.length} bytes, streaming to WebSocket');
          // Send audio chunk immediately to WebSocket
          wsManager.sendAudioChunk(audioChunk);
        } else {
          debugPrint(
              '🎙️ Skipping audio chunk - agent is speaking (${audioChunk.length} bytes)');
        }
      },
      onError: (error) {
        debugPrint('❌ Error in audio stream: $error');
      },
      onDone: () {
        debugPrint('🎙️ Audio stream ended');
      },
    );

    debugPrint('🎙️ Real-time recording and streaming started successfully');
    return 'success';
  } catch (e) {
    debugPrint('❌ Error starting real-time recording: $e');
    return 'error: ${e.toString()}';
  }
}

// Get temporary directory path
Future<String> getTempPath() async {
  final tempDir = await getTemporaryDirectory();
  return tempDir.path;
}

// Getter functions for accessing the recorder and stream subscription
AudioRecorder getRecorder() => _recorder;
StreamSubscription<Uint8List>? getAudioStreamSubscription() =>
    _audioStreamSubscription;
StreamSubscription<bool>? getAgentSpeakingSubscription() =>
    _agentSpeakingSubscription;

// Getter for recording path
String? getRecordingPath() {
  return _recordingPath;
}
