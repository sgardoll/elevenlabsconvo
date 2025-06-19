// Automatic FlutterFlow imports
import '/actions/actions.dart' as action_blocks;
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
import '../websocket_manager.dart';
import 'dart:async';

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
    this.borderColor,
    this.borderWeight = 0.0,
    this.borderRadius = 30.0,
    this.rippleColor,
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
  final Color? borderColor;
  final double borderWeight;
  final double borderRadius;
  final Color? rippleColor;

  @override
  _RoundRecordingButtonState createState() => _RoundRecordingButtonState();
}

class _RoundRecordingButtonState extends State<RoundRecordingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isAgentSpeaking = false;
  bool _isUserSpeaking = false;
  ConversationState _conversationState = ConversationState.idle;
  StreamSubscription<bool>? _agentSpeakingSubscription;
  StreamSubscription<bool>? _userSpeakingSubscription;
  StreamSubscription<ConversationState>? _conversationStateSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Initially stop animation
    _animationController.stop();

    // Listen to conversation states
    _setupStateListeners();
  }

  void _setupStateListeners() {
    try {
      final wsManager = WebSocketManager();

      // Listen to agent speaking state
      _agentSpeakingSubscription = wsManager.agentSpeakingStream.listen(
        (isAgentSpeaking) {
          if (mounted) {
            setState(() {
              _isAgentSpeaking = isAgentSpeaking;
            });
            debugPrint('🎙️ Agent speaking state: $isAgentSpeaking');
          }
        },
        onError: (error) {
          debugPrint('❌ Error in agent speaking stream: $error');
        },
      );

      // Listen to user speaking state
      _userSpeakingSubscription = wsManager.userSpeakingStream.listen(
        (isUserSpeaking) {
          if (mounted) {
            setState(() {
              _isUserSpeaking = isUserSpeaking;
            });
            debugPrint('🎙️ User speaking state: $isUserSpeaking');

            // Control animation based on user speaking
            if (isUserSpeaking && widget.pulseAnimation) {
              _animationController.repeat(reverse: true);
            } else {
              _animationController.stop();
              _animationController.reset();
            }
          }
        },
        onError: (error) {
          debugPrint('❌ Error in user speaking stream: $error');
        },
      );

      // Listen to overall conversation state
      _conversationStateSubscription = wsManager.conversationStateStream.listen(
        (conversationState) {
          if (mounted) {
            setState(() {
              _conversationState = conversationState;
            });
            debugPrint('🎙️ Conversation state: $conversationState');
          }
        },
        onError: (error) {
          debugPrint('❌ Error in conversation state stream: $error');
        },
      );
    } catch (e) {
      debugPrint('❌ Error setting up state listeners: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _agentSpeakingSubscription?.cancel();
    _userSpeakingSubscription?.cancel();
    _conversationStateSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(RoundRecordingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Animation is now controlled by user speaking state
  }

  void _showSnackBar(String message) {
    debugPrint('📱 _showSnackBar called with: $message');
    debugPrint('📱 showSnackbar widget property: ${widget.showSnackbar}');

    if (!widget.showSnackbar) {
      debugPrint('📱 Snackbar disabled by widget property');
      return;
    }

    try {
      // Try to find the nearest ScaffoldMessenger
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      debugPrint('📱 Found ScaffoldMessenger: ${scaffoldMessenger != null}');

      scaffoldMessenger.clearSnackBars(); // Clear any existing snackbars
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          duration: Duration(milliseconds: 3000), // Longer duration
          backgroundColor: Colors.blue.shade700,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      debugPrint('📱 Snackbar shown successfully');
    } catch (e) {
      debugPrint('❌ Error showing snackbar: $e');
      // Fallback to print if snackbar fails
      debugPrint('📱 Snackbar message: $message');

      // Alternative: Try to show a simple dialog as fallback
      try {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Status'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      } catch (dialogError) {
        debugPrint('❌ Error showing dialog fallback: $dialogError');
      }
    }
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
    print('💬 Agent speaking: $_isAgentSpeaking');
    print('💬 User speaking: $_isUserSpeaking');
    print('💬 Conversation state: $_conversationState');

    if (appState.wsConnectionState == 'disconnected') {
      debugPrint('💬 WebSocket disconnected, showing snackbar');
      _showSnackBar('Disconnected');
      return;
    }

    // Handle different conversation states
    if (_isAgentSpeaking) {
      // If agent is speaking, interrupt it
      debugPrint('💬 Agent speaking, showing interruption snackbar');
      _showSnackBar('Interrupting agent...');
      final wsManager = WebSocketManager();
      await wsManager.interruptAgent();
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
          debugPrint('💬 Stop recording error, showing snackbar');
          _showSnackBar('Error stopping recording: ${result.substring(7)}');
        }

        // Update app state
        FFAppState().update(() {
          FFAppState().isRecording = false;
        });
      } catch (e) {
        print('❌ Error stopping recording: $e');
        debugPrint('💬 Stop recording exception, showing snackbar');
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
          debugPrint('💬 Microphone permission denied, showing snackbar');
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
        debugPrint('💬 Start recording error, showing snackbar');
        _showSnackBar('Error starting recording: ${result.substring(7)}');
        return;
      }

      // Update app state
      FFAppState().update(() {
        FFAppState().isRecording = true;
      });
    } catch (e) {
      print('❌ Error starting recording: $e');
      debugPrint('💬 Start recording exception, showing snackbar');
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
    final agentSpeakingColor = FlutterFlowTheme.of(context).warning;
    final userSpeakingColor = FlutterFlowTheme.of(context).success;

    // Determine button state and appearance based on conversation state
    Color buttonColor;
    IconData buttonIcon;
    double buttonElevation;
    String buttonTooltip;

    switch (_conversationState) {
      case ConversationState.agentSpeaking:
        buttonColor = agentSpeakingColor;
        buttonIcon = Icons.volume_up;
        buttonElevation = widget.elevation;
        buttonTooltip = 'Agent is speaking - tap to interrupt';
        break;

      case ConversationState.userSpeaking:
        buttonColor = userSpeakingColor;
        buttonIcon = Icons.record_voice_over;
        buttonElevation = 0.0;
        buttonTooltip = 'You are speaking';
        break;

      case ConversationState.processing:
        buttonColor = FlutterFlowTheme.of(context).secondaryText;
        buttonIcon = Icons.hourglass_empty;
        buttonElevation = widget.elevation;
        buttonTooltip = 'Processing...';
        break;

      case ConversationState.idle:
      default:
        if (appState.isRecording) {
          buttonColor = recordingColor;
          buttonIcon = Icons.mic;
          buttonElevation = 0.0;
          buttonTooltip = 'Recording - tap to stop';
        } else {
          buttonColor = idleColor;
          buttonIcon = Icons.mic;
          buttonElevation = widget.elevation;
          buttonTooltip = 'Tap to start recording';
        }
        break;
    }

    return Tooltip(
      message: buttonTooltip,
      child: Padding(
        padding: EdgeInsets.all(widget.padding),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final scale = _isUserSpeaking && widget.pulseAnimation
                ? _scaleAnimation.value
                : 1.0;

            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: Material(
            color: Colors.transparent,
            elevation: buttonElevation,
            shape: CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: buttonColor,
                border: widget.borderWeight > 0 && widget.borderColor != null
                    ? Border.all(
                        color: widget.borderColor!,
                        width: widget.borderWeight,
                      )
                    : null,
              ),
              child: InkWell(
                onTap: _handleRecording,
                splashColor:
                    widget.rippleColor ?? Colors.white.withOpacity(0.4),
                highlightColor: widget.rippleColor?.withOpacity(0.2) ??
                    Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(widget.size / 2),
                child: Center(
                  child: Icon(
                    buttonIcon,
                    color: iconColor,
                    size: widget.iconSize,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
