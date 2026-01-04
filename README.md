# ElevenLabs Conversational AI v2 for FlutterFlow

A complete Flutter implementation of the **ElevenLabs Conversational AI v2 API** using the official `elevenlabs_agents` Flutter SDK, designed specifically for FlutterFlow projects. This library provides state-of-the-art conversational AI capabilities with real-time voice interactions via WebRTC, advanced turn-taking models, and enterprise-grade features.

## 🔐 Secure Architecture

This library employs a cutting-edge, secure architecture to protect your ElevenLabs API key, ensuring it is never exposed on the client-side.

  *   **Server-Side API Key Management**: Your ElevenLabs API key is stored and managed exclusively in a secure cloud environment. The client application no longer directly handles or stores the API key.
  *   **Conversation Token Generation**: The client communicates with a cloud function (e.g., on BuildShip, Xano, or n8n) to request a temporary `conversationToken`. This token grants a short-lived, secure connection for the `elevenlabs_agents` SDK.
  *   **Secure WebRTC Communication**: The `elevenlabs_agents` SDK handles secure WebRTC communication internally, ensuring ultra-low latency, encrypted audio streaming.
  *   **Cloud Function Templates**: To simplify the server-side setup, we provide templates for popular low-code/no-code platforms:
      *   **BuildShip** (Available now)

This approach represents the pinnacle of API key security by implementing a complete separation between client applications and sensitive credentials.

-----

## 🚀 Features

### Core Capabilities

  -   **Real-time Voice Conversations**: Low-latency, bidirectional audio streaming via WebRTC powered by the `elevenlabs_agents` SDK.
  -   **Advanced Turn-Taking**: Client-side Voice Activity Detection (VAD) with intelligent interruption handling.
  -   **Multi-modal Support**: Audio input/output with text transcription.
  -   **State-of-the-art TTS**: Uses ElevenLabs Turbo v2.5 for ultra-low latency speech synthesis.
  -   **Robust Connection Management**: Automatic reconnection and error recovery via the SDK.
  -   **Audio Feedback Prevention**: Intelligent recording pause during agent speech.
  -   **FlutterFlow Integration**: Full App State integration and reactive UI updates.

### FlutterFlow-Specific Features

  -   **Custom Widgets**: Pre-built recording button with visual feedback.
  -   **Custom Actions**: Simple initialize/stop conversation management.
  -   **App State Integration**: Automatic synchronization with FFAppState.
  -   **Theme Integration**: Respects FlutterFlow theme colors and styles.
  -   **Permission Handling**: Seamless microphone, Bluetooth, and background audio permission management.

-----

## 🛠️ Quick Setup

### 1\. Server-Side Configuration

Before using the library, you need to set up your secure cloud function endpoint.

1.  **Get ElevenLabs Credentials**:
      *   **ElevenLabs API Key**: Get from [ElevenLabs Dashboard](https://elevenlabs.io/app/settings/api-keys).
      *   **Agent ID**: Create a conversational agent in ElevenLabs and copy its ID.
2.  **Deploy Cloud Function**:
      *   Choose a provider (e.g., BuildShip).
      *   Use our template to deploy a function that takes your Agent ID and returns a `conversationToken`.
      *   Store your ElevenLabs API Key securely within the cloud function's environment variables.
      *   Copy the deployed function's endpoint URL.

### 2\. FlutterFlow App State

Ensure these variables exist in your FlutterFlow App State:

```dart
// Connection state tracking
String wsConnectionState = 'disconnected'; // Reflects connection status (e.g., 'connected', 'disconnected')

// Secure Endpoint and Agent ID
String elevenLabsAgentId = ''; // Your ElevenLabs Agent ID
String elevenLabsConversationTokenEndpoint = ''; // Your Cloud Function Endpoint URL for conversation tokens

// Recording state
bool isRecording = false; // True when audio is being recorded

// Conversation messages
List<dynamic> conversationMessages = []; // List to store conversation turns (text/audio)

// Additional states from ElevenLabsSdkService
bool isAgentSpeaking = false; // True when the ElevenLabs agent is speaking
bool isInitializing = false; // True during service initialization
```

### 3\. Platform Permissions

Add to your platform configuration files:

#### Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
```

#### iOS (`ios/Runner/Info.plist`)

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for voice conversations</string>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to manage audio devices during conversations.</string>
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>voip</string>
</array>
```

-----

## 🎯 Implementation Guide

### Basic Implementation

Add to your page's "On Page Load" action:

1.  **Request Permissions**

    ```dart
    await requestPermission(microphonePermission);
    // You might also want to request bluetooth permissions depending on your use case
    // await requestPermission(bluetoothPermission);
    ```

2.  **Initialize Service**

    ```dart
    // Get the conversation token from your secure backend endpoint
    String? conversationToken = await GetSignedURLViaBuildShipCallCall.call(
      agentId: FFAppState().elevenLabsAgentId,
      // Pass other necessary parameters for your backend function
    );

    if (conversationToken != null) {
      String result = await initializeConversationService(
        context,
        conversationToken,
        FFAppState().elevenLabsAgentId, // The SDK might still need the agent ID
      );
      // Handle the result (e.g., show error if initialization failed)
    } else {
      // Handle case where conversation token could not be obtained
    }
    ```

3.  **Add Recording Button**
    Use the `SimpleRecordingButton` custom widget in your UI.

4.  **Display Conversation**
    Use a ListView with the conversation messages from App State.

### Page Cleanup

Add to your page's "On Page Dispose" action:

```dart
await stopConversationService();
```

-----

## 🔐 Security & Best Practices

### API Key Security

  -   **Never expose your API key on the client-side.** The key should only reside in your secure cloud function environment.
  -   The `initializeConversationService` action now uses a `conversationToken` obtained from your secure endpoint, not a raw API key.
  -   This architecture prevents decompilation of your app from revealing your secret keys.

### Permission Handling

  -   Always request necessary permissions (microphone, Bluetooth) before initialization.
  -   Handle permission denial gracefully.

### Error Handling

  -   All actions return descriptive error messages.
  -   Connection failures trigger automatic reconnection via the `elevenlabs_agents` SDK.

-----

## 📦 Installation Options

### Option 1: FlutterFlow Marketplace (Recommended)

Import directly from the FlutterFlow Marketplace: [ElevenLabs Conversational AI v2](https://marketplace.flutterflow.io/item/6iqd6d7dIphUrTANELHe)

1.  Navigate to the marketplace link.
2.  Click "Add to Project".
3.  Follow the integration wizard.
4.  Configure your ElevenLabs `agentId` and `elevenLabsConversationTokenEndpoint` in the App States.

### Option 2: Manual Integration

If you prefer to integrate manually or are using a plain Flutter project, you'll need to add the required dependencies and custom code.

#### 1\. Add Dependencies to `pubspec.yaml`

Add the following to your `pubspec.yaml` under `dependencies`:

```yaml
  elevenlabs_agents: ^0.3.0
  just_audio: ^0.10.4
  record: ^6.0.0
  path_provider: 2.1.4 # Or the latest compatible version
  permission_handler: 12.0.0+1 # Or the latest compatible version
  flutter_secure_storage: 9.2.2 # Or the latest compatible version
  http: 1.4.0 # Or the latest compatible version
  web_socket_channel: ^3.0.0 # Or the latest compatible version
```

After updating `pubspec.yaml`, run `flutter pub get` in your terminal.

#### 2\. Copy Custom Code

Copy the custom code files (from the original source) to your FlutterFlow project or Flutter project, ensuring the following structure:

```
lib/custom_code/
├── elevenlabs_sdk_service.dart          # Core service
├── actions/
│   ├── index.dart
│   ├── initialize_conversation_service.dart
│   └── stop_conversation_service.dart
│   └── get_signed_url.dart             # For fetching conversation token from your backend
└── widgets/
    ├── index.dart
    └── simple_recording_button.dart
```

-----

## 📱 Platform Support

### Supported Platforms

  -   ✅ iOS (14.0+)
  -   ✅ Android (API 21+)
  -   ❌ Web (limited audio support for conversational AI)

### iOS Simulator Limitation

The ElevenLabs SDK uses LiveKit's WebRTC implementation, which has known issues capturing microphone input on iOS Simulator.

**Important:** You MUST test on a physical iOS device to verify audio input works. iOS Simulator will always show "..." for transcripts because it cannot capture real microphone input for WebRTC.

For proper testing and development:
- Use a physical iPhone (iOS 14.0+) for voice conversation features
- iOS Simulator can be used for UI testing and connection verification
- Audio capture and transcription require physical device microphone access

-----

## 🤝 Support & Contributing

### Getting Help

  -   Review the debug logs for error details.
  -   Check ElevenLabs API documentation.
  -   Verify your FlutterFlow project configuration and that the secure token endpoint is correctly set up.

### ElevenLabs Resources

  -   [API Documentation](https://elevenlabs.io/docs/conversational-ai/overview)
  -   [Conversational AI v2 Blog Post](https://elevenlabs.io/blog/conversational-ai-v2)
  -   [Agent Configuration Guide](https://elevenlabs.io/docs/conversational-ai/agents)

-----

**Ready to build amazing voice-enabled apps with FlutterFlow and ElevenLabs? Start with the marketplace integration or copy the custom code to get started\!** 🎉