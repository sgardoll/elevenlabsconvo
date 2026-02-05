# Roadmap: ElevenLabs SDK Migration

## Overview

Migrate from custom WebSocket implementation to official ElevenLabs SDK (`elevenlabs_agents`). The migration follows the critical path: dependencies → service layer → integration → platform configs → testing. Each phase builds on the previous, with testing as the final validation gate.

## Domain Expertise

- Flutter/Dart development patterns
- FlutterFlow custom code conventions
- ElevenLabs Conversational AI SDK
- Mobile platform permissions (iOS/Android)

## Phases

- [ ] **Phase 1: Foundation** - Add SDK dependency and create new service
- [ ] **Phase 2: Integration** - Update actions and widgets to use new service
- [ ] **Phase 3: Platform Config** - Update Android/iOS permissions
- [ ] **Phase 4: Testing** - Verify on physical devices
- [ ] **Phase 5: Documentation** - Update docs and finalize

## Phase Details

### Phase 1: Foundation
**Goal**: Add elevenlabs_agents SDK and replace the core service layer
**Depends on**: Nothing (first phase)
**Research**: Unlikely (migration guide provides exact steps)
**Plans**: 1 plan (verification)

**Status**: Migration already complete in repository. Creating verification plan to confirm.

Plans:
- [ ] 01-01: Verify foundation components are properly integrated

**Verification Checklist**:
- [x] pubspec.yaml has `elevenlabs_agents: ^0.3.0`
- [x] elevenlabs_sdk_service.dart exists (~495 lines, complete implementation)
- [x] conversational_ai_service.dart removed
- [x] Actions use new service (initialize_conversation_service.dart)
- [x] Widgets use new service (simple_recording_button.dart)
- [x] App state variables present
- [x] Android permissions configured (BLUETOOTH_SCAN, BLUETOOTH_CONNECT)
- [x] iOS voip background mode configured

**Next**: Run verification plan, then proceed to Phase 4 (Testing)

### Phase 2: Integration
**Goal**: Update all actions and widgets to use the new service
**Depends on**: Phase 1
**Research**: Unlikely (clear migration path in docs)
**Plans**: 3 plans

Plans:
- [ ] 02-01: Update initialize_conversation_service.dart (simplify params)
- [ ] 02-02: Update simple_recording_button.dart (new imports/methods)
- [ ] 02-03: Verify app_state.dart variables exist

**Critical Notes**:
- Action params reduced from 6 to 2 (agentId, endpoint only)
- Update FlutterFlow action UI to remove old parameters
- Import change: `conversational_ai_service.dart` → `elevenlabs_sdk_service.dart`
- Method change: `interrupt()` → `triggerInterruption()`

### Phase 3: Platform Config
**Goal**: Update platform-specific permissions for WebRTC audio
**Depends on**: Phase 2
**Research**: Unlikely (exact snippets provided in docs)
**Plans**: 2 plans

Plans:
- [ ] 03-01: Update AndroidManifest.xml (add Bluetooth permissions)
- [ ] 03-02: Update Info.plist (add voip background mode)

**Critical Notes**:
- Android: Add BLUETOOTH_SCAN and BLUETOOTH_CONNECT permissions
- iOS: Add voip to UIBackgroundModes array
- Both edits done via FlutterFlow Settings UI, not direct file edit

### Phase 4: Testing
**Goal**: Verify full functionality on physical devices
**Depends on**: Phase 3
**Research**: Unlikely (testing procedures documented)
**Plans**: 3 plans

Plans:
- [ ] 04-01: Build and test on physical iOS device
- [ ] 04-02: Build and test on Android device
- [ ] 04-03: Complete validation checklist

**Critical Notes**:
- **iOS Simulator will NOT work** - must test on physical device
- Test voice capture, agent response, interruption, state updates
- Validation checklist: 12 functional + 6 quality checks

### Phase 5: Documentation
**Goal**: Update project documentation to reflect new SDK
**Depends on**: Phase 4
**Research**: Unlikely (template content available)
**Plans**: 2 plans

Plans:
- [ ] 05-01: Update AGENTS.md with new build/test commands
- [ ] 05-02: Update README.md with SDK information

## Progress

**Execution Order:**
Phases execute sequentially: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 0/1 | Ready to verify | - |
| 2. Integration | N/A | Complete (migrated) | - |
| 3. Platform Config | N/A | Complete (migrated) | - |
| 4. Testing | 0/3 | Not started | - |
| 5. Documentation | N/A | Complete | - |

## Migration Files Reference

All migration documentation in `MIGRATION/` folder:
- QUICK_START.md - Step-by-step (start here)
- MIGRATION_GUIDE.md - Detailed guide with code
- FILE_STRUCTURE.md - File change details
- INDEX.md - Documentation map
- AGENTS.md - Build/lint/test commands (reference copy)
- README.md - Overview (reference copy)

## FlutterFlow-Specific Constraints

### Must Edit via FlutterFlow UI:
- `pubspec.yaml` → Settings → Code
- `AndroidManifest.xml` → Settings → Android
- `Info.plist` → Settings → iOS
- `app_state.dart` → App State panel
- Custom actions/widgets → Custom Code section

### Files to Document for Manual Replication:
Any file outside `lib/custom_code/` that requires changes must be documented with exact steps for FlutterFlow UI replication.
