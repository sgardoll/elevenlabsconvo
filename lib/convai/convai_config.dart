/// Configuration for the ElevenLabs Conversational AI WebSocket client.
///
/// Credentials are injected from the build environment or by the host app at
/// runtime. Never hardcode keys in source control.
///
/// Supply values at build time with dart-defines:
///
/// ```sh
/// flutter run \
///   --dart-define=ELEVENLABS_TOKEN=<short-lived-token> \
///   --dart-define=ELEVENLABS_AGENT_ID=agent_...
/// ```
///
/// Three authentication modes are supported, in order of preference:
///
/// - **Signed URL** (default, production): the host backend provisions a
///   short-lived `wss://...token=...` URL; the client opens it directly.
///   Browsers cannot set custom headers on WebSockets, so this mode also
///   works on web.
/// - **Token** (production): the backend provisions a short-lived
///   conversation token (`ELEVENLABS_TOKEN`); the client attaches it to the
///   endpoint as a `token` query parameter. Short-lived by design, so a
///   leaked value expires quickly.
/// - **Direct API key** (dev-only, opt-in): sends the reusable
///   `ELEVENLABS_API_KEY` in the `xi-api-key` upgrade header. A reusable key
///   embedded in a distributed build can be extracted and replayed outside
///   the app, so this mode is refused unless the caller explicitly passes
///   `allowInsecureApiKey: true`, and it logs a loud security warning when
///   it activates. Never ship it to production.
library;

import 'package:flutter/foundation.dart';

const String _envApiKey = String.fromEnvironment('ELEVENLABS_API_KEY');
const String _envAgentId = String.fromEnvironment('ELEVENLABS_AGENT_ID');
const String _envWssUrl = String.fromEnvironment('ELEVENLABS_WSS_URL');
const String _envToken = String.fromEnvironment('ELEVENLABS_TOKEN');

/// Thrown when [ConvAiConfig] cannot be built because required credentials or
/// identifiers are missing — or because insecure API-key mode was requested
/// without its explicit opt-in flag. The message names every missing value
/// and how to supply it, so setup mistakes are immediately diagnosable.
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
  /// Reusable and extractable from distributed builds: dev-only, and only
  /// with the explicit `allowInsecureApiKey: true` opt-in. Empty when
  /// signed-URL or token mode is used instead.
  final String apiKey;

  /// Backend-provisioned signed WebSocket URL (`wss://...token=...`).
  ///
  /// Takes precedence over [token] and [apiKey] when non-empty.
  final String signedUrl;

  /// Backend-provisioned short-lived conversation token.
  ///
  /// Attached to [endpoint] as a `token` query parameter. Takes precedence
  /// over [apiKey]; ignored when [signedUrl] is set.
  final String token;

  /// Target ElevenLabs agent id. Required for direct API-key mode; embedded
  /// in the connection query for token mode when present.
  final String agentId;

  /// WebSocket endpoint. Ignored in signed-URL mode (the URL carries its own).
  final String endpoint;

  /// Explicit dev-only opt-in for plaintext `ws://` transports.
  ///
  /// Credentials (short-lived tokens in the URL/query or the reusable
  /// `xi-api-key` header) cross a plaintext socket readable and tamperable by
  /// anything on the network path, so non-wss endpoints are refused unless
  /// this flag is true — mirroring [fromEnvironment]'s
  /// `allowInsecureApiKey` gate. Never ship it enabled.
  final bool allowInsecureTransport;

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
    this.token = '',
    this.agentId = '',
    this.endpoint = defaultEndpoint,
    this.allowInsecureTransport = false,
    this.connectTimeout = const Duration(seconds: 15),
    this.initiationTimeout = const Duration(seconds: 15),
    this.responseTimeout = const Duration(seconds: 45),
    this.initialBackoff = const Duration(seconds: 1),
    this.maxBackoff = const Duration(seconds: 30),
    this.maxReconnectAttempts = 5,
  });

  /// Builds configuration from dart-defines merged with explicit overrides.
  ///
  /// Explicit arguments win over environment values. Signed-URL and
  /// short-lived-token credentials are preferred; a reusable API key is only
  /// accepted when [allowInsecureApiKey] is explicitly true (dev-only), and
  /// activating it logs a loud security warning. Throws
  /// [ConvAiConfigException] when no usable credential combination is
  /// available.
  factory ConvAiConfig.fromEnvironment({
    String? signedUrl,
    String? token,
    String? apiKey,
    String? agentId,
    bool allowInsecureApiKey = false,
  }) {
    // Signed URLs are provisioned per-session by the host backend and passed
    // explicitly; tokens arrive via parameter or the ELEVENLABS_TOKEN define.
    final effectiveSignedUrl = _trimmed(signedUrl ?? '');
    final effectiveToken = _trimmed(token ?? _envToken);
    final effectiveAgentId = _trimmed(agentId ?? _envAgentId);
    final effectiveKey = _trimmed(apiKey ?? _envApiKey);

    if (effectiveSignedUrl.isEmpty && effectiveToken.isNotEmpty) {
      return ConvAiConfig(
        token: effectiveToken,
        agentId: effectiveAgentId,
        endpoint: _endpointOverride(),
      );
    }
    if (effectiveSignedUrl.isNotEmpty) {
      return ConvAiConfig(
        signedUrl: effectiveSignedUrl,
        agentId: effectiveAgentId,
      );
    }

    if (effectiveKey.isNotEmpty) {
      if (!allowInsecureApiKey) {
        throw const ConvAiConfigException(
          'Refusing to embed a reusable ElevenLabs API key: it can be '
          'extracted from the build and replayed outside the app. Provision '
          'a short-lived credential instead (--dart-define='
          'ELEVENLABS_TOKEN=<token> or a backend signed URL), or explicitly '
          'opt in for local development with allowInsecureApiKey: true.',
        );
      }
      _warnInsecureApiKey();
      if (effectiveAgentId.isEmpty) {
        throw const ConvAiConfigException(
          'Direct API-key authentication requires an agent id. Pass agentId '
          'explicitly or provide it with --dart-define=ELEVENLABS_AGENT_ID=<id>.',
        );
      }
      return ConvAiConfig(
        apiKey: effectiveKey,
        agentId: effectiveAgentId,
        endpoint: _endpointOverride(),
      );
    }

    throw const ConvAiConfigException(
      'No ElevenLabs credentials found. Pass a short-lived token or '
      'signedUrl explicitly, or provide one at build time with '
      '--dart-define=ELEVENLABS_TOKEN=<token> '
      '(and optionally --dart-define=ELEVENLABS_AGENT_ID=<agentId>).',
    );
  }

  /// True when a signed URL or short-lived token carries authentication.
  bool get usesSignedCredentials => usesSignedUrl || token.isNotEmpty;

  /// True when the signed-URL authentication mode is active.
  bool get usesSignedUrl => signedUrl.isNotEmpty;

  /// Guards credential-bearing sockets: refuses any non-`wss` transport
  /// unless [allowInsecureTransport] opted in, and warns loudly when it did.
  ///
  /// Every mode carries credentials on the wire — a token in the query or
  /// signed URL, or the reusable API key in the `xi-api-key` upgrade header —
  /// so plaintext `ws://` is rejected by default.
  void ensureSecureTransport(Uri uri) {
    if (uri.scheme == 'wss') return;
    if (!allowInsecureTransport) {
      throw ConvAiConfigException(
        'Refusing to send ConvAI credentials over plaintext ws:// ($uri): '
        'anything on the network path can read or tamper with them. Use a '
        'wss:// endpoint, or opt in explicitly for local development with '
        'allowInsecureTransport: true.',
      );
    }
    _warnInsecureTransport(uri);
  }

  static String _endpointOverride() {
    final override = _trimmed(_envWssUrl);
    return override.isEmpty ? defaultEndpoint : override;
  }

  static void _warnInsecureApiKey() {
    debugPrint(
      '┌─ SECURITY WARNING ──────────────────────────────────────────────\n'
      '│ ConvAI is using a REUSABLE ElevenLabs API key (insecure mode).\n'
      '│ The key can be extracted from this build and replayed outside\n'
      '│ the app. Dev use only — never ship this configuration.\n'
      '└─────────────────────────────────────────────────────────────────',
    );
  }

  static void _warnInsecureTransport(Uri uri) {
    debugPrint(
      '┌─ SECURITY WARNING ──────────────────────────────────────────────\n'
      '│ ConvAI is sending credentials over PLAINTEXT ws:// ($uri).\n'
      '│ Anything on the network path can read or tamper with them.\n'
      '│ Dev use only — never ship this configuration.\n'
      '└─────────────────────────────────────────────────────────────────',
    );
  }

  static String _trimmed(String value) => value.trim();
}
