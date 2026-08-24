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

/// Lists past conversations, newest-updated first, as a JSON array string:
///
/// ```json
/// [{"id":"conv_123","title":"Hello there","session_id":"...","messageCount":4,"startedAt":1730000000000,"updatedAt":1730000100000}]
/// ```
///
/// Returns `'error: <reason>'` when listing fails.
Future<String> listConvAiConversations(
  BuildContext context,
) async {
  try {
    final conversations = await ConvAiService().listConversations();
    return jsonEncode(conversations
        .map((conversation) => <String, dynamic>{
              'id': conversation.id,
              'title': conversation.title,
              'sessionId': conversation.sessionId,
              'messageCount': conversation.messages.length,
              'startedAt': conversation.startedAt.millisecondsSinceEpoch,
              'updatedAt': conversation.updatedAt.millisecondsSinceEpoch,
            })
        .toList());
  } catch (e) {
    debugPrint('Error listing ConvAI conversations: $e');
    return 'error: ${e.toString()}';
  }
}
