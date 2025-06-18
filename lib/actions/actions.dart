import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/permissions_util.dart';
import 'package:flutter/material.dart';

Future initElevenlabsAndPermissions(BuildContext context) async {
  String? initElevenlabsWs;

  await requestPermission(microphonePermission);
  await requestPermission(bluetoothPermission);
  initElevenlabsWs = await actions.initializeWebSocket(
    context,
    FFLibraryValues().elevenlabsApiKey,
    FFLibraryValues().elevenLabsAgentId,
  );
}
