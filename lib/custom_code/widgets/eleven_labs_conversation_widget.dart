// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'dart:async';
import '../conversation_state_manager.dart';
import '../websocket_service.dart';
import '../recording_service.dart';
import '../audio_service.dart';

class ElevenLabsConversationWidget extends StatefulWidget {
  const ElevenLabsConversationWidget({
    Key? key,
    required this.apiKey,
    required this.agentId,
    this.width,
    this.height,
    // Parameters for visual feedback, not interaction
    this.indicatorSize = 80.0,
    this.iconSize = 32.0,
    this.indicatorElevation = 4.0,
    // Colors
    this.idleColor,
    this.recordingColor,
    this.agentSpeakingColor,
    this.processingColor,
    this.errorColor,
    this.iconColor,
    // Features
    this.showStatusText = true,
    this.enableHapticFeedback = true,
    // Callbacks
    this.onStateChanged,
    this.onError,
    this.onTranscript,
  }) : super(key: key);

  final String apiKey;
  final String agentId;
  final double? width;
  final double? height;
  final double indicatorSize;
  final double iconSize;
  final double indicatorElevation;
  final Color? idleColor;
  final Color? recordingColor;
  final Color? agentSpeakingColor;
  final Color? processingColor;
  final Color? errorColor;
  final Color? iconColor;
  final bool showStatusText;
  final bool enableHapticFeedback;
  final Future Function(String state)? onStateChanged;
  final Future Function(String error)? onError;
  final Future Function(String transcript)? onTranscript;

  @override
  State<ElevenLabsConversationWidget> createState() =>
      _ElevenLabsConversationWidgetState();
}

class _ElevenLabsConversationWidgetState
    extends State<ElevenLabsConversationWidget>
    with SingleTickerProviderStateMixin {
  // Services
  final _stateManager = ConversationStateManager();
  final _webSocketService = WebSocketService();
  final _recordingService = RecordingService();
  final _audioService = AudioService();

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // State subscriptions
  StreamSubscription<ConversationState>? _conversationStateSubscription;
  StreamSubscription<bool>? _connectionStatusSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<double>? _vadScoreSubscription;

  // Local state
  ConversationState _conversationState = ConversationState.disconnected;
  bool _isConnected = false;
  String? _lastError;
  bool _isInitialized = false;
  bool _isInitialRecordingStarted = false;
  double _currentVadScore = 0.0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _setupStateListeners();

    // Auto-connect and start the process on widget load
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  void _setupStateListeners() {
    // Listen to conversation state changes
    _conversationStateSubscription =
        _stateManager.conversationStateStream.listen((state) {
      if (!mounted) return;

      setState(() => _conversationState = state);
      widget.onStateChanged?.call(state.toString());

      // Handle animation based on state
      _updateAnimationForState(state);

      // Haptic feedback for state changes
      if (widget.enableHapticFeedback) {
        HapticFeedback.lightImpact();
      }

      // Log state changes for debugging
      debugPrint('🎯 Widget: Conversation state changed to $state');
    });

    // Listen to connection status changes
    _connectionStatusSubscription =
        _stateManager.connectionStatusStream.listen((connected) {
      if (!mounted) return;

      setState(() => _isConnected = connected);

      if (connected && !_isInitialRecordingStarted) {
        debugPrint(
            "✅ Connection established. Automatically starting recording.");
        _isInitialRecordingStarted = true;
        _recordingService.startRecording();
      } else if (!connected) {
        // Reset flag when disconnected
        _isInitialRecordingStarted = false;
      }
    });

    // Listen to error messages
    _errorSubscription = _stateManager.errorStream.listen((error) {
      if (!mounted) return;

      setState(() => _lastError = error);
      widget.onError?.call(error);

      debugPrint('❌ Widget: Error received - $error');
    });

    // Listen to VAD scores for visual feedback
    _vadScoreSubscription = _stateManager.vadScoreStream.listen((score) {
      if (!mounted) return;

      setState(() => _currentVadScore = score);

      // You could use VAD score for additional visual effects
      // e.g., changing indicator intensity based on voice activity
    });
  }

  void _updateAnimationForState(ConversationState state) {
    switch (state) {
      case ConversationState.userSpeaking:
      case ConversationState.agentSpeaking:
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
        break;
      case ConversationState.connecting:
      case ConversationState.processing:
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
        break;
      default:
        if (_pulseController.isAnimating) {
          _pulseController.stop();
          _pulseController.reset();
        }
        break;
    }
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🚀 Initializing ElevenLabs Conversation Widget');

      // Initialize services in correct order
      await _recordingService.initialize();
      await _audioService.initialize();
      await _webSocketService.initialize(
        apiKey: widget.apiKey,
        agentId: widget.agentId,
      );

      _isInitialized = true;
      debugPrint('✅ Widget initialization complete');
    } catch (e) {
      debugPrint('❌ Widget initialization failed: $e');
      _stateManager.reportError('Initialization failed: $e');
    }
  }

  Color _getIndicatorColor() {
    switch (_conversationState) {
      case ConversationState.disconnected:
        return widget.errorColor ?? FlutterFlowTheme.of(context).error;
      case ConversationState.connecting:
      case ConversationState.processing:
        return widget.processingColor ??
            FlutterFlowTheme.of(context).secondaryText;
      case ConversationState.idle:
      case ConversationState.userSpeaking:
        // Show different intensity based on VAD score for user speaking
        if (_conversationState == ConversationState.userSpeaking) {
          final baseColor =
              widget.recordingColor ?? FlutterFlowTheme.of(context).success;
          // Increase saturation/brightness based on VAD score
          final intensity = (_currentVadScore * 0.3).clamp(0.0, 0.3);
          return Color.lerp(baseColor, Colors.white, intensity) ?? baseColor;
        }
        return widget.recordingColor ?? FlutterFlowTheme.of(context).success;
      case ConversationState.agentSpeaking:
        return widget.agentSpeakingColor ??
            FlutterFlowTheme.of(context).warning;
      case ConversationState.error:
        return widget.errorColor ?? FlutterFlowTheme.of(context).error;
    }
  }

  IconData _getIcon() {
    switch (_conversationState) {
      case ConversationState.disconnected:
        return Icons.power_off;
      case ConversationState.connecting:
      case ConversationState.processing:
        return Icons.sync;
      case ConversationState.idle:
        return Icons.mic; // Always show mic when ready to listen
      case ConversationState.userSpeaking:
        return Icons.mic; // Microphone active
      case ConversationState.agentSpeaking:
        return Icons.volume_up;
      case ConversationState.error:
        return Icons.error_outline;
    }
  }

  String _getStatusText() {
    switch (_conversationState) {
      case ConversationState.disconnected:
        return 'Disconnected';
      case ConversationState.connecting:
        return 'Connecting...';
      case ConversationState.idle:
        return _isConnected ? 'Listening...' : 'Connecting...';
      case ConversationState.userSpeaking:
        // Show VAD-based feedback
        final intensity = _currentVadScore > 0.7
            ? 'Hearing you clearly'
            : 'I\'m listening...';
        return intensity;
      case ConversationState.agentSpeaking:
        return 'Agent Speaking...';
      case ConversationState.processing:
        return 'Thinking...';
      case ConversationState.error:
        return _lastError ?? 'An error occurred';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: widget.indicatorSize,
                  height: widget.indicatorSize,
                  child: Material(
                    color: _getIndicatorColor(),
                    shape: CircleBorder(),
                    elevation: widget.indicatorElevation,
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        _getIcon(),
                        key: ValueKey(
                            _conversationState), // Key for AnimatedSwitcher
                        size: widget.iconSize,
                        color: widget.iconColor ?? Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (widget.showStatusText) ...[
            SizedBox(height: 16),
            AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              child: Text(
                _getStatusText(),
                key: ValueKey(_getStatusText()), // Key for AnimatedSwitcher
                textAlign: TextAlign.center,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'Readex Pro',
                      color: _conversationState == ConversationState.error
                          ? widget.errorColor ??
                              FlutterFlowTheme.of(context).error
                          : FlutterFlowTheme.of(context).secondaryText,
                    ),
              ),
            ),
          ],

          // // Optional debug info in debug mode
          // if (kDebugMode) ...[
          //   SizedBox(height: 8),
          //   Text(
          //     'VAD: ${_currentVadScore.toStringAsFixed(2)} | Connected: $_isConnected',
          //     style: TextStyle(
          //       fontSize: 10,
          //       color: Colors.grey,
          //     ),
          //   ),
          // ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    debugPrint('🗑️ Disposing ElevenLabs Conversation Widget');

    _pulseController.dispose();

    // Cancel subscriptions
    _conversationStateSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _errorSubscription?.cancel();
    _vadScoreSubscription?.cancel();

    // Dispose services if initialized
    if (_isInitialized) {
      _webSocketService.dispose();
      _recordingService.dispose();
      _audioService.dispose();
    }

    super.dispose();
  }
}
