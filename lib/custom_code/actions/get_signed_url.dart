// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '../../backend/api_requests/api_calls.dart';

Future<String?> getSignedUrl(
  String agentId,
  String endpoint,
) async {
  try {
    final resp = await GetSignedURLViaBuildShipCallCall.call(
      agentId: agentId,
      endpoint: endpoint,
    );
    if (resp.succeeded) {
      final body = (resp.jsonBody ?? {}) as Map<String, dynamic>;
      final url = body['signedUrl']?.toString();
      if (url != null && url.startsWith('wss://')) {
        return url;
      }
      debugPrint('❌ getSignedUrl: missing/invalid wss url');
      return null;
    } else {
      debugPrint('❌ getSignedUrl failed: ${resp.statusCode}');
      return null;
    }
  } catch (e) {
    debugPrint('❌ getSignedUrl exception: $e');
    return null;
  }
}
