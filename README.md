# ElevenLabs Conversational AI v2 for FlutterFlow

A complete Flutter implementation of the **ElevenLabs Conversational AI 2.0 API** designed specifically for FlutterFlow projects. This library provides state-of-the-art conversational AI capabilities with real-time voice interactions, advanced turn-taking models, and enterprise-grade features.

## 🔐 Secure Architecture

This library employs a cutting-edge, secure architecture to protect your ElevenLabs API key, ensuring it is never exposed on the client-side.

  * **Server-Side API Key Management**: Your ElevenLabs API key is stored and managed exclusively in a secure cloud environment. The client application no longer directly handles or stores the API key.
  * **Signed URL Generation**: The client communicates with a cloud function (e.g., on BuildShip, Xano, or n8n) to request a temporary, signed URL. This URL grants a short-lived, secure connection to the ElevenLabs API.
  * **TLS 1.3 (WSS)**: All communication between the client and the ElevenLabs WebSocket API is encrypted using the latest TLS 1.3 standard, ensuring data privacy and integrity.
  * **Cloud Function Templates**: To simplify the server-side setup, we provide templates for popular low-code/no-code platforms:
      * **BuildShip** (Available now)
      * **Xano** (Coming soon)
      * **n8n** (Coming soon)

This approach represents the pinnacle of API key security by implementing a complete separation between client applications and sensitive credentials.

-----

## 🚀 Features

### Core Capabilities

  - **Real-time Voice Conversations**: WebSocket-based bidirectional audio streaming secured via WSS (TLS 1.3).
  - **Advanced Turn-Taking**: Client-side Voice Activity Detection (VAD) with intelligent interruption handling.
  - **Multi-modal Support**: Audio input/output with text transcription.
  - **State-of-the-art TTS**: Uses ElevenLabs Turbo v2.5 for ultra-low latency speech synthesis.
  - **Robust Connection Management**: Automatic reconnection and error recovery.
  - **Audio Feedback Prevention**: Intelligent recording pause during agent speech.
  - **FlutterFlow Integration**: Full App State integration and reactive UI updates.

### FlutterFlow-Specific Features

  - **Custom Widgets**: Pre-built recording button with visual feedback.
  - **Custom Actions**: Simple initialize/stop conversation management.
  - **App State Integration**: Automatic synchronization with FFAppState.
  - **Theme Integration**: Respects FlutterFlow theme colors and styles.
  - **Permission Handling**: Seamless microphone permission management.

-----

## 🛠️ Quick Setup

### 1\. Server-Side Configuration

Before using the library, you need to set up your secure cloud function endpoint.

1.  **Get ElevenLabs Credentials**:
      * **ElevenLabs API Key**: Get from [ElevenLabs Dashboard](https://elevenlabs.io/app/settings/api-keys).
      * **Agent ID**: Create a conversational agent in ElevenLabs and copy its ID.
2.  **Deploy Cloud Function**:
      * Choose a provider (e.g., BuildShip).
      * Use our template to deploy a function that takes your Agent ID and returns a signed URL.
      * Store your ElevenLabs API Key securely within the cloud function's environment variables.
      * Copy the deployed function's endpoint URL.

### 2\. FlutterFlow App State

Ensure these variables exist in your FlutterFlow App State:

```dart
// Connection state tracking
String wsConnectionState = 'disconnected';

// Secure Endpoint and Agent ID
String elevenLabsAgentId = ''; // Your Agent ID
String endpoint = ''; // Your Cloud Function Endpoint URL

// Recording state
bool isRecording = false;

// Conversation messages
List<dynamic> conversationMessages = [];
```

### 3\. Platform Permissions

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

-----

## 🎯 Implementation Guide

### Basic Implementation

Add to your page's "On Page Load" action:

1.  **Request Permissions**

    ```dart
    await requestPermission(microphonePermission);
    ```

2.  **Initialize Service**

    ```dart
    String result = await initializeConversationService(
      context,
      FFAppState().elevenLabsAgentId,
      FFAppState().endpoint,
    );
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

  - **Never expose your API key on the client-side.** The key should only reside in your secure cloud function environment.
  - The `initializeConversationService` action now uses a `signedUrl` obtained from your secure endpoint, not a raw API key.
  - This architecture prevents decompilation of your app from revealing your secret keys.

### Permission Handling

  - Always request microphone permissions before initialization.
  - Handle permission denial gracefully.

### Error Handling

  - All actions return descriptive error messages.
  - Connection failures trigger automatic reconnection.

-----

## 📦 Installation Options

### Option 1: FlutterFlow Marketplace (Recommended)

Import directly from the FlutterFlow Marketplace: [ElevenLabs Conversational AI v2](https://marketplace.flutterflow.io/item/6iqd6d7dIphUrTANELHe)

1.  Navigate to the marketplace link
2.  Click "Add to Project"
3.  Follow the integration wizard
4.  Configure your ElevenLabs `agentId` and `endpoint` in the App States.

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

-----

## 📱 Platform Support

### Supported Platforms

  - ✅ iOS (14.0+)
  - ✅ Android (API 21+)
  - ❌ Web (no audio support)

-----

## 🤝 Support & Contributing

### Getting Help

  - Review the debug logs for error details.
  - Check ElevenLabs API documentation.
  - Verify your FlutterFlow project configuration and that the secure endpoint is correctly set up.

### ElevenLabs Resources

  - [API Documentation](https://elevenlabs.io/docs/conversational-ai/overview)
  - [Conversational AI 2.0 Blog Post](https://elevenlabs.io/blog/conversational-ai-v2)
  - [Agent Configuration Guide](https://elevenlabs.io/docs/conversational-ai/agents)

-----

**Ready to build amazing voice-enabled apps with FlutterFlow and ElevenLabs? Start with the marketplace integration or copy the custom code to get started\!** 🎉
