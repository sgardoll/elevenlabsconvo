# ElevenLabs Conversational AI v2

**Generated:** 2026-02-05
**Commit:** 1a09836
**Branch:** sdkRedeploy

## Overview
FlutterFlow project implementing ElevenLabs Conversational AI v2 using the official `elevenlabs_agents` SDK. Features real-time voice conversations via WebRTC, secure token-based authentication, and FlutterFlow-native integration.

## Structure

```
lib/
├── flutter_flow/          # FlutterFlow framework utilities (9 files)
├── custom_code/           # ElevenLabs SDK integration (7 files)
│   ├── elevenlabs_sdk_service.dart    # Core WebRTC service
│   ├── actions/                       # Custom actions (init, stop, get token)
│   └── widgets/                       # Custom widgets (recording button)
├── backend/               # API requests & schema structs
├── pages/                 # Page widgets (conversational_demo)
└── components/            # UI components (transcription bubbles)
```

## Where to Look

| Task | Location | Notes |
|------|----------|-------|
| Initialize conversation | `lib/custom_code/actions/initialize_conversation_service.dart` | Main entry point |
| Core SDK service | `lib/custom_code/elevenlabs_sdk_service.dart` | WebRTC, state management |
| Recording UI | `lib/custom_code/widgets/simple_recording_button.dart` | Visual feedback |
| App state | `lib/app_state.dart` | FFAppState singleton |
| Theme | `lib/flutter_flow/flutter_flow_theme.dart` | FlutterFlow colors |
| API calls | `lib/backend/api_requests/` | Token endpoint calls |

## Commands

```bash
flutter pub get                 # Install deps (includes elevenlabs_agents)
flutter analyze                 # Static analysis (custom_code excluded)
flutter test                    # Run tests
dart format lib/                # Format code
flutter build apk/ios/web       # Platform builds
```

## Conventions

### Imports
```dart
// Automatic FlutterFlow imports (REQUIRED for custom code)
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart';
import '/custom_code/actions/index.dart';
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!
```

### State Management
- Use `FFAppState()` singleton for global state
- Use `safeSetState()` which checks `mounted` before calling `setState()`
- Use `context.watch<FFAppState>()` for reactive UI

### Custom Action Pattern
```dart
Future<String> myAction(BuildContext context, String param) async {
  try {
    final result = await someAsyncOperation();
    return result;
  } catch (e) {
    return 'error: ${e.toString()}';
  }
}
```

### Error Handling
- Return error strings prefixed with `'error: '`
- Use `debugPrint()` for logging
- Wrap async operations in `try-catch`

## Anti-Patterns

- **Never** expose ElevenLabs API key client-side (use token endpoint)
- **Never** use raw `setState()` (use `safeSetState()`)
- **Never** modify automatic FlutterFlow import blocks
- **Never** skip `mounted` checks in async callbacks
- **Avoid** `print()` (use `debugPrint()`)

## FlutterFlow Specifics

- `lib/custom_code/**` excluded from `flutter analyze`
- Model pattern: `*_widget.dart` + `*_model.dart`
- Use `wrapWithModel()` for widget models
- Custom code must start with automatic import block

## Key Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| elevenlabs_agents | ^0.3.0 | WebRTC conversation SDK |
| just_audio | ^0.10.4 | Audio playback |
| record | ^6.0.0 | Audio recording |
| permission_handler | 12.0.0+1 | Mic/Bluetooth permissions |
| web_socket_channel | ^3.0.0 | WebSocket connections |

## Platform Notes

- **iOS Simulator**: Cannot capture microphone for WebRTC (test on physical device)
- **Android**: Requires RECORD_AUDIO, BLUETOOTH, INTERNET permissions
- **Web**: Limited audio support for conversational AI
