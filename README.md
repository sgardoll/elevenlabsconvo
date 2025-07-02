# ElevenLabs Conversational AI v2 for FlutterFlow

A complete Flutter implementation of the **ElevenLabs Conversational AI 2.0 API** designed specifically for FlutterFlow projects. This library provides state-of-the-art conversational AI capabilities with real-time voice interactions, advanced turn-taking models, and enterprise-grade features.

## 🚀 Features

### Core Capabilities
- **Real-time Voice Conversations**: WebSocket-based bidirectional audio streaming
- **Advanced Turn-Taking**: Client-side Voice Activity Detection (VAD) with intelligent interruption handling
- **Multi-modal Support**: Audio input/output with text transcription
- **State-of-the-art TTS**: Uses ElevenLabs Turbo v2.5 for ultra-low latency speech synthesis
- **Robust Connection Management**: Automatic reconnection and error recovery
- **Audio Feedback Prevention**: Intelligent recording pause during agent speech
- **FlutterFlow Integration**: Full App State integration and reactive UI updates

### FlutterFlow-Specific Features
- **Custom Widgets**: Pre-built recording button with visual feedback
- **Custom Actions**: Simple initialize/stop conversation management
- **App State Integration**: Automatic synchronization with FFAppState
- **Theme Integration**: Respects FlutterFlow theme colors and styles
- **Permission Handling**: Seamless microphone permission management
- **Secure Storage**: API keys stored using Flutter Secure Storage

## 📦 Installation Options

### Option 1: FlutterFlow Marketplace (Recommended)
Import directly from the FlutterFlow Marketplace: [ElevenLabs Conversational AI v2](https://marketplace.flutterflow.io/item/6iqd6d7dIphUrTANELHe)

1. Navigate to the marketplace link
2. Click "Add to Project"
3. Follow the integration wizard
4. Configure your ElevenLabs credentials

### Option 2: Copy Custom Code
Copy the custom code files to your FlutterFlow project:

#### Required Files Structure
```
lib/custom_code/
├── conversational_ai_service.dart          # Core service (shared)
├── actions/
│   ├── index.dart
│   ├── initialize_conversation_service.dart
│   └── stop_conversation_service.dart
└── widgets/
    ├── index.dart
    └── simple_recording_button.dart
```

#### Dependencies
Add these to your `pubspec.yaml`:
```yaml
dependencies:
  web_socket_channel: ^3.0.0
  just_audio: ^0.10.4
  record: ^6.0.0
  path_provider: ^2.1.5
  permission_handler: ^12.0.0+1
  flutter_secure_storage: ^10.0.0-beta.4
```

## ⚠️ Dependency Restrictions

### Critical Version Requirements
This library requires specific package versions for compatibility:

- **web_socket_channel**: Must be `^3.0.0` or higher for ElevenLabs WebSocket support
- **just_audio**: Requires `^0.10.4` for PCM audio playback compatibility
- **record**: Must be `^6.0.0` for proper microphone recording
- **permission_handler**: Requires `^12.0.0+1` for modern permission handling
- **flutter_secure_storage**: Must use `^10.0.0-beta.4` or higher for secure API key storage

### Conflicting Dependencies
**Avoid these packages** as they may conflict with audio functionality:
- `audioplayers` (conflicts with `just_audio`)
- `sound_pool` (may interfere with real-time audio)
- `flutter_sound` (incompatible recording formats)
- Older versions of `permission_handler` (< 12.0.0)

### Platform-Specific Restrictions
- **iOS**: Requires iOS 14.0+ for full WebSocket and audio API support
- **Android**: Minimum API level 21 (Android 5.0) required
- **Web**: Audio recording and playback NOT supported - use mobile platforms only

## 🛠️ Quick Setup

### 1. ElevenLabs Configuration
Before using the library, you need:
- **ElevenLabs API Key**: Get from [ElevenLabs Dashboard](https://elevenlabs.io/app/settings/api-keys)
- **Agent ID**: Create a conversational agent in ElevenLabs and copy its ID

### 2. App State Variables
Ensure these variables exist in your FlutterFlow App State:
```dart
// Connection state tracking
String wsConnectionState = 'disconnected';

// Credentials (stored securely)
String elevenLabsApiKey = '';
String elevenLabsAgentId = '';

// Recording state
bool isRecording = false;

// Conversation messages
List<dynamic> conversationMessages = [];
```

### 3. Platform Permissions
Add to your platform configuration files:

#### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

#### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for voice conversations</string>
```

## 🎯 Implementation Guide

### Basic Implementation
Add to your page's "On Page Load" action:

1. **Request Permissions**
   ```dart
   await requestPermission(microphonePermission);
   ```

2. **Initialize Service**
   ```dart
   String result = await initializeConversationService(
     context,
     FFAppState().elevenLabsApiKey,
     FFAppState().elevenLabsAgentId,
   );
   ```

3. **Add Recording Button**
   Use the `SimpleRecordingButton` custom widget in your UI

4. **Display Conversation**
   Use a ListView with the conversation messages from App State

### Page Cleanup
Add to your page's "On Page Dispose" action:
```dart
await stopConversationService();
```

### Example Page Structure
```dart
// Page Load Actions
1. Request microphone permissions
2. Initialize conversation service with credentials
3. Setup message listeners (optional)

// UI Structure
- AppBar with connection status
- ListView for conversation messages
- SimpleRecordingButton for voice input
- Status indicators for recording/speaking states

// Page Dispose Actions
1. Stop conversation service
2. Cleanup resources
```

## 🎨 Custom Widgets

### SimpleRecordingButton
A fully featured recording button with visual feedback:

**Parameters:**
- `size` (double): Button size (default: 60.0)
- `iconSize` (double): Icon size (default: 24.0)
- `elevation` (double): Button elevation (default: 8.0)
- `recordingColor` (Color?): Color when recording
- `idleColor` (Color?): Color when idle
- `iconColor` (Color?): Icon color
- `pulseAnimation` (bool): Enable pulse animation (default: true)

**Features:**
- Automatic state management
- Visual feedback for all conversation states
- Pulse animation during recording
- Theme-aware color defaults
- Error state handling
- Snackbar notifications

## 🔧 Custom Actions

### initializeConversationService
Initializes the conversation service with your credentials.

**Parameters:**
- `apiKey` (String): Your ElevenLabs API key
- `agentId` (String): Your conversational agent ID

**Returns:** String indicating success or error

### stopConversationService
Stops the conversation service and cleans up resources.

**No parameters required**

## 📊 State Management

### Connection States
- `disconnected`: Not connected to ElevenLabs
- `connecting`: Establishing connection
- `connected`: Ready for conversations
- `error`: Connection or service error

### Conversation States
- `idle`: No active conversation
- `recording`: User is speaking
- `playing`: Agent is responding
- `connected`: Ready for interaction

### Message Types
```dart
{
  'type': 'user' | 'agent' | 'system',
  'content': 'Message content',
  'timestamp': DateTime.now().millisecondsSinceEpoch,
  'conversationId': 'unique_conversation_id'
}
```

## 🔐 Security & Best Practices

### API Key Storage
- API keys are automatically stored using Flutter Secure Storage
- Keys persist between app sessions
- Secure credential management built-in

### Permission Handling
- Always request microphone permissions before initialization
- Handle permission denial gracefully
- Provide clear user messaging about permission requirements

### Error Handling
- All actions return descriptive error messages
- Connection failures trigger automatic reconnection
- Audio errors are logged and reported to UI

### Performance Optimization
- Efficient audio streaming with chunked playback
- Memory management for temporary audio files
- Background processing for real-time audio

## 🎛️ Advanced Configuration

### Custom Audio Settings
The service uses optimized settings for best quality:
- **Input Format**: PCM 16kHz mono
- **Output Format**: PCM 16kHz mono  
- **TTS Model**: ElevenLabs Turbo v2.5
- **VAD Threshold**: 0.6
- **Silence Duration**: 1000ms

### Conversation Configuration
You can modify the conversation settings in `conversational_ai_service.dart`:
```dart
'conversation_config_override': {
  'agent': {
    'language': 'en',
    'turn_detection': {
      'type': 'client_vad',
      'threshold': 0.6,           // Adjust sensitivity
      'silence_duration_ms': 1000 // Adjust turn-taking timing
    }
  },
  'tts': {
    'model': 'eleven_turbo_v2_5',
  }
}
```

## 🐛 Troubleshooting

### Common Issues

**Connection Fails**
- Verify API key and Agent ID are correct
- Check internet connection
- Ensure ElevenLabs service is accessible

**No Audio Playback**
- Verify device audio permissions
- Check device volume settings
- Test with device speakers/headphones

**Recording Not Working**
- Confirm microphone permissions granted
- Test microphone with other apps
- Check for conflicting audio apps

**State Not Updating**
- Verify App State variables are configured
- Check for proper widget context
- Ensure service initialization completed

### Debug Logging
Enable debug prints by setting `debugPrint` statements in:
- `conversational_ai_service.dart`
- Custom action files
- Widget state changes

## 📱 Platform Support

### Supported Platforms
- ✅ iOS (14.0+)
- ✅ Android (API 21+)
- ❌ Web (no audio support)

### Platform-Specific Notes

**iOS**
- Requires microphone permission in Info.plist
- Background audio requires additional configuration
- Works with AirPods and Bluetooth devices
- Full WebSocket and audio API support

**Android**
- Requires multiple audio permissions
- Works with USB and Bluetooth audio devices
- Background processing requires foreground service
- Tested on API levels 21-34

**Web**
- **NOT SUPPORTED**: Web platform lacks the necessary audio recording and real-time playback APIs
- WebSocket connections work, but audio functionality is unavailable
- Use iOS or Android for full conversational AI features

## 🤝 Support & Contributing

### Getting Help
- Review the debug logs for error details
- Check ElevenLabs API documentation
- Verify FlutterFlow project configuration
- Test with a minimal implementation first

### FlutterFlow Community
- Share improvements in FlutterFlow forums
- Report marketplace issues through FlutterFlow support
- Contribute custom widget enhancements

### ElevenLabs Resources
- [API Documentation](https://elevenlabs.io/docs/conversational-ai/overview)
- [Conversational AI 2.0 Blog Post](https://elevenlabs.io/blog/conversational-ai-v2)
- [Agent Configuration Guide](https://elevenlabs.io/docs/conversational-ai/agents)

## 📄 License

This project is built for FlutterFlow and uses the ElevenLabs Conversational AI API. Ensure compliance with ElevenLabs Terms of Service and your FlutterFlow license.

---

**Ready to build amazing voice-enabled apps with FlutterFlow and ElevenLabs? Start with the marketplace integration or copy the custom code to get started!** 🎉
