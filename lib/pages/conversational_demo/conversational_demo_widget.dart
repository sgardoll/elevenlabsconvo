import '/components/transcription_bubbles/transcription_bubbles_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/permissions_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
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

class _ConversationalDemoWidgetState extends State<ConversationalDemoWidget>
    with RouteAware {
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
      _model.initConvoAi = await actions.initializeConversationService(
        context,
        FFAppState().elevenLabsAgentId,
        FFAppState().endpoint,
      );
    });
  }

  @override
  void dispose() {
    // On page dispose action.
    () async {
      await actions.stopConversationService();
    }();

    routeObserver.unsubscribe(this);

    _model.dispose();

    super.dispose();
  }

  @override
  void didUpdateWidget(ConversationalDemoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _model.widget = widget;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = DebugModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
    debugLogGlobalProperty(context);
  }

  @override
  void didPopNext() {
    if (mounted && DebugFlutterFlowModelContext.maybeOf(context) == null) {
      setState(() => _model.isRouteVisible = true);
      debugLogWidgetClass(_model);
    }
  }

  @override
  void didPush() {
    if (mounted && DebugFlutterFlowModelContext.maybeOf(context) == null) {
      setState(() => _model.isRouteVisible = true);
      debugLogWidgetClass(_model);
    }
  }

  @override
  void didPop() {
    _model.isRouteVisible = false;
  }

  @override
  void didPushNext() {
    _model.isRouteVisible = false;
  }

  @override
  Widget build(BuildContext context) {
    DebugFlutterFlowModelContext.maybeOf(context)
        ?.parentModelCallback
        ?.call(_model);
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
                      _model.debugGeneratorVariables[
                              'conversationMessages${conversationMessages.length > 100 ? ' (first 100)' : ''}'] =
                          debugSerializeParam(
                        conversationMessages.take(100),
                        ParamType.JSON,
                        isList: true,
                        link:
                            'https://beta.flutterflow.io/project/elevenlabs-conversational2-x2dkep?tab=uiBuilder&page=ConversationalDemo',
                        name: 'dynamic',
                        nullable: false,
                      );
                      debugLogWidgetClass(_model);

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
                            child: Builder(builder: (_) {
                              return DebugFlutterFlowModelContext(
                                rootModel: _model.rootModel,
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
                            }),
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
