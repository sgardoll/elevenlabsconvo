# Migration Documentation Index

## Overview

This folder contains complete documentation for migrating your FlutterFlow project from the **flutterflow branch** to **main branch** compatibility.

---

## What You're Doing

**Migration Goal**: Replace custom WebSocket implementation with official ElevenLabs SDK

**Why**: Main branch uses `elevenlabs_agents` package which provides:
- Lower latency (100-200ms vs 500-1000ms)
- Better reliability (WebRTC vs custom WebSocket)
- Official support and updates from ElevenLabs
- Less custom code to maintain

---

## Document Map

| Document | Purpose | When to Use | Length |
|----------|-------------|-------------|
| **QUICK_START.md** | Step-by-step instructions | Start here (quick reference) |
| **MIGRATION_GUIDE.md** | Detailed guide with full code | Need implementation details |
| **FILE_STRUCTURE.md** | File-by-file comparison | Understanding what changed |
| **README.md** | Overview and best practices | High-level understanding |
| **AGENTS.md** | Build/test/lint commands | Development workflow |

---

## Recommended Reading Order

### For Fast Migration (2 hours)
1. **QUICK_START.md** - Follow steps 1-10
2. Verify with checklist at the end
3. Test on physical devices

### For Detailed Migration (4 hours)
1. **FILE_STRUCTURE.md** - Understand what's changing
2. **README.md** - Review benefits and risks
3. **MIGRATION_GUIDE.md** - Follow all steps with detailed explanations
4. **AGENTS.md** - Update development workflow

### For Troubleshooting
1. **QUICK_START.md** - Check "Troubleshooting" section
2. **MIGRATION_GUIDE.md** - Check "Common Issues" section
3. **README.md** - Check "Rollback Plan" section

---

## Key Changes Summary

### Files You Must Create/Update

| # | File | Action | Complexity |
|---|--------|---------|-----------|
| 1 | `pubspec.yaml` | Add dependency | Easy (1 line) |
| 2 | `elevenlabs_sdk_service.dart` | Create new | Medium (495 lines) |
| 3 | `conversational_ai_service.dart` | Delete | Easy |
| 4 | `initialize_conversation_service.dart` | Update parameters | Easy |
| 5 | `simple_recording_button.dart` | Update imports | Easy |
| 6 | `AndroidManifest.xml` | Add permissions | Easy (2 lines) |
| 7 | `Info.plist` | Add voip mode | Easy (1 line) |
| 8 | `app_state.dart` | Verify variables | Easy |

### Files You Should Update (Optional)

| # | File | Action | Priority |
|---|--------|---------|----------|
| 9 | `stop_conversation_service.dart` | Update service calls | Low |
| 10 | `toggle_conversation_mic.dart` | Update service calls | Low |
| 11 | `AGENTS.md` | Create from main branch | Medium |
| 12 | `README.md` | Update content | Medium |

---

## File Locations

All files referenced in this guide are in your FlutterFlow project:

### Custom Code
```
lib/custom_code/
├── actions/
│   ├── initialize_conversation_service.dart   # UPDATE (STEP 4)
│   ├── stop_conversation_service.dart      # OPTIONAL (STEP 9)
│   └── toggle_conversation_mic.dart        # OPTIONAL (STEP 10)
├── widgets/
│   └── simple_recording_button.dart       # UPDATE (STEP 5)
├── elevenlabs_sdk_service.dart             # CREATE (STEP 2) [NEW FILE]
└── conversational_ai_service.dart          # DELETE (STEP 3)
```

### Configuration
```
pubspec.yaml                                    # UPDATE (STEP 1)
android/app/src/main/AndroidManifest.xml          # UPDATE (STEP 6)
ios/Runner/Info.plist                            # UPDATE (STEP 7)
```

### App State
```
lib/app_state.dart                                # VERIFY (STEP 8)
```

### Documentation
```
AGENTS.md                                       # OPTIONAL (STEP 11)
README.md                                       # OPTIONAL (STEP 12)
```

---

## Critical Path (Must Follow in Order)

### Phase 1: Foundation (15 min)
```
1. Add dependency to pubspec.yaml
2. Create elevenlabs_sdk_service.dart
3. Delete conversational_ai_service.dart
```

### Phase 2: Integration (20 min)
```
4. Update initialize_conversation_service
5. Update simple_recording_button
6. Verify app state variables
```

### Phase 3: Platform Config (10 min)
```
7. Update Android permissions
8. Update iOS permissions
```

### Phase 4: Testing (60+ min)
```
9. Build and test on physical iOS device
10. Build and test on Android device
11. Verify all features work
```

### Phase 5: Documentation (Optional - 15 min)
```
12. Add AGENTS.md
13. Update README.md
```

---

## Quick Commands

### Before Starting
```bash
# Backup your project
flutter clean

# Verify current state
flutter doctor
```

### During Migration
```bash
# After updating pubspec.yaml
flutter pub get

# Check for errors
flutter analyze

# Test build
flutter build apk --debug
```

### After Migration
```bash
# Clean build artifacts
flutter clean

# Get fresh dependencies
flutter pub get

# Analyze for issues
flutter analyze

# Run tests
flutter test

# Build for release
flutter build apk --release
flutter build ios --release
```

---

## Migration Time Estimates

| Phase | Minimum | Recommended |
|-------|----------|--------------|
| Phase 1: Foundation | 10 min | 15 min |
| Phase 2: Integration | 15 min | 20 min |
| Phase 3: Platform Config | 5 min | 10 min |
| Phase 4: Testing | 30 min | 60 min |
| Phase 5: Documentation | 10 min | 15 min |
| **Total** | **70 min** | **2 hours** |

---

## Success Metrics

Migration is complete when:

### Build & Deploy
✅ No build errors for iOS
✅ No build errors for Android
✅ App launches on both platforms

### Functionality
✅ Voice conversation works on physical iOS device
✅ Voice conversation works on Android device
✅ Microphone audio captures correctly
✅ Agent audio plays clearly
✅ Transcriptions display in real-time
✅ Can interrupt agent speech
✅ Can stop conversation
✅ Reconnection works

### Quality
✅ Audio latency < 1 second
✅ Audio quality is clear (no distortion)
✅ Transcription accuracy > 90%
✅ State updates reflect actual status
✅ No console errors during normal operation

---

## Support Resources

### Within This Repo
- **MIGRATION/** - All migration documentation
- **main branch** - Reference implementation
- **flutterflow branch** - Starting point

### External Resources
- [FlutterFlow Documentation](https://flutterflow.com/docs)
- [ElevenLabs SDK Docs](https://pub.dev/packages/elevenlabs_agents)
- [ElevenLabs GitHub](https://github.com/elevenlabs/elevenlabs-flutter)

---

## Common Questions

### Q: Can I migrate in stages?

**A**: Yes! You can do Phase 1-3, test, then continue to Phase 4-5. However, it's faster to complete all code changes (Phases 1-3) before testing.

### Q: What if I have custom features in conversational_ai_service.dart?

**A**: You'll need to port them to `elevenlabs_sdk_service.dart`. The official SDK provides most features automatically. Check MIGRATION_GUIDE.md for examples of how to extend the service.

### Q: Do I need to delete the old service file?

**A**: Yes, to avoid confusion and build errors. Rename to `.backup` if you want to keep it for reference.

### Q: Can I test on iOS Simulator?

**A**: No! iOS Simulator cannot capture microphone audio for WebRTC. You MUST test on a physical iOS device for voice conversation features.

### Q: What if I encounter build errors?

**A**: Check each document's "Troubleshooting" section. Most common issues are:
- Missing dependency (run `flutter pub get`)
- Old action parameters (update action config in FlutterFlow)
- Import errors (check file names and paths)

---

## Next Steps

After completing migration:

1. **Monitor** production use for issues
2. **Optimize** audio quality if needed
3. **Enhance** with any custom features
4. **Document** changes for team
5. **Deploy** to app stores

---

## Version History

- **v1.0** (2026-01-04): Initial migration guide
- Supports: flutterflow → main branch compatibility
- SDK Version: elevenlabs_agents ^0.3.0
- FlutterFlow Platform Support: Yes

---

**Last Updated**: 2026-01-04
**Documentation Version**: 1.0
**Status**: Production Ready
