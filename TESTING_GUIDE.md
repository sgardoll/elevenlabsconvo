# Conversational AI Service Testing Guide

## 🧪 Test Configuration

**Agent ID**: `agent_01jzmvwhxhf6kaya6n6zbtd0s1`  
**Endpoint**: `https://515q53.buildship.run/GetSignedUrl`  
**Test Status**: ✅ Ready for Testing

## 🚀 Setup Verification

### ✅ Pre-flight Checks Completed

- [x] Library values updated with test configuration
- [x] Signed URL endpoint tested and working
- [x] Android permissions configured correctly
- [x] iOS permissions configured correctly
- [x] Build issues resolved (WAV format for all platforms)
- [x] Android build successful
- [x] Android app deployed to device

### 📱 Test Environments

- **Android**: Samsung SM F741B (API 35) ✅ Ready
- **iOS**: iPhone 16 Pro Simulator ⏳ Testing

## 🎯 Testing Steps

### 1. App Launch Test

1. Open the app on your device
2. **Expected**: App requests microphone permission
3. **Expected**: Service initializes automatically
4. **Expected**: Connection established with ElevenLabs
5. **Check**: Recording button becomes active (not grayed out)

### 2. Basic Recording Test

1. Tap the recording button (should turn red and pulse)
2. Speak clearly: "Hello, can you hear me?"
3. Tap the button again to stop recording
4. **Expected**: Agent responds with audio playback
5. **Expected**: Conversation message appears in UI

### 3. Conversation Flow Test

1. Start a natural conversation
2. Try phrases like:
   - "What's the weather like today?"
   - "Tell me a joke"
   - "How are you doing?"
3. **Expected**: Natural back-and-forth conversation
4. **Expected**: Proper turn-taking (no overlapping speech)

### 4. Interruption Test

1. Start recording and let the agent respond
2. While agent is speaking, tap the recording button
3. **Expected**: Agent stops immediately
4. **Expected**: You can speak without echo/feedback
5. **Expected**: Conversation continues naturally

### 5. Audio Quality Test

1. Test in quiet environment
2. Test with background noise
3. Test with different speaking volumes
4. **Expected**: Clear audio transmission both ways
5. **Expected**: No echo or feedback loops

## 🔍 Advanced Testing

### Audio Isolation & Feedback Prevention

- **Test**: Speak while agent is talking
- **Expected**: No feedback loops or echoing
- **Expected**: Recording pauses during agent speech

### Session Management

- **Test**: Long conversation (5+ exchanges)
- **Expected**: Consistent session throughout
- **Expected**: No connection drops or resets

### Error Recovery

- **Test**: Disable/enable network during conversation
- **Expected**: Automatic reconnection
- **Expected**: Service continues after network restored

## 📊 Test Results Checklist

### Core Functionality

- [ ] Service initializes successfully
- [ ] WebSocket connection established
- [ ] Recording starts/stops properly
- [ ] Audio playback works correctly
- [ ] UI updates reflect current state

### Audio Quality

- [ ] Clear voice transmission
- [ ] No echo or feedback
- [ ] Proper volume levels
- [ ] No audio distortion

### Conversation Flow

- [ ] Natural turn-taking
- [ ] Interruption handling works
- [ ] Multiple exchanges successful
- [ ] Conversation messages display correctly

### Platform-Specific

#### Android (Samsung SM F741B)

- [ ] WAV audio encoding works
- [ ] Microphone permissions granted
- [ ] Storage permissions handled
- [ ] Audio quality acceptable

#### iOS (iPhone 16 Pro Simulator)

- [ ] WAV audio encoding works (simplified from MP3)
- [ ] Microphone permissions granted
- [ ] AVAudioSession configured properly
- [ ] Background audio permissions

## 🐛 Troubleshooting

### If Connection Fails

1. Check internet connectivity
2. Verify endpoint URL is accessible
3. Check signed URL generation in logs
4. Restart app and try again

### If Recording Doesn't Work

1. Verify microphone permissions
2. Check for other apps using microphone
3. Test with built-in voice recorder app
4. Restart app and retry

### If Audio Playback Fails

1. Check device volume settings
2. Test with other audio apps
3. Verify audio files are being created
4. Check temporary directory permissions

### If Echo/Feedback Occurs

1. Use headphones/earbuds
2. Lower device volume
3. Ensure echo cancellation is enabled
4. Check for hardware audio issues

## 🎉 Success Criteria

### Minimum Viable Test

- ✅ App launches without crashes
- ✅ Service connects to ElevenLabs
- ✅ One successful recording → response cycle
- ✅ Audio quality is acceptable
- ✅ No major audio feedback issues

### Full Feature Test

- ✅ All basic functionality working
- ✅ Interruption handling works properly
- ✅ Multiple conversation exchanges
- ✅ Error recovery mechanisms
- ✅ Platform-specific optimizations active

## 📱 Debug Information

### Viewing Logs

To see detailed debug information:

1. Connect device to computer
2. Run `flutter logs` while testing
3. Look for messages starting with:
   - `🔌 Conversational AI Service`
   - `🔐 Signed URL`
   - `🎙️ Recording`
   - `🔊 Audio`

### Common Log Messages

- `🔌 Service connected successfully`
- `🔐 Signed URL cached successfully`
- `🎙️ Recording started successfully`
- `🔊 Started new audio session`
- `🔇 Audio feedback detected` (should be rare)

## 📝 Test Report Template

```
## Test Results for [Platform]

**Date**: [Date]
**Device**: [Device Info]
**App Version**: Debug Build

### Test Results:
- Connection: ✅/❌
- Recording: ✅/❌
- Playback: ✅/❌
- Conversation: ✅/❌
- Interruption: ✅/❌

### Issues Found:
- [Describe any issues]

### Audio Quality Rating: [1-5 stars]

### Overall Assessment: [Pass/Fail]
```

---

## 🔧 Developer Notes

- Service uses WAV format for all platforms (simplified from original MP3/WAV split)
- Echo cancellation includes multiple layers for robust feedback prevention
- Session isolation prevents cross-conversation audio contamination
- Adaptive VAD thresholds adjust based on device characteristics
- Smart recording pause during agent speech prevents feedback loops

**Ready for comprehensive testing!** 🚀
