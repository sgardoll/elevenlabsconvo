// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '../conversational_ai_service.dart';

Future<void> toggleConversationMic(
  bool? keepMicHotDuringAgent,
) async {
  try {
    final svc = ConversationalAIService();
    final keepHot = keepMicHotDuringAgent ?? true;
    final res = await svc.toggleMic(keepMicHotDuringAgent: keepHot);

    // reflect status in FFAppState for UI instead of returning
    FFAppState().update(() {
      if (res == 'recording') {
        FFAppState().isRecording = true;
        FFAppState().isInConversation = true;
      } else if (res == 'stopped') {
        FFAppState().isRecording = false;
      } else if (res.startsWith('error:')) {
        FFAppState().wsConnectionState = res;
      }
    });
  } catch (e) {
    debugPrint('toggleConversationMic error: $e');
    FFAppState().update(() {
      FFAppState().wsConnectionState = 'error:${e.toString()}';
    });
  }
}
