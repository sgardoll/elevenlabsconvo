// Automatic FlutterFlow imports
import '/actions/actions.dart' as action_blocks;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '../websocket_manager.dart';

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String> sendAudioToWebSocket(String? filePath) async {
  if (filePath == null || filePath.isEmpty) {
    debugPrint('❌ Send Audio: No file path provided');
    return 'error: No file path provided';
  }

  try {
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('❌ Send Audio: File does not exist: $filePath');
      return 'error: File does not exist';
    }

    debugPrint('🎙️ Reading file bytes...');
    final audioBytes = await file.readAsBytes();
    debugPrint('🎙️ File size: ${audioBytes.length} bytes');

    // Validate audio data
    if (audioBytes.isEmpty) {
      debugPrint('❌ Audio file is empty');
      return 'error: Audio file is empty';
    }

    // Basic audio validation - check if it contains meaningful data
    int nonZeroBytes = 0;
    for (int i = 0; i < audioBytes.length && i < 1000; i++) {
      if (audioBytes[i] != 0) nonZeroBytes++;
    }
    debugPrint(
        '🎙️ Audio validation: ${nonZeroBytes}/1000 non-zero bytes in sample');

    if (nonZeroBytes < 10) {
      debugPrint('⚠️ Audio appears to be mostly silence');
    }

    debugPrint('🎙️ Sending audio to WebSocket...');

    // For Conversational AI 2.0, the format is different
    final wsManager = WebSocketManager();

    // The audio is already in raw PCM format, so we can send it directly
    debugPrint(
        '🔊 Sending raw PCM audio data for Conversational AI 2.0 (length: ${audioBytes.length})');

    // Send the audio data in chunks for better performance with large files
    // Try smaller chunks for better server-side VAD detection
    const chunkSize = 1024; // Reduced from 4096 to improve VAD responsiveness
    debugPrint(
        '🔊 Total audio size: ${audioBytes.length} bytes, sending in ${chunkSize}-byte chunks');

    for (int i = 0; i < audioBytes.length; i += chunkSize) {
      final end = (i + chunkSize > audioBytes.length)
          ? audioBytes.length
          : i + chunkSize;
      final chunk = audioBytes.sublist(i, end);
      debugPrint(
          '🔊 Sending audio chunk ${(i / chunkSize).floor() + 1} to Conversational AI 2.0 (${chunk.length} bytes)');
      await wsManager.sendAudioChunk(Uint8List.fromList(chunk));

      // Add small delay between chunks to help with processing
      await Future.delayed(const Duration(milliseconds: 10));
    }

    debugPrint(
        '🔊 Finished sending all ${(audioBytes.length / chunkSize).ceil()} audio chunks');

    // Send an empty audio chunk to explicitly signal end of speech for server-side VAD
    debugPrint('🔊 Sending empty audio chunk to signal end of speech');
    await wsManager.sendAudioChunk(Uint8List(0));

    // For server-side VAD, we need to signal the end of user turn properly
    // Send user activity signal to help with turn-taking in Conversational AI 2.0
    await wsManager.sendUserActivity();

    debugPrint('🔊 Audio successfully sent to Conversational AI 2.0');

    // Clean up temporary file
    try {
      await file.delete();
      debugPrint('🎙️ Temporary file deleted');
    } catch (e) {
      debugPrint('⚠️ Error deleting temporary file: $e');
    }

    debugPrint('🎙️ Audio sent to WebSocket successfully');
    return 'success';
  } catch (e) {
    debugPrint('❌ Error sending audio to WebSocket: $e');
    return 'error: ${e.toString()}';
  }
}

/// Streams audio from a file to the WebSocket in real-time chunks
/// This is an alternative implementation that reads the file as a stream
/// and sends it chunk by chunk as requested in the improvement suggestion
Future<String> sendAudioFileAsStream(String? filePath) async {
  if (filePath == null || filePath.isEmpty) {
    debugPrint('❌ Send Audio Stream: No file path provided');
    return 'error: No file path provided';
  }

  try {
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('❌ Send Audio Stream: File does not exist: $filePath');
      return 'error: File does not exist';
    }

    debugPrint('🎙️ Starting to stream audio file: $filePath');
    
    // Get the WebSocket manager
    final wsManager = WebSocketManager();
    
    // Get the stream of bytes from the audio file
    Stream<List<int>> audioStream = file.openRead();
    
    // Buffer to accumulate data for proper chunk sizes
    List<int> buffer = [];
    const int targetChunkSize = 1024; // 1KB chunks for real-time feel
    int totalBytesSent = 0;
    
    await for (List<int> chunk in audioStream) {
      // Add new data to buffer
      buffer.addAll(chunk);
      
      // Send chunks of target size
      while (buffer.length >= targetChunkSize) {
        final audioChunk = buffer.sublist(0, targetChunkSize);
        buffer = buffer.sublist(targetChunkSize);
        
        debugPrint('🔊 Streaming audio chunk: ${audioChunk.length} bytes');
        await wsManager.sendAudioChunk(Uint8List.fromList(audioChunk));
        totalBytesSent += audioChunk.length;
        
        // Small delay to simulate real-time streaming
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }
    
    // Send any remaining data in buffer
    if (buffer.isNotEmpty) {
      debugPrint('🔊 Streaming final audio chunk: ${buffer.length} bytes');
      await wsManager.sendAudioChunk(Uint8List.fromList(buffer));
      totalBytesSent += buffer.length;
    }
    
    // Send empty chunk to signal end of audio
    debugPrint('🔊 Sending empty chunk to signal end of audio stream');
    await wsManager.sendAudioChunk(Uint8List(0));
    
    // Send end-of-turn signal
    await wsManager.sendUserActivity();
    await wsManager.sendEndOfTurn();
    
    debugPrint('🔊 Audio file streaming completed. Total bytes sent: $totalBytesSent');
    
    // Clean up the file
    try {
      await file.delete();
      debugPrint('🎙️ Temporary file deleted after streaming');
    } catch (e) {
      debugPrint('⚠️ Error deleting temporary file after streaming: $e');
    }
    
    return 'success';
  } catch (e) {
    debugPrint('❌ Error streaming audio file to WebSocket: $e');
    return 'error: ${e.toString()}';
  }
}

/// Implementation exactly as suggested in the improvement request
/// This function implements the exact approach described in the user's suggestion
Future<void> sendAudioToWebSocketAsStream(String? filePath) async {
  if (filePath == null) {
    print("File path is null, cannot send audio.");
    return;
  }

  final file = File(filePath);
  if (!await file.exists()) {
    print("File does not exist at path: $filePath");
    return;
  }
  
  // Get the stream of bytes from the audio file
  Stream<List<int>> audioStream = file.openRead();

  // Send it via the manager
  // Note: This assumes your WebSocket server is set up to receive audio this way.
  // You may need to wrap it in a specific JSON structure.
  await WebSocketManager().sendAudio(audioStream);
}
