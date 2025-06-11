// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '../websocket_manager.dart';
import 'package:flutter/foundation.dart';

Future<String> sendTextToWebSocket(
  BuildContext context,
  String textMessage,
) async {
  try {
    if (textMessage.isEmpty) {
      debugPrint('❌ Empty text message provided to Conversational AI 2.0');
      return 'error: Empty text message';
    }

    debugPrint(
        '💬 Sending text message to Conversational AI 2.0: $textMessage');
    final wsManager = WebSocketManager();

    // Check connection state
    if (wsManager.currentState != WebSocketConnectionState.connected) {
      debugPrint(
          '⚠️ Conversational AI 2.0 WebSocket not connected, attempting to reconnect...');
      await wsManager.initialize(
        apiKey: FFAppState().elevenLabsApiKey,
        agentId: FFAppState().elevenLabsAgentId,
      );
    }

    // Check if we're connected now, if not return error
    if (wsManager.currentState != WebSocketConnectionState.connected) {
      debugPrint('❌ Failed to connect to Conversational AI 2.0 WebSocket');
      return 'error: Failed to connect to Conversational AI 2.0 WebSocket';
    }

    // Send text message using Conversational AI 2.0 multimodal feature
    await wsManager.sendTextMessage(textMessage);

    // Send user activity signal to improve turn-taking
    await wsManager.sendUserActivity();

    debugPrint('💬 Text message successfully sent to Conversational AI 2.0');

    // Update app state to show the sent message
    FFAppState().update(() {
      FFAppState().conversationMessages = [
        ...FFAppState().conversationMessages,
        {
          'type': 'user_text',
          'content': textMessage,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }
      ];
    });

    return 'success';
  } catch (e) {
    debugPrint(
        '❌ Error sending text message to Conversational AI 2.0 WebSocket: $e');
    return 'error: ${e.toString()}';
  }
}
