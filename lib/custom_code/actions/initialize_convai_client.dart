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
/// Pass empty [apiKey] / [signedUrl] / [token] to fall back to the
/// dart-defines (`ELEVENLABS_TOKEN`, `ELEVENLABS_AGENT_ID`). Prefer
/// [signedUrl] or [token] — short-lived, backend-provisioned credentials.
///
/// [apiKey] is a REUSABLE key that can be extracted from a distributed
/// build and replayed outside the app. It is refused unless
/// [allowInsecureApiKey] is true (local development only), in which case a
/// loud security warning is logged. Never enable it in production builds.
///
/// Returns `'success'` or `'error: <reason>'`.
Future<String> initializeConvAiClient(
  BuildContext context,
  String agentId,
  String apiKey,
  String signedUrl, {
  String token = '',
  bool allowInsecureApiKey = false,
}) async {
  try {
    debugPrint('Initializing ConvAI WebSocket client');
    return await ConvAiService().initialize(
      agentId: agentId,
      apiKey: apiKey,
      signedUrl: signedUrl,
      token: token,
      allowInsecureApiKey: allowInsecureApiKey,
    );
  } catch (e) {
    debugPrint('Error initializing ConvAI client: $e');
    return 'error: ${e.toString()}';
  }
}
