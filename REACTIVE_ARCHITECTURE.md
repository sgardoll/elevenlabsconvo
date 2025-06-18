# Reactive Service-Based Architecture Refactor

## Overview

This refactor transforms the ElevenLabs conversation app from a tightly-coupled architecture using global singletons and scattered UI logic into a clean, reactive service-based architecture. The new design separates concerns, improves testability, and creates a clearer one-way data flow.

## Architecture Comparison

### Before (Problems)
- **Global Singleton Dependency**: WebSocketManager was a global singleton directly accessed throughout the app
- **Scattered Business Logic**: WebSocket communication logic was mixed with UI widgets and custom action files
- **Tight Coupling**: UI widgets directly manipulated global state (FFAppState) 
- **Difficult Testing**: Business logic was tightly coupled to UI, making unit testing nearly impossible
- **State Management Issues**: Multiple sources of truth with FFAppState and WebSocketManager managing overlapping concerns

### After (Solutions)
- **Service Layer**: Clean separation between business logic (services) and UI (widgets)
- **Reactive Streams**: All state changes flow through streams, creating predictable one-way data flow
- **Dependency Injection**: Services are injected rather than accessed globally
- **Single Source of Truth**: ConversationService manages all app state in one place
- **Testable Architecture**: Services can be easily mocked and tested in isolation

## New Architecture Components

### 1. WebSocketManager (`lib/custom_code/websocket_manager.dart`)
**Purpose**: Pure WebSocket communication service
**Responsibilities**:
- Manages WebSocket connection lifecycle
- Handles message parsing and protocol implementation
- Exposes streams for different types of events
- Manages voice activity detection
- No UI concerns or global state dependencies

**Key Streams**:
```dart
Stream<List<ChatMessage>> get chatHistoryStream
Stream<ConnectionStatus> get connectionStatusStream  
Stream<ConversationState> get conversationStateStream
Stream<bool> get isBotSpeakingStream
Stream<bool> get isUserSpeakingStream
Stream<double> get vadScoreStream
```

### 2. AudioService (`lib/custom_code/audio_service.dart`)
**Purpose**: Audio playback management
**Responsibilities**:
- Queues and plays audio chunks from the server
- Manages audio buffering and concatenation
- Handles interruptions and state management
- Creates WAV files from PCM data
- No WebSocket or UI dependencies

**Key Streams**:
```dart
Stream<bool> get isPlayingStream
Stream<bool> get isBufferingStream
Stream<String> get currentTrackStream
```

### 3. ConversationService (`lib/custom_code/conversation_service.dart`)
**Purpose**: Main application state coordinator
**Responsibilities**:
- Orchestrates WebSocketManager and AudioService
- Maintains single app state object
- Provides unified API for UI components
- Handles error states and user actions
- Exposes computed properties for UI convenience

**Key Features**:
```dart
Stream<AppState> get stateStream
AppState get currentState

// Computed properties for UI
String get connectionStatusText
String get conversationStateText  
bool get canRecord
bool get shouldShowError
```

### 4. Reactive UI Components

#### ResponseListWidget (`lib/components/response_list/response_list_widget.dart`)
- Uses `StreamBuilder<AppState>` to reactively display chat messages
- No direct state management or business logic
- Automatically rebuilds when conversation state changes

#### HomePageWidget (`lib/pages/home_page/home_page_widget.dart`)  
- Uses `StreamBuilder<AppState>` for the entire page
- Displays connection status, error states, and conversation UI
- Recording button adapts to current state automatically

## Data Flow

### 1. User Input Flow
```
User Action → ConversationService → WebSocketManager → Server
```

### 2. Server Response Flow  
```
Server → WebSocketManager → ConversationService → UI (via StreamBuilder)
```

### 3. Audio Flow
```
Server → WebSocketManager → AudioService → Audio Playback
AudioService State → ConversationService → UI (via StreamBuilder)
```

## Key Benefits

### 1. **Separation of Concerns**
- WebSocket logic is isolated in WebSocketManager
- Audio logic is isolated in AudioService  
- UI logic is isolated in widget files
- State coordination happens in ConversationService

### 2. **Testability**
```dart
// Easy to test services in isolation
final mockWebSocket = MockWebSocketManager();
final audioService = AudioService.instance;
final conversationService = ConversationService(mockWebSocket, audioService);

// Test state changes
expect(conversationService.connectionStatus, ConnectionStatus.connected);
```

### 3. **Predictable State Flow**
- All state changes flow through streams
- UI automatically updates via StreamBuilder
- No manual state synchronization needed
- Clear debugging trail through state changes

### 4. **Scalability**
- Easy to add new features by extending services
- New UI components just need to listen to streams
- Business logic changes don't affect UI code
- Services can be reused across different UI implementations

### 5. **Error Handling**
- Centralized error handling in ConversationService
- Errors flow through the same stream as other state
- UI can reactively display error states
- Easy to implement retry logic

## Implementation Examples

### Using ConversationService in UI
```dart
class MyWidget extends StatelessWidget {
  final _conversationService = ConversationService.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppState>(
      stream: _conversationService.stateStream,
      builder: (context, snapshot) {
        final state = snapshot.data!;
        
        return Column(
          children: [
            Text('Status: ${_conversationService.connectionStatusText}'),
            if (state.shouldShowError) 
              ErrorBanner(message: state.errorMessage!),
            ChatList(messages: state.chatHistory),
            RecordButton(enabled: _conversationService.canRecord),
          ],
        );
      },
    );
  }
}
```

### Testing Services
```dart
test('conversation service handles connection errors', () async {
  final mockWebSocket = MockWebSocketManager();
  final service = ConversationService(mockWebSocket, AudioService.instance);
  
  mockWebSocket.simulateError('Connection failed');
  
  await expectLater(
    service.stateStream,
    emits(predicate<AppState>((state) => 
      state.connectionStatus == ConnectionStatus.error &&
      state.errorMessage == 'Connection failed'
    ))
  );
});
```

## Migration Guide

### For UI Components
1. Replace `context.watch<FFAppState>()` with `StreamBuilder<AppState>`
2. Use `ConversationService.instance.stateStream` as the stream
3. Access state through the `AppState` object instead of global getters

### For Custom Actions  
1. Replace direct WebSocketManager usage with ConversationService
2. Use `ConversationService.instance` instead of `WebSocketManager()`
3. Call service methods instead of manipulating global state

### For New Features
1. Add new state to `AppState` model
2. Add streams to underlying services if needed
3. Update `ConversationService` to coordinate new functionality
4. UI automatically receives updates via existing StreamBuilder

## Performance Considerations

- **Stream Efficiency**: Broadcast streams allow multiple listeners without performance penalty
- **State Deduplication**: State updates only emit when values actually change
- **Memory Management**: Proper disposal of streams and subscriptions
- **Minimal Rebuilds**: StreamBuilder only rebuilds affected widgets

## Future Enhancements

This architecture makes several improvements easy to implement:

1. **Offline Support**: Add caching layer to ConversationService
2. **Multiple Conversations**: Extend to support multiple conversation streams  
3. **Plugin Architecture**: Services can be extended or replaced independently
4. **Advanced Testing**: Full integration testing with mocked services
5. **State Persistence**: Easy to add state saving/loading to ConversationService
6. **Monitoring**: Add logging and analytics to service layer

## Conclusion

The new reactive service-based architecture provides a solid foundation for building scalable, maintainable, and testable conversational AI applications. The clear separation of concerns and one-way data flow make it easy to reason about application behavior and add new features without introducing technical debt.