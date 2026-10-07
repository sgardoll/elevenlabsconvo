// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/convai/convai_service.dart';

/// Closes the ConvAI WebSocket session and stops reconnection attempts.
///
/// Returns `'success'` or `'error: <reason>'`.
Future<String> stopConvAiClient(BuildContext context) async {
  try {
    return await ConvAiService().stop();
  } catch (e) {
    debugPrint('Error stopping ConvAI client: $e');
    return 'error: ${e.toString()}';
  }
}
