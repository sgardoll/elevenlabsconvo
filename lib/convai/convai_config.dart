/// Configuration for the ElevenLabs Conversational AI WebSocket client.
///
/// Credentials are injected from the build environment or by the host app at
/// runtime. Never hardcode keys in source control.
///
/// Supply values at build time with dart-defines:
///
/// ```sh
/// flutter run \
///   --dart-define=ELEVENLABS_API_KEY=sk_... \
///   --dart-define=ELEVENLABS_AGENT_ID=agent_...
/// ```
///
/// Two authentication modes are supported:
/// - **Direct API key** (native platforms): the `xi-api-key` header is sent on
///   the WebSocket upgrade request together with `?agent_id=` in the query.
/// - **Signed URL** (browser-safe): the host backend provisions a short-lived
///   `wss://...token=...` URL; the client opens it directly. Browsers cannot
///   set custom headers on WebSockets, so use this mode on web.
library;

const String _envApiKey = String.fromEnvironment('ELEVENLABS_API_KEY');
const String _envAgentId = String.fromEnvironment('ELEVENLABS_AGENT_ID');
const String _envWssUrl = String.fromEnvironment('ELEVENLABS_WSS_URL');

/// Thrown when [ConvAiConfig] cannot be built because required credentials or
/// identifiers are missing. The message names every missing value and how to
/// supply it, so setup mistakes are immediately diagnosable.
class ConvAiConfigException implements Exception {
  final String message;

  const ConvAiConfigException(this.message);

  @override
  String toString() => 'ConvAiConfigException: $message';
}

/// Immutable configuration for a ConvAI WebSocket session.
class ConvAiConfig {
  /// Default ElevenLabs ConvAI WebSocket endpoint.
  ///
  /// Override with the `ELEVENLABS_WSS_URL` dart-define (or [endpoint]) when a
  /// proxy or alternate deployment path is required.
  static const String defaultEndpoint =
      'wss://api.elevenlabs.io/v1/convai/conversation';

  /// ElevenLabs API key for direct (header-based) authentication.
  ///
  /// Empty when [signedUrl] mode is used instead. Exactly one of the two modes
  /// must be active.
  final String apiKey;

  /// Backend-provisioned signed WebSocket URL (`wss://...token=...`).
  ///
  /// Takes precedence over [apiKey] when non-empty.
  final String signedUrl;

  /// Target ElevenLabs agent id. Required for direct API-key mode; embedded in
  /// the signed URL otherwise.
  final String agentId;

  /// WebSocket endpoint. Ignored in signed-URL mode (the URL carries its own).
  final String endpoint;

  /// Max time to establish the TCP/TLS/upgrade handshake.
  final Duration connectTimeout;

  /// Max time to receive `conversation_initiation_metadata` after connecting.
  final Duration initiationTimeout;

  /// Max time to await an `agent_response` after sending a text message.
  final Duration responseTimeout;

  /// Base delay for the first reconnect attempt; doubles each attempt.
  final Duration initialBackoff;

  /// Upper bound for a reconnect delay before jitter.
  final Duration maxBackoff;

  /// Reconnect attempts after an established session drops unexpectedly.
  final int maxReconnectAttempts;

  const ConvAiConfig({
    this.apiKey = '',
    this.signedUrl = '',
    this.agentId = '',
    this.endpoint = defaultEndpoint,
    this.connectTimeout = const Duration(seconds: 15),
    this.initiationTimeout = const Duration(seconds: 15),
    this.responseTimeout = const Duration(seconds: 45),
    this.initialBackoff = const Duration(seconds: 1),
    this.maxBackoff = const Duration(seconds: 30),
    this.maxReconnectAttempts = 5,
  });

  /// Builds configuration from dart-defines merged with explicit overrides.
  ///
  /// Explicit arguments win over environment values. Throws
  /// [ConvAiConfigException] when neither an API key nor a signed URL is
  /// available, or when direct mode lacks an agent id.
  factory ConvAiConfig.fromEnvironment({
    String? apiKey,
    String? signedUrl,
    String? agentId,
  }) {
    final effectiveKey = _trimmed(apiKey ?? _envApiKey);
    final effectiveSignedUrl = _trimmed(signedUrl ?? '');
    final effectiveAgentId = _trimmed(agentId ?? _envAgentId);

    if (effectiveSignedUrl.isEmpty && effectiveKey.isEmpty) {
      throw const ConvAiConfigException(
        'No ElevenLabs credentials found. Pass apiKey or signedUrl explicitly, '
        'or provide them at build time with '
        '--dart-define=ELEVENLABS_API_KEY=<key> '
        '(and --dart-define=ELEVENLABS_AGENT_ID=<agentId>).',
      );
    }
    if (effectiveSignedUrl.isEmpty && effectiveAgentId.isEmpty) {
      throw const ConvAiConfigException(
        'Direct API-key authentication requires an agent id. Pass agentId '
        'explicitly or provide it with --dart-define=ELEVENLABS_AGENT_ID=<id>.',
      );
    }

    return ConvAiConfig(
      apiKey: effectiveKey,
      signedUrl: effectiveSignedUrl,
      agentId: effectiveAgentId,
      endpoint: _trimmed(_envWssUrl).isEmpty
          ? defaultEndpoint
          : _trimmed(_envWssUrl),
    );
  }

  /// True when the signed-URL authentication mode is active.
  bool get usesSignedUrl => signedUrl.isNotEmpty;

  static String _trimmed(String value) => value.trim();
}
