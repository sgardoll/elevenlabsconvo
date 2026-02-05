# Migration Summary: FlutterFlow → Main Branch

## Quick Start

**Estimated Time**: 2-4 hours
**Complexity**: Medium
**Risk**: Medium (can rollback if needed)

---

## What You're Getting

| Feature | FlutterFlow Branch | Main Branch | Benefit |
|-----------|-------------------|--------------|----------|
| **Audio** | Custom WebSocket | Official WebRTC SDK | ✅ 100-200ms latency, reliable |
| **Maintenance** | High (custom code) | Low (official SDK) | ✅ Automatic updates, bug fixes |
| **Documentation** | Minimal | Comprehensive | ✅ AGENTS.md, detailed README |
| **Permissions** | Basic | Modern (Android 31+, iOS 14+) | ✅ Better device compatibility |
| **Features** | Basic | Advanced (VAD, transcripts, state) | ✅ Richer user experience |

---

## High-Level Migration Path

```
STEP 1: Dependencies (5 min)
   └─ Add elevenlabs_agents package
   └─ Run flutter pub get

STEP 2: Core Service (30 min)
   └─ Delete conversational_ai_service.dart
   └─ Create elevenlabs_sdk_service.dart
   └─ Copy/paste new implementation

STEP 3: Actions (15 min)
   └─ Update initialize_conversation_service.dart
   └─ Update simple_recording_button.dart

STEP 4: App State (10 min)
   └─ Verify variables exist
   └─ Add new state tracking

STEP 5: Platform Config (10 min)
   └─ Update AndroidManifest.xml
   └─ Update Info.plist

STEP 6: Documentation (10 min)
   └─ Add AGENTS.md
   └─ Update README.md

STEP 7: Testing (60 min)
   └─ Build and test on physical devices
   └─ Verify all features work

STEP 8: Deployment (15 min)
   └─ Build release APK/IPA
   └─ Deploy to app stores
```

---

## Critical Files to Update

### Must Update (3 files)
1. `pubspec.yaml` - Add SDK dependency
2. `lib/custom_code/elevenlabs_sdk_service.dart` - Create new service
3. `lib/custom_code/actions/initialize_conversation_service.dart` - Update initialization

### Should Update (5 files)
4. `lib/custom_code/widgets/simple_recording_button.dart` - Fix imports
5. `android/app/src/main/AndroidManifest.xml` - Add permissions
6. `ios/Runner/Info.plist` - Add voip mode
7. `lib/app_state.dart` - Add state variables
8. `README.md` - Update documentation

### Optional Update (4 files)
9. `lib/custom_code/actions/stop_conversation_service.dart`
10. `lib/custom_code/actions/toggle_conversation_mic.dart`
11. `AGENTS.md` - Create new file
12. Build configuration files

---

## Copy-Paste Templates

### 1. pubspec.yaml Addition

Find `dependencies:` section and add:

```yaml
  elevenlabs_agents: ^0.3.0
```

### 2. Android Permissions Addition

Find `<uses-permission>` section and add these lines:

```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

### 3. iOS Permissions Addition

Find `<key>UIBackgroundModes</key>` section and ensure it has:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>voip</string>
</array>
```

---

## Pre-Migration Checklist

Before starting, verify:

- [ ] FlutterFlow project is backed up
- [ ] You have access to FlutterFlow custom code editor
- [ ] You can edit AndroidManifest.xml in FlutterFlow
- [ ] You can edit Info.plist in FlutterFlow
- [ ] You have a physical iOS device for testing
- [ ] You have an Android device for testing
- [ ] You have valid ElevenLabs agent ID
- [ ] You have valid backend endpoint URL

---

## Post-Migration Validation

After completing migration, verify:

### Functional Tests
- [ ] App launches without crashes
- [ ] Microphone permission requested and granted
- [ ] Conversation initializes successfully
- [ ] Can speak to agent and get transcriptions
- [ ] Agent speaks and plays audio
- [ ] Can interrupt agent by tapping button
- [ ] Can stop conversation cleanly
- [ ] Reconnection works on network issues

### Quality Tests
- [ ] Audio latency is low (< 1 second)
- [ ] Audio quality is good (no crackling, clear voice)
- [ ] Transcriptions are accurate
- [ ] State updates correctly (recording, playing, idle)
- [ ] UI reflects state changes
- [ ] No console errors

### Platform Tests
- [ ] iOS 14.0+ works
- [ ] Android API 21+ works
- [ ] Both platforms have same behavior
- [ ] Permissions handled correctly
- [ ] Background audio works (iOS)

---

## Rollback Plan

If migration fails, you can rollback in reverse order:

1. **Immediate Rollback** (< 5 min)
   - Restore `conversational_ai_service.dart`
   - Remove `elevenlabs_agents` from pubspec.yaml
   - Revert action changes

2. **Full Rollback** (< 30 min)
   - Restore all files from backup
   - Run `flutter clean`
   - Run `flutter pub get`
   - Test old implementation

---

## Common Migration Errors

### Error: "Could not resolve package 'elevenlabs_agents'"

**Cause**: Dependency not added or `pub get` not run

**Fix**:
```bash
flutter pub get
# Or in FlutterFlow, wait for package resolution
```

### Error: "Undefined name 'ElevenLabsSdkService'"

**Cause**: Service file not created or not saved

**Fix**:
1. Go to FlutterFlow Custom Code
2. Create file `elevenlabs_sdk_service.dart`
3. Paste content from MIGRATION_GUIDE.md STEP 2
4. Click "Save"

### Error: "Too many positional arguments"

**Cause**: Action signature not updated

**Fix**:
1. Go to FlutterFlow Custom Actions
2. Open `initialize_conversation_service`
3. Update signature to:
   ```dart
   Future<void> initializeConversationService(
     String agentId,
     String endpoint,
   )
   ```
4. Remove old parameters from action configuration in FlutterFlow UI

### Error: App crashes on launch

**Cause**: iOS build issue with new dependencies

**Fix**:
```bash
cd ios
rm Podfile.lock
pod install
cd ..
flutter clean
flutter pub get
flutter build ios
```

### Error: "Microphone permission denied"

**Cause**: Android 31+ runtime permissions

**Fix**:
- Ensure `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT` in AndroidManifest.xml
- Test on Android 12+ device
- Check runtime permission request

---

## Success Criteria

Migration is successful when:

✅ All files from FILE_STRUCTURE.md verified
✅ All checklist items in MIGRATION_GUIDE.md complete
✅ App builds for both iOS and Android
✅ Voice conversation works on physical iOS device
✅ Voice conversation works on Android device
✅ No console errors
✅ Audio quality is good
✅ Transcriptions are accurate
✅ Can interrupt and resume conversations

---

## Next Steps After Migration

1. **Monitor** - Watch for any issues in production
2. **Optimize** - Tune audio quality and VAD thresholds if needed
3. **Enhance** - Add any custom features you had in old branch
4. **Document** - Update any custom features for future developers
5. **Deploy** - Push updates to app stores

---

## Additional Resources

### Reference Documents (in MIGRATION/ folder)
- **MIGRATION_GUIDE.md** - Step-by-step detailed instructions
- **AGENTS.md** - Build, lint, and test commands
- **README.md** - Complete project documentation
- **FILE_STRUCTURE.md** - Detailed file comparison

### Main Branch Reference
- Check `main` branch for final implementation
- Use as reference for any issues
- Compare behavior if something doesn't match

### FlutterFlow Resources
- FlutterFlow custom code documentation
- FlutterFlow action builder docs
- FlutterFlow widget customization guides

---

## Support

If you encounter issues:

1. **Check logs** - Use `flutter run --verbose` for detailed output
2. **Verify files** - Compare with main branch using git diff
3. **Test incremental** - Test each step before proceeding to next
4. **Ask questions** - Review main branch for best practices

---

**Last Updated**: 2026-01-04
**Migration Version**: 1.0
**Status**: Ready for Execution
