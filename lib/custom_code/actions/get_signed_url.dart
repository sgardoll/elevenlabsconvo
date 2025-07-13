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
    debugPrint('🔐 Fetching signed URL for agent: $agentId');

    // Call the endpoint to get signed URL
    final response = await GetSignedURLViaBuildShipCallCall.call(
      agentId: agentId,
      endpoint: endpoint,
    );

    if (response.succeeded) {
      final signedUrl = response.jsonBody?['signedUrl']?.toString();

      if (signedUrl != null && signedUrl.isNotEmpty) {
        debugPrint('🔐 Successfully obtained signed URL');
        return signedUrl;
      } else {
        debugPrint('❌ No signed URL in response');
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
