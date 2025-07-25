// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/custom_code/conversational_ai_service.dart';

Future stopConversationService() async {
  try {
    // Get the singleton instance and permanently shut it down
    final service = ConversationalAIService();
    await service.shutdown(); // Use enhanced shutdown instead of dispose

    // Update FFAppState to reflect permanently stopped state
    FFAppState().update(() {
      FFAppState().wsConnectionState = 'stopped';
      FFAppState().isRecording = false;
      FFAppState().elevenLabsAgentId = '';
      FFAppState().conversationMessages = [];
    });

    debugPrint('🛑 Conversation service permanently stopped - no restart possible');
  } catch (e) {
    debugPrint('❌ Error stopping conversation service: $e');

    // Still update state even if there was an error
    FFAppState().update(() {
      FFAppState().wsConnectionState = 'error: ${e.toString()}';
      FFAppState().isRecording = false;
    });
  }
}
