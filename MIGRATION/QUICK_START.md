# Quick Start: FlutterFlow → Main Branch Migration

## TL;DR

You need to replace the **old custom WebSocket service** with the **official ElevenLabs SDK** to match the main branch.

**Files to Change**: 8 files
**Estimated Time**: 2-3 hours
**Difficulty**: Medium

---

## Step-by-Step (In Order)

### STEP 1: Add SDK Dependency (5 min)

**In FlutterFlow → Settings → Code → pubspec.yaml**:

Add this line under `dependencies:`:

```yaml
  elevenlabs_agents: ^0.3.0
```

**Important**: After saving, FlutterFlow should automatically run `flutter pub get`

---

### STEP 2: Create New Service (20 min)

**In FlutterFlow → Custom Code → New File**:

1. Click "Add Custom Code"
2. Name it: `elevenlabs_sdk_service.dart`
3. Paste the **entire content** from:
   - `MIGRATION/AGENTS.md` (for reference)
   - OR copy from `MIGRATION_GUIDE.md` STEP 2 section

**Code to paste is ~495 lines** - ensure you get all of it!

---

### STEP 3: Delete Old Service (2 min)

**In FlutterFlow → Custom Code**:

1. Find `conversational_ai_service.dart`
2. Delete it (or rename to `conversational_ai_service.dart.backup`)

---

### STEP 4: Update Initialize Action (10 min)

**In FlutterFlow → Custom Actions → initialize_conversation_service**:

Replace the entire code with this simpler version:

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

**Note**: The action parameters in FlutterFlow UI should be:
- `agentId` (String)
- `endpoint` (String)

Remove all other parameters from the action configuration.

---

### STEP 5: Update Recording Button Widget (5 min)

**In FlutterFlow → Custom Widgets → simple_recording_button**:

Make 3 changes:

#### Change 1: Import (top of file)
```dart
// FROM:
import '/custom_code/conversational_ai_service.dart';

// TO:
import '/custom_code/elevenlabs_sdk_service.dart';
```

#### Change 2: Service instantiation
```dart
// FROM:
final ConversationalAIService _service = ConversationalAIService();

// TO:
final ElevenLabsSdkService _service = ElevenLabsSdkService();
```

#### Change 3: Interrupt call
```dart
// FROM:
await _service.interrupt();

// TO:
await _service.triggerInterruption();
```

---

### STEP 6: Update Android Permissions (5 min)

**In FlutterFlow → Settings → Android → AndroidManifest.xml**:

Add these 2 lines to the permissions section:

```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

**Where**: In the `<uses-permission>` section at the top of the file.

---

### STEP 7: Update iOS Permissions (5 min)

**In FlutterFlow → Settings → iOS → Info.plist**:

Ensure `<key>UIBackgroundModes</key>` has `voip`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>voip</string>  <!-- ADD THIS LINE -->
</array>
```

---

### STEP 8: Test on Physical Device (30-60 min)

**CRITICAL**: Test on a **real device, not simulator**.

#### iOS Testing:
1. Build and install on iPhone (iOS 14.0+)
2. Open app and grant microphone permission
3. Initialize conversation with your agentId and endpoint
4. Speak to the device
5. Verify transcriptions appear (not "...")
6. Listen to agent response
7. Tap button to interrupt agent
8. Verify conversation state updates correctly

#### Android Testing:
1. Build and install on Android device (API 21+)
2. Grant microphone and Bluetooth permissions
3. Repeat steps 3-8 from iOS testing

---

### STEP 9: Verify App State (5 min)

**In FlutterFlow → App State**:

Verify these variables exist:

| Variable | Type | Default |
|----------|------|----------|
| `wsConnectionState` | String | `'disconnected'` |
| `isRecording` | Boolean | `false` |
| `elevenLabsAgentId` | String | `''` |
| `endpoint` | String | `''` |
| `conversationMessages` | List<JSON> | `[]` |

If any are missing, add them in App State.

---

### STEP 10: Documentation (Optional - 10 min)

**In FlutterFlow → Project Settings**:

Update your README to mention:

1. **iOS Simulator Limitation**: Add note about testing on physical devices
2. **Official SDK**: Mention you're using `elevenlabs_agents` package
3. **Permissions**: List required permissions for Android/iOS

See `MIGRATION/README.md` in this repo for complete documentation.

---

## Validation Checklist

After completing all steps, verify:

- [ ] pubspec.yaml has `elevenlabs_agents: ^0.3.0`
- [ ] `elevenlabs_sdk_service.dart` exists (495 lines)
- [ ] `conversational_ai_service.dart` is deleted
- [ ] `initialize_conversation_service` only has 2 parameters
- [ ] `simple_recording_button` imports `elevenlabs_sdk_service.dart`
- [ ] AndroidManifest.xml has new Bluetooth permissions
- [ ] Info.plist has `voip` background mode
- [ ] App state variables exist
- [ ] App builds successfully
- [ ] Works on physical iOS device
- [ ] Works on Android device
- [ ] Voice conversations work
- [ ] Transcripts display correctly

---

## Troubleshooting

### Problem: "elevenlabs_sdk_service.dart not found"

**Solution**:
1. Make sure you clicked "Save" in FlutterFlow Custom Code
2. Wait for FlutterFlow to process the file
3. Try refreshing the Custom Code section

### Problem: Build fails with import errors

**Solution**:
1. Check that `pubspec.yaml` has the dependency
2. Wait for FlutterFlow to run `flutter pub get`
3. Refresh the project and try again

### Problem: iOS Simulator shows "..." for transcripts

**Solution**: **This is expected!** iOS Simulator cannot capture microphone audio for WebRTC.

**You must test on a physical iPhone.**

### Problem: Android shows permission denied

**Solution**:
1. Check AndroidManifest.xml has new permissions
2. Rebuild the APK
3. Clear app data and reinstall
4. Grant permissions when prompted

### Problem: Action has wrong number of parameters

**Solution**:
1. Open `initialize_conversation_service` in FlutterFlow
2. In the action settings, remove old parameters:
   - `firstMessage`
   - `language`
   - `keepMicHotDuringAgent`
   - `autoStartMic`
3. Keep only: `agentId` and `endpoint`

---

## Success!

When all validation items are checked, your migration is complete!

**What you now have**:
✅ Official ElevenLabs SDK integration
✅ Lower latency (100-200ms vs 500-1000ms)
✅ Better reliability (WebRTC vs WebSocket)
✅ Automatic updates from ElevenLabs
✅ Less custom code to maintain
✅ Better audio quality
✅ Proper Android 12+ and iOS 14+ support

---

## Files Created for Reference

All migration documentation is in the `MIGRATION/` folder:

- **QUICK_START.md** - This file (step-by-step)
- **MIGRATION_GUIDE.md** - Detailed instructions with full code
- **FILE_STRUCTURE.md** - File comparison details
- **README.md** - Overview and best practices
- **AGENTS.md** - Build/lint/test commands (copied from main)
- **README.md** - Complete project docs (copied from main)

---

**Need more detail?** Check:
- `MIGRATION_GUIDE.md` for full implementation details
- `FILE_STRUCTURE.md` for what changed and why
- `MIGRATION/README.md` for comprehensive overview

---

**Last Updated**: 2026-01-04
**Version**: 1.0
