import '/components/transcription_bubbles_widget.dart';
import '/components/user_credentials_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/permissions_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'demo_model.dart';
export 'demo_model.dart';

class DemoWidget extends StatefulWidget {
  const DemoWidget({super.key});

  static String routeName = 'Demo';
  static String routePath = '/demo';

  @override
  State<DemoWidget> createState() => _DemoWidgetState();
}

class _DemoWidgetState extends State<DemoWidget> {
  late DemoModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DemoModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (!((FFAppState().elevenLabsApiKey != '') &&
          (FFAppState().elevenLabsAgentId != ''))) {
        await showDialog(
          context: context,
          builder: (dialogContext) {
            return Dialog(
              elevation: 0,
              insetPadding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              alignment: AlignmentDirectional(0.0, 0.0)
                  .resolve(Directionality.of(context)),
              child: GestureDetector(
                onTap: () {
                  FocusScope.of(dialogContext).unfocus();
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                child: UserCredentialsWidget(),
              ),
            );
          },
        );
      }
      await requestPermission(microphonePermission);
      _model.initEleven = await actions.initializeConversationService(
        context,
        FFAppState().elevenLabsApiKey,
        FFAppState().elevenLabsAgentId,
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

    return Builder(
      builder: (context) => GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Scaffold(
          key: scaffoldKey,
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          appBar: AppBar(
            backgroundColor: FlutterFlowTheme.of(context).alternate,
            automaticallyImplyLeading: false,
            title: Text(
              'Elevenlabs Conversational AI V2',
              style: FlutterFlowTheme.of(context).headlineMedium.override(
                    font: GoogleFonts.interTight(
                      fontWeight: FlutterFlowTheme.of(context)
                          .headlineMedium
                          .fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                    ),
                    color: FlutterFlowTheme.of(context).secondaryText,
                    fontSize: 22.0,
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).headlineMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
            ),
            actions: [],
            centerTitle: true,
            elevation: 4.0,
          ),
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
                                  'Key9w1_${conversationMessagesIndex.toString()}',
                                ),
                                jsonResponse: conversationMessagesItem,
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
                      iconColor:
                          FlutterFlowTheme.of(context).secondaryBackground,
                      pulseAnimation: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
