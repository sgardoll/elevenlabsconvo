// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/custom_code/elevenlabs_sdk_service.dart';

/// Initialize the ElevenLabs SDK Conversation Service
/// Uses the official ElevenLabs Flutter SDK for WebRTC-based conversations
Future<String> initializeConversationService(
  BuildContext context,
  String agentId,
  String endpoint,
) async {
  try {
    debugPrint('Initializing ElevenLabs SDK Conversation Service');

    final service = ElevenLabsSdkService();
    final result = await service.initialize(agentId: agentId, endpoint: endpoint);

    debugPrint('Service initialization result: $result');
    return result;
  } catch (e) {
    debugPrint('Error initializing conversation service: $e');
    return 'error: ${e.toString()}';
  }
}
