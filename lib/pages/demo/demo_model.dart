import '/components/transcription_bubbles_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'demo_widget.dart' show DemoWidget;
import 'package:flutter/material.dart';

class DemoModel extends FlutterFlowModel<DemoWidget> {
  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - initializeConversationService] action in Demo widget.
  String? initEleven;
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
