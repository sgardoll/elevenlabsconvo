// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:convert';
import '../websocket_manager.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' show min;

Future<String> initializeWebSocket(
  BuildContext context,
  String apiKey,
  String agentId,
) async {
  try {
    if (apiKey.isEmpty || agentId.isEmpty) {
      debugPrint('❌ Missing API key or agent ID');
      return 'error: Missing API key or agent ID';
    }

    debugPrint('🔌 Initializing WebSocket connection');
    debugPrint(
        '🔌 API Key: ${apiKey.substring(0, min(10, apiKey.length))}... (masked)');
    debugPrint('🔌 Agent ID: $agentId');

    final wsManager = WebSocketManager();
    await wsManager.initialize(apiKey: apiKey, agentId: agentId);

    // Update app state
    FFAppState().update(() {
      FFAppState().wsConnectionState = 'connected';
      FFAppState().elevenLabsApiKey = apiKey;
      FFAppState().elevenLabsAgentId = agentId;
    });

    // Listen to connection state changes
    wsManager.stateStream.listen((state) {
      debugPrint('🔌 WebSocket state changed: $state');
      FFAppState().update(() {
        FFAppState().wsConnectionState = state.toString().split('.').last;
      });
    });

    // Listen to messages
    wsManager.messageStream.listen((message) {
      debugPrint(
          '🔌 Received message from WebSocket: ${message.keys.join(", ")}');
      FFAppState().update(() {
        FFAppState().conversationMessages = [
          ...FFAppState().conversationMessages,
          message
        ];
      });
    }, onError: (error) {
      debugPrint('❌ Error from WebSocket message stream: $error');
    });

    // Listen to audio data
    wsManager.audioStream.listen((audioData) {
      debugPrint('🔌 Received audio data: ${audioData.length} bytes');
      final base64Audio = base64Encode(audioData);
      FFAppState().update(() {
        FFAppState().lastAudioResponse = base64Audio;
      });
    }, onError: (error) {
      debugPrint('❌ Error from WebSocket audio stream: $error');
    });

    debugPrint('🔌 WebSocket initialized successfully');
    return 'success';
  } catch (e) {
    debugPrint('❌ Error initializing WebSocket: $e');

    // Update app state to show the error
    FFAppState().update(() {
      FFAppState().wsConnectionState =
          'error: ${e.toString().substring(0, min(50, e.toString().length))}';
    });

    return 'error: ${e.toString()}';
  }
}
