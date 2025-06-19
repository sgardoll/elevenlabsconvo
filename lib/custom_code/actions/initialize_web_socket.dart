// Automatic FlutterFlow imports
import '/actions/actions.dart' as action_blocks;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:convert';
import '../conversation_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' show min;
import '../widgets/auto_play_audio_response.dart';

Future<String> initializeWebSocket(
  BuildContext context,
  String apiKey,
  String agentId,
) async {
  try {
    if (apiKey.isEmpty || agentId.isEmpty) {
      if (kDebugMode) print('❌ Missing API key or agent ID');
      return 'error: Missing API key or agent ID';
    }

    if (kDebugMode) {
      print('🔌 Initializing ConversationService');
      print('🔌 API Key: ${apiKey.substring(0, min(10, apiKey.length))}... (masked)');
      print('🔌 Agent ID: $agentId');
    }

    // Use the new ConversationService instead of direct WebSocketManager
    final conversationService = ConversationService.instance;
    await conversationService.initialize(apiKey: apiKey, agentId: agentId);

    if (kDebugMode) print('🔌 ConversationService initialized successfully');
    return 'success';
  } catch (e) {
    if (kDebugMode) print('❌ Error initializing ConversationService: $e');
    return 'error: ${e.toString()}';
  }
}
