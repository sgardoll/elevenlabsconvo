// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/backend/api_requests/api_calls.dart';
import 'index.dart'; // Imports other custom actions

/// Gets a conversation token from the backend endpoint.
/// The endpoint should return either:
/// - { "token": "..." } for the official ElevenLabs SDK
/// - { "signedUrl": "..." } for legacy WebSocket connections (fallback)
Future<String?> getSignedUrl(
  String agentId,
  String endpoint,
) async {
  try {
    // Validate inputs
    if (agentId.isEmpty) {
      debugPrint('ERROR: agentId is empty');
      return null;
    }
    if (endpoint.isEmpty) {
      debugPrint('ERROR: endpoint is empty');
      return null;
    }

    debugPrint('Fetching conversation token...');
    debugPrint('  agentId: $agentId');
    debugPrint('  endpoint: $endpoint');

    // Call the endpoint to get conversation token
    final response = await GetSignedURLViaBuildShipCallCall.call(
      agentId: agentId,
      endpoint: endpoint,
    );

    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response body: ${response.jsonBody}');

    if (response.succeeded) {
      // Try to get token first (new SDK format)
      final token = response.jsonBody?['token']?.toString();
      if (token != null && token.isNotEmpty) {
        debugPrint('Successfully obtained conversation token');
        return token;
      }

      // Fallback to signedUrl for backward compatibility
      final signedUrl = response.jsonBody?['signedUrl']?.toString();
      if (signedUrl != null && signedUrl.isNotEmpty) {
        debugPrint('Successfully obtained signed URL (legacy format)');
        return signedUrl;
      }

      debugPrint('No token or signedUrl in response body');
      return null;
    } else {
      debugPrint('Failed to get conversation token: ${response.statusCode}');
      if (response.exception != null) {
        debugPrint('Exception: ${response.exceptionMessage}');
      }
      return null;
    }
  } catch (e, stackTrace) {
    debugPrint('Error fetching conversation token: $e');
    debugPrint('Stack trace: $stackTrace');
    return null;
  }
}
