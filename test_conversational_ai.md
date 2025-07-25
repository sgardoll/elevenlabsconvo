# Conversational AI Service Testing Plan

## Configuration

- **Agent ID**: `agent_01jzmvwhxhf6kaya6n6zbtd0s1`
- **Endpoint**: `https://515q53.buildship.run/GetSignedUrl`

## Test Platforms

- [x] iOS Simulator (iPhone 16 Pro)
- [ ] Android Device (Samsung SM F741B)

## Test Cases

### 1. Service Initialization

- [ ] Verify connection to ElevenLabs service
- [ ] Verify signed URL retrieval from endpoint
- [ ] Check WebSocket connection establishment
- [ ] Validate conversation session creation

### 2. Audio Permissions

- [ ] Microphone permission requested and granted (iOS)
- [ ] Microphone permission requested and granted (Android)
- [ ] Bluetooth permission handling
- [ ] Background audio permission (iOS)

### 3. Recording Functionality

- [ ] Start recording with button tap
- [ ] Stop recording with button tap
- [ ] Visual feedback (button animation, color changes)
- [ ] Audio stream transmission to ElevenLabs
- [ ] VAD (Voice Activity Detection) working

### 4. Audio Playback

- [ ] Agent response audio playback
- [ ] Multiple audio chunks handling
- [ ] Audio quality verification
- [ ] Interruption handling (tap to interrupt agent)

### 5. Echo Cancellation & Feedback Prevention

- [ ] Recording pauses during agent speech
- [ ] No feedback loops detected
- [ ] Audio signature detection working
- [ ] Hardware-specific optimizations active

### 6. Real-time Conversation

- [ ] User speech transcription displayed
- [ ] Agent responses displayed
- [ ] Turn-taking functionality
- [ ] Interruption handling
- [ ] Session isolation

### 7. Error Handling

- [ ] Network disconnection recovery
- [ ] Permission denied scenarios
- [ ] Invalid agent ID/endpoint handling
- [ ] Audio device unavailable scenarios

### 8. Platform-Specific Features

#### iOS Testing

- [ ] MP3 audio encoding (dart_lame)
- [ ] AVAudioSession configuration
- [ ] Background audio continuation
- [ ] Audio route changes (headphones/speaker)

#### Android Testing

- [ ] WAV audio encoding
- [ ] AudioManager integration
- [ ] Storage permissions
- [ ] Audio focus management

## Expected Behavior

1. **App Launch**:

   - App starts and requests microphone permissions
   - Service initializes and connects to ElevenLabs
   - Recording button becomes active

2. **First Interaction**:

   - Tap record button to start recording
   - Button shows recording state (red, pulsing)
   - Speak a test phrase
   - Tap button again to stop recording
   - Agent should respond with audio playback

3. **Conversation Flow**:
   - Natural turn-taking between user and agent
   - Ability to interrupt agent by tapping during playback
   - Continuous conversation without re-initialization

## Troubleshooting Steps

### If connection fails:

1. Verify internet connectivity
2. Check endpoint URL format
3. Validate agent ID
4. Check signed URL generation

### If recording doesn't work:

1. Verify microphone permissions
2. Check audio session configuration
3. Validate audio encoding format

### If playback fails:

1. Check audio player initialization
2. Verify audio file creation
3. Check platform-specific audio handling

### If echo/feedback occurs:

1. Verify echo cancellation is active
2. Check recording pause during agent speech
3. Validate audio signature detection

## Success Criteria

- ✅ Service connects successfully on both platforms
- ✅ Recording and playback work without issues
- ✅ No echo or feedback loops
- ✅ Natural conversation flow maintained
- ✅ Proper error handling and recovery
- ✅ Platform-specific optimizations working
