// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'start_audio_recording.dart'; // Import to access getRecorder function

import 'package:record/record.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

Future<String> stopAudioRecording(BuildContext context) async {
  try {
    debugPrint('🎙️ Stopping audio recording...');

    // Get the recorder from the start recording action
    final recorder = getRecorder();
    final isRecording = await recorder.isRecording();

    if (!isRecording) {
      debugPrint('⚠️ Not recording, nothing to stop');
      return 'error: Not recording';
    }

    final path = await recorder.stop();
    debugPrint('🎙️ Recording stopped, path: $path');

    if (path != null) {
      final file = File(path);

      if (!await file.exists()) {
        debugPrint('❌ Recorded file does not exist: $path');
        return 'error: File not found';
      }

      debugPrint('🎙️ Reading file bytes...');
      final bytes = await file.readAsBytes();
      debugPrint('🎙️ File size: ${bytes.length} bytes');

      if (bytes.isEmpty) {
        debugPrint('❌ Recorded file is empty');
        return 'error: Empty recording';
      }

      final base64Audio = base64Encode(bytes);
      debugPrint('🎙️ Sending audio to WebSocket...');

      // Send audio to WebSocket
      final result = await sendAudioToWebSocket(context, base64Audio);
      if (result.startsWith('error')) {
        debugPrint(
            '❌ Error sending audio to WebSocket: ${result.substring(7)}');
        return result;
      }

      debugPrint('🎙️ Audio sent to WebSocket successfully');

      // Clean up temporary file
      try {
        await file.delete();
        debugPrint('🎙️ Temporary file deleted');
      } catch (e) {
        debugPrint('⚠️ Failed to delete temporary file: $e');
        // Don't return error here, as the audio was already sent
      }
    } else {
      debugPrint('❌ No recording path returned from recorder');
      return 'error: No recording path';
    }

    return 'success';
  } catch (e) {
    debugPrint('❌ Error stopping recording: $e');
    return 'error: ${e.toString()}';
  }
}

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
