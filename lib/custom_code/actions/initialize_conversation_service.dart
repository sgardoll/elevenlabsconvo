// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/custom_code/conversational_ai_service.dart';

/// Initialize the Consolidated Conversational AI Service Replaces the complex
/// initializeWebSocket action with a simple service call
Future<String> initializeConversationService(
  BuildContext context,
  String apiKey,
  String agentId,
) async {
  try {
    debugPrint('🚀 Initializing Consolidated Conversational AI Service');

    final service = ConversationalAIService();
    final result = await service.initialize(apiKey: apiKey, agentId: agentId);

    debugPrint('🚀 Service initialization result: $result');
    return result;
  } catch (e) {
    debugPrint('❌ Error initializing conversation service: $e');
    return 'error: ${e.toString()}';
  }
}
