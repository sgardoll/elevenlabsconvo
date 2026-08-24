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
/// SECURITY BOUNDARY — TEMPORARY CREDENTIALS ONLY. This action accepts a
/// backend-provisioned [signedUrl] or short-lived [token] (falling back to
/// the `ELEVENLABS_TOKEN` dart-define when blank). REUSABLE API KEYS ARE
/// NEVER ACCEPTED: a key embedded in a distributed build can be extracted
/// and replayed outside the app, so no parameter surface exists for one.
/// Provision credentials from your backend, never from build constants.
///
/// Returns `'success'` or `'error: <reason>'`.
Future<String> initializeConvAiClient(
  BuildContext context,
  String agentId,
  String signedUrl, {
  String token = '',
}) async {
  try {
    debugPrint('Initializing ConvAI WebSocket client');
    return await ConvAiService().initialize(
      agentId: agentId,
      signedUrl: signedUrl,
      token: token,
    );
  } catch (e) {
    debugPrint('Error initializing ConvAI client: $e');
    return 'error: ${e.toString()}';
  }
}
