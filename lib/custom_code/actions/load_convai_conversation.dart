// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:convert';

import '/convai/convai_service.dart';

/// Loads one past conversation's messages as a JSON array string:
///
/// ```json
/// [{"role":"user","content":"...","timestamp":1730000000000},...]
/// ```
///
/// Returns `'error: <reason>'` when the conversation cannot be loaded.
Future<String> loadConvAiConversation(
  BuildContext context,
  String conversationId,
) async {
  try {
    final conversation =
        await ConvAiService().loadConversation(conversationId);
    if (conversation == null) {
      return 'error: Conversation "$conversationId" not found.';
    }
    return jsonEncode(
        conversation.messages.map((message) => message.toJson()).toList());
  } catch (e) {
    debugPrint('Error loading ConvAI conversation "$conversationId": $e');
    return 'error: ${e.toString()}';
  }
}
