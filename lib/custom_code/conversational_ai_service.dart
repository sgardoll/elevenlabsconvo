import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:dart_lame/dart_lame.dart';
import 'package:permission_handler/permission_handler.dart';
import '/custom_code/actions/index.dart'; // Imports custom actions

enum ConversationState {
  idle,
  connecting,
  connected,
  recording,
  playing,
  error
}

class ConversationMessage {
  final String type;
  final String content;
  final DateTime timestamp;
  final String? conversationId;

  ConversationMessage({
    required this.type,
    required this.content,
    required this.timestamp,
    this.conversationId,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'content': content,
        'timestamp': timestamp.millisecondsSinceEpoch,
        if (conversationId != null) 'conversation_id': conversationId,
      };
}

class ConversationalAIService {
  static final ConversationalAIService _instance =
      ConversationalAIService._internal();
  factory ConversationalAIService() => _instance;
  ConversationalAIService._internal();

  // Core components
  WebSocketChannel? _channel;
  final AudioRecorder _recorder = AudioRecorder();

  // ENHANCED AUDIO SYSTEM FOR iOS/Android COMPATIBILITY
  final AudioPlayer _player = AudioPlayer();
  late ConcatenatingAudioSource _playlist;
  final List<String> _tempFilePaths = [];

  // AUDIO CHUNK SEQUENCING FOR ANDROID
  final Map<int, Uint8List> _audioChunkBuffer = {};
  int _expectedAudioSequence = 0;
  Timer? _audioPlaybackTimer;

  // iOS AUDIO SESSION MANAGEMENT
  bool _iosAudioSessionActive = false;
  Timer? _iosAudioSessionTimer;

  // Configuration
  String _agentId = '';
  String _endpoint = '';
  String? _conversationId;

  // Enhanced state management to prevent infinite loops
  bool _isRecording = false;
  bool _isAgentSpeaking = false;
  bool _isConnected = false;
  bool _isDisposing = false;
  bool _isInitializing = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  bool _recordingPaused = false;
  int _tempFileCounter = 0;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _currentIndexSubscription;

  // CRITICAL: Permanent disposal flag to prevent runaway services
  bool _permanentlyDisposed = false;

  // CRITICAL FIX: Audio source management
  bool _isSettingAudioSource = false;
  bool _audioSourceInitialized = false;

  // SMOOTH PLAYBACK: Audio queue management
  final List<String> _audioQueue = [];
  bool _isProcessingQueue = false;

  // INFINITE LOOP PREVENTION SYSTEM
  DateTime? _lastInitializationAttempt;
  int _initializationAttempts = 0;
  static const int _maxInitializationAttempts = 3;
  static const int _initializationCooldownMs = 5000;
  bool _preventInfiniteLoops = true;

  // Enhanced interruption state management
  bool _isInterrupted = false;
  DateTime? _lastInterruptionTime;
  String _currentAudioSessionId = '';
  static const int _audioChunkGracePeriodMs = 500;

  // Enhanced turn detection
  double _lastVadScore = 0.0;
  double _vadThreshold = 0.5;
  int _consecutiveHighVadCount = 0;
  Timer? _vadMonitorTimer;

  // Advanced VAD filtering
  List<double> _vadScoreHistory = [];
  static const int _vadHistoryLength = 5;
  double _vadBaselineScore = 0.0;
  bool _vadCalibrated = false;

  // ENHANCED FEEDBACK PREVENTION SYSTEM
  bool _recordingPausedForAgent = false;
  Timer? _recordingResumeTimer;
  DateTime? _agentSpeechStartTime;
  static const int _rapidResumeWindowMs = 200;

  // Audio direction detection
  List<double> _recentAudioLevels = [];
  static const int _audioLevelHistoryLength = 10;
  double _baselineAudioLevel = 0.0;

  // Enhanced echo cancellation
  bool _echoCancellationActive = false;
  DateTime? _lastAgentAudioTime;
  static const int _echoSuppressionMs =
      1200; // Increased for better feedback prevention

  // Audio session correlation
  String _lastPlayedAudioSignature = '';
  Map<String, DateTime> _audioSignatureHistory = {};

  // ENHANCED SESSION ISOLATION
  Map<String, List<String>> _sessionAudioSignatures = {};
  Map<String, DateTime> _sessionStartTimes = {};
  String _currentConversationSessionId = '';
  static const int _maxSessionsInMemory = 5;

  // Cross-session contamination prevention
  Set<String> _activeAudioSessions = {};
  Map<String, String> _sessionToConversationMapping = {};
  DateTime? _lastSessionCleanup;
  static const int _sessionCleanupIntervalMs = 30000;

  // Hardware-specific optimizations
  String _deviceAudioProfile = 'default';
  Map<String, dynamic> _deviceSpecificSettings = {};

  // Echo cancellation layers
  bool _hardwareEchoCancellationActive = false;
  bool _softwareEchoCancellationActive = false;
  bool _adaptiveEchoCancellationActive = false;

  // Hardware-specific echo parameters
  int _deviceSpecificEchoSuppressionMs = 1200; // Increased default
  double _deviceSpecificVadThreshold =
      0.6; // Increased for better feedback prevention
  double _deviceSpecificAudioLevelThreshold = 0.2; // Increased sensitivity

  // Audio device characteristics
  bool _isHeadphonesConnected = false;
  bool _isBluetoothAudio = false;
  bool _isBuiltInSpeaker = true;
  String _audioDeviceType = 'builtin';

  // Adaptive echo suppression
  List<double> _echoLevelHistory = [];
  double _adaptiveEchoThreshold = 0.2; // Increased for better prevention
  int _echoDetectionCount = 0;
  static const int _echoHistoryLength = 20;

  // ENHANCED AUDIO DIRECTION DETECTION & FEEDBACK LOOP PREVENTION
  List<double> _inputAudioLevelHistory = [];
  List<double> _outputAudioLevelHistory = [];
  static const int _audioDirectionHistoryLength = 15;

  // Feedback loop detection
  int _feedbackLoopDetectionCount = 0;
  bool _feedbackLoopActive = false;
  DateTime? _lastFeedbackDetection;
  static const int _feedbackCooldownMs = 5000; // Increased cooldown

  // Audio correlation analysis
  List<String> _recentOutputSignatures = [];
  List<String> _recentInputSignatures = [];
  double _audioCorrelationThreshold =
      0.6; // Lowered for more aggressive detection

  // Real-time feedback prevention
  bool _emergencyFeedbackPrevention = false;
  int _consecutiveFeedbackDetections = 0;
  Timer? _feedbackPreventionTimer;

  // Audio flow monitoring
  double _inputToOutputRatio = 0.0;
  bool _unnaturalAudioFlow = false;

  // Reactive streams for UI
  final _conversationController =
      StreamController<ConversationMessage>.broadcast();
  final _stateController = StreamController<ConversationState>.broadcast();
  final _recordingController = StreamController<bool>.broadcast();
  final _connectionController = StreamController<String>.broadcast();

  // Public streams
  Stream<ConversationMessage> get conversationStream =>
      _conversationController.stream;
  Stream<ConversationState> get stateStream => _stateController.stream;
  Stream<bool> get recordingStream => _recordingController.stream;
  Stream<String> get connectionStream => _connectionController.stream;

  // Getters
  bool get isRecording => _isRecording;
  bool get isAgentSpeaking => _isAgentSpeaking;
  bool get isConnected => _isConnected;
  bool get isDisposing => _isDisposing;
  bool get isInterrupted => _isInterrupted;
  String get currentAudioSessionId => _currentAudioSessionId;
  ConversationState get currentState => _getCurrentState();

  // INFINITE LOOP PREVENTION METHODS
  bool _canAttemptInitialization() {
    if (!_preventInfiniteLoops) return true;

    final now = DateTime.now();

    // Check if we're within cooldown period
    if (_lastInitializationAttempt != null) {
      final timeSinceLastAttempt =
          now.difference(_lastInitializationAttempt!).inMilliseconds;
      if (timeSinceLastAttempt < _initializationCooldownMs) {
        debugPrint(
            '🔄 Initialization blocked - still in cooldown period (${_initializationCooldownMs - timeSinceLastAttempt}ms remaining)');
        return false;
      }
    }

    // Check if we've exceeded max attempts recently
    if (_initializationAttempts >= _maxInitializationAttempts) {
      debugPrint(
          '🔄 Initialization blocked - max attempts reached ($_initializationAttempts/$_maxInitializationAttempts)');
      return false;
    }

    return true;
  }

  void _recordInitializationAttempt() {
    _lastInitializationAttempt = DateTime.now();
    _initializationAttempts++;

    // Reset attempts counter after successful initialization or timeout
    Timer(Duration(milliseconds: _initializationCooldownMs), () {
      _initializationAttempts = 0;
    });
  }

  void _resetInitializationState() {
    _initializationAttempts = 0;
    _lastInitializationAttempt = null;
    _isInitializing = false;
  }

  // Get or refresh signed URL if needed
  Future<String?> _getSignedUrl() async {
    // Check if we have a valid cached signed URL
    if (!FFAppState().isSignedUrlExpired &&
        FFAppState().cachedSignedUrl.isNotEmpty) {
      debugPrint('🔐 Using cached signed URL');
      return FFAppState().cachedSignedUrl;
    }

    // Fetch new signed URL
    debugPrint('🔐 Fetching new signed URL');
    final signedUrl = await getSignedUrl(_agentId, _endpoint);

    if (signedUrl != null) {
      // Cache the signed URL with 15-minute expiration
      FFAppState().update(() {
        FFAppState().cachedSignedUrl = signedUrl;
        FFAppState().signedUrlExpirationTime =
            DateTime.now().add(Duration(minutes: 15));
      });
      debugPrint('🔐 Signed URL cached successfully');
      return signedUrl;
    } else {
      debugPrint('❌ Failed to obtain signed URL');
      return null;
    }
  }

  Future<String> initialize(
      {required String agentId, required String endpoint}) async {
    debugPrint(
        '🚀 Initializing Consolidated Conversational AI Service with Signed URLs');

    // CRITICAL FIX: Prevent initialization after permanent disposal
    if (_permanentlyDisposed) {
      debugPrint('🚫 Service permanently disposed - cannot reinitialize');
      return 'error: Service permanently disposed';
    }

    // INFINITE LOOP PREVENTION
    if (!_canAttemptInitialization()) {
      return 'error: Initialization blocked to prevent infinite loops';
    }

    if (_isInitializing) {
      debugPrint('🔄 Initialization already in progress');
      return 'error: Initialization already in progress';
    }

    _isInitializing = true;
    _recordInitializationAttempt();

    if (_agentId == agentId && _endpoint == endpoint && _isConnected) {
      debugPrint('🔌 Service already initialized and connected');
      _isInitializing = false;
      return 'success';
    }

    debugPrint(
        '🔌 Initializing Conversational AI Service v3.0 with Enhanced Audio Support');
    _isDisposing = false;
    _agentId = agentId;
    _endpoint = endpoint;

    try {
      // iOS/Android specific audio permissions
      if (Platform.isIOS) {
        await _requestiOSAudioPermissions();
      } else if (Platform.isAndroid) {
        await _requestAndroidAudioPermissions();
      }

      // Initialize audio components with platform-specific settings
      await _initializeAudioSystem();

      await _connect();

      FFAppState().update(() {
        FFAppState().wsConnectionState = 'connected';
        FFAppState().elevenLabsAgentId = agentId;
        FFAppState().endpoint = endpoint;
      });

      _resetInitializationState();
      return 'success';
    } catch (e) {
      debugPrint('❌ Error initializing service: $e');
      _isInitializing = false;
      return 'error: ${e.toString()}';
    }
  }

  // iOS AUDIO PERMISSION AND SESSION MANAGEMENT
  Future<void> _requestiOSAudioPermissions() async {
    debugPrint('🍎 Setting up iOS audio permissions and session');

    try {
      // Request microphone permission
      final microphoneStatus = await Permission.microphone.request();
      debugPrint('🍎 iOS microphone permission: $microphoneStatus');

      // iOS doesn't need explicit storage permissions for app cache
      debugPrint('🍎 iOS audio setup complete');
    } catch (e) {
      debugPrint('⚠️ iOS audio permission setup failed: $e');
    }
  }

  // ANDROID AUDIO PERMISSION AND OPTIMIZATION
  Future<void> _requestAndroidAudioPermissions() async {
    debugPrint('🤖 Setting up Android audio permissions');

    try {
      // Request microphone permission
      final microphoneStatus = await Permission.microphone.request();

      // Request audio permissions for Android 13+
      final audioStatus = await Permission.audio.request();

      // Request media library access
      var mediaAudioStatus = PermissionStatus.granted;
      try {
        mediaAudioStatus = await Permission.mediaLibrary.request();
      } catch (e) {
        debugPrint('⚠️ Media library permission not available: $e');
      }

      debugPrint(
          '🤖 Android permissions - Microphone: $microphoneStatus, Audio: $audioStatus, Media: $mediaAudioStatus');

      // Configure Android-specific audio optimizations
      await _configureAndroidAudioOptimizations();
    } catch (e) {
      debugPrint('⚠️ Android audio permission setup failed: $e');
    }
  }

  // ANDROID AUDIO OPTIMIZATION
  Future<void> _configureAndroidAudioOptimizations() async {
    debugPrint('🤖 Configuring Android audio optimizations');

    // Set Android-specific audio parameters
    _deviceSpecificEchoSuppressionMs =
        1500; // Longer echo suppression for Android
    _deviceSpecificVadThreshold = 0.7; // Higher VAD threshold for Android
    _deviceSpecificAudioLevelThreshold = 0.25; // Higher audio level threshold

    // Enable all echo cancellation layers for Android
    _hardwareEchoCancellationActive = true;
    _softwareEchoCancellationActive = true;
    _adaptiveEchoCancellationActive = true;

    debugPrint('🤖 Android audio optimizations applied');
  }

  // CRITICAL FIX: Configure Android audio focus for media playback
  Future<void> _configureAndroidAudioFocus() async {
    debugPrint('🤖 Configuring Android audio focus for media playback');

    try {
      // Ensure the audio player is properly configured for audible playback
      // The volume setting should be sufficient for most audio routing issues
      await _player.setVolume(1.0);
      debugPrint(
          '🤖 Android audio focus configuration completed (volume-based)');
    } catch (e) {
      debugPrint('❌ Error configuring Android audio: $e');
      // Continue anyway - this is not critical
    }
  }

  // ENHANCED AUDIO SYSTEM INITIALIZATION
  Future<void> _initializeAudioSystem() async {
    debugPrint('🔊 Initializing enhanced audio system');

    _playlist = ConcatenatingAudioSource(children: []);

    // Cancel previous subscriptions to prevent race conditions
    await _playerStateSubscription?.cancel();
    await _currentIndexSubscription?.cancel();

    // CRITICAL FIX: Set volume to ensure audio is audible
    await _player.setVolume(1.0);
    debugPrint('🔊 Audio volume set to maximum (1.0)');

    // Platform-specific audio configuration
    if (Platform.isIOS) {
      await _initializeiOSAudioSession();
    } else if (Platform.isAndroid) {
      await _configureAndroidAudioFocus();
    }

    // Listen for player state changes (but don't auto-reset on completion)
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      debugPrint('🔊 Player state changed: ${state.processingState}');

      // CRITICAL FIX: Don't auto-reset on completion since we're using a queue system
      // The queue processor will handle cleanup when all chunks are done
      if (state.processingState == ProcessingState.completed) {
        debugPrint('🔊 Audio playback completed (queue will handle cleanup)');
      }

      // iOS: Ensure audio session remains active during playback
      if (Platform.isIOS && state.playing) {
        _maintainiOSAudioSession();
      }
    });

    // Listen for track changes to manage audio chunk sequencing
    _currentIndexSubscription = _player.currentIndexStream.listen((index) {
      if (index != null && index > 0) {
        final targetIndex = index - 1;
        if (targetIndex >= 0 && targetIndex < _tempFilePaths.length) {
          final fileToDelete = _tempFilePaths[targetIndex];
          _deleteTempFile(fileToDelete);
          debugPrint('🗑️ Cleaned up audio file at index $targetIndex');
        }
      }
    });

    debugPrint('🔊 Audio system initialization complete');
  }

  // iOS AUDIO SESSION MANAGEMENT
  Future<void> _initializeiOSAudioSession() async {
    debugPrint('🍎 Initializing iOS audio session');

    try {
      // iOS audio session will be managed by just_audio
      // but we'll track its state for optimization
      _iosAudioSessionActive = true;

      // Set up timer to maintain iOS audio session
      _iosAudioSessionTimer?.cancel();
      _iosAudioSessionTimer = Timer.periodic(Duration(seconds: 30), (timer) {
        if (_isAgentSpeaking) {
          _maintainiOSAudioSession();
        }
      });

      debugPrint('🍎 iOS audio session initialized');
    } catch (e) {
      debugPrint('⚠️ iOS audio session initialization failed: $e');
    }
  }

  void _maintainiOSAudioSession() {
    if (Platform.isIOS && !_iosAudioSessionActive) {
      debugPrint('🍎 Reactivating iOS audio session');
      _iosAudioSessionActive = true;
    }
  }

  // ENHANCED AUDIO PLAYBACK WITH CHUNK SEQUENCING
  Future<void> _playAudio(String base64Audio) async {
    try {
      // Check for interruption state - reject stale audio chunks
      if (_isInterrupted && _lastInterruptionTime != null) {
        final timeSinceInterruption =
            DateTime.now().difference(_lastInterruptionTime!).inMilliseconds;
        if (timeSinceInterruption < _audioChunkGracePeriodMs) {
          debugPrint(
              '🔊 Ignoring stale audio chunk (${timeSinceInterruption}ms since interruption)');
          return;
        }
      }

      if (!_isAgentSpeaking) {
        // Start new audio session with enhanced setup
        _currentAudioSessionId = _generateAudioSessionId();
        _isAgentSpeaking = true;
        _isInterrupted = false;
        _lastInterruptionTime = null;
        _expectedAudioSequence = 0; // Reset audio sequencing

        // iOS: Ensure audio session is active
        if (Platform.isIOS) {
          _maintainiOSAudioSession();
        }

        // SMART RECORDING PAUSE: Enhanced feedback prevention
        _agentSpeechStartTime = DateTime.now();
        _lastAgentAudioTime = DateTime.now();
        await _pauseRecordingForAgent();
        _stateController.add(ConversationState.playing);

        // SIMPLIFIED: Clear old files and prepare for direct playback
        await _clearPlaylistAndFiles();

        debugPrint(
            '🔊 Started new direct audio session ${_currentAudioSessionId} (Platform: ${Platform.operatingSystem})');

        // Set volume to maximum for direct playback
        await _player.setVolume(1.0);
        debugPrint('🔊 Audio volume set to maximum for direct playback');
      }

      final audioBytes = base64Decode(base64Audio);
      if (audioBytes.length < 10) return;

      // Update last agent audio time for enhanced echo suppression
      _lastAgentAudioTime = DateTime.now();

      // Enhanced audio signature generation for feedback detection
      final audioSignature = _generateAudioSignature(audioBytes);
      _lastPlayedAudioSignature = audioSignature;
      _audioSignatureHistory[audioSignature] = DateTime.now();

      // SESSION-AWARE SIGNATURE TRACKING
      if (_currentConversationSessionId.isNotEmpty) {
        _sessionAudioSignatures[_currentConversationSessionId] ??= [];
        _sessionAudioSignatures[_currentConversationSessionId]!
            .add(audioSignature);

        final sessionSigs =
            _sessionAudioSignatures[_currentConversationSessionId]!;
        if (sessionSigs.length > 50) {
          sessionSigs.removeRange(0, sessionSigs.length - 50);
        }
      }

      // Track output signatures for enhanced correlation analysis
      _recentOutputSignatures.add(audioSignature);
      if (_recentOutputSignatures.length > 15) {
        // Increased history for better detection
        _recentOutputSignatures.removeAt(0);
      }

      // Enhanced audio level tracking
      final audioLevel = _calculateAudioLevel(audioBytes);
      _trackOutputAudioLevel(audioLevel);
      _cleanOldAudioSignatures();

      // COMPLETELY REDESIGNED: Direct audio playback for both platforms
      if (Platform.isAndroid) {
        await _handleAndroidAudioDirect(audioBytes);
      } else {
        await _handleiOSAudioDirect(audioBytes);
      }
    } catch (e) {
      debugPrint('❌ Error playing audio: $e');

      // Platform-specific error recovery
      if (Platform.isIOS) {
        debugPrint('🍎 Attempting iOS audio recovery');
        await _recoveriOSAudio();
      } else {
        debugPrint('🤖 Attempting Android audio recovery');
        await _recoverAndroidAudio();
      }
    }
  }

  // SIMPLIFIED ANDROID AUDIO: Direct file playback
  Future<void> _handleAndroidAudioDirect(Uint8List audioBytes) async {
    debugPrint('🤖 Processing Android audio chunk directly');

    try {
      await _playAudioChunkDirectly(audioBytes);
      debugPrint('🤖 Android direct audio playback initiated');
    } catch (e) {
      debugPrint('❌ Android direct audio failed: $e');
      await _recoverAndroidAudio();
    }
  }

  // SIMPLIFIED iOS AUDIO: Direct file playback
  Future<void> _handleiOSAudioDirect(Uint8List audioBytes) async {
    debugPrint('🍎 Processing iOS audio chunk directly');

    try {
      await _playAudioChunkDirectly(audioBytes);
      debugPrint('🍎 iOS direct audio playback initiated');
    } catch (e) {
      debugPrint('❌ iOS direct audio failed: $e');
      await _recoveriOSAudio();
    }
  }

  // IMPROVED: Smooth audio playback with queue system
  Future<void> _playAudioChunkDirectly(Uint8List audioBytes) async {
    try {
      // Create audio file
      final audioFileBytes = await _createAudioFile(audioBytes);
      final tempFile = await _createTempFile(audioFileBytes);
      _tempFilePaths.add(tempFile.path);

      debugPrint(
          '🔊 Adding audio file to queue: ${tempFile.path} (${audioBytes.length} bytes)');

      // Add to queue for smooth playback
      _audioQueue.add(tempFile.path);

      // Start processing queue if not already processing
      if (!_isProcessingQueue) {
        _processAudioQueue();
      }
    } catch (e) {
      debugPrint('❌ Audio file preparation failed: $e');
      rethrow;
    }
  }

  // Process audio queue for smooth playback
  Future<void> _processAudioQueue() async {
    if (_isProcessingQueue) return;

    _isProcessingQueue = true;
    debugPrint('🔊 Starting smooth audio queue processing');

    try {
      while (_audioQueue.isNotEmpty && _isAgentSpeaking) {
        final audioPath = _audioQueue.removeAt(0);

        debugPrint('🔊 Playing queued audio: $audioPath');

        // Set volume to maximum
        await _player.setVolume(1.0);

        // Play the file
        await _player.setFilePath(audioPath);
        await _player.play();

        // Wait for this chunk to finish before playing next
        await _waitForPlaybackCompletion();

        // Small delay between chunks for smooth transition
        await Future.delayed(Duration(milliseconds: 50));
      }

      debugPrint('🔊 Audio queue processing completed');

      // CRITICAL FIX: Only reset agent state after queue is completely empty
      // and we're sure all audio has been played
      if (_audioQueue.isEmpty) {
        debugPrint('🔊 Queue empty - scheduling cleanup after brief delay');
        await Future.delayed(
            Duration(milliseconds: 200)); // Allow final cleanup

        if (_isAgentSpeaking) {
          debugPrint('🔊 Queue processing complete - resetting agent state');
          _resetAgentSpeakingState();
        }
      }
    } catch (e) {
      debugPrint('❌ Audio queue processing failed: $e');
    } finally {
      _isProcessingQueue = false;
    }
  }

  // Wait for current audio to finish playing (without interfering with file management)
  Future<void> _waitForPlaybackCompletion() async {
    final completer = Completer<void>();

    StreamSubscription? subscription;
    subscription = _player.playerStateStream.listen((state) {
      debugPrint('🔊 Queue waiting - player state: ${state.processingState}');

      if (state.processingState == ProcessingState.completed ||
          state.processingState == ProcessingState.idle) {
        debugPrint('🔊 Audio chunk completed - continuing queue');
        subscription?.cancel();
        completer.complete();
      }
    });

    return completer.future;
  }

  // iOS AUDIO RECOVERY
  Future<void> _recoveriOSAudio() async {
    debugPrint('🍎 Attempting iOS audio recovery');

    try {
      // Stop current playback
      await _player.stop();

      // Reinitialize iOS audio session
      await _initializeiOSAudioSession();

      // Clear and reset playlist
      await _playlist.clear();
      _tempFilePaths.clear();

      // Reset audio state
      _isAgentSpeaking = false;
      _stateController.add(ConversationState.connected);

      debugPrint('🍎 iOS audio recovery completed');
    } catch (e) {
      debugPrint('❌ iOS audio recovery failed: $e');
    }
  }

  // ANDROID AUDIO RECOVERY
  Future<void> _recoverAndroidAudio() async {
    debugPrint('🤖 Attempting Android audio recovery');

    try {
      // Clear audio chunk buffer
      _audioChunkBuffer.clear();
      _expectedAudioSequence = 0;

      // Stop current playback
      await _player.stop();

      // Clear and reset playlist
      await _playlist.clear();
      _tempFilePaths.clear();

      // Reset audio state
      _isAgentSpeaking = false;
      _stateController.add(ConversationState.connected);

      debugPrint('🤖 Android audio recovery completed');
    } catch (e) {
      debugPrint('❌ Android audio recovery failed: $e');
    }
  }

  void _resetAgentSpeakingState() async {
    debugPrint(
        '🔊 Resetting agent speaking state (Session: $_currentAudioSessionId, Platform: ${Platform.operatingSystem})');

    _isAgentSpeaking = false;
    _recordingPaused = false;

    // Reset interruption state when audio naturally completes
    _isInterrupted = false;
    _lastInterruptionTime = null;
    _currentAudioSessionId = '';
    _agentSpeechStartTime = null;
    _lastAgentAudioTime = null;

    // CRITICAL FIX: Reset audio source state
    _audioSourceInitialized = false;
    _isSettingAudioSource = false;

    // SMOOTH PLAYBACK: Clear audio queue
    _audioQueue.clear();
    _isProcessingQueue = false;

    // Clear audio chunk buffer for Android
    if (Platform.isAndroid) {
      _audioChunkBuffer.clear();
      _expectedAudioSequence = 0;
    }

    // iOS: Deactivate audio session timer
    if (Platform.isIOS) {
      _iosAudioSessionActive = false;
    }

    // CONVERSATION END: Properly stop player to prevent background activity
    try {
      await _player.stop();
      debugPrint('🔊 Audio player stopped to prevent background activity');
    } catch (e) {
      debugPrint('⚠️ Error stopping player: $e');
    }

    // SMART RECORDING RESUME: Enhanced feedback prevention
    await _resumeRecordingAfterAgent();

    _stateController.add(
        _isConnected ? ConversationState.connected : ConversationState.idle);

    // Platform-specific cleanup delay
    final cleanupDelay = Platform.isIOS
        ? Duration(milliseconds: 400)
        : Duration(milliseconds: 300);
    await Future.delayed(cleanupDelay);
    await _clearPlaylistAndFiles();
  }

  // Public method to manually trigger interruption (enhanced for better reliability)
  Future<void> triggerInterruption() async {
    debugPrint(
        '🔊 Manual interruption triggered by user (Platform: ${Platform.operatingSystem})');
    await _handleUserInterruption();
  }

  // Generate unique audio session ID
  String _generateAudioSessionId() {
    final sessionId =
        'audio_session_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}_${Platform.operatingSystem}';

    // SESSION ISOLATION: Associate audio session with conversation session
    if (_currentConversationSessionId.isNotEmpty) {
      _sessionToConversationMapping[sessionId] = _currentConversationSessionId;
      debugPrint(
          '🔊 Audio session $sessionId mapped to conversation $_currentConversationSessionId');
    }

    return sessionId;
  }

  // Generate unique conversation session ID
  String _generateSessionId() {
    return 'session_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(10000)}_${Platform.operatingSystem}';
  }

  // ENHANCED USER INTERRUPTION HANDLING
  Future<void> _handleUserInterruption() async {
    debugPrint(
        '🔊 User interrupted agent - enhanced stopping (Session: $_currentAudioSessionId, Platform: ${Platform.operatingSystem})');

    // Set interruption state immediately
    _isInterrupted = true;
    _lastInterruptionTime = DateTime.now();

    if (_isAgentSpeaking) {
      // Platform-specific interruption handling
      if (Platform.isAndroid) {
        // Android: Clear buffer and reset sequence
        _audioChunkBuffer.clear();
        _expectedAudioSequence = 0;
      }

      if (Platform.isIOS) {
        // iOS: Deactivate audio session
        _iosAudioSessionActive = false;
      }

      // Stop audio playback immediately
      await _player.stop();

      // Clear the playlist to prevent further playback
      await _playlist.clear();

      // Reset speaking state
      _isAgentSpeaking = false;
      _recordingPaused = false;
      _recordingPausedForAgent = false;
      _agentSpeechStartTime = null;
      _lastAgentAudioTime = null;

      // RAPID RESUME: Resume recording immediately for user interruption
      await _resumeRecordingAfterAgent();

      // Update UI state
      _stateController.add(
          _isConnected ? ConversationState.connected : ConversationState.idle);

      // Clean up temp files safely
      _safeClearTempFiles();
      _tempFileCounter = 0;

      // Invalidate current audio session
      _currentAudioSessionId = '';

      // Invalidate conversation session on interruption
      _invalidateCurrentSession();

      debugPrint(
          '🔊 Audio session interrupted and cleaned up (Platform: ${Platform.operatingSystem})');
    }
  }

  // Handle VAD scores for enhanced turn detection with platform-specific optimization
  Future<void> _handleVadScore(Map<String, dynamic> data) async {
    final vadScore = data['vad_score_event']?['score'];
    if (vadScore != null) {
      _lastVadScore = vadScore.toDouble();

      // Enhanced VAD filtering during agent speech
      if (_isAgentSpeaking && !_isInterrupted) {
        // Skip VAD processing if recording is paused for agent (prevents feedback)
        if (_recordingPausedForAgent) {
          return;
        }

        // Enhanced echo suppression for VAD with platform-specific thresholds
        if (_lastAgentAudioTime != null) {
          final timeSinceAgentAudio =
              DateTime.now().difference(_lastAgentAudioTime!).inMilliseconds;
          final echoSuppressionTime = Platform.isAndroid
              ? _deviceSpecificEchoSuppressionMs
              : _echoSuppressionMs;

          if (timeSinceAgentAudio < echoSuppressionTime) {
            // Apply platform-specific VAD threshold during echo suppression
            final platformVadThreshold = Platform.isAndroid
                ? _deviceSpecificVadThreshold
                : _vadThreshold;

            if (_lastVadScore > platformVadThreshold * 1.5) {
              _consecutiveHighVadCount++;
              debugPrint(
                  '🎤 High VAD score detected during echo suppression (${Platform.operatingSystem}): $_lastVadScore (count: $_consecutiveHighVadCount)');

              // Platform-specific consecutive count requirements
              final requiredCount = Platform.isAndroid ? 3 : 2;
              if (_consecutiveHighVadCount >= requiredCount) {
                debugPrint(
                    '🎤 Sustained user speech detected (echo-filtered, ${Platform.operatingSystem}) - triggering interruption');
                await _handleUserInterruption();
                _consecutiveHighVadCount = 0;
              }
            } else {
              _consecutiveHighVadCount = 0;
            }
            return;
          }
        }

        // Normal VAD processing when not in echo suppression
        final platformVadThreshold =
            Platform.isAndroid ? _deviceSpecificVadThreshold : _vadThreshold;

        if (_lastVadScore > platformVadThreshold) {
          _consecutiveHighVadCount++;
          debugPrint(
              '🎤 High VAD score detected during agent speech (${Platform.operatingSystem}): $_lastVadScore (count: $_consecutiveHighVadCount)');

          // Platform-specific interruption sensitivity
          final interruptionThreshold = Platform.isAndroid ? 2 : 1;
          if (_consecutiveHighVadCount >= interruptionThreshold) {
            debugPrint(
                '🎤 Sustained user speech detected (${Platform.operatingSystem}) - triggering interruption');
            await _handleUserInterruption();
            _consecutiveHighVadCount = 0;
          }
        } else {
          _consecutiveHighVadCount = 0;
        }
      } else {
        _consecutiveHighVadCount = 0;
      }
    }
  }

  // SMART RECORDING PAUSE/RESUME METHODS
  Future<void> _pauseRecordingForAgent() async {
    if (_isRecording && !_recordingPausedForAgent) {
      debugPrint(
          '🔇 Pausing recording during agent speech to prevent feedback');
      _recordingPausedForAgent = true;
      _echoCancellationActive = true;

      // Don't actually stop the recording stream, just mark it as paused
      // This allows for rapid resume when user interrupts
      _recordingController.add(false);

      // Schedule a check to resume recording if agent speech is too long
      _recordingResumeTimer?.cancel();
      _recordingResumeTimer = Timer(Duration(milliseconds: 5000), () {
        if (_recordingPausedForAgent && _isAgentSpeaking) {
          debugPrint(
              '🔇 Agent speech too long, resuming recording for interruption detection');
          _resumeRecordingAfterAgent();
        }
      });
    }
  }

  Future<void> _resumeRecordingAfterAgent() async {
    if (_recordingPausedForAgent) {
      debugPrint('🔇 Resuming recording after agent speech');
      _recordingPausedForAgent = false;
      _echoCancellationActive = false;
      _recordingResumeTimer?.cancel();

      if (_isRecording) {
        _recordingController.add(true);
      }
    }
  }

  // AUDIO SIGNATURE DETECTION FOR FEEDBACK PREVENTION
  String _generateAudioSignature(Uint8List audioBytes) {
    // Generate a more robust hash of the audio data for feedback detection
    try {
      final digest = sha256.convert(audioBytes);
      return digest
          .toString()
          .substring(0, 16); // Use first 16 chars for efficiency
    } catch (e) {
      // Fallback to simple hash if crypto fails
      int hash = 0;
      for (int i = 0; i < audioBytes.length; i += 10) {
        hash = hash ^ audioBytes[i];
      }
      return hash.toString();
    }
  }

  void _cleanOldAudioSignatures() {
    final now = DateTime.now();
    _audioSignatureHistory
        .removeWhere((key, value) => now.difference(value).inSeconds > 10);
  }

  bool _isAudioFeedback(Uint8List audioChunk) {
    // ADVANCED SESSION-AWARE FEEDBACK DETECTION
    final signature = _generateAudioSignature(audioChunk);

    // Add to recent input signatures for correlation analysis
    _recentInputSignatures.add(signature);
    if (_recentInputSignatures.length > 10) {
      _recentInputSignatures.removeAt(0);
    }

    // Check against current session signatures
    if (_currentConversationSessionId.isNotEmpty) {
      final sessionSignatures =
          _sessionAudioSignatures[_currentConversationSessionId] ?? [];
      if (sessionSignatures.contains(signature)) {
        debugPrint('🔇 Session-specific audio feedback detected');
        return true;
      }
    }

    // Enhanced correlation-based feedback detection
    for (String outputSig in _recentOutputSignatures) {
      double correlation = _calculateSignatureCorrelation(signature, outputSig);
      if (correlation > _audioCorrelationThreshold) {
        debugPrint(
            '🔇 High correlation feedback detected (${correlation.toStringAsFixed(2)})');
        return true;
      }
    }

    // Check against global signature history
    if (_audioSignatureHistory.containsKey(signature)) {
      // Additional timing check for feedback
      final signatureTime = _audioSignatureHistory[signature]!;
      final timeDiff = DateTime.now().difference(signatureTime).inMilliseconds;
      if (timeDiff < 1000) {
        // Feedback within 1 second
        debugPrint('🔇 Temporal audio feedback detected (${timeDiff}ms)');
        return true;
      }
    }

    return false;
  }

  double _calculateSignatureCorrelation(String sig1, String sig2) {
    // Simple correlation based on signature similarity
    if (sig1.length != sig2.length) return 0.0;

    int matches = 0;
    for (int i = 0; i < sig1.length; i++) {
      if (sig1[i] == sig2[i]) matches++;
    }

    return matches / sig1.length;
  }

  // SESSION MANAGEMENT METHODS
  void _cleanupOldSessions() {
    final now = DateTime.now();

    // Only cleanup if enough time has passed
    if (_lastSessionCleanup != null &&
        now.difference(_lastSessionCleanup!).inMilliseconds <
            _sessionCleanupIntervalMs) {
      return;
    }

    // Remove sessions older than 5 minutes
    final sessionsToRemove = <String>[];

    _sessionStartTimes.forEach((sessionId, startTime) {
      if (now.difference(startTime).inMinutes > 5) {
        sessionsToRemove.add(sessionId);
      }
    });

    // Keep only the most recent sessions if we have too many
    if (_sessionStartTimes.length > _maxSessionsInMemory) {
      final sortedSessions = _sessionStartTimes.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      final sessionsToKeep =
          sortedSessions.skip(_maxSessionsInMemory).map((e) => e.key).toList();
      sessionsToRemove.addAll(sessionsToKeep);
    }

    // Remove old sessions
    for (final sessionId in sessionsToRemove) {
      _sessionStartTimes.remove(sessionId);
      _sessionAudioSignatures.remove(sessionId);
      _activeAudioSessions.remove(sessionId);

      // Remove audio session mappings
      _sessionToConversationMapping
          .removeWhere((key, value) => value == sessionId);

      debugPrint('🗑️ Cleaned up old session: $sessionId');
    }

    _lastSessionCleanup = now;
  }

  void _invalidateCurrentSession() {
    debugPrint(
        '🗑️ Invalidating current session: $_currentConversationSessionId');

    if (_currentConversationSessionId.isNotEmpty) {
      _activeAudioSessions.remove(_currentConversationSessionId);
      _sessionAudioSignatures[_currentConversationSessionId]?.clear();

      // Remove associated audio sessions
      _sessionToConversationMapping
          .removeWhere((key, value) => value == _currentConversationSessionId);
    }

    _currentConversationSessionId = '';
  }

  // HARDWARE-SPECIFIC AUDIO CONFIGURATION METHODS
  Future<void> _configureHardwareSpecificAudio() async {
    try {
      // Detect audio device characteristics
      await _detectAudioDeviceType();

      // Configure hardware-specific settings
      _configureDeviceSpecificSettings();

      // Enable appropriate echo cancellation layers
      _configureEchoCancellationLayers();

      debugPrint(
          '🔊 Hardware audio configuration complete: $_deviceAudioProfile');
    } catch (e) {
      debugPrint('⚠️ Error configuring hardware audio: $e');
      // Fallback to default settings
      _useDefaultAudioSettings();
    }
  }

  Future<void> _detectAudioDeviceType() async {
    // Note: In a real implementation, you would use platform-specific code
    // to detect actual hardware. For now, we'll use reasonable defaults.

    // Default assumptions for mobile devices
    _isBuiltInSpeaker = true;
    _isHeadphonesConnected = false;
    _isBluetoothAudio = false;
    _audioDeviceType = 'builtin';

    // Set device profile based on assumptions
    if (_isHeadphonesConnected) {
      _deviceAudioProfile = 'headphones';
    } else if (_isBluetoothAudio) {
      _deviceAudioProfile = 'bluetooth';
    } else {
      _deviceAudioProfile = 'builtin_speaker';
    }
  }

  void _configureDeviceSpecificSettings() {
    switch (_deviceAudioProfile) {
      case 'headphones':
        _deviceSpecificEchoSuppressionMs =
            400; // Less aggressive for headphones
        _deviceSpecificVadThreshold = 0.4;
        _deviceSpecificAudioLevelThreshold = 0.1;
        _hardwareEchoCancellationActive = false; // Headphones don't need it
        break;

      case 'bluetooth':
        _deviceSpecificEchoSuppressionMs =
            1200; // More aggressive for Bluetooth
        _deviceSpecificVadThreshold = 0.6;
        _deviceSpecificAudioLevelThreshold = 0.2;
        _hardwareEchoCancellationActive = true;
        break;

      case 'builtin_speaker':
      default:
        _deviceSpecificEchoSuppressionMs = 800; // Standard for built-in speaker
        _deviceSpecificVadThreshold = 0.5;
        _deviceSpecificAudioLevelThreshold = 0.15;
        _hardwareEchoCancellationActive = true;
        break;
    }

    _deviceSpecificSettings = {
      'echo_suppression_ms': _deviceSpecificEchoSuppressionMs,
      'vad_threshold': _deviceSpecificVadThreshold,
      'audio_level_threshold': _deviceSpecificAudioLevelThreshold,
      'hardware_echo_cancel': _hardwareEchoCancellationActive,
    };
  }

  void _configureEchoCancellationLayers() {
    // Layer 1: Hardware echo cancellation (if supported)
    _hardwareEchoCancellationActive =
        _deviceSpecificSettings['hardware_echo_cancel'] ?? true;

    // Layer 2: Software echo cancellation (always active)
    _softwareEchoCancellationActive = true;

    // Layer 3: Adaptive echo cancellation (for problematic devices)
    _adaptiveEchoCancellationActive = _deviceAudioProfile == 'bluetooth' ||
        _deviceAudioProfile == 'builtin_speaker';

    debugPrint(
        '🔊 Echo cancellation layers: HW=$_hardwareEchoCancellationActive, SW=$_softwareEchoCancellationActive, Adaptive=$_adaptiveEchoCancellationActive');
  }

  void _useDefaultAudioSettings() {
    _deviceAudioProfile = 'default';
    _deviceSpecificEchoSuppressionMs = 800;
    _deviceSpecificVadThreshold = 0.5;
    _deviceSpecificAudioLevelThreshold = 0.15;
    _hardwareEchoCancellationActive = true;
    _softwareEchoCancellationActive = true;
    _adaptiveEchoCancellationActive = true;
  }

  // ADVANCED ECHO DETECTION METHODS
  bool _isLikelyEcho(double audioLevel, int timeSinceAgentAudio) {
    // Update echo level history
    _echoLevelHistory.add(audioLevel);
    if (_echoLevelHistory.length > _echoHistoryLength) {
      _echoLevelHistory.removeAt(0);
    }

    // Calculate average recent echo levels
    double averageEchoLevel = 0.0;
    if (_echoLevelHistory.isNotEmpty) {
      averageEchoLevel =
          _echoLevelHistory.reduce((a, b) => a + b) / _echoLevelHistory.length;
    }

    // Echo detection logic
    bool isTemporalEcho = timeSinceAgentAudio < 200; // Very recent agent audio
    bool isLevelBasedEcho =
        audioLevel < averageEchoLevel * 1.2; // Similar to recent patterns
    bool isAdaptiveEcho =
        _adaptiveEchoCancellationActive && audioLevel < _adaptiveEchoThreshold;

    return isTemporalEcho && (isLevelBasedEcho || isAdaptiveEcho);
  }

  void _updateAdaptiveEchoThreshold() {
    // Adapt the echo threshold based on detection patterns
    if (_echoDetectionCount > 3) {
      _adaptiveEchoThreshold = math.min(_adaptiveEchoThreshold * 1.1, 0.3);
      debugPrint(
          '🔊 Adaptive echo threshold increased to: ${_adaptiveEchoThreshold.toStringAsFixed(3)}');
      _echoDetectionCount = 0;
    }

    // Reset threshold periodically to avoid being too restrictive
    if (_echoLevelHistory.length >= _echoHistoryLength) {
      double averageLevel =
          _echoLevelHistory.reduce((a, b) => a + b) / _echoLevelHistory.length;
      if (averageLevel < _adaptiveEchoThreshold * 0.5) {
        _adaptiveEchoThreshold = math.max(
            _deviceSpecificAudioLevelThreshold, _adaptiveEchoThreshold * 0.9);
        debugPrint(
            '🔊 Adaptive echo threshold decreased to: ${_adaptiveEchoThreshold.toStringAsFixed(3)}');
      }
    }
  }

  // ENHANCED AUDIO DIRECTION DETECTION & FEEDBACK PREVENTION METHODS
  void _analyzeAudioDirection(double audioLevel) {
    // Update input audio level history
    _inputAudioLevelHistory.add(audioLevel);
    if (_inputAudioLevelHistory.length > _audioDirectionHistoryLength) {
      _inputAudioLevelHistory.removeAt(0);
    }

    // Calculate input to output audio ratio
    if (_outputAudioLevelHistory.isNotEmpty &&
        _inputAudioLevelHistory.isNotEmpty) {
      double avgInput = _inputAudioLevelHistory.reduce((a, b) => a + b) /
          _inputAudioLevelHistory.length;
      double avgOutput = _outputAudioLevelHistory.reduce((a, b) => a + b) /
          _outputAudioLevelHistory.length;

      _inputToOutputRatio = avgOutput > 0 ? avgInput / avgOutput : 0.0;

      // Detect unnatural audio flow patterns
      _unnaturalAudioFlow = _inputToOutputRatio > 0.8 && avgInput > 0.1;
    }
  }

  void _trackOutputAudioLevel(double outputLevel) {
    // Track output audio levels for correlation analysis
    _outputAudioLevelHistory.add(outputLevel);
    if (_outputAudioLevelHistory.length > _audioDirectionHistoryLength) {
      _outputAudioLevelHistory.removeAt(0);
    }
  }

  bool _detectUnnaturalAudioFlow(double currentLevel) {
    // Check for rapid alternation between input and output
    if (_inputAudioLevelHistory.length < 5 ||
        _outputAudioLevelHistory.length < 5) {
      return false;
    }

    // Detect if current input closely matches recent output patterns
    double recentAvgOutput = _outputAudioLevelHistory
            .skip(_outputAudioLevelHistory.length - 3)
            .reduce((a, b) => a + b) /
        3;

    bool levelCorrelation = (currentLevel - recentAvgOutput).abs() < 0.05;
    bool rapidOscillation = _unnaturalAudioFlow && _inputToOutputRatio > 0.9;

    return levelCorrelation && rapidOscillation;
  }

  void _handleFeedbackDetection() {
    _feedbackLoopDetectionCount++;
    _consecutiveFeedbackDetections++;
    _lastFeedbackDetection = DateTime.now();

    debugPrint(
        '🔇 Feedback detection count: $_feedbackLoopDetectionCount, consecutive: $_consecutiveFeedbackDetections');

    // Enable emergency feedback prevention for severe cases
    if (_consecutiveFeedbackDetections >= 3) {
      _enableEmergencyFeedbackPrevention();
    }

    // Mark feedback loop as active
    if (_consecutiveFeedbackDetections >= 2) {
      _feedbackLoopActive = true;
      debugPrint('🔇 Feedback loop marked as active');
    }
  }

  void _enableEmergencyFeedbackPrevention() {
    debugPrint('🔇 EMERGENCY: Enabling aggressive feedback prevention');
    _emergencyFeedbackPrevention = true;

    // Cancel any existing timer
    _feedbackPreventionTimer?.cancel();

    // Disable emergency prevention after a timeout
    _feedbackPreventionTimer =
        Timer(Duration(milliseconds: _feedbackCooldownMs), () {
      _emergencyFeedbackPrevention = false;
      _consecutiveFeedbackDetections = 0;
      _feedbackLoopActive = false;
      debugPrint('🔇 Emergency feedback prevention disabled');
    });
  }

  void _resetFeedbackDetection() {
    _feedbackLoopDetectionCount = 0;
    _consecutiveFeedbackDetections = 0;
    _feedbackLoopActive = false;
    _emergencyFeedbackPrevention = false;
    _lastFeedbackDetection = null;
    _feedbackPreventionTimer?.cancel();

    // Clear audio direction history
    _inputAudioLevelHistory.clear();
    _outputAudioLevelHistory.clear();
    _recentInputSignatures.clear();
    _recentOutputSignatures.clear();

    _inputToOutputRatio = 0.0;
    _unnaturalAudioFlow = false;

    debugPrint('🔇 Feedback detection state reset');
  }

  // Enhanced audio level monitoring
  double _calculateAudioLevel(Uint8List audioChunk) {
    if (audioChunk.isEmpty) return 0.0;

    double sum = 0.0;
    for (int i = 0; i < audioChunk.length; i += 2) {
      if (i + 1 < audioChunk.length) {
        // Convert 16-bit PCM to amplitude
        int sample = (audioChunk[i + 1] << 8) | audioChunk[i];
        if (sample > 32767) sample -= 65536;
        sum += sample.abs();
      }
    }

    double average = sum / (audioChunk.length / 2);
    return average / 32767.0; // Normalize to 0-1 range
  }

  Future<void> _clearPlaylistAndFiles() async {
    await _player.stop();
    await _playlist.clear();
    _safeClearTempFiles();
    _tempFileCounter = 0;
  }

  /// Safely clears temporary files with race condition protection
  void _safeClearTempFiles() {
    // Create a copy of the paths to avoid concurrent modification
    final pathsCopy = List<String>.from(_tempFilePaths);
    _tempFilePaths.clear();

    // Delete files from the copy to prevent interference with ongoing operations
    for (final path in pathsCopy) {
      _deleteTempFile(path);
    }
    debugPrint('🗑️ Safely cleared ${pathsCopy.length} temporary audio files');
  }

  void _deleteTempFile(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
        debugPrint('🗑️ Deleted temp file: $path');
      }
    } catch (e) {
      debugPrint('⚠️ Could not delete temp file $path: $e');
    }
  }

  Future<Uint8List> _createAudioFile(Uint8List pcmData) async {
    // Use WAV format for all platforms to avoid dependency issues
    const int sampleRate = 16000;
    const int bitsPerSample = 16;
    const int channels = 1;
    final int dataSize = pcmData.length;
    final int fileSize = 44 + dataSize;
    final ByteData wavHeader = ByteData(44);
    wavHeader.setUint8(0, 0x52); // 'R'
    wavHeader.setUint8(1, 0x49); // 'I'
    wavHeader.setUint8(2, 0x46); // 'F'
    wavHeader.setUint8(3, 0x46); // 'F'
    wavHeader.setUint32(4, fileSize - 8, Endian.little);
    wavHeader.setUint8(8, 0x57); // 'W'
    wavHeader.setUint8(9, 0x41); // 'A'
    wavHeader.setUint8(10, 0x56); // 'V'
    wavHeader.setUint8(11, 0x45); // 'E'
    wavHeader.setUint8(12, 0x66); // 'f'
    wavHeader.setUint8(13, 0x6d); // 'm'
    wavHeader.setUint8(14, 0x74); // 't'
    wavHeader.setUint8(15, 0x20); // ' '
    wavHeader.setUint32(16, 16, Endian.little);
    wavHeader.setUint16(20, 1, Endian.little);
    wavHeader.setUint16(22, channels, Endian.little);
    wavHeader.setUint32(24, sampleRate, Endian.little);
    wavHeader.setUint32(
        28, sampleRate * channels * bitsPerSample ~/ 8, Endian.little);
    wavHeader.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
    wavHeader.setUint16(34, bitsPerSample, Endian.little);
    wavHeader.setUint8(36, 0x64); // 'd'
    wavHeader.setUint8(37, 0x61); // 'a'
    wavHeader.setUint8(38, 0x74); // 't'
    wavHeader.setUint8(39, 0x61); // 'a'
    wavHeader.setUint32(40, dataSize, Endian.little);
    final Uint8List wavFile = Uint8List(fileSize);
    wavFile.setRange(0, 44, wavHeader.buffer.asUint8List());
    wavFile.setRange(44, fileSize, pcmData);
    return wavFile;
  }

  Future<File> _createTempFile(Uint8List data) async {
    try {
      // Use app's cache directory which doesn't require storage permissions
      final dir = await getTemporaryDirectory();
      final extension = 'wav'; // Use WAV for all platforms
      final fileName = 'temp_audio_${_tempFileCounter++}.$extension';
      final file = File('${dir.path}/$fileName');

      // Ensure the directory exists
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      await file.writeAsBytes(data);
      debugPrint(
          '🗂️ Created temp audio file: ${file.path} (${data.length} bytes)');
      return file;
    } catch (e) {
      debugPrint('❌ Error creating temp file: $e');
      rethrow;
    }
  }

  Future<void> _connect() async {
    _stateController.add(ConversationState.connecting);
    _connectionController.add('connecting');

    // Reset interruption state on new connection
    _isInterrupted = false;
    _lastInterruptionTime = null;
    _currentAudioSessionId = '';

    // Reset audio isolation state
    _recordingPausedForAgent = false;
    _agentSpeechStartTime = null;
    _lastAgentAudioTime = null;
    _echoCancellationActive = false;
    _recentAudioLevels.clear();
    _baselineAudioLevel = 0.0;
    _audioSignatureHistory.clear();
    _lastPlayedAudioSignature = '';

    // Reset VAD calibration state
    _vadScoreHistory.clear();
    _vadBaselineScore = 0.0;
    _vadCalibrated = false;

    // Reset session isolation state
    _sessionAudioSignatures.clear();
    _sessionStartTimes.clear();
    _currentConversationSessionId = '';
    _activeAudioSessions.clear();
    _sessionToConversationMapping.clear();
    _lastSessionCleanup = null;

    // Reset hardware-specific state
    _echoLevelHistory.clear();
    _adaptiveEchoThreshold = 0.15;
    _echoDetectionCount = 0;
    _hardwareEchoCancellationActive = false;
    _softwareEchoCancellationActive = false;
    _adaptiveEchoCancellationActive = false;
    _deviceAudioProfile = 'default';
    _deviceSpecificSettings.clear();

    // Reset feedback detection state
    _resetFeedbackDetection();

    // Cancel any pending timers
    _recordingResumeTimer?.cancel();

    try {
      // Get signed URL for connection
      final signedUrl = await _getSignedUrl();
      if (signedUrl == null) {
        throw Exception('Failed to obtain signed URL');
      }

      final uri = Uri.parse(signedUrl);
      _channel = IOWebSocketChannel.connect(
        uri,
        headers: {
          'User-Agent': 'ElevenLabs-Flutter-Consolidated/2.0',
        },
      );
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );
      _sendInitialization();
      _isConnected = true;
      _reconnectAttempts = 0;
      _stateController.add(ConversationState.connected);
      _connectionController.add('connected');
      debugPrint(
          '🔌 Conversational AI Service connected successfully with clean state');
    } catch (e) {
      debugPrint('❌ Connection error: $e');
      _handleError(e);
    }
  }

  void _sendInitialization() {
    final initMessage = jsonEncode({
      'type': 'conversation_initiation_client_data',
      'conversation_config_override': {
        'agent': {
          'language': 'en',
          'turn_detection': {
            'type': 'server_vad',
            'threshold':
                0.5, // Increased threshold to reduce false positives from echo
            'silence_duration_ms':
                800, // Longer silence to prevent echo triggering
            'prefix_padding_ms':
                400, // More padding to ensure clean speech detection
            'suffix_padding_ms': 300,
            'create_new_conversation_on_interruption':
                false, // Prevent echo from creating new conversations
            'vad_window_size_ms':
                100 // Smaller window for more responsive detection
          }
        },
        'tts': {
          'model': 'eleven_turbo_v2_5',
          'voice_settings': {'stability': 0.8, 'similarity_boost': 0.7}
        },
        'audio': {
          'input_format': 'pcm_16000',
          'output_format': 'pcm_16000',
          'input_sample_rate': 16000,
          'output_sample_rate': 16000
        }
      },
      'conversation_config': {
        'modalities': ['audio'],
        'turn_detection': {
          'type': 'server_vad',
          'threshold': 0.5,
          'silence_duration_ms': 800
        }
      }
    });
    _channel!.sink.add(initMessage);
    debugPrint(
        '🔌 Initialization message sent with server-side turn detection');
  }

  Future<String> toggleRecording() async {
    if (_isRecording) {
      return await stopRecording();
    } else {
      return await startRecording();
    }
  }

  Future<String> startRecording() async {
    if (_isRecording || _isAgentSpeaking) {
      debugPrint(
          '⚠️ Cannot start recording - already recording or agent speaking');
      return 'error: Cannot start recording';
    }
    if (!_isConnected) {
      debugPrint('❌ Cannot start recording - not connected');
      return 'error: Not connected';
    }
    try {
      debugPrint('🎙️ Starting real-time recording...');
      final recordingStream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
          autoGain: true, // Additional audio optimization
        ),
      );
      _audioStreamSubscription = recordingStream.listen(
        _handleAudioChunk,
        onError: (error) => debugPrint('❌ Audio stream error: $error'),
        onDone: () => debugPrint('🎙️ Audio stream ended'),
      );
      _isRecording = true;
      _recordingController.add(true);
      _stateController.add(ConversationState.recording);
      FFAppState().update(() {
        FFAppState().isRecording = true;
      });
      debugPrint('🎙️ Recording started successfully');
      return 'success';
    } catch (e) {
      debugPrint('❌ Error starting recording: $e');
      return 'error: ${e.toString()}';
    }
  }

  Future<String> stopRecording() async {
    if (!_isRecording) {
      debugPrint('⚠️ Not currently recording');
      return 'error: Not recording';
    }
    try {
      debugPrint('🎙️ Stopping recording...');
      await _recorder.stop();
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      if (_isConnected) {
        _channel!.sink.add(jsonEncode({'type': 'user_turn_ended'}));
        await _sendUserActivity();
      }
      _isRecording = false;
      _recordingController.add(false);
      _stateController.add(
          _isConnected ? ConversationState.connected : ConversationState.idle);
      FFAppState().update(() {
        FFAppState().isRecording = false;
      });
      debugPrint('🎙️ Recording stopped successfully');
      return 'success';
    } catch (e) {
      debugPrint('❌ Error stopping recording: $e');
      return 'error: ${e.toString()}';
    }
  }

  Future<void> _handleAudioChunk(Uint8List audioChunk) async {
    if (!_isConnected) {
      return;
    }

    // Skip processing if recording is paused for agent speech
    if (_recordingPausedForAgent) {
      // Still check for strong interruption signals
      double audioLevel = _calculateAudioLevel(audioChunk);
      if (audioLevel > 0.4) {
        debugPrint('🎤 Strong user interruption detected - rapid resume');
        await _resumeRecordingAfterAgent();
        await _handleUserInterruption();
      }
      return;
    }

    // Calculate audio level for local monitoring
    double audioLevel = _calculateAudioLevel(audioChunk);

    // Update audio level history for baseline calculation
    _recentAudioLevels.add(audioLevel);
    if (_recentAudioLevels.length > _audioLevelHistoryLength) {
      _recentAudioLevels.removeAt(0);
    }

    // Calculate baseline audio level
    if (_recentAudioLevels.isNotEmpty) {
      _baselineAudioLevel = _recentAudioLevels.reduce((a, b) => a + b) /
          _recentAudioLevels.length;
    }

    // ENHANCED FEEDBACK LOOP DETECTION
    if (_isAudioFeedback(audioChunk)) {
      debugPrint('🔇 Audio feedback detected - ignoring chunk');
      _handleFeedbackDetection();
      return;
    }

    // Audio direction analysis
    _analyzeAudioDirection(audioLevel);

    // Real-time feedback loop prevention
    if (_emergencyFeedbackPrevention) {
      debugPrint('🔇 Emergency feedback prevention active - blocking audio');
      return;
    }

    // Check for unnatural audio flow patterns
    if (_detectUnnaturalAudioFlow(audioLevel)) {
      debugPrint('🔇 Unnatural audio flow detected - suspected feedback loop');
      _handleFeedbackDetection();
      return;
    }

    // MULTI-LAYER ECHO SUPPRESSION
    if (_lastAgentAudioTime != null) {
      final timeSinceAgentAudio =
          DateTime.now().difference(_lastAgentAudioTime!).inMilliseconds;

      // Layer 1: Time-based echo suppression
      if (timeSinceAgentAudio < _deviceSpecificEchoSuppressionMs) {
        // Layer 2: Audio level based suppression
        if (audioLevel < _adaptiveEchoThreshold) {
          debugPrint(
              '🔇 Multi-layer echo suppression active - ignoring low-level audio (${audioLevel.toStringAsFixed(3)} < ${_adaptiveEchoThreshold.toStringAsFixed(3)})');
          return;
        }

        // Layer 3: Adaptive echo detection
        if (_isLikelyEcho(audioLevel, timeSinceAgentAudio)) {
          debugPrint('🔇 Adaptive echo detection - ignoring suspected echo');
          _echoDetectionCount++;
          _updateAdaptiveEchoThreshold();
          return;
        }
      }
    }

    // Enhanced local interruption detection
    if (_isAgentSpeaking && !_isInterrupted && audioLevel > 0.15) {
      debugPrint(
          '🎤 High local audio level detected during agent speech: ${audioLevel.toStringAsFixed(3)}');

      // Trigger immediate interruption on strong local audio signal
      if (audioLevel > 0.3) {
        debugPrint(
            '🎤 Strong user audio detected - triggering immediate interruption');
        await _handleUserInterruption();
        return; // Don't send this chunk if we're interrupting
      }
    }

    // Send audio chunks to ElevenLabs with enhanced filtering
    try {
      final base64Audio = base64Encode(audioChunk);
      final audioMessage = jsonEncode({'user_audio_chunk': base64Audio});
      _channel!.sink.add(audioMessage);

      // Log high audio levels during agent speech for debugging
      if (_isAgentSpeaking && audioLevel > 0.1) {
        debugPrint(
            '🎤 User audio level during agent speech: ${audioLevel.toStringAsFixed(3)} (baseline: ${_baselineAudioLevel.toStringAsFixed(3)})');
      }
    } catch (e) {
      debugPrint('❌ Error sending audio chunk: $e');
    }
  }

  Future<void> _handleMessage(dynamic message) async {
    try {
      final jsonData = jsonDecode(message);
      final messageType = jsonData['type'] ?? 'unknown';
      switch (messageType) {
        case 'conversation_initiation_metadata':
          _handleConversationInit(jsonData);
          break;
        case 'user_transcript':
          _handleUserTranscript(jsonData);
          break;
        case 'agent_response':
          _handleAgentResponse(jsonData);
          break;
        case 'audio':
          _handleAudioResponse(jsonData);
          break;
        case 'vad_score':
          await _handleVadScore(jsonData);
          break;
        case 'interruption':
          await _handleInterruption(jsonData);
          break;
        case 'conversation_end':
        case 'conversation_ended':
        case 'session_end':
          _handleConversationEnd(jsonData);
          break;
        default:
          debugPrint('🔌 Received message type: $messageType');
      }
    } catch (e) {
      debugPrint('❌ Error handling message: $e');
    }
  }

  void _handleConversationInit(Map<String, dynamic> data) {
    _conversationId =
        data['conversation_initiation_metadata_event']?['conversation_id'];
    debugPrint('🔌 Conversation ID: $_conversationId');

    // ENHANCED SESSION ISOLATION: Initialize new conversation session
    _currentConversationSessionId = _conversationId ?? _generateSessionId();
    _sessionStartTimes[_currentConversationSessionId] = DateTime.now();
    _sessionAudioSignatures[_currentConversationSessionId] = [];
    _activeAudioSessions.add(_currentConversationSessionId);

    // Clean up old sessions to prevent memory bloat
    _cleanupOldSessions();

    debugPrint(
        '🔌 Session isolation initialized for conversation: $_currentConversationSessionId');

    final message = ConversationMessage(
      type: 'system',
      content: 'Conversational AI 2.0 session started with enhanced isolation',
      timestamp: DateTime.now(),
      conversationId: _conversationId,
    );
    _conversationController.add(message);
    _updateFFAppStateMessages(message);
  }

  void _handleUserTranscript(Map<String, dynamic> data) {
    final transcript = data['user_transcription_event']?['user_transcript'];
    if (transcript != null) {
      final message = ConversationMessage(
        type: 'user',
        content: transcript,
        timestamp: DateTime.now(),
      );
      _conversationController.add(message);
      _updateFFAppStateMessages(message);
      debugPrint('👤 User: $transcript');
    }
  }

  void _handleAgentResponse(Map<String, dynamic> data) {
    final response = data['agent_response_event']?['agent_response'];
    if (response != null) {
      final message = ConversationMessage(
        type: 'agent',
        content: response,
        timestamp: DateTime.now(),
      );
      _conversationController.add(message);
      _updateFFAppStateMessages(message);
      debugPrint('🤖 Agent: $response');
    }
  }

  void _handleAudioResponse(Map<String, dynamic> data) {
    final base64Audio = data['audio_event']?['audio_base_64'];
    if (base64Audio != null && base64Audio.isNotEmpty) {
      _playAudio(base64Audio);
    }
  }

  // Handle conversation end to prevent restarts and background activity
  void _handleConversationEnd(Map<String, dynamic> data) {
    debugPrint('🔚 Conversation ended - cleaning up to prevent restart');

    // Stop all audio processing immediately
    _isAgentSpeaking = false;
    _audioQueue.clear();
    _isProcessingQueue = false;

    // Stop the player completely
    _player.stop();

    // Clear conversation state
    _conversationId = null;
    _currentConversationSessionId = '';

    // Stop recording if active
    if (_isRecording) {
      stopRecording();
    }

    // Update state to idle to prevent background activity
    _stateController.add(ConversationState.idle);

    // Clear temp files
    _clearPlaylistAndFiles();

    debugPrint('🔚 Conversation cleanup completed - no restart should occur');
  }

  Future<void> _handleInterruption(Map<String, dynamic> data) async {
    final reason = data['interruption_event']?['reason'];
    debugPrint('🔌 Conversation interrupted: $reason');

    // Immediately stop agent audio when user interrupts
    await _handleUserInterruption();

    final message = ConversationMessage(
      type: 'system',
      content: 'Conversation interrupted: $reason',
      timestamp: DateTime.now(),
    );
    _conversationController.add(message);
    _updateFFAppStateMessages(message);
  }

  Future<String> sendTextMessage(String text) async {
    if (!_isConnected) {
      return 'error: Not connected';
    }
    try {
      final textMessage = jsonEncode({'type': 'user_message', 'text': text});
      _channel!.sink.add(textMessage);
      debugPrint('💬 Text message sent: $text');
      return 'success';
    } catch (e) {
      debugPrint('❌ Error sending text message: $e');
      return 'error: ${e.toString()}';
    }
  }

  Future<void> _sendUserActivity() async {
    if (_isConnected) {
      try {
        _channel!.sink.add(jsonEncode({'type': 'user_activity'}));
      } catch (e) {
        debugPrint('❌ Error sending user activity: $e');
      }
    }
  }

  void _updateFFAppStateMessages(ConversationMessage message) {
    FFAppState().update(() {
      FFAppState().conversationMessages = [
        ...FFAppState().conversationMessages,
        message.toJson()
      ];
    });
  }

  ConversationState _getCurrentState() {
    if (!_isConnected) return ConversationState.idle;
    if (_isRecording) return ConversationState.recording;
    if (_isAgentSpeaking) return ConversationState.playing;
    return ConversationState.connected;
  }

  void _handleError(dynamic error) {
    debugPrint('❌ Service error: $error');
    _stateController.add(ConversationState.error);
    _connectionController.add('error: ${error.toString()}');
    FFAppState().update(() {
      FFAppState().wsConnectionState =
          'error: ${error.toString().substring(0, math.min(50, error.toString().length))}';
    });

    // CRITICAL FIX: Don't auto-reconnect on errors - let user handle manually
    debugPrint(
        '❌ Service error occurred - no automatic reconnection, manual restart required');
  }

  void _handleDisconnect() {
    debugPrint('🔌 Service disconnected');
    _isConnected = false;
    _stateController.add(ConversationState.idle);
    _connectionController.add('disconnected');
    FFAppState().update(() {
      FFAppState().wsConnectionState = 'disconnected';
    });

    // CRITICAL FIX: Don't auto-reconnect - let user explicitly reinitialize
    debugPrint(
        '🔌 No automatic reconnection - service will remain disconnected until explicitly reinitialized');
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= 5) {
      debugPrint('🔌 Maximum reconnect attempts reached');
      return;
    }
    if (_isDisposing) {
      debugPrint('🔌 Service is disposing, skipping reconnect');
      return;
    }
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: math.pow(2, _reconnectAttempts).toInt());
    _reconnectTimer = Timer(delay, () {
      // Double-check disposal state before reconnecting
      if (!_isDisposing) {
        _connect();
      }
    });
    _reconnectAttempts++;
  }

  Future<void> dispose() async {
    debugPrint(
        '🔌 Disposing Conversational AI Service v3.0 (Platform: ${Platform.operatingSystem})');
    _isDisposing = true; // Set flag to prevent reconnection
    _permanentlyDisposed =
        true; // CRITICAL: Permanent flag to prevent any restart

    if (_isRecording) {
      await stopRecording();
    }

    // Handle any active audio interruption
    if (_isAgentSpeaking) {
      await _handleUserInterruption();
    }

    // ENHANCED CLEANUP: Stop all audio processing immediately
    _isAgentSpeaking = false;
    _audioQueue.clear();
    _isProcessingQueue = false;

    // Reset infinite loop prevention state
    _resetInitializationState();

    // Reset interruption state
    _isInterrupted = false;
    _lastInterruptionTime = null;
    _currentAudioSessionId = '';

    // Reset audio isolation state
    _recordingPausedForAgent = false;
    _agentSpeechStartTime = null;
    _lastAgentAudioTime = null;
    _echoCancellationActive = false;
    _recentAudioLevels.clear();
    _baselineAudioLevel = 0.0;
    _audioSignatureHistory.clear();
    _lastPlayedAudioSignature = '';

    // Reset VAD calibration state
    _vadScoreHistory.clear();
    _vadBaselineScore = 0.0;
    _vadCalibrated = false;

    // Reset session isolation state
    _sessionAudioSignatures.clear();
    _sessionStartTimes.clear();
    _currentConversationSessionId = '';
    _activeAudioSessions.clear();
    _sessionToConversationMapping.clear();
    _lastSessionCleanup = null;

    // Reset platform-specific audio state
    if (Platform.isAndroid) {
      _audioChunkBuffer.clear();
      _expectedAudioSequence = 0;
      _audioPlaybackTimer?.cancel();
    }

    if (Platform.isIOS) {
      _iosAudioSessionActive = false;
      _iosAudioSessionTimer?.cancel();
    }

    // Reset hardware-specific state
    _echoLevelHistory.clear();
    _adaptiveEchoThreshold = 0.2;
    _echoDetectionCount = 0;
    _hardwareEchoCancellationActive = false;
    _softwareEchoCancellationActive = false;
    _adaptiveEchoCancellationActive = false;
    _deviceAudioProfile = 'default';
    _deviceSpecificSettings.clear();

    // Reset feedback detection state
    _resetFeedbackDetection();

    // Cancel all timers
    _vadMonitorTimer?.cancel();
    _recordingResumeTimer?.cancel();
    _feedbackPreventionTimer?.cancel();

    // Clean up audio components - cancel subscriptions BEFORE disposing player
    // to prevent final stream events from triggering race conditions
    await _playerStateSubscription?.cancel();
    await _currentIndexSubscription?.cancel();
    await _player.dispose();

    // Close connection
    await _channel?.sink.close();
    await _recorder.dispose();
    await _audioStreamSubscription?.cancel();

    // Cancel timers
    _reconnectTimer?.cancel();
    debugPrint(
        '🔌 Reconnect timer cancelled, disposal flag set to prevent re-initialization');

    // Close streams
    await _conversationController.close();
    await _stateController.close();
    await _recordingController.close();
    await _connectionController.close();

    // Clean up temporary files safely
    _safeClearTempFiles();

    debugPrint(
        '🔌 Conversational AI Service v3.0 disposed with enhanced cleanup (Platform: ${Platform.operatingSystem})');
  }

  /// Completely shut down the service and prevent any restart
  /// Use this when the app is closing to prevent background activity
  Future<void> shutdown() async {
    debugPrint('🛑 Shutting down Conversational AI Service permanently');
    
    _permanentlyDisposed = true;
    _isDisposing = true;
    
    // Stop all timers immediately
    _reconnectTimer?.cancel();
    _vadMonitorTimer?.cancel();
    _recordingResumeTimer?.cancel();
    _feedbackPreventionTimer?.cancel();
    
    // Stop all audio processing
    _isAgentSpeaking = false;
    _audioQueue.clear();
    _isProcessingQueue = false;
    
    // Close connection immediately
    try {
      await _channel?.sink.close();
    } catch (e) {
      debugPrint('⚠️ Error closing WebSocket: $e');
    }
    
    // Stop player
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('⚠️ Error stopping player: $e');
    }
    
    // Clean up temp files
    _safeClearTempFiles();
    
    debugPrint('🛑 Service permanently shut down - no further activity possible');
  }
}
