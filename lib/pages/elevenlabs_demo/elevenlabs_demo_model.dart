import '/backend/api_requests/api_calls.dart';
import '/components/transcription_bubbles_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'elevenlabs_demo_widget.dart' show ElevenlabsDemoWidget;
import 'package:flutter/material.dart';

class ElevenlabsDemoModel extends FlutterFlowModel<ElevenlabsDemoWidget> {
  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend Call - API (Get Signed URL via BuildShip)] action in Elevenlabs_Demo widget.
  ApiCallResponse? signedUrlResponse;
  // Stores action output result for [Custom Action - initializeConversationService] action in Elevenlabs_Demo widget.
  String? initializeElevenlabsWebsocket;
  // State field(s) for ListView widget.
  ScrollController? listViewController;
  // Models for TranscriptionBubbles dynamic component.
  late FlutterFlowDynamicModels<TranscriptionBubblesModel>
      transcriptionBubblesModels;

  @override
  void initState(BuildContext context) {
    listViewController = ScrollController();
    transcriptionBubblesModels =
        FlutterFlowDynamicModels(() => TranscriptionBubblesModel());
  }

  @override
  void dispose() {
    listViewController?.dispose();
    transcriptionBubblesModels.dispose();
  }
}
