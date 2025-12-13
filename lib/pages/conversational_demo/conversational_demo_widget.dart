import '/components/transcription_bubbles/transcription_bubbles_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/permissions_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'conversational_demo_model.dart';
export 'conversational_demo_model.dart';

class ConversationalDemoWidget extends StatefulWidget {
  const ConversationalDemoWidget({super.key});

  static String routeName = 'ConversationalDemo';
  static String routePath = '/conversationalDemo';

  @override
  State<ConversationalDemoWidget> createState() =>
      _ConversationalDemoWidgetState();
}

class _ConversationalDemoWidgetState extends State<ConversationalDemoWidget> {
  late ConversationalDemoModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ConversationalDemoModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await requestPermission(microphonePermission);
      await requestPermission(bluetoothPermission);
      await actions.initializeConversationService(
        FFAppState().agentId,
        FFAppState().endpoint,
        'I\'m I\'m your ElevenLabs Conversational AI Agent',
        'en',
        true,
        true,
      );
    });
  }

  @override
  void dispose() {
    // On page dispose action.
    () async {
      await actions.stopConversationService();
    }();

    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: SafeArea(
          top: true,
          child: Container(
            width: MediaQuery.sizeOf(context).width * 1.0,
            height: MediaQuery.sizeOf(context).height * 1.0,
            decoration: BoxDecoration(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Builder(
                    builder: (context) {
                      final conversationMessages =
                          FFAppState().conversationMessages.toList();

                      return ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        scrollDirection: Axis.vertical,
                        itemCount: conversationMessages.length,
                        itemBuilder: (context, conversationMessagesIndex) {
                          final conversationMessagesItem =
                              conversationMessages[conversationMessagesIndex];
                          return wrapWithModel(
                            model: _model.transcriptionBubblesModels.getModel(
                              conversationMessagesIndex.toString(),
                              conversationMessagesIndex,
                            ),
                            updateCallback: () => safeSetState(() {}),
                            updateOnChange: true,
                            child: TranscriptionBubblesWidget(
                              key: Key(
                                'Keyleu_${conversationMessagesIndex.toString()}',
                              ),
                              jsonResponse: conversationMessagesItem,
                              agentName: 'ElevenLabs Agent',
                              onInitCallback: () async {
                                await _model.listViewController?.animateTo(
                                  _model.listViewController!.position
                                      .maxScrollExtent,
                                  duration: Duration(milliseconds: 100),
                                  curve: Curves.ease,
                                );
                              },
                            ),
                          );
                        },
                        controller: _model.listViewController,
                      );
                    },
                  ),
                ),
                Container(
                  width: 100.0,
                  height: 100.0,
                  child: custom_widgets.SimpleRecordingButton(
                    width: 100.0,
                    height: 100.0,
                    size: 80.0,
                    iconSize: 40.0,
                    elevation: 4.0,
                    recordingColor: FlutterFlowTheme.of(context).tertiary,
                    idleColor: FlutterFlowTheme.of(context).primary,
                    iconColor: FlutterFlowTheme.of(context).secondaryBackground,
                    pulseAnimation: true,
                    keepMicHotDuringAgent: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
