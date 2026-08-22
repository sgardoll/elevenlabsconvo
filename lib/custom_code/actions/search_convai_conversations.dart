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

/// Searches past conversations for [query] (case-insensitive, matches titles
/// and message text) and returns matches as the same JSON array shape as
/// `listConvAiConversations`. Blank queries return `[]`.
///
/// Returns `'error: <reason>'` when the search fails.
Future<String> searchConvAiConversations(
  BuildContext context,
  String query,
) async {
  try {
    final conversations = await ConvAiService().searchConversations(query);
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
    debugPrint('Error searching ConvAI conversations: $e');
    return 'error: ${e.toString()}';
  }
}
