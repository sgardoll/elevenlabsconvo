// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/custom_code/conversational_ai_service.dart';

/// Mute or unmute the microphone during conversation
/// This allows designers to bind UI toggles to runtime mic control
Future muteMic(BuildContext context, bool mute) async {
  try {
    final service = ConversationalAIService();

    if (mute) {
      await service.pauseMic();
      debugPrint('🔇 Microphone muted via FlutterFlow action');
    } else {
      await service.resumeMic();
      debugPrint('🎤 Microphone unmuted via FlutterFlow action');
    }

    // Update app state to reflect mute status
    FFAppState().update(() {
      FFAppState().isRecording = !mute;
    });
  } catch (e) {
    debugPrint('❌ Error in muteMic action: $e');
  }
}
