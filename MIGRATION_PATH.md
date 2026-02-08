# Migration Path: FlutterFlow Branch → Main Branch Compatibility

## Overview

This repository contains complete migration documentation to update your FlutterFlow project from the **flutterflow branch** (custom WebSocket implementation) to **main branch** (official ElevenLabs SDK) compatibility.

**All documentation is in the `MIGRATION/` folder.**

---

## Quick Summary

**What's Changing**:
- Replace custom `ConversationalAIService` with official `ElevenLabsSdkService`
- Add `elevenlabs_agents: ^0.3.0` dependency
- Update platform permissions for modern Android/iOS
- Update documentation and best practices

**Why Migrate**:
- ✅ Lower latency (100-200ms vs 500-1000ms)
- ✅ Better reliability (WebRTC vs custom WebSocket)
- ✅ Official support and automatic updates
- ✅ Less custom code to maintain

**Migration Time**: 2-3 hours (recommended) or 1-2 hours (fast)

---

## Where to Start

### For Fast Migration (Recommended)
**Read**: `MIGRATION/QUICK_START.md`

Contains:
- Step-by-step instructions (10 steps)
- Copy-paste code templates
- Validation checklist
- Troubleshooting guide

**Estimated Time**: 1-2 hours

### For Detailed Migration
**Read**: `MIGRATION/MIGRATION_GUIDE.md`

Contains:
- Complete implementation details
- Full code for all files
- Common issues and solutions
- Rollback plan

**Estimated Time**: 2-3 hours

### For Understanding Changes
**Read**: `MIGRATION/FILE_STRUCTURE.md`

Contains:
- File-by-file comparison
- What changed and why
- Migration priority
- Testing strategy

---

## Migration Documents

| Document | Purpose | Length | Audience |
|-----------|-------------|-----------|
| **MIGRATION/INDEX.md** | Document map and overview | All users |
| **MIGRATION/QUICK_START.md** | Step-by-step quick guide | Developers in hurry |
| **MIGRATION/MIGRATION_GUIDE.md** | Detailed implementation guide | All developers |
| **MIGRATION/FILE_STRUCTURE.md** | File comparison details | Architects/leads |
| **MIGRATION/README.md** | Overview and best practices | Project managers |
| **MIGRATION/AGENTS.md** | Build/test/lint commands | DevOps/CI |
| **MIGRATION/README.md** (from main) | Full project documentation | All users |

---

## Files You Need to Change

### Critical (Must Do)
1. `pubspec.yaml` - Add `elevenlabs_agents: ^0.3.0`
2. `lib/custom_code/elevenlabs_sdk_service.dart` - CREATE (new service)
3. `lib/custom_code/actions/initialize_conversation_service.dart` - UPDATE parameters

### Important (Should Do)
4. `lib/custom_code/widgets/simple_recording_button.dart` - UPDATE imports
5. `android/app/src/main/AndroidManifest.xml` - ADD Android 31+ permissions
6. `ios/Runner/Info.plist` - ADD voip background mode

### Optional (Nice to Have)
7. `lib/app_state.dart` - VERIFY state variables
8. `README.md` - UPDATE documentation
9. `AGENTS.md` - CREATE (copy from MIGRATION/)
10. Other action files - UPDATE service calls

---

## Migration Path

### Phase 1: Foundation (Code Changes)
```
STEP 1: Add dependency to pubspec.yaml (5 min)
STEP 2: Create elevenlabs_sdk_service.dart (20 min)
STEP 3: Delete old conversational_ai_service.dart (2 min)
STEP 4: Update initialize_conversation_service (10 min)
STEP 5: Update simple_recording_button (5 min)
```

### Phase 2: Platform Configuration
```
STEP 6: Update AndroidManifest.xml permissions (5 min)
STEP 7: Update Info.plist background modes (5 min)
STEP 8: Verify app state variables (5 min)
```

### Phase 3: Testing & Deployment
```
STEP 9: Test on physical iOS device (30 min)
STEP 10: Test on Android device (30 min)
STEP 11: Verify all features work (15 min)
STEP 12: Build for release (10 min)
```

### Phase 4: Documentation (Optional)
```
STEP 13: Update README.md (10 min)
STEP 14: Add AGENTS.md (5 min)
```

---

## Key Benefits After Migration

| Feature | Before | After | Improvement |
|----------|----------|---------|--------------|
| **Audio Latency** | 500-1000ms | 100-200ms | 5-10x faster |
| **Reliability** | Custom WebSocket | Official WebRTC | Battle-tested |
| **Support** | Manual fixes | Official SDK updates | Automatic |
| **Maintenance** | High | Low | Less custom code |
| **Permissions** | Basic | Modern (Android 31+, iOS 14+) | Better compatibility |
| **Documentation** | Minimal | Comprehensive | Easier onboarding |

---

## Testing Requirements

### Critical Requirements

**You MUST test on physical devices**:

- [ ] **Physical iOS device** (iPhone with iOS 14.0+)
  - iOS Simulator does NOT work for voice features
  - Reason: WebRTC microphone limitations on simulator

- [ ] **Android device** (API 21+, recommended Android 12+)
  - Verify Bluetooth permissions on Android 12+

### Test Coverage

After migration, test:
- [ ] App launches without crashes
- [ ] Microphone permission granted
- [ ] Conversation initializes successfully
- [ ] Voice input captured (transcripts show real speech, not "...")
- [ ] Agent audio plays clearly
- [ ] Can interrupt agent by tapping
- [ ] State updates correctly in UI
- [ ] Can stop conversation cleanly

---

## Rollback Plan

If migration encounters issues:

### Immediate Rollback (< 5 min)
1. Restore `conversational_ai_service.dart`
2. Remove `elevenlabs_agents` from pubspec.yaml
3. Revert action changes in FlutterFlow
4. Run `flutter pub get`

### Full Rollback (< 30 min)
1. Restore all files from git backup
2. Run `flutter clean`
3. Run `flutter pub get`
4. Test old implementation
5. Verify features work

---

## Common Issues & Solutions

### Issue: "Could not find package 'elevenlabs_agents'"

**Cause**: Dependency not added or `pub get` failed

**Solution**:
```bash
flutter pub get
# In FlutterFlow, wait for package resolution
```

### Issue: "Undefined name 'ElevenLabsSdkService'"

**Cause**: Service file not created or not saved in FlutterFlow

**Solution**:
1. Go to FlutterFlow Custom Code
2. Create `elevenlabs_sdk_service.dart`
3. Paste full content from MIGRATION_GUIDE.md
4. Click "Save" and wait for processing

### Issue: iOS Simulator shows "..." for transcripts

**Cause**: **This is expected behavior** - iOS Simulator cannot capture microphone audio for WebRTC

**Solution**: Test on a physical iOS device, not simulator.

### Issue: Android permission denied on runtime

**Cause**: Android 12+ requires new runtime permissions

**Solution**:
- Ensure `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT` in AndroidManifest.xml
- Rebuild APK
- Clear app data and reinstall
- Grant permissions when prompted

### Issue: Action has wrong parameters

**Cause**: FlutterFlow action configuration still has old parameters

**Solution**:
1. Open `initialize_conversation_service` in FlutterFlow
2. Remove old parameters from action settings:
   - `firstMessage`
   - `language`
   - `keepMicHotDuringAgent`
   - `autoStartMic`
3. Save action

---

## Success Criteria

Migration is complete when:

### Build & Deploy
✅ App builds successfully for iOS
✅ App builds successfully for Android
✅ No compilation errors or warnings
✅ App launches without crashes

### Functionality
✅ Voice conversation works on physical iOS device
✅ Voice conversation works on Android device
✅ Transcriptions show real speech (not "...")
✅ Agent audio plays clearly
✅ Latency is low (< 1 second)
✅ Can interrupt agent by tapping button
✅ State updates in UI correctly
✅ Can stop and restart conversations

### Quality
✅ Audio quality is clear (no distortion)
✅ Transcription accuracy is high
✅ No console errors during normal operation
✅ Reconnection works on network issues
✅ Background audio works on iOS

---

## Support & Resources

### In This Repository
- **MIGRATION/** - All migration documentation
- **main branch** - Reference implementation (source of truth)
- **flutterflow branch** - Your current starting point

### External Resources
- [FlutterFlow Documentation](https://docs.flutterflow.io/)
- [ElevenLabs SDK](https://pub.dev/packages/elevenlabs_agents)
- [ElevenLabs GitHub](https://github.com/elevenlabs/elevenlabs-flutter)
- [Flutter Docs](https://flutter.dev/docs)

---

## Quick Commands

### Before Migration
```bash
# Clean build artifacts
flutter clean

# Check Flutter installation
flutter doctor

# Backup current branch
git checkout -b backup-before-migration
```

### During Migration
```bash
# After updating dependencies
flutter pub get

# Check for issues
flutter analyze

# Test build
flutter build apk --debug
```

### After Migration
```bash
# Clean and rebuild
flutter clean
flutter pub get

# Run tests
flutter test

# Build for release
flutter build apk --release
flutter build ios --release
```

---

## Next Steps

1. **Review** MIGRATION/QUICK_START.md
2. **Complete** migration following steps 1-10
3. **Test** thoroughly on physical devices
4. **Validate** using success criteria above
5. **Deploy** to production when confident

---

**Documentation Version**: 1.0
**Last Updated**: 2026-01-04
**Status**: Ready for Migration
**Supported FlutterFlow Version**: All recent versions
**Target SDK Version**: elevenlabs_agents ^0.3.0
