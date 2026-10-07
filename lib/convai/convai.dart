/// Public surface of the ElevenLabs ConvAI WebSocket slice.
///
/// Import this barrel from host-app code; FlutterFlow custom actions import
/// the concrete files they need.
library;

export 'convai_config.dart' show ConvAiConfig, ConvAiConfigException;
export 'convai_events.dart'
    show
        AgentResponse,
        AgentResponseCorrection,
        AudioChunkReceived,
        ConvAiEvent,
        ConvAiEventCodec,
        ConvAiProtocolException,
        ConversationInitiationMetadata,
        InterruptionReceived,
        PingReceived,
        UnknownConvAiEvent,
        UserTranscript,
        VadScoreReceived;
export 'convai_service.dart' show ConvAiService;
export 'convai_websocket_client.dart'
    show
        ConvAiConnectionException,
        ConvAiConnectionState,
        ConvAiWebSocketClient;
export 'conversation_history.dart'
    show
        ConvAiConversation,
        ConvAiConversationHistoryStore,
        ConvAiHistoryException,
        ConvAiMessage,
        ConvAiMessageRole,
        SharedPreferencesConvAiConversationHistoryStore;
export 'session_store.dart'
    show ConvAiSessionStore, SharedPreferencesConvAiSessionStore;
export 'turn_rate_limiter.dart'
    show ConvAiRateLimitException, ConvAiTurnRateLimiter;
