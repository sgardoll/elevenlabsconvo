import '/components/transcription_bubbles_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'conversational_demo_widget.dart' show ConversationalDemoWidget;
import 'package:flutter/material.dart';

class ConversationalDemoModel
    extends FlutterFlowModel<ConversationalDemoWidget> {
  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - initializeConversationService] action in ConversationalDemo widget.
  String? initConvoAi;
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
