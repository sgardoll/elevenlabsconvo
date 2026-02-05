# File Structure Comparison

## Overview

This document shows the file structure differences between `flutterflow` branch and `main` branch.

---

## Files Added in Main Branch

```
lib/
├── custom_code/
│   └── elevenlabs_sdk_service.dart      # NEW: Official SDK service
└── AGENTS.md                             # NEW: Build/lint/test guide

MIGRATION/
├── MIGRATION_GUIDE.md                  # NEW: This file
├── AGENTS.md                            # COPY: For reference
└── README.md                            # COPY: For reference
```

## Files Deleted in Main Branch

```
lib/
├── custom_code/
│   └── conversational_ai_service.dart     # DELETED: Replaced by SDK
└── library_values.dart                    # DELETED: Unused

components/
├── transcription_bubbles_model.dart        # MOVED: components/transcription_bubbles/
└── transcription_bubbles_widget.dart       # MOVED: components/transcription_bubbles/
```

## Files Modified in Main Branch

### High Impact Changes

| File | Change Type | Impact |
|-------|-------------|---------|
| `lib/custom_code/widgets/simple_recording_button.dart` | Updated service integration | Medium |
| `lib/custom_code/actions/initialize_conversation_service.dart` | Simplified parameters | High |
| `lib/app_state.dart` | Added 6 new state variables | High |
| `android/app/src/main/AndroidManifest.xml` | Added modern permissions | High |
| `ios/Runner/Info.plist` | Added voip background mode | Medium |
| `pubspec.yaml` | Added SDK dependency | Critical |

### Medium Impact Changes

| File | Changes |
|-------|----------|
| `lib/custom_code/actions/get_signed_url.dart` | Simplified implementation |
| `lib/custom_code/actions/stop_conversation_service.dart` | Updated service calls |
| `lib/backend/api_requests/api_calls.dart` | Minor API adjustments |
| `lib/backend/schema/structs/index.dart` | Struct rename |
| `lib/flutter_flow/flutter_flow_widgets.dart` | Minor updates |
| `ios/Podfile` | Version pinning |
| `android/app/build.gradle` | SDK version update |

### Low Impact Changes

| File | Changes |
|-------|----------|
| `ios/Runner.xcodeproj/project.pbxproj` | Project config |
| `ios/Runner.xcworkspace/` | Workspace config |
| `android/build.gradle` | Gradle config |
| `android/gradle.properties` | Properties |
| `.gitignore` | Updated ignore patterns |

---

## Key Architectural Changes

### 1. Service Layer

**FlutterFlow Branch**:
```
lib/custom_code/conversational_ai_service.dart
├── IOWebSocketChannel (custom)
├── AudioRecorder (manual)
├── AudioPlayer (manual)
└── Manual state management
```

**Main Branch**:
```
lib/custom_code/elevenlabs_sdk_service.dart
├── ConversationClient (official SDK)
├── Built-in WebRTC
├── Automatic VAD
└── Stream-based state management
```

### 2. Dependency Tree

**FlutterFlow Branch**:
```
pubspec.yaml
├── just_audio
├── record
├── web_socket_channel
└── (other packages)
```

**Main Branch**:
```
pubspec.yaml
├── elevenlabs_agents (NEW - replaces all custom audio code)
├── just_audio
└── (other packages)
```

### 3. App State

**FlutterFlow Branch** - Basic tracking:
```dart
FFAppState
├── wsConnectionState
├── isRecording
└── conversationMessages
```

**Main Branch** - Enhanced tracking:
```dart
FFAppState
├── wsConnectionState
├── isRecording
├── conversationMessages
├── isAgentSpeaking (NEW)
├── isInConversation (NEW)
├── lastUserTranscript (NEW)
├── lastAgentResponse (NEW)
├── lastVadScore (NEW)
├── lastSignedUrl (NEW)
├── agentId (NEW - persistent)
└── endpoint (NEW - persistent)
```

---

## Migration Priority

### Critical Path (Must Do First)

1. **pubspec.yaml** - Add `elevenlabs_agents: ^0.3.0`
2. **elevenlabs_sdk_service.dart** - Create new service file
3. **conversational_ai_service.dart** - Delete old service file
4. **initialize_conversation_service.dart** - Update to use new service

### High Priority (Do After Critical)

5. **AndroidManifest.xml** - Update permissions
6. **Info.plist** - Add voip mode
7. **simple_recording_button.dart** - Update imports

### Medium Priority (Do After High Priority)

8. **app_state.dart** - Add new variables
9. **AGENTS.md** - Add documentation
10. **README.md** - Update project docs

### Low Priority (Optional)

11. **get_signed_url.dart** - Simplify (optional optimization)
12. **Stop/start conversation actions** - Update calls
13. **Build configs** - Verify settings

---

## File-by-File Migration Map

| FlutterFlow File | Main Branch File | Action Required |
|-----------------|-------------------|-----------------|
| `conversational_ai_service.dart` | `elevenlabs_sdk_service.dart` | **REPLACE** |
| `initialize_conversation_service.dart` | (same file) | **UPDATE** parameters |
| `simple_recording_button.dart` | (same file) | **UPDATE** imports |
| `pubspec.yaml` | (same file) | **ADD** dependency |
| `AndroidManifest.xml` | (same file) | **ADD** permissions |
| `Info.plist` | (same file) | **ADD** voip mode |
| `app_state.dart` | (same file) | **ADD** variables |
| (not present) | `AGENTS.md` | **CREATE** file |
| `README.md` | (same file) | **UPDATE** content |
| (not present) | `library_values.dart` | **IGNORE** (deleted in main) |

---

## Quick Reference Code Snippets

### Service Import Change

**Old**:
```dart
import '../conversational_ai_service.dart';
final ConversationalAIService _service = ConversationalAIService();
```

**New**:
```dart
import '../elevenlabs_sdk_service.dart';
final ElevenLabsSdkService _service = ElevenLabsSdkService();
```

### Action Signature Change

**Old**:
```dart
Future<void> initializeConversationService(
  String agentId,
  String endpoint,
  String? firstMessage,
  String? language,
  bool? keepMicHotDuringAgent,
  bool? autoStartMic,
) async { ... }
```

**New**:
```dart
Future<void> initializeConversationService(
  String agentId,
  String endpoint,
) async { ... }
```

### Widget Update

**Old**:
```dart
await _service.interrupt();
```

**New**:
```dart
await _service.triggerInterruption();
```

---

## Testing Strategy

After migrating each section, run:

### Phase 1: Dependency Test
```bash
flutter pub get
flutter analyze
```

### Phase 2: Build Test
```bash
flutter build apk --debug
```

### Phase 3: Integration Test
- Open app in FlutterFlow preview or test on device
- Initialize conversation
- Test recording
- Test interruption
- Verify transcripts

### Phase 4: Production Test
- Build release APK/IPA
- Test on physical iOS device (not simulator)
- Test on Android device

---

## Verification Checklist

Use this to verify each file change:

**Dependencies**
- [ ] `elevenlabs_agents: ^0.3.0` in pubspec.yaml
- [ ] `flutter pub get` completed successfully
- [ ] No import errors

**Service Layer**
- [ ] `elevenlabs_sdk_service.dart` created
- [ ] `conversational_ai_service.dart` deleted
- [ ] All imports updated
- [ ] Service initializes successfully

**Actions**
- [ ] `initialize_conversation_service.dart` updated
- [ ] `simple_recording_button.dart` updated
- [ ] All action calls use new service

**State Management**
- [ ] App State variables exist
- [ ] State updates work correctly
- [ ] Streams flow properly

**Platform Config**
- [ ] Android permissions updated
- [ ] iOS permissions updated
- [ ] Background modes configured

**Documentation**
- [ ] AGENTS.md added
- [ ] README.md updated
- [ ] iOS Simulator warning added

**Build**
- [ ] `flutter analyze` passes
- [ ] Android builds successfully
- [ ] iOS builds successfully

**Testing**
- [ ] Tested on physical iOS device
- [ ] Tested on Android device
- [ ] Voice conversation works
- [ ] Transcripts display correctly

---

**Created**: 2026-01-04
**Purpose**: FlutterFlow to Main Branch migration reference
