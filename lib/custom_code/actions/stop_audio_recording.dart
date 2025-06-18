// Automatic FlutterFlow imports
import '/actions/actions.dart' as action_blocks;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'start_audio_recording.dart'; // Import to access getRecorder function

import 'package:record/record.dart';
import 'package:flutter/foundation.dart';
import '../websocket_manager.dart';
import 'dart:typed_data';

Future<String> stopAudioRecording(BuildContext context) async {
  try {
    debugPrint('🎙️ Stopping real-time audio recording and streaming...');

    // Get the recorder from the start recording action
    final recorder = getRecorder();
    final isRecording = await recorder.isRecording();

    if (!isRecording) {
      debugPrint('⚠️ Not recording, nothing to stop');
      return 'error: Not recording';
    }

    // Stop the recording stream
    await recorder.stop();

    // Cancel the audio stream subscription
    final subscription = getAudioStreamSubscription();
    await subscription?.cancel();

    // Cancel the agent speaking subscription
    final agentSpeakingSubscription = getAgentSpeakingSubscription();
    await agentSpeakingSubscription?.cancel();

    debugPrint('🎙️ Real-time recording and streaming stopped');

    // Get WebSocket manager for end-of-turn signaling
    final wsManager = WebSocketManager();

    // Send end-of-turn signal for client-side VAD
    debugPrint('🎙️ Sending end-of-turn signal...');
    await wsManager.sendEndOfTurn();

    // Send user activity signal for turn-taking
    await wsManager.sendUserActivity();

    debugPrint('🎙️ End-of-speech signals sent successfully');
    return 'success';
  } catch (e) {
    debugPrint('❌ Error stopping real-time recording: $e');
    return 'error: ${e.toString()}';
  }
}

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
