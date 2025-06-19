import 'dart:async';
import 'package:flutter/foundation.dart';

enum ConversationState {
  disconnected,
  connecting,
  idle,
  userSpeaking,
  agentSpeaking,
  processing,
  error
}

enum RecordingState { idle, recording, paused, stopping }

class ConversationStateManager {
  static final ConversationStateManager _instance =
      ConversationStateManager._internal();
  factory ConversationStateManager() => _instance;
  ConversationStateManager._internal();

  // State controllers
  final _conversationStateController =
      StreamController<ConversationState>.broadcast();
  final _recordingStateController =
      StreamController<RecordingState>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _vadScoreController = StreamController<double>.broadcast();

  // Current states
  ConversationState _conversationState = ConversationState.disconnected;
  RecordingState _recordingState = RecordingState.idle;
  bool _isConnected = false;
  double _currentVadScore = 0.0;
  String? _lastError;

  // State flags
  bool _isInterrupting = false;
  DateTime? _lastStateChange;

  // Getters for streams
  Stream<ConversationState> get conversationStateStream =>
      _conversationStateController.stream;
  Stream<RecordingState> get recordingStateStream =>
      _recordingStateController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<double> get vadScoreStream => _vadScoreController.stream;

  // Getters for current states
  ConversationState get conversationState => _conversationState;
  RecordingState get recordingState => _recordingState;
  bool get isConnected => _isConnected;
  double get currentVadScore => _currentVadScore;
  String? get lastError => _lastError;
  bool get isInterrupting => _isInterrupting;

  // Callback for when user finishes speaking
  void Function()? _onUserFinishedSpeaking;

  void setOnUserFinishedSpeaking(void Function() callback) {
    _onUserFinishedSpeaking = callback;
  }

  // State update methods with improved logging and validation
  void updateConversationState(ConversationState newState) {
    if (_conversationState == newState) return;

    final previousState = _conversationState;
    _conversationState = newState;
    _lastStateChange = DateTime.now();

    debugPrint('🎯 Conversation state: $previousState → $newState');
    _conversationStateController.add(newState);

    // Auto-handle recording state based on conversation state
    _updateRecordingStateForConversationState(newState);

    // Clear error when transitioning away from error state
    if (previousState == ConversationState.error &&
        newState != ConversationState.error) {
      _lastError = null;
    }
  }

  void updateRecordingState(RecordingState newState) {
    if (_recordingState == newState) return;

    final previousState = _recordingState;
    _recordingState = newState;

    debugPrint('🎙️ Recording state: $previousState → $newState');
    _recordingStateController.add(newState);
  }

  void updateConnectionStatus(bool connected) {
    if (_isConnected == connected) return;

    debugPrint('🔌 Connection status: $_isConnected → $connected');
    _isConnected = connected;
    _connectionStatusController.add(connected);

    if (!connected) {
      updateConversationState(ConversationState.disconnected);
      updateRecordingState(RecordingState.idle);
    } else if (_conversationState == ConversationState.disconnected) {
      updateConversationState(ConversationState.idle);
    }
  }

  void updateVadScore(double score) {
    _currentVadScore = score;
    _vadScoreController.add(score);

    // Log significant VAD score changes for debugging
    if (score > 0.7 || score < 0.3) {
      debugPrint('🎤 VAD score: $score');
    }
  }

  void reportError(String error) {
    debugPrint('❌ Error reported: $error');
    _lastError = error;
    _errorController.add(error);

    // Only update to error state if not in a critical transition
    if (_conversationState != ConversationState.connecting) {
      updateConversationState(ConversationState.error);
    }
  }

  // Event handling from services
  void userStartedSpeaking() {
    debugPrint('🎤 User started speaking (current state: $_conversationState)');

    if (_conversationState == ConversationState.agentSpeaking) {
      _isInterrupting = true;
      debugPrint('🛑 User interrupting agent');
    }

    updateConversationState(ConversationState.userSpeaking);
  }

  void userFinishedSpeaking() {
    debugPrint(
        '🎤 User finished speaking (current state: $_conversationState)');

    if (_conversationState == ConversationState.userSpeaking) {
      updateConversationState(ConversationState.idle);
      _notifyUserFinishedSpeaking();
    }
  }

  void agentPlaybackStarted() {
    debugPrint('🔊 Agent playback started');
    _isInterrupting = false;
    updateConversationState(ConversationState.agentSpeaking);
  }

  void agentPlaybackFinished() {
    debugPrint('🔊 Agent playback finished');

    if (_conversationState == ConversationState.agentSpeaking) {
      updateConversationState(ConversationState.idle);
    }
  }

  void interruptionAcknowledged() {
    debugPrint('🛑 Interruption acknowledged by server');
    _isInterrupting = false;

    // Only transition to idle if not currently user speaking
    if (_conversationState != ConversationState.userSpeaking) {
      updateConversationState(ConversationState.idle);
    }
  }

  void _notifyUserFinishedSpeaking() {
    _onUserFinishedSpeaking?.call();
  }

  // Private helper methods
  void _updateRecordingStateForConversationState(ConversationState state) {
    switch (state) {
      case ConversationState.agentSpeaking:
        // Pause recording during agent speech to prevent echo/feedback
        if (_recordingState == RecordingState.recording) {
          updateRecordingState(RecordingState.paused);
        }
        break;

      case ConversationState.userSpeaking:
      case ConversationState.idle:
        // Resume recording when agent finishes or user is expected to speak
        if (_recordingState == RecordingState.paused && _isConnected) {
          updateRecordingState(RecordingState.recording);
        }
        break;

      case ConversationState.disconnected:
      case ConversationState.error:
        // Stop recording on disconnect or error
        if (_recordingState != RecordingState.idle) {
          updateRecordingState(RecordingState.idle);
        }
        break;

      case ConversationState.connecting:
        // Keep current recording state during connection
        break;

      case ConversationState.processing:
        // Keep current recording state during processing
        break;
    }
  }

  // Helper methods for state queries
  bool get canRecord =>
      _isConnected &&
      (_conversationState == ConversationState.idle ||
          _conversationState == ConversationState.userSpeaking);

  bool get shouldPauseRecording =>
      _conversationState == ConversationState.agentSpeaking;

  bool get isInActiveConversation =>
      _isConnected &&
      _conversationState != ConversationState.disconnected &&
      _conversationState != ConversationState.error;

  // Get time since last state change
  Duration? get timeSinceLastStateChange {
    if (_lastStateChange == null) return null;
    return DateTime.now().difference(_lastStateChange!);
  }

  // Cleanup
  void dispose() {
    debugPrint('🔄 Disposing ConversationStateManager');

    _conversationStateController.close();
    _recordingStateController.close();
    _connectionStatusController.close();
    _errorController.close();
    _vadScoreController.close();
  }

  // Reset all states for new conversation
  void reset() {
    debugPrint('🔄 Resetting all conversation states');

    _isInterrupting = false;
    _lastStateChange = null;
    _currentVadScore = 0.0;
    _lastError = null;

    updateConversationState(ConversationState.disconnected);
    updateRecordingState(RecordingState.idle);
    updateConnectionStatus(false);
  }

  // Advanced state management for debugging
  Map<String, dynamic> getStateSnapshot() {
    return {
      'conversationState': _conversationState.toString(),
      'recordingState': _recordingState.toString(),
      'isConnected': _isConnected,
      'isInterrupting': _isInterrupting,
      'vadScore': _currentVadScore,
      'lastError': _lastError,
      'timeSinceLastChange': timeSinceLastStateChange?.inMilliseconds,
      'canRecord': canRecord,
      'shouldPauseRecording': shouldPauseRecording,
      'isInActiveConversation': isInActiveConversation,
    };
  }

  void logCurrentState() {
    final snapshot = getStateSnapshot();
    debugPrint('📊 Current state snapshot: $snapshot');
  }
}
