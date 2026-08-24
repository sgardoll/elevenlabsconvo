// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/convai/convai_service.dart';

/// Deletes one past conversation from local history. Deleting an unknown id
/// succeeds (idempotent).
///
/// Returns `'success'` or `'error: <reason>'`.
Future<String> deleteConvAiConversation(
  BuildContext context,
  String conversationId,
) async {
  try {
    return await ConvAiService().deleteConversation(conversationId);
  } catch (e) {
    debugPrint('Error deleting ConvAI conversation "$conversationId": $e');
    return 'error: ${e.toString()}';
  }
}
