// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '../conversational_ai_service.dart';
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
    this.keepMicHotDuringAgent = true,
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

  /// Controls whether the mic remains active while the agent is speaking.
  final bool keepMicHotDuringAgent;

  @override
  _SimpleRecordingButtonState createState() => _SimpleRecordingButtonState();
}

class _SimpleRecordingButtonState extends State<SimpleRecordingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final ConversationalAIService _service = ConversationalAIService();
  StreamSubscription<ConversationState>? _stateSubscription;

  bool _isRecording = false;
  ConversationState _currentState = ConversationState.idle;

  @override
  void initState() {
    super.initState();

    // Pulse animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..stop();

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _bindServiceState();
  }

  void _bindServiceState() {
    // Single source of truth: stateStream
    _stateSubscription = _service.stateStream.listen((state) {
      if (!mounted) return;

      setState(() {
        _currentState = state;
        _isRecording = (state == ConversationState.recording);
      });

      // Drive pulse animation only when actively recording
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final shouldPulse = _isRecording && widget.pulseAnimation;
        if (shouldPulse) {
          if (!_animationController.isAnimating) {
            _animationController.repeat(reverse: true);
          }
        } else {
          if (_animationController.isAnimating) {
            _animationController.stop();
            _animationController.reset();
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    if (_animationController.isAnimating) {
      _animationController.stop();
    }
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (!mounted) return;

    // Tap-to-interrupt while agent is speaking
    if (_currentState == ConversationState.playing) {
      await _service.interrupt();
      _showSnackBar('Interrupted');
      return;
    }

    // Not connected yet / error
    if (_currentState == ConversationState.idle ||
        _currentState == ConversationState.connecting ||
        _currentState == ConversationState.error) {
      _showSnackBar('Not connected');
      return;
    }

    // Toggle mic (single button behavior)
    final res = await _service.toggleMic(
      keepMicHotDuringAgent: widget.keepMicHotDuringAgent,
    );

    if (!mounted) return;
    if (res.startsWith('error:')) {
      _showSnackBar(res.replaceFirst('error:', '').trim());
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
        duration: const Duration(milliseconds: 1800),
        backgroundColor: FlutterFlowTheme.of(context).secondary,
      ),
    );
  }

  Color _getButtonColor() {
    switch (_currentState) {
      case ConversationState.recording:
        return widget.recordingColor ?? FlutterFlowTheme.of(context).error;
      case ConversationState.playing:
        // Distinct color while agent is speaking so users know they can tap to interrupt
        return FlutterFlowTheme.of(context).secondary;
      case ConversationState.connected:
        return widget.idleColor ?? FlutterFlowTheme.of(context).primary;
      case ConversationState.connecting:
        return FlutterFlowTheme.of(context).alternate;
      case ConversationState.error:
        return FlutterFlowTheme.of(context).error;
      case ConversationState.idle:
      default:
        return FlutterFlowTheme.of(context).secondaryText;
    }
  }

  IconData _getButtonIcon() {
    switch (_currentState) {
      case ConversationState.recording:
        return Icons.stop;
      case ConversationState.playing:
        // “Pause” visually implies you can stop/interrupt the agent
        return Icons.pause;
      case ConversationState.connecting:
        return Icons.sync;
      case ConversationState.error:
        return Icons.error;
      case ConversationState.connected:
      case ConversationState.idle:
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
