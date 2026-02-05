# Project: ElevenLabs SDK Migration

## One-Liner
Migrate FlutterFlow ElevenLabs integration from custom WebSocket to official `elevenlabs_agents` SDK for better reliability, lower latency, and reduced maintenance.

## Core Value
Enable real-time voice conversations with 100-200ms latency via WebRTC instead of 500-1000ms via WebSocket, while eliminating custom audio code maintenance burden.

## Success Criteria

### Functional
- [ ] Voice conversation works on physical iOS device (iOS 14.0+)
- [ ] Voice conversation works on Android device (API 21+)
- [ ] Microphone captures audio correctly
- [ ] Agent audio plays clearly
- [ ] Transcriptions display in real-time
- [ ] Can interrupt agent speech
- [ ] Can stop conversation cleanly

### Technical
- [ ] No build errors for iOS
- [ ] No build errors for Android
- [ ] `flutter analyze` passes
- [ ] All imports resolve correctly
- [ ] No console errors during operation

### Quality
- [ ] Audio latency < 1 second
- [ ] Audio quality clear (no distortion)
- [ ] Transcription accuracy > 90%
- [ ] State updates reflect actual status

## Constraints

### FlutterFlow-Specific
- **Custom Code Only**: All code changes must be in `lib/custom_code/` directory
- **FlutterFlow UI**: App State variables configured via FlutterFlow interface
- **Platform Configs**: AndroidManifest.xml and Info.plist edited via FlutterFlow Settings
- **No Direct Edits**: Cannot edit files outside custom_code in repo (must replicate in FlutterFlow)

### Platform
- iOS Simulator: Cannot test voice (WebRTC limitation) - requires physical device
- Android 12+: Requires new Bluetooth permissions
- iOS 14+: Requires voip background mode

## Key Decisions

| Decision | Context | Implication |
|----------|---------|-------------|
| Use official SDK | elevenlabs_agents ^0.3.0 | Replaces ~500 lines custom code |
| Token-based auth | Secure backend endpoint | API key never exposed client-side |
| WebRTC over WebSocket | Lower latency, better reliability | iOS Simulator won't work for voice |
| Simplified action params | Remove firstMessage, language, etc. | Breaking change - update FlutterFlow actions |

## Anti-Goals

- **No new features**: Migration only, no enhancements
- **No UI redesign**: Keep existing FlutterFlow UI
- **No backend changes**: Use existing token endpoint
- **No custom audio logic**: Let SDK handle all audio

## Unknowns

| Unknown | Impact | Plan |
|---------|--------|------|
| FlutterFlow package resolution timing | Medium | Monitor after pubspec.yaml update |
| iOS build issues with new SDK | Medium | Clean build if needed (rm Podfile.lock) |
| Existing custom features in old service | Low | Port if any found during migration |

## References

- MIGRATION/QUICK_START.md - Step-by-step guide
- MIGRATION/FILE_STRUCTURE.md - File change details
- MIGRATION/README.md - Overview and best practices
- pub.dev/packages/elevenlabs_agents - Official SDK docs

## Definition of Done

1. All 8 critical files updated (pubspec, service, actions, configs)
2. App builds successfully for both platforms
3. Voice conversation verified on physical iOS device
4. Voice conversation verified on Android device
5. All validation checklist items complete
6. Migration documentation updated
