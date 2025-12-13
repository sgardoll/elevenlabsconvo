// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '../conversational_ai_service.dart';

Future<void> interruptConversationService() async {
  try {
    final svc = ConversationalAIService();
    await svc.interrupt();
    // optional: flag a brief UI pulse if you want
    // FFAppState().update(() { FFAppState().lastInterruptAt = DateTime.now().toIso8601String(); });
  } catch (e) {
    debugPrint('interruptConversationService error: $e');
    FFAppState().update(() {
      FFAppState().wsConnectionState = 'error:${e.toString()}';
    });
  }
}
