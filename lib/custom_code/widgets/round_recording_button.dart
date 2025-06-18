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
      barrierDismissible: false, // Require user action
      builder: (BuildContext context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.mic_off, color: FlutterFlowTheme.of(context).error),
            SizedBox(width: 8),
            Text('Microphone Permission Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This app needs microphone access to record your voice for conversation.',
              style: FlutterFlowTheme.of(context).bodyMedium,
            ),
            SizedBox(height: 12),
            Text(
              'To enable microphone access:',
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '1. Tap "Open Settings" below\n2. Find this app in the list\n3. Enable "Microphone" permission\n4. Return to the app',
              style: FlutterFlowTheme.of(context).bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            icon: Icon(Icons.settings),
            label: Text('Open Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FlutterFlowTheme.of(context).primary,
              foregroundColor: FlutterFlowTheme.of(context).primaryText,
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message, {String? actionLabel, VoidCallback? onAction}) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: FlutterFlowTheme.of(context).error),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
          if (actionLabel != null && onAction != null)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onAction();
              },
              child: Text(actionLabel),
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

    // Check WebSocket connection state first
    if (appState.wsConnectionState == 'disconnected') {
      _showSnackBar('Not connected to voice service');
      return;
    }

    if (appState.wsConnectionState.startsWith('error:')) {
      _showErrorDialog(
        'Connection Error', 
        'There\'s an issue with the voice service connection. Please try reconnecting.',
        actionLabel: 'Retry Connection',
        onAction: () async {
          // Trigger reconnection
          final wsManager = WebSocketManager();
          await wsManager.retryConnection();
        },
      );
      return;
    }

    if (appState.wsConnectionState == 'retryExhausted') {
      _showErrorDialog(
        'Connection Failed', 
        'Unable to connect to voice service after multiple attempts.',
        actionLabel: 'Try Again',
        onAction: () async {
          final wsManager = WebSocketManager();
          await wsManager.retryConnection();
        },
      );
      return;
    }

    // Handle different conversation states
    if (_isAgentSpeaking) {
      // If agent is speaking, interrupt it
      _showSnackBar('Interrupting agent...');
      try {
        final wsManager = WebSocketManager();
        await wsManager.interruptAgent();
      } catch (e) {
        print('❌ Error interrupting agent: $e');
        _showSnackBar('Failed to interrupt agent');
      }
      return;
    }

    if (appState.isRecording) {
      // Stop recording
      print('💬 Stopping recording...');
      try {
        final result = await stopAudioRecording(context);
        print('💬 Stop recording result: $result');
        
        if (result.startsWith('error')) {
          final errorMsg = result.substring(7);
          _showSnackBar('Error stopping recording: $errorMsg');
          
          // Try to reset recording state even if stop failed
          FFAppState().update(() {
            FFAppState().isRecording = false;
          });
        } else {
          // Update app state on successful stop
          FFAppState().update(() {
            FFAppState().isRecording = false;
          });
        }
      } catch (e) {
        print('❌ Error stopping recording: $e');
        _showSnackBar('Error: $e');
        
        // Reset state on error
        FFAppState().update(() {
          FFAppState().isRecording = false;
        });
      }
    } else {
      // Start recording - check permissions with enhanced UX
      await _handlePermissionAndStartRecording();
    }
  }

  Future<void> _handlePermissionAndStartRecording() async {
    try {
      print('💬 Checking microphone permission...');
      final status = await Permission.microphone.status;
      print('💬 Microphone permission status: $status');

      switch (status) {
        case PermissionStatus.granted:
          // Permission already granted, start recording
          await _startRecording();
          break;

        case PermissionStatus.denied:
          // Permission denied but can be requested
          print('💬 Requesting microphone permission...');
          _showSnackBar('Requesting microphone permission...');
          
          final requestStatus = await Permission.microphone.request();
          print('💬 Microphone permission request result: $requestStatus');

          if (requestStatus.isGranted) {
            await _startRecording();
          } else if (requestStatus.isPermanentlyDenied) {
            _showPermissionDialog();
          } else {
            _showSnackBar('Microphone permission is required for voice recording');
          }
          break;

        case PermissionStatus.permanentlyDenied:
          // Permission permanently denied, show dialog to open settings
          _showPermissionDialog();
          break;

        case PermissionStatus.restricted:
          // Permission restricted (iOS parental controls, etc.)
          _showErrorDialog(
            'Permission Restricted',
            'Microphone access is restricted on this device. This may be due to parental controls or device management settings.',
          );
          break;

        case PermissionStatus.limited:
          // Limited permission (iOS 14+) - treat as granted
          await _startRecording();
          break;

        default:
          _showErrorDialog(
            'Permission Error',
            'Unable to determine microphone permission status. Please check your device settings.',
            actionLabel: 'Open Settings',
            onAction: () => openAppSettings(),
          );
      }
    } catch (e) {
      print('❌ Error handling permission: $e');
      _showErrorDialog(
        'Permission Error',
        'An error occurred while checking microphone permissions: $e',
        actionLabel: 'Try Again',
        onAction: () => _handlePermissionAndStartRecording(),
      );
    }
  }

  Future<void> _startRecording() async {
    print('💬 Starting recording...');
    try {
      // Show loading state
      _showSnackBar('Starting recording...');
      
      final result = await startAudioRecording(context);
      print('💬 Start recording result: $result');

      if (result.startsWith('error')) {
        final errorMsg = result.substring(7);
        print('❌ Recording start failed: $errorMsg');
        
        // Provide specific error feedback
        if (errorMsg.contains('permission')) {
          _showErrorDialog(
            'Permission Error',
            'Microphone permission was denied or revoked.',
            actionLabel: 'Check Settings',
            onAction: () => openAppSettings(),
          );
        } else if (errorMsg.contains('already recording')) {
          _showSnackBar('Recording is already in progress');
        } else {
          _showErrorDialog(
            'Recording Error',
            'Failed to start recording: $errorMsg',
            actionLabel: 'Try Again',
            onAction: () => _startRecording(),
          );
        }
        return;
      }

      // Update app state on successful start
      FFAppState().update(() {
        FFAppState().isRecording = true;
      });
      
      _showSnackBar('Recording started');
    } catch (e) {
      print('❌ Error starting recording: $e');
      _showErrorDialog(
        'Recording Error',
        'An unexpected error occurred: $e',
        actionLabel: 'Try Again',
        onAction: () => _startRecording(),
      );
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
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: widget.borderWeight > 0 && widget.borderColor != null
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.borderColor!,
                      width: widget.borderWeight,
                    ),
                  )
                : null,
            child: Material(
              color: buttonColor,
              elevation: buttonElevation,
              shape: CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _handleRecording,
                splashColor:
                    widget.rippleColor ?? Colors.white.withOpacity(0.3),
                highlightColor: widget.rippleColor?.withOpacity(0.1) ??
                    Colors.white.withOpacity(0.1),
                customBorder: CircleBorder(),
                child: Container(
                  width: widget.size,
                  height: widget.size,
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
