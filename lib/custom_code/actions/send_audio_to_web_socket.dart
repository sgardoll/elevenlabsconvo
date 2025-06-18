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
