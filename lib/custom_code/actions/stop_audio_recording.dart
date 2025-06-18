// Automatic FlutterFlow imports
import '/actions/actions.dart' as action_blocks;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:flutter/foundation.dart';
import '../conversation_service.dart';
import 'start_audio_recording.dart'; // Import to access shared recorder

Future<String> stopAudioRecording(BuildContext context) async {
  try {
    if (kDebugMode) print('🎙️ Stopping audio recording...');
    
    final conversationService = ConversationService.instance;
    
    // Update recording state
    conversationService.setRecording(false);

    // Stop the recording stream
    final recorder = getRecorder();
    final isRecording = await recorder.isRecording();
    
    if (isRecording) {
      await recorder.stop();
      if (kDebugMode) print('🎙️ Recording stopped');
    } else {
      if (kDebugMode) print('⚠️ Recorder was not recording');
    }

    // Cancel audio stream subscription
    final audioStreamSubscription = getAudioStreamSubscription();
    if (audioStreamSubscription != null) {
      await audioStreamSubscription.cancel();
      if (kDebugMode) print('🎙️ Audio stream subscription cancelled');
    }

    // Cancel agent speaking subscription
    final agentSpeakingSubscription = getAgentSpeakingSubscription();
    if (agentSpeakingSubscription != null) {
      await agentSpeakingSubscription.cancel();
      if (kDebugMode) print('🎙️ Bot speaking subscription cancelled');
    }

    if (kDebugMode) print('🎙️ Audio recording stopped successfully');
    return 'success';
  } catch (e) {
    if (kDebugMode) print('❌ Error stopping recording: $e');
    // Ensure recording state is cleared even on error
    ConversationService.instance.setRecording(false);
    return 'error: ${e.toString()}';
  }
}

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
