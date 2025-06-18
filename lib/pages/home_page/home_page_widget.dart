import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/actions/actions.dart' as action_blocks;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/custom_code/conversation_service.dart';
import '/components/response_list/response_list_widget.dart';
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
  final _conversationService = ConversationService.instance;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomePageModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await action_blocks.initElevenlabsAndPermissions(context);
    });
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppState>(
      stream: _conversationService.stateStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final state = snapshot.data!;

        return GestureDetector(
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
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _conversationService.connectionStatusText,
                    style: FlutterFlowTheme.of(context).headlineMedium.override(
                      font: GoogleFonts.interTight(
                        fontWeight: FlutterFlowTheme.of(context).headlineMedium.fontWeight,
                        fontStyle: FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                      ),
                      color: _getStatusColor(state.connectionStatus),
                      fontSize: 22.0,
                      letterSpacing: 0.0,
                      fontWeight: FlutterFlowTheme.of(context).headlineMedium.fontWeight,
                      fontStyle: FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                    ),
                  ),
                  if (state.conversationState != ConversationState.idle)
                    Text(
                      _conversationService.conversationStateText,
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                        fontFamily: GoogleFonts.interTight().fontFamily,
                        color: FlutterFlowTheme.of(context).secondaryText,
                        fontSize: 12.0,
                      ),
                    ),
                ],
              ),
              centerTitle: true,
              elevation: 2.0,
            ),
            body: SafeArea(
              top: true,
              child: Column(
                children: [
                  // Error banner
                  if (state.errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: FlutterFlowTheme.of(context).error,
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: FlutterFlowTheme.of(context).primaryBackground,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.errorMessage!,
                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                fontFamily: GoogleFonts.interTight().fontFamily,
                                color: FlutterFlowTheme.of(context).primaryBackground,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _conversationService.clearError(),
                            icon: Icon(
                              Icons.close,
                              color: FlutterFlowTheme.of(context).primaryBackground,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Chat history
                  Expanded(
                    child: ResponseListWidget(),
                  ),
                  
                  // Audio status indicators
                  if (state.isBufferingAudio || state.isPlayingAudio)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).accent4,
                        border: Border(
                          top: BorderSide(
                            color: FlutterFlowTheme.of(context).alternate,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (state.isBufferingAudio)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else if (state.isPlayingAudio)
                            Icon(
                              Icons.volume_up,
                              size: 16,
                              color: FlutterFlowTheme.of(context).primary,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            state.isBufferingAudio ? 'Buffering audio...' : 'Playing audio',
                            style: FlutterFlowTheme.of(context).bodySmall.override(
                              fontFamily: GoogleFonts.interTight().fontFamily,
                              color: FlutterFlowTheme.of(context).secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Recording button area
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100.0,
                          height: 100.0,
                          child: custom_widgets.RoundRecordingButton(
                            width: 100.0,
                            height: 100.0,
                            size: 100.0,
                            iconSize: 50.0,
                            elevation: 8.0,
                            padding: 0.0,
                            recordingColor: FlutterFlowTheme.of(context).tertiary,
                            idleColor: _conversationService.canRecord 
                              ? FlutterFlowTheme.of(context).primary
                              : FlutterFlowTheme.of(context).secondaryText,
                            iconColor: FlutterFlowTheme.of(context).secondaryBackground,
                            showSnackbar: false,
                            pulseAnimation: state.isBotSpeaking,
                            borderColor: state.isBotSpeaking 
                              ? FlutterFlowTheme.of(context).tertiary
                              : FlutterFlowTheme.of(context).primary,
                            borderWeight: 3.0,
                            borderRadius: 100.0,
                            rippleColor: FlutterFlowTheme.of(context).secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return FlutterFlowTheme.of(context).success;
      case ConnectionStatus.connecting:
        return FlutterFlowTheme.of(context).warning;
      case ConnectionStatus.error:
        return FlutterFlowTheme.of(context).error;
      case ConnectionStatus.disconnected:
        return FlutterFlowTheme.of(context).secondaryText;
    }
  }
}
