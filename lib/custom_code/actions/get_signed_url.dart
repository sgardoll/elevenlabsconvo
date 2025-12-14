// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/backend/api_requests/api_calls.dart';

Future<String?> getSignedUrl(
  String agentId,
  String endpoint,
) async {
  try {
    debugPrint('🔐 Fetching signed URL/token for agent: $agentId');

    // Call the endpoint to get signed URL
    final response = await GetSignedURLViaBuildShipCallCall.call(
      agentId: agentId,
      endpoint: endpoint,
    );

    if (response.succeeded) {
      // The API returns a JSON object with 'signedUrl' and 'token'.
      // We prioritize the 'token' for the official SDK.
      final token = response.jsonBody?['token']?.toString();
      final signedUrl = response.jsonBody?['signedUrl']?.toString();

      if (token != null && token.isNotEmpty) {
        debugPrint('🔐 Successfully obtained conversation token');
        return token;
      } else if (signedUrl != null && signedUrl.isNotEmpty) {
        debugPrint('⚠️ Token not found, falling back to signed URL (might fail with official SDK)');
        return signedUrl;
      } else {
        debugPrint('❌ No token or signed URL in response');
        return null;
      }
    } else {
      debugPrint('❌ Failed to get signed URL: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    debugPrint('❌ Error fetching signed URL: $e');
    return null;
  }
}
