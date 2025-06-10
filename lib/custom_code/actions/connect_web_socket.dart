// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:convert';
import '../websocket_manager.dart';

Future<String> connectWebSocket(
  BuildContext context,
  String apiKey,
  String agentId,
) async {
  try {
    final wsManager = WebSocketManager();
    await wsManager.initialize(apiKey: apiKey, agentId: agentId);

    // Update app state
    FFAppState().update(() {
      FFAppState().wsConnectionState = 'connected';
      FFAppState().elevenLabsApiKey = apiKey;
      FFAppState().elevenLabsAgentId = agentId;
    });

    return 'success';
  } catch (e) {
    return 'error: ${e.toString()}';
  }
}
