// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/convai/convai_service.dart';

/// Sends [text] over the active ConvAI WebSocket session and returns the
/// agent's reply text once the `agent_response` event arrives.
///
/// Returns `'error: <reason>'` when the client is not connected or the
/// exchange times out.
Future<String> sendConvAiTextMessage(
  BuildContext context,
  String text,
) async {
  try {
    return await ConvAiService().sendTextMessage(text);
  } catch (e) {
    debugPrint('Error sending ConvAI text message: $e');
    return 'error: ${e.toString()}';
  }
}
