// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:convert';
import '../websocket_manager.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' show min;

Future<String> initializeWebSocket(
  BuildContext context,
  String apiKey,
  String agentId,
) async {
  try {
    if (apiKey.isEmpty || agentId.isEmpty) {
      debugPrint('❌ Missing API key or agent ID for Conversational AI 2.0');
      return 'error: Missing API key or agent ID';
    }

    debugPrint('🔌 Initializing Conversational AI 2.0 WebSocket connection');
    debugPrint(
        '🔌 API Key: ${apiKey.substring(0, min(10, apiKey.length))}... (masked)');
    debugPrint('🔌 Agent ID: $agentId');

    final wsManager = WebSocketManager();
    await wsManager.initialize(apiKey: apiKey, agentId: agentId);

    // Update app state with Conversational AI 2.0 status
    FFAppState().update(() {
      FFAppState().wsConnectionState = 'connected';
      FFAppState().elevenLabsApiKey = apiKey;
      FFAppState().elevenLabsAgentId = agentId;
    });

    // Listen to connection state changes
    wsManager.stateStream.listen((state) {
      debugPrint('🔌 Conversational AI 2.0 WebSocket state changed: $state');
      FFAppState().update(() {
        FFAppState().wsConnectionState = state.toString().split('.').last;
      });
    });

    // Listen to messages with enhanced Conversational AI 2.0 handling
    wsManager.messageStream.listen((message) {
      final messageType = message['type'] ?? 'unknown';
      debugPrint(
          '🔌 Received Conversational AI 2.0 message type: $messageType');

      // Handle different Conversational AI 2.0 message types
      switch (messageType) {
        case 'conversation_initiation_metadata':
          final conversationId =
              message['conversation_initiation_metadata_event']
                  ?['conversation_id'];
          debugPrint('🔌 Conversation initialized with ID: $conversationId');
          FFAppState().update(() {
            FFAppState().conversationMessages = [
              ...FFAppState().conversationMessages,
              {
                'type': 'system',
                'content': 'Conversational AI 2.0 session started',
                'timestamp': DateTime.now().millisecondsSinceEpoch,
                'conversation_id': conversationId,
              }
            ];
          });
          break;

        case 'user_transcript':
          final transcript =
              message['user_transcription_event']?['user_transcript'];
          if (transcript != null) {
            debugPrint('🔌 User said: $transcript');
            FFAppState().update(() {
              FFAppState().conversationMessages = [
                ...FFAppState().conversationMessages,
                {
                  'type': 'user',
                  'content': transcript,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                }
              ];
            });
          }
          break;

        case 'agent_response':
          final response = message['agent_response_event']?['agent_response'];
          if (response != null) {
            debugPrint('🔌 Agent responded: $response');
            FFAppState().update(() {
              FFAppState().conversationMessages = [
                ...FFAppState().conversationMessages,
                {
                  'type': 'agent',
                  'content': response,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                }
              ];
            });
          }
          break;

        case 'vad_score':
          final vadScore = message['vad_score_event']?['vad_score'];
          if (vadScore != null) {
            debugPrint('🔌 Voice Activity Detection score: $vadScore');
            // Could be used for UI feedback
          }
          break;

        case 'interruption':
          final reason = message['interruption_event']?['reason'];
          debugPrint('🔌 Conversation interrupted: $reason');
          FFAppState().update(() {
            FFAppState().conversationMessages = [
              ...FFAppState().conversationMessages,
              {
                'type': 'system',
                'content': 'Conversation interrupted: $reason',
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              }
            ];
          });
          break;

        case 'client_tool_call':
          final toolName = message['client_tool_call']?['tool_name'];
          debugPrint('🔌 Tool call requested: $toolName');
          // Handle tool calls for advanced Conversational AI 2.0 features
          break;

        default:
          debugPrint('🔌 Received message: ${message.keys.join(", ")}');
          FFAppState().update(() {
            FFAppState().conversationMessages = [
              ...FFAppState().conversationMessages,
              message
            ];
          });
      }
    }, onError: (error) {
      debugPrint(
          '❌ Error from Conversational AI 2.0 WebSocket message stream: $error');
      FFAppState().update(() {
        FFAppState().wsConnectionState =
            'error: ${error.toString().substring(0, min(50, error.toString().length))}';
      });
    });

    // Listen to audio data with enhanced processing
    wsManager.audioStream.listen((audioData) {
      debugPrint(
          '🔌 Received Conversational AI 2.0 audio data: ${audioData.length} bytes');
      final base64Audio = base64Encode(audioData);
      FFAppState().update(() {
        FFAppState().lastAudioResponse = base64Audio;
      });
    }, onError: (error) {
      debugPrint(
          '❌ Error from Conversational AI 2.0 WebSocket audio stream: $error');
    });

    debugPrint('🔌 Conversational AI 2.0 WebSocket initialized successfully');
    return 'success';
  } catch (e) {
    debugPrint('❌ Error initializing Conversational AI 2.0 WebSocket: $e');

    // Update app state to show the error
    FFAppState().update(() {
      FFAppState().wsConnectionState =
          'error: ${e.toString().substring(0, min(50, e.toString().length))}';
    });

    return 'error: ${e.toString()}';
  }
}
