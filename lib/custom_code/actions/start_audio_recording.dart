// Automatic FlutterFlow imports
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

// Global recorder instance to ensure we use the same instance for start and stop
final AudioRecorder _recorder = AudioRecorder();
String? _recordingPath;

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
    }

    debugPrint('🎙️ Starting audio recording...');

    // Get temp path for storing the recording
    final tempPath = await getTempPath();
    _recordingPath = '$tempPath/audio_recording.wav';

    debugPrint('🎙️ Recording to path: $_recordingPath');

    // Start recording with PCM format (raw audio) which works better with ElevenLabs
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav, // WAV format is more reliable than M4A
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _recordingPath!,
    );

    debugPrint('🎙️ Recording started successfully');
    return 'success';
  } catch (e) {
    debugPrint('❌ Error starting recording: $e');
    return 'error: ${e.toString()}';
  }
}

// Get temporary directory path
Future<String> getTempPath() async {
  final tempDir = await getTemporaryDirectory();
  return tempDir.path;
}

// Getter for global recorder
AudioRecorder getRecorder() {
  return _recorder;
}

// Getter for recording path
String? getRecordingPath() {
  return _recordingPath;
}
