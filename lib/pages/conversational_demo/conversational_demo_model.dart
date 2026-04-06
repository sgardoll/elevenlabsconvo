import '/components/transcription_bubbles/transcription_bubbles_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/permissions_util.dart';
import 'conversational_demo_widget.dart' show ConversationalDemoWidget;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ConversationalDemoModel
    extends FlutterFlowModel<ConversationalDemoWidget> {
  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - initializeConversationService] action in ConversationalDemo widget.
  String? _initConvoAi;
  set initConvoAi(String? value) {
    _initConvoAi = value;
    debugLogWidgetClass(this);
  }

  String? get initConvoAi => _initConvoAi;

  // State field(s) for ListView widget.
  ScrollController? listViewController;
  // Models for TranscriptionBubbles dynamic component.
  late FlutterFlowDynamicModels<TranscriptionBubblesModel>
      transcriptionBubblesModels;

  final Map<String, DebugDataField> debugGeneratorVariables = {};
  final Map<String, DebugDataField> debugBackendQueries = {};
  final Map<String, FlutterFlowModel> widgetBuilderComponents = {};
  @override
  void initState(BuildContext context) {
    listViewController = ScrollController();
    transcriptionBubblesModels =
        FlutterFlowDynamicModels(() => TranscriptionBubblesModel());

    debugLogWidgetClass(this);
  }

  @override
  void dispose() {
    listViewController?.dispose();
    transcriptionBubblesModels.dispose();
  }

  @override
  WidgetClassDebugData toWidgetClassDebugData() => WidgetClassDebugData(
        actionOutputs: {
          'initConvoAi': debugSerializeParam(
            initConvoAi,
            ParamType.String,
            link:
                'https://beta.flutterflow.io/project/elevenlabs-conversational2-x2dkep?tab=uiBuilder&page=ConversationalDemo',
            name: 'String',
            nullable: true,
          )
        }.entries,
        generatorVariables: debugGeneratorVariables.entries,
        backendQueries: debugBackendQueries.entries,
        componentStates: {
          ...widgetBuilderComponents.map(
            (key, value) => MapEntry(
              key,
              value.toWidgetClassDebugData(),
            ),
          ),
        }.withoutNulls.entries,
        dynamicComponentStates: {
          'transcriptionBubblesModels (List<TranscriptionBubbles>)':
              transcriptionBubblesModels?.toDynamicWidgetClassDebugData(),
        }.withoutNulls.entries,
        link:
            'https://beta.flutterflow.io/project/elevenlabs-conversational2-x2dkep/tab=uiBuilder&page=ConversationalDemo',
        searchReference:
            'reference=OhJDb252ZXJzYXRpb25hbERlbW9QAVoSQ29udmVyc2F0aW9uYWxEZW1v',
        widgetClassName: 'ConversationalDemo',
      );
}
