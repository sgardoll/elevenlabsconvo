# Echo Cancellation & Mic-Gating Testing Checklist

## Overview

This document provides a comprehensive testing checklist for the echo-cancellation and mic-gating improvements implemented in the sgardoll/elevenlabsconvo FlutterFlow library.

## Testing Environment Setup

### Prerequisites

1. **FlutterFlow Project**: Updated with latest custom code changes
2. **Test Device**: Physical Android/iOS device (simulators may not have proper audio hardware)
3. **Audio Environment**: Quiet room with loudspeaker capability
4. **BuildShip Endpoint**: Updated with allow_interrupt parameter (optional)

### Test Equipment

- Physical device with microphone and speaker
- Bluetooth headset (for testing AEC bypass)
- External speaker for feedback testing
- Audio level meter app (optional)

## Platform-Level Echo Cancellation Tests

### Android AEC Tests

#### Test 1: AEC Initialization

```bash
# Run the app and check Android logs
adb logcat | grep -i "aec\|echo"
```

**Expected Results:**

- ✅ "Android AEC enabled for session: [session_id]" in logs
- ✅ No "AEC not available" warnings on modern devices
- ✅ Audio mode set to MODE_IN_COMMUNICATION

#### Test 2: Audio Session Configuration

**Steps:**

1. Launch app and initialize conversation service
2. Check audio session configuration

**Expected Results:**

- ✅ AudioManager.MODE_IN_COMMUNICATION active
- ✅ AcousticEchoCanceler enabled and attached to recording session
- ✅ No audio configuration errors in logs

### iOS AVAudioSession Tests

#### Test 3: Audio Session Setup

**Steps:**

1. Launch app on iOS device
2. Check console logs for audio session configuration

**Expected Results:**

- ✅ "iOS AVAudioSession configured for conversational AI with echo cancellation"
- ✅ Category: .playAndRecord
- ✅ Mode: .voiceChat
- ✅ Sample Rate: 16kHz
- ✅ Buffer Duration: 5ms

#### Test 4: Audio Session Activation

**Steps:**

1. Start conversation
2. Monitor for audio session activation

**Expected Results:**

- ✅ Audio session activates without errors
- ✅ Both recording and playback available simultaneously
- ✅ Echo cancellation processing active

## Enhanced Mic Gating Tests

### Stream Subscription Tests

#### Test 5: Mode Change Response Time

**Steps:**

1. Start conversation
2. Trigger agent response
3. Monitor mic pause timing

**Expected Results:**

- ✅ "Mode change detected: speaking" in logs
- ✅ "Recording paused via enhanced mode listener (< 5ms)" message
- ✅ Microphone pauses within 5ms of agent speech start

#### Test 6: Stream-Based Resume

**Steps:**

1. During agent speech, speak loudly into microphone
2. Monitor resume timing

**Expected Results:**

- ✅ "Mode change detected: listening" in logs
- ✅ "Recording resumed via enhanced mode listener (< 5ms)" message
- ✅ Microphone resumes within 5ms of mode change

### Soft Ducking Tests

#### Test 7: Speaker Volume Ducking

**Steps:**

1. Start conversation with volume at maximum
2. Trigger agent response
3. Monitor volume changes

**Expected Results:**

- ✅ "Speaker volume ducked to prevent feedback" in logs
- ✅ Audio volume reduces to 0.25 (12 dB reduction) during agent speech
- ✅ "Speaker volume restored" when agent finishes

#### Test 8: Volume Restoration

**Steps:**

1. Complete agent response
2. Monitor volume restoration

**Expected Results:**

- ✅ Volume returns to 1.0 after agent speech
- ✅ No audio distortion during volume changes
- ✅ Smooth volume transitions

## VAD Enhancement Tests

### Amplitude Monitoring Tests

#### Test 9: Dead Air Filtering

**Steps:**

1. Start recording in silent environment
2. Monitor audio chunk processing

**Expected Results:**

- ✅ Audio chunks below -50 dB threshold are dropped
- ✅ No unnecessary packets sent during silence
- ✅ VAD threshold approximately 0.003 level

#### Test 10: Voice Activity Detection

**Steps:**

1. Speak at normal volume
2. Monitor audio level processing

**Expected Results:**

- ✅ Speech above threshold is processed normally
- ✅ Audio level meter shows activity during speech
- ✅ No false positives from background noise

## Echo Loop Prevention Tests

### Feedback Detection Tests

#### Test 11: Basic Echo Prevention

**Setup:** Speaker at 70 dB SPL, microphone 30 cm away
**Steps:**

1. Start conversation
2. Let agent speak
3. Monitor for echo detection

**Expected Results:**

- ✅ Agent does not transcribe its own reply
- ✅ No feedback loops detected in logs
- ✅ Clean audio isolation between input/output

#### Test 12: High Volume Feedback Test

**Setup:** External speaker at high volume
**Steps:**

1. Increase speaker volume significantly
2. Start conversation
3. Monitor for feedback prevention

**Expected Results:**

- ✅ "Audio feedback detected - ignoring chunk" messages
- ✅ No runaway feedback loops
- ✅ Emergency feedback prevention activates if needed

#### Test 13: Room Echo Test

**Setup:** Test in reverberant room
**Steps:**

1. Position device away from walls
2. Test conversation with room echo

**Expected Results:**

- ✅ Room echo doesn't trigger false feedback detection
- ✅ Agent speech tail doesn't cause interruption
- ✅ Adaptive echo threshold adjusts appropriately

## Public API Tests

### FlutterFlow Integration Tests

#### Test 14: MuteMic Action

**Steps:**

1. Create UI button in FlutterFlow
2. Bind to muteMic(context, true) action
3. Test mute/unmute functionality

**Expected Results:**

- ✅ "Microphone muted via FlutterFlow action" in logs
- ✅ Recording pauses when mute = true
- ✅ Recording resumes when mute = false
- ✅ App state updates correctly

#### Test 15: Real-time Mute Control

**Steps:**

1. Start conversation
2. Use mute toggle during agent speech
3. Verify immediate response

**Expected Results:**

- ✅ Immediate microphone control response
- ✅ No audio processing delays
- ✅ Smooth state transitions

## Device-Specific Tests

### Bluetooth Audio Tests

#### Test 16: Bluetooth Headset AEC

**Setup:** Connect Bluetooth headset
**Steps:**

1. Start conversation with Bluetooth audio
2. Test echo cancellation

**Expected Results:**

- ✅ AEC handled by headset hardware
- ✅ allowBluetoothA2DP setting active
- ✅ No additional software echo cancellation needed

#### Test 17: Bluetooth Audio Switching

**Steps:**

1. Start conversation with built-in audio
2. Connect Bluetooth headset mid-conversation
3. Continue conversation

**Expected Results:**

- ✅ Audio seamlessly switches to Bluetooth
- ✅ Echo cancellation adapts to new audio path
- ✅ No audio dropouts during transition

### Hardware-Specific Tests

#### Test 18: Different Device Models

**Test on multiple devices:**

- Modern flagship phones
- Budget Android devices
- Older iOS devices
- Tablets

**Expected Results:**

- ✅ AEC available on most modern devices
- ✅ Graceful degradation on devices without hardware AEC
- ✅ Consistent performance across device types

## Integration Tests

### End-to-End Conversation Tests

#### Test 19: Full Conversation Flow

**Steps:**

1. Initialize conversation service
2. Complete full conversation with multiple turns
3. Test interruptions and resumptions

**Expected Results:**

- ✅ No echo artifacts throughout conversation
- ✅ Smooth turn-taking behavior
- ✅ Reliable interruption handling

#### Test 20: Stress Test

**Steps:**

1. Run continuous conversation for 10+ minutes
2. Perform frequent interruptions
3. Monitor for audio degradation

**Expected Results:**

- ✅ Consistent performance over time
- ✅ No memory leaks or resource issues
- ✅ Reliable echo cancellation throughout

## Performance Validation

### Latency Tests

#### Test 21: Mode Change Latency

**Steps:**

1. Use audio analysis tools to measure timing
2. Monitor mode change response times

**Expected Results:**

- ✅ Mode changes complete in < 5ms
- ✅ Audio processing gaps < 20ms
- ✅ Smooth real-time performance

#### Test 22: Resource Usage

**Steps:**

1. Monitor CPU and memory usage during conversation
2. Compare with baseline implementation

**Expected Results:**

- ✅ Minimal additional CPU overhead
- ✅ No significant memory increase
- ✅ Efficient stream processing

## Troubleshooting Common Issues

### Debug Commands

```bash
# Android AEC status
adb logcat | grep -i "aec\|acousticecho"

# iOS audio session logs
# Use Xcode console and filter for "AVAudioSession"

# Flutter debug logs
flutter logs | grep -E "🎤|🔇|🔊"
```

### Common Issues and Solutions

1. **AEC Not Available**

   - Verify device supports hardware AEC
   - Check audio permissions
   - Ensure correct audio source configuration

2. **Feedback Still Present**

   - Increase VAD threshold
   - Adjust soft ducking level
   - Check for hardware-specific audio routing issues

3. **Mode Changes Too Slow**
   - Verify stream subscription setup
   - Check for blocking operations in listener
   - Monitor for background audio interference

## Success Criteria

### Minimum Requirements

- ✅ No agent self-hearing in normal conditions
- ✅ Mode changes complete in < 20ms
- ✅ Soft ducking reduces feedback by 12 dB minimum
- ✅ VAD filters dead air below -50 dB

### Optimal Performance

- ✅ Mode changes complete in < 5ms
- ✅ Zero false positives in feedback detection
- ✅ Seamless audio quality during all operations
- ✅ Reliable performance across all supported devices

## Test Report Template

```markdown
## Echo Cancellation Test Results

**Date:** [Test Date]
**Device:** [Device Model/OS Version]
**Environment:** [Testing Environment Description]

### Platform AEC

- [ ] Android AEC Enabled
- [ ] iOS Audio Session Configured
- [ ] No Audio Configuration Errors

### Enhanced Mic Gating

- [ ] Mode Changes < 5ms
- [ ] Stream Subscriptions Working
- [ ] Soft Ducking Active

### VAD Enhancement

- [ ] Dead Air Filtering
- [ ] Voice Activity Detection
- [ ] Amplitude Monitoring

### Echo Prevention

- [ ] No Agent Self-Hearing
- [ ] Feedback Loop Prevention
- [ ] Room Echo Handling

### Public API

- [ ] MuteMic Action Working
- [ ] FlutterFlow Integration
- [ ] Real-time Control

### Performance

- [ ] Latency < 20ms
- [ ] Resource Usage Acceptable
- [ ] Stable Long-term Operation

**Overall Result:** PASS/FAIL
**Notes:** [Additional observations]
```

This testing checklist ensures comprehensive validation of all echo cancellation and mic-gating improvements. Follow each section systematically to verify the implementation delivers the expected no-echo experience while maintaining ultra-low latency performance.
