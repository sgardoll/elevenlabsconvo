// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'index.dart'; // Imports other custom widgets

import '/custom_code/conversational_ai_service.dart';
import 'dart:async';

class SimpleRecordingButton extends StatefulWidget {
  const SimpleRecordingButton({
    Key? key,
    this.width,
    this.height,
    this.size = 60.0,
    this.iconSize = 24.0,
    this.elevation = 8.0,
    this.recordingColor,
    this.idleColor,
    this.iconColor,
    this.pulseAnimation = true,
  }) : super(key: key);

  final double? width;
  final double? height;
  final double size;
  final double iconSize;
  final double elevation;
  final Color? recordingColor;
  final Color? idleColor;
  final Color? iconColor;
  final bool pulseAnimation;

  @override
  _SimpleRecordingButtonState createState() => _SimpleRecordingButtonState();
}

class _SimpleRecordingButtonState extends State<SimpleRecordingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final ConversationalAIService _service = ConversationalAIService();
  StreamSubscription<bool>? _recordingSubscription;
  StreamSubscription<ConversationState>? _stateSubscription;

  bool _isRecording = false;
  ConversationState _currentState = ConversationState.idle;

  @override
  void initState() {
    super.initState();

    // Setup pulse animation
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

    _animationController.stop();
    _setupServiceListeners();
  }

  void _setupServiceListeners() {
    // Listen to recording state
    _recordingSubscription = _service.recordingStream.listen((isRecording) {
      if (mounted) {
        setState(() {
          _isRecording = isRecording;
        });

        // Control animation based on recording state with proper checks
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            if (isRecording && widget.pulseAnimation) {
              if (!_animationController.isAnimating) {
                _animationController.repeat(reverse: true);
              }
            } else {
              if (_animationController.isAnimating) {
                _animationController.stop();
                _animationController.reset();
              }
            }
          }
        });
      }
    });

    // Listen to overall conversation state
    _stateSubscription = _service.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _currentState = state;
        });
      }
    });
  }

  @override
  void dispose() {
    _recordingSubscription?.cancel();
    _stateSubscription?.cancel();

    // Ensure animation controller is properly stopped before disposal
    if (_animationController.isAnimating) {
      _animationController.stop();
    }
    _animationController.dispose();

    super.dispose();
  }

  Future<void> _handleTap() async {
    if (!mounted) return;

    // Allow interruption if agent is speaking - tap to interrupt
    if (_currentState == ConversationState.playing) {
      debugPrint('🔊 User tapped to interrupt agent speaking');
      await _service.triggerInterruption();
      _showSnackBar('Agent interrupted');
      return;
    }

    // Prevent interaction if not connected
    if (_currentState == ConversationState.idle ||
        _currentState == ConversationState.error) {
      _showSnackBar('Not connected to conversation service');
      return;
    }

    // Toggle recording using the consolidated service
    final result = await _service.toggleRecording();

    if (mounted && result.startsWith('error:')) {
      _showSnackBar('Recording error: ${result.substring(6)}');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

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

  Color _getButtonColor() {
    switch (_currentState) {
      case ConversationState.recording:
        return widget.recordingColor ?? FlutterFlowTheme.of(context).error;
      case ConversationState.playing:
        return FlutterFlowTheme.of(context)
            .secondary; // Changed to secondary for better tap-to-interrupt visibility
      case ConversationState.connected:
        return widget.idleColor ?? FlutterFlowTheme.of(context).primary;
      case ConversationState.connecting:
        return FlutterFlowTheme.of(context).alternate;
      case ConversationState.error:
        return FlutterFlowTheme.of(context).error;
      default:
        return FlutterFlowTheme.of(context).secondaryText;
    }
  }

  IconData _getButtonIcon() {
    switch (_currentState) {
      case ConversationState.recording:
        return Icons.stop;
      case ConversationState.playing:
        return Icons
            .pause; // Changed from volume_up to pause to indicate tap-to-interrupt
      case ConversationState.connecting:
        return Icons.sync;
      case ConversationState.error:
        return Icons.error;
      default:
        return Icons.mic;
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonContent = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: _getButtonColor(),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: widget.elevation,
            offset: Offset(0, widget.elevation / 2),
          ),
        ],
      ),
      child: Icon(
        _getButtonIcon(),
        color: widget.iconColor ??
            FlutterFlowTheme.of(context).secondaryBackground,
        size: widget.iconSize,
      ),
    );

    return GestureDetector(
      onTap: _handleTap,
      child: SizedBox(
        width: widget.width ?? widget.size,
        height: widget.height ?? widget.size,
        child: Center(
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              // Only apply scale animation when recording and pulse animation is enabled
              final shouldAnimate = _isRecording && widget.pulseAnimation;
              return Transform.scale(
                scale: shouldAnimate ? _scaleAnimation.value : 1.0,
                child: buttonContent,
              );
            },
          ),
        ),
      ),
    );
  }
}
