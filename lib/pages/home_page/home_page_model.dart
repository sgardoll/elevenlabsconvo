import '/components/transcription_bubbles_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'home_page_widget.dart' show HomePageWidget;
import 'package:flutter/material.dart';

class HomePageModel extends FlutterFlowModel<HomePageWidget> {
  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - initializeConversationService] action in HomePage widget.
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
