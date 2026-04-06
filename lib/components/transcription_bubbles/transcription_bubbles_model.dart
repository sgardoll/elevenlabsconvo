import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/backend/schema/structs/index.dart';
import 'transcription_bubbles_widget.dart' show TranscriptionBubblesWidget;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class TranscriptionBubblesModel
    extends FlutterFlowModel<TranscriptionBubblesWidget> {
  final Map<String, DebugDataField> debugGeneratorVariables = {};
  final Map<String, DebugDataField> debugBackendQueries = {};
  final Map<String, FlutterFlowModel> widgetBuilderComponents = {};
  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}

  @override
  WidgetClassDebugData toWidgetClassDebugData() => WidgetClassDebugData(
        widgetParameters: {
          'jsonResponse': debugSerializeParam(
            widget?.jsonResponse,
            ParamType.JSON,
            link:
                'https://beta.flutterflow.io/project/elevenlabs-conversational2-x2dkep?tab=uiBuilder&page=TranscriptionBubbles',
            searchReference:
                'reference=Sh4KFgoManNvblJlc3BvbnNlEgZ4bDJ6ZnByBAgJIAFQAFoManNvblJlc3BvbnNl',
            name: 'dynamic',
            nullable: true,
          ),
          'onInitCallback': debugSerializeParam(
            widget?.onInitCallback,
            ParamType.Action,
            link:
                'https://beta.flutterflow.io/project/elevenlabs-conversational2-x2dkep?tab=uiBuilder&page=TranscriptionBubbles',
            searchReference:
                'reference=SiAKGAoOb25Jbml0Q2FsbGJhY2sSBmZxNmNza3IECBUgAVAAWg5vbkluaXRDYWxsYmFjaw==',
            name: 'Future Function()',
            nullable: true,
          ),
          'agentName': debugSerializeParam(
            widget?.agentName,
            ParamType.String,
            link:
                'https://beta.flutterflow.io/project/elevenlabs-conversational2-x2dkep?tab=uiBuilder&page=TranscriptionBubbles',
            searchReference:
                'reference=Si8KEwoJYWdlbnROYW1lEgZwM2gzejcqEhIQRWxldmVubGFicyBBZ2VudHIECAMgAVAAWglhZ2VudE5hbWU=',
            name: 'String',
            nullable: false,
          ),
          'agentImage': debugSerializeParam(
            widget?.agentImage,
            ParamType.String,
            link:
                'https://beta.flutterflow.io/project/elevenlabs-conversational2-x2dkep?tab=uiBuilder&page=TranscriptionBubbles',
            searchReference:
                'reference=ShwKFAoKYWdlbnRJbWFnZRIGeTE5Nmt2cgQIBCAAUABaCmFnZW50SW1hZ2U=',
            name: 'String',
            nullable: true,
          )
        }.withoutNulls.entries,
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
        link:
            'https://beta.flutterflow.io/project/elevenlabs-conversational2-x2dkep/tab=uiBuilder&page=TranscriptionBubbles',
        searchReference:
            'reference=OhRUcmFuc2NyaXB0aW9uQnViYmxlc1AAWhRUcmFuc2NyaXB0aW9uQnViYmxlcw==',
        widgetClassName: 'TranscriptionBubbles',
      );
}
