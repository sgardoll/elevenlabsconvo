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
import '../conversation_service.dart';
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
      if (kDebugMode) print('❌ Microphone permission denied');
      return 'error: Microphone permission denied';
    }

    // Check if already recording
    final isRecording = await _recorder.isRecording();
    if (isRecording) {
      if (kDebugMode) print('⚠️ Already recording, stopping previous recording first');
      await _recorder.stop();
      _audioStreamSubscription?.cancel();
      _agentSpeakingSubscription?.cancel();
    }

    if (kDebugMode) print('🎙️ Starting real-time audio recording and streaming...');

    // Get ConversationService for real-time streaming
    final conversationService = ConversationService.instance;

    // Check if we can record
    if (!conversationService.canRecord) {
      if (kDebugMode) print('❌ Cannot record: not connected or bot is speaking');
      return 'error: Cannot record at this time';
    }

    // Update recording state
    conversationService.setRecording(true);

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

    // Listen to bot speaking state to pause/resume recording
    _agentSpeakingSubscription = conversationService.stateStream
        .map((state) => state.isBotSpeaking)
        .distinct()
        .listen(
      (isBotSpeaking) {
        if (kDebugMode) print('🎙️ Bot speaking state changed: $isBotSpeaking');
        if (isBotSpeaking) {
          if (kDebugMode) print('🎙️ Pausing audio capture while bot speaks');
        } else {
          if (kDebugMode) print('🎙️ Resuming audio capture');
        }
      },
      onError: (error) {
        if (kDebugMode) print('❌ Error in bot speaking stream: $error');
      },
    );

    // Listen to the audio stream and send chunks in real-time
    _audioStreamSubscription = recordingStream.listen(
      (audioChunk) {
        // Only send audio if bot is not speaking to prevent feedback
        if (conversationService.canRecord && !conversationService.isBotSpeaking) {
          if (kDebugMode) {
            print('🎙️ Received audio chunk: ${audioChunk.length} bytes, streaming to ConversationService');
          }
          // Send audio chunk immediately to ConversationService
          conversationService.sendAudioChunk(audioChunk);
        } else {
          if (kDebugMode) {
            print('🎙️ Skipping audio chunk - bot is speaking (${audioChunk.length} bytes)');
          }
        }
      },
      onError: (error) {
        if (kDebugMode) print('❌ Error in audio stream: $error');
        conversationService.setRecording(false);
      },
      onDone: () {
        if (kDebugMode) print('🎙️ Audio stream ended');
        conversationService.setRecording(false);
      },
    );

    if (kDebugMode) print('🎙️ Real-time recording and streaming started successfully');
    return 'success';
  } catch (e) {
    if (kDebugMode) print('❌ Error starting real-time recording: $e');
    ConversationService.instance.setRecording(false);
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
