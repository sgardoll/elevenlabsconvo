// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '../websocket_manager.dart';

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

Future<String> sendAudioToWebSocket(
  BuildContext context,
  String base64AudioData,
) async {
  try {
    if (base64AudioData.isEmpty) {
      debugPrint('❌ Empty audio data provided to Conversational AI 2.0');
      return 'error: Empty audio data';
    }

    debugPrint(
        '🔊 Decoding audio data for Conversational AI 2.0 (length: ${base64AudioData.length})');
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

    final audioBytes = base64Decode(base64AudioData);
    debugPrint(
        '🔊 Sending audio chunk to Conversational AI 2.0 (${audioBytes.length} bytes)');

    await wsManager.sendAudioChunk(Uint8List.fromList(audioBytes));

    // Send user activity signal to improve turn-taking (Conversational AI 2.0 feature)
    await wsManager.sendUserActivity();

    debugPrint('🔊 Audio successfully sent to Conversational AI 2.0');

    return 'success';
  } catch (e) {
    debugPrint('❌ Error sending audio to Conversational AI 2.0 WebSocket: $e');
    return 'error: ${e.toString()}';
  }
}
