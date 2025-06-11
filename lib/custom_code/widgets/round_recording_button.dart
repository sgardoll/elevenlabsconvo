// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import '/custom_code/actions/start_audio_recording.dart';
import '/custom_code/actions/stop_audio_recording.dart';

class RoundRecordingButton extends StatefulWidget {
  const RoundRecordingButton({
    Key? key,
    this.width,
    this.height,
    this.size = 60.0,
    this.iconSize = 24.0,
    this.elevation = 8.0,
    this.padding = 0.0,
    this.recordingColor,
    this.idleColor,
    this.iconColor,
    this.showSnackbar = true,
    this.pulseAnimation = true,
  }) : super(key: key);

  final double? width;
  final double? height;
  final double size;
  final double iconSize;
  final double elevation;
  final double padding;
  final Color? recordingColor;
  final Color? idleColor;
  final Color? iconColor;
  final bool showSnackbar;
  final bool pulseAnimation;

  @override
  _RoundRecordingButtonState createState() => _RoundRecordingButtonState();
}

class _RoundRecordingButtonState extends State<RoundRecordingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Only animate when recording
    if (!FFAppState().isRecording || !widget.pulseAnimation) {
      _animationController.stop();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RoundRecordingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Control animation based on recording state
    if (FFAppState().isRecording && widget.pulseAnimation) {
      _animationController.repeat(reverse: true);
    } else {
      _animationController.stop();
      _animationController.reset();
    }
  }

  void _showSnackBar(String message) {
    if (!widget.showSnackbar) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: FlutterFlowTheme.of(context).primaryText,
          ),
        ),
        duration: Duration(milliseconds: 2000),
        backgroundColor: FlutterFlowTheme.of(context).secondary,
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Microphone Permission Required'),
        content: Text(
            'Please enable microphone permission in app settings to use this feature.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRecording() async {
    final appState = FFAppState();
    print(
        '💬 Recording button pressed. Current state: ${appState.isRecording ? 'Recording' : 'Not recording'}');
    print('💬 Connection state: ${appState.wsConnectionState}');

    if (appState.wsConnectionState == 'disconnected') {
      _showSnackBar('Disconnected');
      return;
    }

    if (appState.isRecording) {
      // Stop recording
      print('💬 Stopping recording...');
      try {
        final result = await stopAudioRecording(
          context,
        );
        print('💬 Stop recording result: $result');
        if (result.startsWith('error')) {
          _showSnackBar('Error stopping recording: ${result.substring(7)}');
        }

        // Update app state
        FFAppState().update(() {
          FFAppState().isRecording = false;
        });
      } catch (e) {
        print('❌ Error stopping recording: $e');
        _showSnackBar('Error: $e');
      }
    } else {
      // Check microphone permission status first
      print('💬 Checking microphone permission...');
      final status = await Permission.microphone.status;
      print('💬 Microphone permission status: $status');

      if (status.isGranted) {
        // Permission already granted, start recording
        _startRecording();
      } else if (status.isPermanentlyDenied) {
        // Permission permanently denied, show dialog to open settings
        _showPermissionDialog();
      } else {
        // Request permission
        print('💬 Requesting microphone permission...');
        final requestStatus = await Permission.microphone.request();
        print('💬 Microphone permission request status: $requestStatus');

        if (requestStatus.isGranted) {
          _startRecording();
        } else {
          _showSnackBar('Need Microphone Permissions');
        }
      }
    }
  }

  Future<void> _startRecording() async {
    print('💬 Starting recording...');
    try {
      final result = await startAudioRecording(
        context,
      );
      print('💬 Start recording result: $result');

      if (result.startsWith('error')) {
        _showSnackBar('Error starting recording: ${result.substring(7)}');
        return;
      }

      // Update app state
      FFAppState().update(() {
        FFAppState().isRecording = true;
      });
    } catch (e) {
      print('❌ Error starting recording: $e');
      _showSnackBar('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = FFAppState();

    // Determine colors based on props or theme
    final recordingColor =
        widget.recordingColor ?? FlutterFlowTheme.of(context).tertiary;
    final idleColor = widget.idleColor ?? FlutterFlowTheme.of(context).primary;
    final iconColor = widget.iconColor ?? FlutterFlowTheme.of(context).info;

    return Padding(
      padding: EdgeInsets.all(widget.padding),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final scale = appState.isRecording && widget.pulseAnimation
              ? _scaleAnimation.value
              : 1.0;

          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          child: FloatingActionButton(
            onPressed: _handleRecording,
            backgroundColor: appState.isRecording ? recordingColor : idleColor,
            elevation: appState.isRecording ? 0.0 : widget.elevation,
            child: Icon(
              Icons.mic,
              color: iconColor,
              size: widget.iconSize,
            ),
          ),
        ),
      ),
    );
  }
}
