/// JSON protocol encode/decode for the ElevenLabs ConvAI WebSocket text
/// protocol.
///
/// All parsing happens here, at the network boundary: raw frames are decoded
/// into typed [ConvAiEvent]s once and trusted everywhere else. Malformed
/// frames throw [ConvAiProtocolException] immediately (fail fast) instead of
/// propagating partially-parsed data downstream.
///
/// Wire shapes implemented (ElevenLabs ConvAI websocket events):
///
/// ```text
/// client -> server:
///   {"type": "conversation_initiation_client_data"}
///   {"type": "user_message", "text": "..."}
///   {"type": "pong", "event_id": 3}
///
/// server -> client:
///   {"type": "conversation_initiation_metadata",
///    "conversation_initiation_metadata_event": {"conversation_id": "...", ...}}
///   {"type": "user_transcript",
///    "user_transcription_event": {"user_message": "...", "event_id": 1}}
///   {"type": "agent_response",
///    "agent_response_event": {"agent_response": "...", "event_id": 2}}
///   {"type": "agent_response_correction",
///    "agent_response_correction_event": {
///      "original_agent_response": "...", "corrected_agent_response": "...",
///      "event_id": 3}}
///   {"type": "audio", "audio_event": {"audio_base_64": "...", "event_id": 4}}
///   {"type": "interruption", "interruption_event": {...}}
///   {"type": "ping", "ping_event": {"event_id": 5, "ping_ms": 100}}
///   {"type": "vad_score", "vad_score_event": {"vad_score": 0.7, ...}}
/// ```
library;

import 'dart:convert';

/// Base class for every decoded ConvAI WebSocket event.
sealed class ConvAiEvent {
  const ConvAiEvent();
}

/// Handshake reply carrying the server-assigned conversation id.
class ConversationInitiationMetadata extends ConvAiEvent {
  final String conversationId;

  const ConversationInitiationMetadata({required this.conversationId});
}

/// Final transcript of what the user said.
class UserTranscript extends ConvAiEvent {
  final String text;

  const UserTranscript(this.text);
}

/// Full text of the agent's response for the current turn.
class AgentResponse extends ConvAiEvent {
  final String text;

  const AgentResponse(this.text);
}

/// Retroactive correction of a previously emitted agent response.
class AgentResponseCorrection extends ConvAiEvent {
  final String originalText;
  final String correctedText;

  const AgentResponseCorrection({
    required this.originalText,
    required this.correctedText,
  });
}

/// Base64-encoded audio chunk. Parsed for completeness; the text-only slice
/// does not consume audio.
class AudioChunkReceived extends ConvAiEvent {
  final String audioBase64;

  const AudioChunkReceived(this.audioBase64);
}

/// The user interrupted the agent mid-response.
class InterruptionReceived extends ConvAiEvent {
  const InterruptionReceived();
}

/// Server keep-alive ping. Clients must answer with an encoded pong.
class PingReceived extends ConvAiEvent {
  final int eventId;
  final int pingMs;

  const PingReceived({required this.eventId, this.pingMs = 0});
}

/// Voice-activity score for user input audio (0.0–1.0).
class VadScoreReceived extends ConvAiEvent {
  final double score;

  const VadScoreReceived(this.score);
}

/// A recognized-but-unhandled event type; kept for forward compatibility so
/// new server fields never break old clients.
class UnknownConvAiEvent extends ConvAiEvent {
  final String type;

  const UnknownConvAiEvent(this.type);
}

/// Thrown when a WebSocket frame violates the ConvAI JSON protocol.
class ConvAiProtocolException implements Exception {
  final String message;

  const ConvAiProtocolException(this.message);

  @override
  String toString() => 'ConvAiProtocolException: $message';
}

/// Pure codec functions between wire JSON and typed events. No I/O, fully
/// unit-testable.
abstract final class ConvAiEventCodec {
  /// Encodes the first client message of a session.
  static String encodeInitiationData() => jsonEncode(<String, dynamic>{
        'type': 'conversation_initiation_client_data',
      });

  /// Encodes a user text message that triggers an agent turn.
  static String encodeUserMessage(String text) =>
      jsonEncode(<String, dynamic>{'type': 'user_message', 'text': text});

  /// Encodes the pong answering a [PingReceived] with its `event_id`.
  static String encodePong(int eventId) =>
      jsonEncode(<String, dynamic>{'type': 'pong', 'event_id': eventId});

  /// Decodes one server frame into a typed event.
  ///
  /// Throws [ConvAiProtocolException] for malformed JSON, non-object frames,
  /// missing `type`, or recognized types whose required payload is absent.
  /// Unrecognized `type` values decode as [UnknownConvAiEvent].
  static ConvAiEvent decode(String payload) {
    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException catch (error) {
      throw ConvAiProtocolException('Malformed JSON frame: ${error.message}');
    }
    if (decoded is! Map) {
      throw ConvAiProtocolException(
        'Expected a JSON object frame but got ${decoded.runtimeType}.',
      );
    }
    final frame = Map<String, dynamic>.from(decoded);

    final type = frame['type'];
    if (type is! String || type.isEmpty) {
      throw const ConvAiProtocolException(
        'Frame is missing a non-empty string "type" field.',
      );
    }

    switch (type) {
      case 'conversation_initiation_metadata':
        final event =
            _requireMap(frame, 'conversation_initiation_metadata_event', type);
        return ConversationInitiationMetadata(
          conversationId:
              _requireString(event, 'conversation_id', type),
        );

      case 'user_transcript':
        final event = _requireMap(frame, 'user_transcription_event', type);
        return UserTranscript(_requireString(event, 'user_message', type));

      case 'agent_response':
        final event = _requireMap(frame, 'agent_response_event', type);
        return AgentResponse(_requireString(event, 'agent_response', type));

      case 'agent_response_correction':
        final event =
            _requireMap(frame, 'agent_response_correction_event', type);
        return AgentResponseCorrection(
          originalText:
              _requireString(event, 'original_agent_response', type),
          correctedText:
              _requireString(event, 'corrected_agent_response', type),
        );

      case 'audio':
        final event = _requireMap(frame, 'audio_event', type);
        return AudioChunkReceived(
          _requireString(event, 'audio_base_64', type),
        );

      case 'interruption':
        return const InterruptionReceived();

      case 'ping':
        final event = _requireMap(frame, 'ping_event', type);
        return PingReceived(
          eventId: _requireInt(event, 'event_id', type),
          pingMs: event['ping_ms'] is int ? event['ping_ms'] as int : 0,
        );

      case 'vad_score':
        final event = _requiredMapOrNull(frame, 'vad_score_event') ?? frame;
        final score = event['vad_score'];
        if (score is! num) {
          throw ConvAiProtocolException(
            '"vad_score" event requires numeric "vad_score", '
            'got ${score.runtimeType}.',
          );
        }
        return VadScoreReceived(score.toDouble());

      default:
        return UnknownConvAiEvent(type);
    }
  }

  static Map<String, dynamic> _requireMap(
    Map<String, dynamic> frame,
    String key,
    String type,
  ) {
    if (frame[key] is! Map) {
      throw ConvAiProtocolException(
        '"$type" requires object "$key".',
      );
    }
    return Map<String, dynamic>.from(frame[key] as Map);
  }

  static Map<String, dynamic>? _requiredMapOrNull(
    Map<String, dynamic> frame,
    String key,
  ) {
    final value = frame[key];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  static String _requireString(
    Map<String, dynamic> map,
    String key,
    String type,
  ) {
    final value = map[key];
    if (value is! String || value.isEmpty) {
      throw ConvAiProtocolException(
        '"$type" requires non-empty string "$key".',
      );
    }
    return value;
  }

  static int _requireInt(Map<String, dynamic> map, String key, String type) {
    final value = map[key];
    if (value is! int) {
      throw ConvAiProtocolException(
        '"$type" requires int "$key", got ${value.runtimeType}.',
      );
    }
    return value;
  }
}
