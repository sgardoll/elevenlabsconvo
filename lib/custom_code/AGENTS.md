# lib/custom_code/ - ElevenLabs SDK Integration

## Overview
Custom code implementing the ElevenLabs Conversational AI v2 SDK (`elevenlabs_agents`). Handles WebRTC connection, audio streaming, and FlutterFlow state synchronization.

## Structure

```
custom_code/
├── elevenlabs_sdk_service.dart          # Core service singleton
├── actions/
│   ├── initialize_conversation_service.dart
│   ├── stop_conversation_service.dart
│   └── get_signed_url.dart
└── widgets/
    └── simple_recording_button.dart
```

## Key Files

| File | Purpose |
|------|---------|
| `elevenlabs_sdk_service.dart` | WebRTC connection, audio streaming, state management |
| `initialize_conversation_service.dart` | Entry point - requests token, initializes service |
| `stop_conversation_service.dart` | Cleanup - stops conversation, releases resources |
| `get_signed_url.dart` | Fetches conversation token from backend |
| `simple_recording_button.dart` | UI widget with visual recording states |

## Service Pattern

`ElevenLabsSdkService` is a singleton managing the conversation lifecycle:

```dart
class ElevenLabsSdkService {
  static final ElevenLabsSdkService _instance = ElevenLabsSdkService._internal();
  factory ElevenLabsSdkService() => _instance;
  
  // WebRTC connection
  // Audio recording/playback
  // State callbacks to FFAppState
}
```

## Initialization Flow

1. **Call backend** → Get conversation token (not API key)
2. **Initialize service** → `ElevenLabsSdkService.initialize()`
3. **Start WebRTC** → SDK handles connection
4. **Update state** → `FFAppState` reflects connection status

## Required App State Variables

```dart
// Connection
String wsConnectionState = 'disconnected';
String elevenLabsAgentId = '';
String elevenLabsConversationTokenEndpoint = '';

// Audio
bool isRecording = false;
bool isAgentSpeaking = false;
bool isInitializing = false;

// Messages
List<dynamic> conversationMessages = [];
```

## Action Usage

```dart
// Initialize
final result = await initializeConversationService(
  context,
  FFAppState().elevenLabsAgentId,
  FFAppState().elevenLabsConversationTokenEndpoint,
);

// Cleanup (on page dispose)
await stopConversationService();
```

## Security

- **Token-based auth**: Never expose API key; use secure backend endpoint
- Cloud function generates temporary `conversationToken`
- Client only handles token, not API key

## Widget Integration

Add `SimpleRecordingButton` to FlutterFlow canvas:
- Visual feedback for recording state
- Handles tap to start/stop
- Respects FlutterFlow theme

## Platform Requirements

- **iOS**: Physical device required (simulator cannot capture WebRTC audio)
- **Android**: RECORD_AUDIO, BLUETOOTH permissions
- **Backend**: Token endpoint must be configured

## Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| "..." transcripts only | iOS Simulator | Test on physical device |
| Connection failed | Invalid token | Verify backend endpoint |
| No audio | Missing permissions | Request mic/bluetooth permissions |
