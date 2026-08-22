// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/convai/convai_service.dart';

/// Opens an ElevenLabs ConvAI WebSocket session for text round-trips.
///
/// Pass empty [apiKey] / [signedUrl] to fall back to the dart-defines
/// (`ELEVENLABS_API_KEY`, `ELEVENLABS_AGENT_ID`). Prefer [signedUrl] on web,
/// where custom WebSocket headers are unavailable.
///
/// Returns `'success'` or `'error: <reason>'`.
Future<String> initializeConvAiClient(
  BuildContext context,
  String agentId,
  String apiKey,
  String signedUrl,
) async {
  try {
    debugPrint('Initializing ConvAI WebSocket client');
    return await ConvAiService().initialize(
      agentId: agentId,
      apiKey: apiKey,
      signedUrl: signedUrl,
    );
  } catch (e) {
    debugPrint('Error initializing ConvAI client: $e');
    return 'error: ${e.toString()}';
  }
}
