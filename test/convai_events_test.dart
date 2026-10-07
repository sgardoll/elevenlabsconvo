import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:eleven_labs_conversational_a_i_library/convai/convai_events.dart';

void main() {
  group('ConvAiEventCodec.decode', () {
    test('decodes initiation metadata and extracts conversation_id', () {
      final event = ConvAiEventCodec.decode(
        jsonEncode({
          'type': 'conversation_initiation_metadata',
          'conversation_initiation_metadata_event': {
            'conversation_id': 'conv_123',
            'agent_output_audio_format': 'pcm_16000',
          },
        }),
      );

      expect(event, isA<ConversationInitiationMetadata>());
      expect(
        (event as ConversationInitiationMetadata).conversationId,
        'conv_123',
      );
    });

    test('decodes user_transcript text', () {
      final event = ConvAiEventCodec.decode(
        jsonEncode({
          'type': 'user_transcript',
          'user_transcription_event': {'user_message': 'hello', 'event_id': 1},
        }),
      );

      expect(event, isA<UserTranscript>());
      expect((event as UserTranscript).text, 'hello');
    });

    test('decodes agent_response text', () {
      final event = ConvAiEventCodec.decode(
        jsonEncode({
          'type': 'agent_response',
          'agent_response_event': {
            'agent_response': 'Hi! How can I help?',
            'event_id': 2,
          },
        }),
      );

      expect(event, isA<AgentResponse>());
      expect((event as AgentResponse).text, 'Hi! How can I help?');
    });

    test('decodes agent_response_correction with both texts', () {
      final event = ConvAiEventCodec.decode(
        jsonEncode({
          'type': 'agent_response_correction',
          'agent_response_correction_event': {
            'original_agent_response': 'draft',
            'corrected_agent_response': 'final',
            'event_id': 3,
          },
        }),
      );

      expect(event, isA<AgentResponseCorrection>());
      final correction = event as AgentResponseCorrection;
      expect(correction.originalText, 'draft');
      expect(correction.correctedText, 'final');
    });

    test('decodes audio chunks', () {
      final event = ConvAiEventCodec.decode(
        jsonEncode({
          'type': 'audio',
          'audio_event': {'audio_base_64': 'QUJD', 'event_id': 4},
        }),
      );

      expect(event, isA<AudioChunkReceived>());
      expect((event as AudioChunkReceived).audioBase64, 'QUJD');
    });

    test('decodes interruption without payload requirements', () {
      final event = ConvAiEventCodec.decode(
        jsonEncode({
          'type': 'interruption',
          'interruption_event': {'event_id': 5},
        }),
      );

      expect(event, isA<InterruptionReceived>());
    });

    test('decodes ping with event id and optional ping_ms defaulting to 0',
        () {
      final withPingMs = ConvAiEventCodec.decode(
        jsonEncode({
          'type': 'ping',
          'ping_event': {'event_id': 6, 'ping_ms': 120},
        }),
      );
      expect(withPingMs, isA<PingReceived>());
      expect((withPingMs as PingReceived).eventId, 6);
      expect(withPingMs.pingMs, 120);

      final withoutPingMs = ConvAiEventCodec.decode(
        jsonEncode({
          'type': 'ping',
          'ping_event': {'event_id': 7},
        }),
      );
      expect((withoutPingMs as PingReceived).pingMs, 0);
    });

    test('decodes vad_score as double', () {
      final event = ConvAiEventCodec.decode(
        jsonEncode({
          'type': 'vad_score',
          'vad_score_event': {'vad_score': 0.75, 'event_id': 8},
        }),
      );

      expect(event, isA<VadScoreReceived>());
      expect((event as VadScoreReceived).score, 0.75);
    });

    test('maps unknown event types to UnknownConvAiEvent', () {
      final event = ConvAiEventCodec.decode(
        jsonEncode({'type': 'some_future_event', 'data': 1}),
      );

      expect(event, isA<UnknownConvAiEvent>());
      expect((event as UnknownConvAiEvent).type, 'some_future_event');
    });

    test('throws on malformed JSON', () {
      expect(
        () => ConvAiEventCodec.decode('{not json'),
        throwsA(isA<ConvAiProtocolException>()),
      );
    });

    test('throws on non-object frames', () {
      expect(
        () => ConvAiEventCodec.decode(jsonEncode(['not', 'an', 'object'])),
        throwsA(isA<ConvAiProtocolException>()),
      );
      expect(
        () => ConvAiEventCodec.decode('"just a string"'),
        throwsA(isA<ConvAiProtocolException>()),
      );
    });

    test('throws when type field is missing or not a string', () {
      expect(
        () => ConvAiEventCodec.decode(jsonEncode({'payload': {}})),
        throwsA(isA<ConvAiProtocolException>()),
      );
      expect(
        () => ConvAiEventCodec.decode(jsonEncode({'type': 42})),
        throwsA(isA<ConvAiProtocolException>()),
      );
    });

    test('throws when initiation metadata lacks conversation_id', () {
      expect(
        () => ConvAiEventCodec.decode(jsonEncode({
              'type': 'conversation_initiation_metadata',
              'conversation_initiation_metadata_event': {},
            })),
        throwsA(isA<ConvAiProtocolException>()),
      );
    });

    test('throws when agent_response payload is absent', () {
      expect(
        () => ConvAiEventCodec.decode(
            jsonEncode({'type': 'agent_response'})),
        throwsA(isA<ConvAiProtocolException>()),
      );
    });

    test('throws when ping lacks event_id', () {
      expect(
        () => ConvAiEventCodec.decode(
          jsonEncode({'type': 'ping', 'ping_event': {'ping_ms': 10}}),
        ),
        throwsA(isA<ConvAiProtocolException>()),
      );
    });
  });

  group('ConvAiEventCodec.encode', () {
    test('encodes initiation client data with correct type', () {
      final payload = ConvAiEventCodec.encodeInitiationData();

      expect(jsonDecode(payload), {
        'type': 'conversation_initiation_client_data',
      });
    });

    test('encodes user_message with exact wire shape', () {
      final payload = ConvAiEventCodec.encodeUserMessage('hello there');

      expect(jsonDecode(payload), {
        'type': 'user_message',
        'text': 'hello there',
      });
    });

    test('encodes pong echoing the ping event_id', () {
      final payload = ConvAiEventCodec.encodePong(42);

      expect(jsonDecode(payload), {'type': 'pong', 'event_id': 42});
    });

    test('round-trips: encoded user_message decodes as expected shape', () {
      // The codec is the single source of truth for the wire format; verify
      // the encoded frame survives a JSON round-trip unchanged.
      final encoded = ConvAiEventCodec.encodeUserMessage('ping');
      final reparsed = jsonDecode(encoded) as Map<String, dynamic>;
      final reEncoded = jsonEncode(reparsed);

      expect(reEncoded, encoded);
    });
  });
}
