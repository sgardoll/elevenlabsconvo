# Migration Guide: FlutterFlow Branch → Main Branch Compatibility

This guide walks through updating your FlutterFlow project to use the **official ElevenLabs SDK** and match the main branch architecture.

---

## Overview of Changes

### What's Changing

| Component | FlutterFlow Branch (Old) | Main Branch (New) |
|-----------|---------------------------|-------------------|
| **Core Service** | `ConversationalAIService` (custom WebSocket) | `ElevenLabsSdkService` (official SDK) |
| **Audio Handling** | Manual recording/playback | Native WebRTC via SDK |
| **Dependencies** | Custom packages | `elevenlabs_agents: ^0.3.0` |
| **App State** | Basic tracking | Enhanced state management |
| **Documentation** | Minimal | Complete (AGENTS.md + detailed README) |

---

## Migration Steps (Follow in Order)

---

### STEP 1: Update Dependencies in FlutterFlow

**Action**: Add the ElevenLabs SDK package

1. In FlutterFlow, go to **Settings → Packages**
2. Add this package to your `pubspec.yaml` dependencies:
   ```yaml
   dependencies:
     elevenlabs_agents: ^0.3.0
   ```
3. **Note**: You may need to use "Code" tab in FlutterFlow to edit pubspec.yaml directly

**Why**: Main branch uses official SDK instead of custom WebSocket implementation

---

### STEP 2: Replace Core Service via Custom Code

**Action**: Create/Update the main service file

In FlutterFlow **Custom Code** section:

1. **Delete** (or backup) `lib/custom_code/conversational_ai_service.dart`
2. **Create** `lib/custom_code/elevenlabs_sdk_service.dart`

**Paste this content** (from main branch):

```dart
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart';

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

class ElevenLabsSdkService extends ChangeNotifier {
  static final ElevenLabsSdkService _instance = ElevenLabsSdkService._internal();
  factory ElevenLabsSdkService() => _instance;
  ElevenLabsSdkService._internal();

  ConversationClient? _client;
  String _agentId = '';
  String _endpoint = '';
  bool _isDisposing = false;
  ConversationState _currentState = ConversationState.idle;
  bool _permissionGranted = false;

  final _conversationController = StreamController<ConversationMessage>.broadcast();
  final _stateController = StreamController<ConversationState>.broadcast();
  final _recordingController = StreamController<bool>.broadcast();
  final _connectionController = StreamController<String>.broadcast();

  Stream<ConversationMessage> get conversationStream => _conversationController.stream;
  Stream<ConversationState> get stateStream => _stateController.stream;
  Stream<bool> get recordingStream => _recordingController.stream;
  Stream<String> get connectionStream => _connectionController.stream;

  bool get isRecording => _client?.isMuted == false && _currentState == ConversationState.recording;
  bool get isAgentSpeaking => _client?.isSpeaking ?? false;
  bool get isConnected => _client?.status == ConversationStatus.connected;
  bool get isDisposing => _isDisposing;
  ConversationState get currentState => _currentState;

  Future<bool> _requestMicrophonePermission() async {
    if (_permissionGranted) return true;

    debugPrint('Requesting microphone permission...');
    final status = await Permission.microphone.request();
    _permissionGranted = status.isGranted;

    if (!_permissionGranted) {
      debugPrint('Microphone permission DENIED: $status');
    } else {
      debugPrint('Microphone permission GRANTED');
    }

    return _permissionGranted;
  }

  Future<String?> _getConversationToken() async {
    debugPrint('Getting conversation token from endpoint');
    final token = await getSignedUrl(_agentId, _endpoint);
    if (token != null) {
      debugPrint('Successfully obtained conversation token');
      return token;
    } else {
      debugPrint('Failed to obtain conversation token');
      return null;
    }
  }

  void _initializeClient() {
    if (_client != null) {
      debugPrint('Client already exists, reusing...');
      return;
    }

    debugPrint('Creating new ConversationClient...');
    _client = ConversationClient(
      callbacks: ConversationCallbacks(
        onConnect: ({required conversationId}) {
          debugPrint('>>> onConnect: $conversationId');
          _handleConnect(conversationId: conversationId);
        },
        onDisconnect: (details) {
          debugPrint('>>> onDisconnect: ${details.reason}');
          _handleDisconnect(details);
        },
        onMessage: ({required message, required source}) {
          debugPrint('>>> onMessage [$source]: $message');
          _handleMessage(message: message, source: source);
        },
        onError: (message, [context]) {
          debugPrint('>>> onError: $message, context: $context');
          _handleError(message, context);
        },
        onStatusChange: ({required status}) {
          debugPrint('>>> onStatusChange: ${status.name}');
          _handleStatusChange(status: status);
        },
        onModeChange: ({required mode}) {
          debugPrint('>>> onModeChange: ${mode.name}');
          _handleModeChange(mode: mode);
        },
        onVadScore: ({required vadScore}) {
          if (vadScore > 0.5) {
            debugPrint('>>> VAD score: $vadScore');
          }
        },
        onInterruption: (event) {
          debugPrint('>>> onInterruption: eventId=${event.eventId}');
        },
        onTentativeUserTranscript: ({required transcript, required eventId}) {
          debugPrint('>>> User speaking (live): "$transcript"');
        },
        onUserTranscript: ({required transcript, required eventId}) {
          debugPrint('>>> User said: "$transcript"');
          if (transcript.isNotEmpty && transcript != '...') {
            final userMessage = ConversationMessage(
              type: 'user',
              content: transcript,
              timestamp: DateTime.now(),
            );
            _conversationController.add(userMessage);
            _updateFFAppStateMessages(userMessage);
          }
        },
        onTentativeAgentResponse: ({required response}) {
          debugPrint('>>> Agent composing: "$response"');
        },
        onDebug: (data) {
          debugPrint('>>> Debug: $data');
        },
      ),
    );

    _client!.addListener(_onClientChanged);
    debugPrint('ConversationClient created successfully');
  }

  Future<String> initialize({
    required String agentId,
    required String endpoint,
  }) async {
    debugPrint('========================================');
    debugPrint('Initializing ElevenLabs SDK Service');
    debugPrint('  agentId: $agentId');
    debugPrint('  endpoint: $endpoint');
    debugPrint('========================================');

    if (_agentId == agentId && _endpoint == endpoint && isConnected) {
      debugPrint('Service already initialized and connected');
      return 'success';
    }

    _isDisposing = false;
    _agentId = agentId;
    _endpoint = endpoint;

    try {
      final hasPermission = await _requestMicrophonePermission();
      if (!hasPermission) {
        throw Exception('Microphone permission denied');
      }

      _updateState(ConversationState.connecting);
      _connectionController.add('connecting');

      final token = await _getConversationToken();
      if (token == null) {
        throw Exception('Failed to obtain conversation token');
      }
      debugPrint('Token obtained (length: ${token.length})');

      if (_client != null && _client!.status != ConversationStatus.disconnected) {
        debugPrint('Ending existing session...');
        await _client!.endSession();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      _initializeClient();

      debugPrint('Starting session with conversationToken...');
      final userId = 'user-${DateTime.now().millisecondsSinceEpoch}';
      await _client!.startSession(
        conversationToken: token,
        userId: userId,
      );

      debugPrint('Session started successfully for user: $userId');

      FFAppState().update(() {
        FFAppState().wsConnectionState = 'connected';
        FFAppState().elevenLabsAgentId = agentId;
        FFAppState().endpoint = endpoint;
      });

      return 'success';
    } catch (e, stackTrace) {
      debugPrint('========================================');
      debugPrint('ERROR initializing service: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('========================================');
      _updateState(ConversationState.error);
      _connectionController.add('error: ${e.toString()}');
      return 'error: ${e.toString()}';
    }
  }

  void _onClientChanged() {
    if (_client == null) return;

    final status = _client!.status;
    final isSpeaking = _client!.isSpeaking;
    final isMuted = _client!.isMuted;

    debugPrint('Client changed: status=$status, isSpeaking=$isSpeaking, isMuted=$isMuted');

    ConversationState newState;
    if (status == ConversationStatus.disconnected) {
      newState = ConversationState.idle;
    } else if (status == ConversationStatus.connecting) {
      newState = ConversationState.connecting;
    } else if (status == ConversationStatus.connected) {
      if (isSpeaking) {
        newState = ConversationState.playing;
      } else if (!isMuted) {
        newState = ConversationState.recording;
      } else {
        newState = ConversationState.connected;
      }
    } else {
      newState = ConversationState.idle;
    }

    if (newState != _currentState) {
      _updateState(newState);
    }

    _recordingController.add(!isMuted && status == ConversationStatus.connected);

    notifyListeners();
  }

  void _handleConnect({required String conversationId}) {
    debugPrint('Connected to conversation: $conversationId');
    _updateState(ConversationState.connected);
    _connectionController.add('connected');

    final message = ConversationMessage(
      type: 'system',
      content: 'Connected to ElevenLabs conversation',
      timestamp: DateTime.now(),
      conversationId: conversationId,
    );
    _conversationController.add(message);
    _updateFFAppStateMessages(message);
  }

  void _handleDisconnect(DisconnectionDetails details) {
    debugPrint('Disconnected from conversation: ${details.reason}');
    _updateState(ConversationState.idle);
    _connectionController.add('disconnected');

    FFAppState().update(() {
      FFAppState().wsConnectionState = 'disconnected';
    });
  }

  void _handleMessage({required String message, required Role source}) {
    debugPrint('Message from $source: $message');

    if (source == Role.ai) {
      final conversationMessage = ConversationMessage(
        type: 'agent',
        content: message,
        timestamp: DateTime.now(),
      );
      _conversationController.add(conversationMessage);
      _updateFFAppStateMessages(conversationMessage);
    }
  }

  void _handleError(String message, [dynamic context]) {
    debugPrint('SDK Error: $message, context: $context');
    _connectionController.add('error: $message');
  }

  void _handleStatusChange({required ConversationStatus status}) {
    debugPrint('Status changed: $status');
    _onClientChanged();
  }

  void _handleModeChange({required ConversationMode mode}) {
    debugPrint('Mode changed: $mode');
    _onClientChanged();
  }

  void _updateState(ConversationState state) {
    debugPrint('State: $_currentState -> $state');
    _currentState = state;
    _stateController.add(state);
  }

  void _updateFFAppStateMessages(ConversationMessage message) {
    FFAppState().update(() {
      FFAppState().conversationMessages = [
        ...FFAppState().conversationMessages,
        message.toJson()
      ];
    });
  }

  Future<String> toggleRecording() async {
    if (_client == null || !isConnected) {
      return 'error: Not connected';
    }

    try {
      await _client!.toggleMute();
      final isMuted = _client!.isMuted;
      debugPrint('Recording ${isMuted ? 'stopped (muted)' : 'started (unmuted)'}');

      FFAppState().update(() {
        FFAppState().isRecording = !isMuted;
      });

      return 'success';
    } catch (e) {
      debugPrint('Error toggling recording: $e');
      return 'error: ${e.toString()}';
    }
  }

  Future<String> startRecording() async {
    if (_client == null || !isConnected) {
      return 'error: Not connected';
    }

    if (!_client!.isMuted) {
      return 'error: Already recording';
    }

    try {
      await _client!.setMicMuted(false);
      debugPrint('Recording started (unmuted)');

      FFAppState().update(() {
        FFAppState().isRecording = true;
      });

      return 'success';
    } catch (e) {
      debugPrint('Error starting recording: $e');
      return 'error: ${e.toString()}';
    }
  }

  Future<String> stopRecording() async {
    if (_client == null || !isConnected) {
      return 'error: Not connected';
    }

    if (_client!.isMuted) {
      return 'error: Not recording';
    }

    try {
      await _client!.setMicMuted(true);
      debugPrint('Recording stopped (muted)');

      FFAppState().update(() {
        FFAppState().isRecording = false;
      });

      return 'success';
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      return 'error: ${e.toString()}';
    }
  }

  Future<void> triggerInterruption() async {
    debugPrint('Manual interruption triggered');
    if (_client != null && _client!.isMuted) {
      await _client!.setMicMuted(false);
    }
  }

  Future<String> sendTextMessage(String text) async {
    if (_client == null || !isConnected) {
      return 'error: Not connected';
    }

    try {
      _client!.sendUserMessage(text);
      debugPrint('Text message sent: $text');
      return 'success';
    } catch (e) {
      debugPrint('Error sending text message: $e');
      return 'error: ${e.toString()}';
    }
  }

  Future<void> dispose() async {
    debugPrint('Disposing ElevenLabs SDK Service');
    _isDisposing = true;

    try {
      if (_client != null) {
        _client!.removeListener(_onClientChanged);
        await _client!.endSession();
        _client!.dispose();
        _client = null;
      }
    } catch (e) {
      debugPrint('Error during disposal: $e');
    }

    _updateState(ConversationState.idle);
    _connectionController.add('disconnected');

    debugPrint('ElevenLabs SDK Service disposed');
  }
}
```

---

### STEP 3: Update Custom Actions

#### 3a. Update `initialize_conversation_service.dart`

**In FlutterFlow Custom Actions → initialize_conversation_service**:

Replace entire action code with:

```dart
// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart';
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

Future<void> initializeConversationService(
  String agentId,
  String endpoint,
) async {
  try {
    final svc = ElevenLabsSdkService();

    final res = await svc.initialize(
      agentId: agentId,
      endpoint: endpoint,
    );

    if (res == 'success') {
      FFAppState().update(() {
        FFAppState().wsConnectionState = 'connected';
        FFAppState().elevenLabsAgentId = agentId;
        FFAppState().endpoint = endpoint;
      });
    } else {
      FFAppState().update(() {
        FFAppState().wsConnectionState = res;
      });
    }
  } catch (e) {
    debugPrint('Error initializing conversation service: $e');
    FFAppState().update(() {
      FFAppState().wsConnectionState = 'error:${e.toString()}';
      FFAppState().isRecording = false;
    });
  }
}
```

**Changes**:
- Removed unused parameters (`firstMessage`, `language`, `keepMicHotDuringAgent`, `autoStartMic`)
- Changed import from `conversational_ai_service.dart` to `elevenlabs_sdk_service.dart`
- Simplified initialization logic

#### 3b. Update `simple_recording_button.dart`

**In FlutterFlow Custom Widgets → simple_recording_button**:

Change the import statement at the top:

```dart
// From:
import '/custom_code/conversational_ai_service.dart';

// To:
import '/custom_code/elevenlabs_sdk_service.dart';
```

And update the service instantiation:

```dart
// From:
final ConversationalAIService _service = ConversationalAIService();

// To:
final ElevenLabsSdkService _service = ElevenLabsSdkService();
```

And update the interrupt method call:

```dart
// From:
await _service.interrupt();

// To:
await _service.triggerInterruption();
```

---

### STEP 4: Update App State Variables

**In FlutterFlow App State → State Variables**:

Add these new variables if they don't exist:

| Variable Name | Type | Initial Value |
|--------------|------|---------------|
| `elevenLabsAgentId` | String | `''` |
| `endpoint` | String | `''` |
| `wsConnectionState` | String | `'disconnected'` |
| `isRecording` | Boolean | `false` |
| `conversationMessages` | List of JSON | `[]` |
| `isAgentSpeaking` | Boolean | `false` |

**Note**: Most of these likely already exist - just verify.

---

### STEP 5: Update Platform Configuration

#### 5a. Android Manifest

**In FlutterFlow** → Settings → Android → Edit AndroidManifest.xml:

Replace the permissions section with:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

#### 5b. iOS Info.plist

**In FlutterFlow** → Settings → iOS → Edit Info.plist:

Ensure these entries exist:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for voice conversations</string>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app requires access to Bluetooth in order to communicate with AI Agents</string>
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>voip</string>
</array>
```

---

### STEP 6: Update Build Configuration

#### 6a. iOS Podfile

**In FlutterFlow** → Settings → iOS → Edit Podfile:

Ensure minimum version is set:

```ruby
platform :ios, '14.0.0'
```

**Note**: This should already be set if using recent FlutterFlow.

#### 6b. Android build.gradle

**In FlutterFlow** → Settings → Android → Edit android/app/build.gradle:

Update to:

```gradle
android {
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

---

### STEP 7: Add Documentation Files

#### 7a. Add AGENTS.md

**In FlutterFlow** → Custom Code:

Create file `AGENTS.md` and paste the content from main branch (see MIGRATION/AGENTS.md.txt in this repo).

#### 7b. Update README.md

**In FlutterFlow** → Project Settings → Description:

Update your project README to match the main branch version (see MIGRATION/README.md.txt in this repo).

**Critical Sections to Include**:
- iOS Simulator limitation warning
- Complete setup guide
- Platform permissions
- Security best practices

---

### STEP 8: Test on Physical Device

**CRITICAL**: After completing all steps:

1. **Run on physical iPhone** (iOS 14.0+)
2. **Run on Android device** (API 21+)
3. Test conversation flow:
   - Initialize conversation
   - Speak and verify transcription
   - Agent response
   - Tap to interrupt
   - Stop conversation

**DO NOT TEST ON IOS SIMULATOR** for voice features - it won't work due to WebRTC limitations.

---

### STEP 9: Verify Build Configuration

Run these commands to ensure everything compiles:

```bash
flutter clean
flutter pub get
flutter analyze
flutter build apk --debug
flutter build ios --debug
```

Fix any errors before proceeding to production.

---

## Migration Checklist

Use this checklist to track your progress:

- [ ] **STEP 1**: Added `elevenlabs_agents: ^0.3.0` to pubspec.yaml
- [ ] **STEP 2**: Created `elevenlabs_sdk_service.dart`
- [ ] **STEP 2**: Deleted/Backed up `conversational_ai_service.dart`
- [ ] **STEP 3a**: Updated `initialize_conversation_service.dart`
- [ ] **STEP 3b**: Updated `simple_recording_button.dart`
- [ ] **STEP 4**: Verified App State variables
- [ ] **STEP 5a**: Updated AndroidManifest.xml permissions
- [ ] **STEP 5b**: Updated Info.plist permissions
- [ ] **STEP 6**: Verified build configuration
- [ ] **STEP 7a**: Added AGENTS.md
- [ ] **STEP 7b**: Updated README.md
- [ ] **STEP 8**: Tested on physical iOS device
- [ ] **STEP 8**: Tested on Android device
- [ ] **STEP 9**: Ran `flutter analyze` with no errors
- [ ] **STEP 9**: Successfully built APK and IPA

---

## Common Issues & Solutions

### Issue: "import '/custom_code/elevenlabs_sdk_service.dart' not found"

**Solution**: Make sure you created the file in Custom Code section and saved it properly in FlutterFlow.

### Issue: "Class 'ConversationClient' not found"

**Solution**: Run `flutter pub get` after adding the dependency. Verify pubspec.yaml has `elevenlabs_agents: ^0.3.0`.

### Issue: iOS app crashes on launch

**Solution**:
1. Delete `ios/Podfile.lock`
2. Run `flutter clean`
3. Run `flutter pub get`
4. Rebuild iOS project

### Issue: Transcripts show "..." even on physical device

**Solution**: This may indicate a permissions issue or network issue:
1. Check microphone permission is granted
2. Check network connectivity
3. Verify agent ID is correct
4. Check backend endpoint is returning valid tokens

### Issue: Android audio doesn't work

**Solution**: Ensure you have updated AndroidManifest.xml with the new permissions:
- `BLUETOOTH_SCAN`
- `BLUETOOTH_CONNECT`

---

## Rollback Plan

If migration fails, you can rollback:

1. Restore `conversational_ai_service.dart` from backup
2. Remove `elevenlabs_agents` dependency from pubspec.yaml
3. Revert all custom action changes
4. Run `flutter pub get`
5. Test the old implementation

---

## Support

If you encounter issues during migration:

1. Check FlutterFlow documentation for custom code limitations
2. Review the main branch implementation for reference
3. Verify all steps in the checklist are complete
4. Test on physical devices only

---

**Last Updated**: 2026-01-04
**Target Branch**: flutterflow → main compatibility
**SDK Version**: elevenlabs_agents ^0.3.0
