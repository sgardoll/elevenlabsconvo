import '/components/response_process_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/permissions_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'home_page_model.dart';
export 'home_page_model.dart';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  static String routeName = 'HomePage';
  static String routePath = '/homePage';

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  late HomePageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomePageModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await requestPermission(microphonePermission);
      await requestPermission(bluetoothPermission);
      _model.initElevenlabsWs = await actions.initializeWebSocket(
        context,
        FFAppState().elevenLabsApiKey,
        FFAppState().elevenLabsAgentId,
      );
      if (_model.initElevenlabsWs == 'success') {}
    });
  }

  @override
  void dispose() {
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
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).primary,
          automaticallyImplyLeading: false,
          title: Text(
            FFAppState().wsConnectionState,
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.interTight(
                    fontWeight:
                        FlutterFlowTheme.of(context).headlineMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
                  color: Colors.white,
                  fontSize: 22.0,
                  letterSpacing: 0.0,
                  fontWeight:
                      FlutterFlowTheme.of(context).headlineMedium.fontWeight,
                  fontStyle:
                      FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                ),
          ),
          actions: [],
          centerTitle: false,
          elevation: 2.0,
        ),
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Align(
                  alignment: AlignmentDirectional(0.0, -1.0),
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
                          return ResponseProcessWidget(
                            key: Key(
                                'Keyet3_${conversationMessagesIndex}_of_${conversationMessages.length}'),
                            parameter1: conversationMessagesItem,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              Container(
                width: 80.0,
                height: 80.0,
                child: custom_widgets.RoundRecordingButton(
                  width: 80.0,
                  height: 80.0,
                  size: 80.0,
                  iconSize: 40.0,
                  elevation: 8.0,
                  padding: 0.0,
                  recordingColor: FlutterFlowTheme.of(context).tertiary,
                  idleColor: FlutterFlowTheme.of(context).primary,
                  iconColor: FlutterFlowTheme.of(context).secondaryBackground,
                  showSnackbar: false,
                  pulseAnimation: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
