// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/backend/api_requests/api_calls.dart';

/// Gets a conversation token from the backend endpoint.
/// The endpoint should return either:
/// - { "token": "..." } for the official ElevenLabs SDK
/// - { "signedUrl": "..." } for legacy WebSocket connections (fallback)

// You can clone the BuildShip template to use from: https://app.buildship.com/remix/dfb510c9-5e03-4284-beba-8471b2340595?via=lb

const _tokenRequestTimeout = Duration(seconds: 10);
const _maxTokenRequestAttempts = 3;

Future<String?> getSignedUrl(
  String agentId,
  String endpoint,
) async {
  try {
    // Validate inputs
    if (agentId.isEmpty) {
      _debugLog('ERROR: agentId is empty');
      return null;
    }
    if (endpoint.isEmpty) {
      _debugLog('ERROR: endpoint is empty');
      return null;
    }

    _debugLog('Fetching conversation token...');
    _debugLog('  agentId: $agentId');
    _debugLog('  endpoint: $endpoint');

    // Call the endpoint to get conversation token
    final response = await _fetchConversationToken(agentId, endpoint);
    if (response == null) {
      return null;
    }

    _debugLog('Response status: ${response.statusCode}');

    if (response.succeeded) {
      // Try to get token first (new SDK format)
      final token = response.jsonBody?['token']?.toString();
      if (token != null && token.isNotEmpty) {
        _debugLog('Successfully obtained conversation token');
        return token;
      }

      // Fallback to signedUrl for backward compatibility
      final signedUrl = response.jsonBody?['signedUrl']?.toString();
      if (signedUrl != null && signedUrl.isNotEmpty) {
        _debugLog('Successfully obtained signed URL (legacy format)');
        return signedUrl;
      }

      _debugLog('No token or signedUrl in response body');
      return null;
    } else {
      _debugLog('Failed to get conversation token: ${response.statusCode}');
      if (response.exception != null) {
        _debugLog('Exception: ${response.exceptionMessage}');
      }
      return null;
    }
  } catch (e, stackTrace) {
    _debugLog('Error fetching conversation token: $e');
    _debugLog('Stack trace: $stackTrace');
    return null;
  }
}

Future<ApiCallResponse?> _fetchConversationToken(
  String agentId,
  String endpoint,
) async {
  for (var attempt = 1; attempt <= _maxTokenRequestAttempts; attempt++) {
    try {
      final response = await GetSignedURLViaBuildShipCallCall.call(
        agentId: agentId,
        endpoint: endpoint,
      ).timeout(_tokenRequestTimeout);

      if (!_shouldRetry(response.statusCode) ||
          attempt == _maxTokenRequestAttempts) {
        return response;
      }
    } catch (e) {
      if (attempt == _maxTokenRequestAttempts) {
        rethrow;
      }
      _debugLog('Retrying token request after error: $e');
    }

    await Future.delayed(Duration(milliseconds: 250 * attempt));
  }

  return null;
}

bool _shouldRetry(int statusCode) =>
    statusCode == -1 ||
    statusCode == 408 ||
    statusCode == 429 ||
    statusCode >= 500;

void _debugLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}
