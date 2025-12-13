// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '../conversational_ai_service.dart';

Future<void> initializeConversationService(
  String agentId,
  String endpoint,
  String? firstMessage,
  String? language,
  bool? keepMicHotDuringAgent,
  bool? autoStartMic,
) async {
  try {
    final svc = ConversationalAIService();

    final _language = language ?? 'en';
    final _keepMicHotDuringAgent = keepMicHotDuringAgent ?? true;
    final _autoStartMic = autoStartMic ?? false;

    final res = await svc.initialize(
      agentId: agentId,
      endpoint: endpoint,
      firstMessage: firstMessage,
      language: _language,
      keepMicHotDuringAgent: _keepMicHotDuringAgent,
      autoStartMic: _autoStartMic,
    );

    if (res == 'success') {
      FFAppState().update(() {
        FFAppState().isInConversation =
            false; // no UI change until user taps mic
      });
    } else {
      FFAppState().update(() {
        FFAppState().wsConnectionState = res; // e.g. error:no_signed_url
      });
    }
  } catch (e) {
    debugPrint('Error initializing conversation service: $e');
    FFAppState().update(() {
      FFAppState().wsConnectionState = 'error:${e.toString()}';
      FFAppState().isRecording = false;
    });
  }
}
