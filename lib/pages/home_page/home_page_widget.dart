import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/actions/actions.dart' as action_blocks;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/custom_code/websocket_manager.dart';
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
      await action_blocks.initElevenlabsAndPermissions(context);
    });
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  Widget _buildConnectionStatusHeader() {
    return StreamBuilder<WebSocketConnectionState>(
      stream: WebSocketManager().stateStream,
      initialData: WebSocketManager().currentState,
      builder: (context, snapshot) {
        final connectionState = snapshot.data ?? WebSocketConnectionState.disconnected;
        final wsManager = WebSocketManager();
        
        Color statusColor;
        IconData statusIcon;
        String statusText;
        bool isClickable = false;
        
        switch (connectionState) {
          case WebSocketConnectionState.connecting:
            statusColor = FlutterFlowTheme.of(context).warning;
            statusIcon = Icons.wifi_protected_setup;
            statusText = wsManager.connectionStatusText;
            break;
          case WebSocketConnectionState.connected:
            statusColor = FlutterFlowTheme.of(context).success;
            statusIcon = Icons.wifi;
            statusText = wsManager.connectionStatusText;
            break;
          case WebSocketConnectionState.disconnected:
            statusColor = FlutterFlowTheme.of(context).secondaryText;
            statusIcon = Icons.wifi_off;
            statusText = wsManager.connectionStatusText;
            break;
          case WebSocketConnectionState.reconnecting:
            statusColor = FlutterFlowTheme.of(context).warning;
            statusIcon = Icons.wifi_protected_setup;
            statusText = wsManager.connectionStatusText;
            break;
          case WebSocketConnectionState.error:
            statusColor = FlutterFlowTheme.of(context).error;
            statusIcon = Icons.error_outline;
            statusText = wsManager.connectionStatusText;
            isClickable = true;
            break;
          case WebSocketConnectionState.retryExhausted:
            statusColor = FlutterFlowTheme.of(context).error;
            statusIcon = Icons.refresh;
            statusText = wsManager.connectionStatusText;
            isClickable = true;
            break;
        }

        return GestureDetector(
          onTap: isClickable ? () async {
            try {
              await wsManager.retryConnection();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Attempting to reconnect...'),
                  backgroundColor: FlutterFlowTheme.of(context).primary,
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to retry connection: $e'),
                  backgroundColor: FlutterFlowTheme.of(context).error,
                ),
              );
            }
          } : null,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              border: Border.all(color: statusColor.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  statusIcon,
                  color: statusColor,
                  size: 18,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    statusText,
                    style: FlutterFlowTheme.of(context).bodySmall.override(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isClickable) ...[
                  SizedBox(width: 4),
                  Icon(
                    Icons.touch_app,
                    color: statusColor,
                    size: 14,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorBanner() {
    return StreamBuilder<WebSocketError>(
      stream: WebSocketManager().errorStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox.shrink();
        
        final error = snapshot.data!;
        return Container(
          width: double.infinity,
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).error.withOpacity(0.1),
            border: Border.all(color: FlutterFlowTheme.of(context).error.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: FlutterFlowTheme.of(context).error,
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error.errorType,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                        color: FlutterFlowTheme.of(context).error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      error.message,
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                        color: FlutterFlowTheme.of(context).error,
                      ),
                    ),
                    if (error.details != null) ...[
                      SizedBox(height: 4),
                      Text(
                        error.details!,
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                          color: FlutterFlowTheme.of(context).secondaryText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () async {
                  await WebSocketManager().retryConnection();
                },
                icon: Icon(
                  Icons.refresh,
                  color: FlutterFlowTheme.of(context).error,
                  size: 20,
                ),
                tooltip: 'Retry connection',
              ),
            ],
          ),
        );
      },
    );
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
          backgroundColor: FlutterFlowTheme.of(context).alternate,
          automaticallyImplyLeading: false,
          title: _buildConnectionStatusHeader(),
          centerTitle: true,
          elevation: 2.0,
        ),
        body: SafeArea(
          top: true,
          child: Column(
            children: [
              _buildErrorBanner(),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional(0.0, 1.0),
                  child: Flex(
                    direction: Axis.horizontal,
                    mainAxisSize: MainAxisSize.max,
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
                          idleColor: FlutterFlowTheme.of(context).primary,
                          iconColor: FlutterFlowTheme.of(context).secondaryBackground,
                          showSnackbar: false,
                          pulseAnimation: true,
                          borderColor: FlutterFlowTheme.of(context).tertiary,
                          borderWeight: 3.0,
                          borderRadius: 100.0,
                          rippleColor: FlutterFlowTheme.of(context).secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
