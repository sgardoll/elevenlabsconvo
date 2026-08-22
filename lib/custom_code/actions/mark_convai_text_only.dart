// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/convai/convai_service.dart';

/// Marks the ConvAI integration as running text-only after the voice path
/// failed (graceful degradation). Text messaging over the WebSocket channel
/// keeps working; the flag lets the UI show a degraded-mode notice.
///
/// Returns `'success'` or `'error: <reason>'`.
Future<String> markConvAiTextOnly(
  BuildContext context,
  String reason,
) async {
  try {
    ConvAiService().enableTextOnlyFallback(
      reason: reason.trim().isEmpty ? 'Voice path unavailable' : reason.trim(),
    );
    return 'success';
  } catch (e) {
    debugPrint('Error marking ConvAI text-only fallback: $e');
    return 'error: ${e.toString()}';
  }
}
