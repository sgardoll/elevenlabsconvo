import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart' as actions;
import 'package:flutter/material.dart';

Future initElevenlabsAndPermissions(BuildContext context) async {
  String? initElevenlabsWs;

  initElevenlabsWs = await actions.initializeWebSocket(
    context,
    FFLibraryValues().elevenlabsApiKey,
    FFLibraryValues().elevenLabsAgentId,
  );
}
