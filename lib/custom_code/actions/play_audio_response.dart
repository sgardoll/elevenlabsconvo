// Automatic FlutterFlow imports
import '/actions/actions.dart' as action_blocks;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:just_audio/just_audio.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

Future<String> playAudioResponse(
  BuildContext context,
  String base64AudioData,
) async {
  AudioPlayer? player;
  File? tempFile;

  try {
    // Validate base64 audio data
    if (base64AudioData.isEmpty) {
      return 'error: Empty audio data provided';
    }

    // For Conversational AI 2.0, lower the threshold to handle streaming audio chunks
    if (base64AudioData.length < 10) {
      debugPrint(
          '❌ Play Audio: Audio data too short (${base64AudioData.length} chars), likely corrupted');
      return 'error: Audio data too short, likely corrupted';
    }

    // Validate base64 format
    try {
      final testLength =
          base64AudioData.length > 100 ? 100 : base64AudioData.length;
      base64Decode(base64AudioData.substring(0, testLength));
    } catch (e) {
      debugPrint('❌ Play Audio: Invalid base64 format: $e');
      return 'error: Invalid base64 format';
    }

    player = AudioPlayer();
    final audioBytes = base64Decode(base64AudioData);

    // For Conversational AI 2.0, lower the threshold for streaming audio
    if (audioBytes.length < 10) {
      debugPrint(
          '❌ Play Audio: Decoded audio too small (${audioBytes.length} bytes), likely corrupted');
      return 'error: Decoded audio too small, likely corrupted';
    }

    debugPrint(
        '🎵 Play Audio: Processing Conversational AI 2.0 audio (${audioBytes.length} bytes)');

    // Create proper WAV file from PCM data (Conversational AI 2.0 format)
    final wavBytes = _createWavFile(audioBytes);

    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    tempFile = File('${dir.path}/play_audio_$timestamp.wav');

    await tempFile.writeAsBytes(wavBytes);

    if (!await tempFile.exists() || await tempFile.length() < 44) {
      debugPrint('❌ Play Audio: Failed to create WAV file');
      return 'error: Failed to create audio file';
    }

    debugPrint(
        '🎵 Play Audio: Playing Conversational AI 2.0 WAV file (${await tempFile.length()} bytes)');

    await player.setFilePath(tempFile.path);
    await player.play();

    // Wait for completion
    final completer = Completer<void>();
    player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed ||
          state.processingState == ProcessingState.idle) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    await completer.future;

    debugPrint('🎵 Play Audio: Conversational AI 2.0 audio playback completed');
    return 'success';
  } catch (e) {
    debugPrint('❌ Play Audio: Error playing Conversational AI 2.0 audio: $e');
    return 'error: ${e.toString()}';
  } finally {
    try {
      await player?.dispose();
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
        debugPrint('🗑️ Play Audio: Temporary file deleted');
      }
    } catch (e) {
      debugPrint('⚠️ Play Audio: Error during cleanup: $e');
    }
  }
}

// Create a proper WAV file from PCM data
// ElevenLabs Conversational AI 2.0 returns PCM 16kHz 16-bit mono audio
Uint8List _createWavFile(Uint8List pcmData) {
  const int sampleRate = 16000; // ElevenLabs Conversational AI 2.0 uses 16kHz
  const int bitsPerSample = 16; // 16-bit audio
  const int channels = 1; // Mono audio

  final int dataSize = pcmData.length;
  final int fileSize = 44 + dataSize; // WAV header is 44 bytes

  final ByteData wavHeader = ByteData(44);

  // RIFF header
  wavHeader.setUint8(0, 0x52); // 'R'
  wavHeader.setUint8(1, 0x49); // 'I'
  wavHeader.setUint8(2, 0x46); // 'F'
  wavHeader.setUint8(3, 0x46); // 'F'
  wavHeader.setUint32(4, fileSize - 8, Endian.little); // File size - 8

  // WAVE header
  wavHeader.setUint8(8, 0x57); // 'W'
  wavHeader.setUint8(9, 0x41); // 'A'
  wavHeader.setUint8(10, 0x56); // 'V'
  wavHeader.setUint8(11, 0x45); // 'E'

  // fmt chunk
  wavHeader.setUint8(12, 0x66); // 'f'
  wavHeader.setUint8(13, 0x6d); // 'm'
  wavHeader.setUint8(14, 0x74); // 't'
  wavHeader.setUint8(15, 0x20); // ' '
  wavHeader.setUint32(16, 16, Endian.little); // fmt chunk size
  wavHeader.setUint16(20, 1, Endian.little); // PCM format
  wavHeader.setUint16(22, channels, Endian.little); // Number of channels
  wavHeader.setUint32(24, sampleRate, Endian.little); // Sample rate
  wavHeader.setUint32(28, sampleRate * channels * bitsPerSample ~/ 8,
      Endian.little); // Byte rate
  wavHeader.setUint16(
      32, channels * bitsPerSample ~/ 8, Endian.little); // Block align
  wavHeader.setUint16(34, bitsPerSample, Endian.little); // Bits per sample

  // data chunk
  wavHeader.setUint8(36, 0x64); // 'd'
  wavHeader.setUint8(37, 0x61); // 'a'
  wavHeader.setUint8(38, 0x74); // 't'
  wavHeader.setUint8(39, 0x61); // 'a'
  wavHeader.setUint32(40, dataSize, Endian.little); // Data size

  // Combine header and PCM data
  final Uint8List wavFile = Uint8List(fileSize);
  wavFile.setRange(0, 44, wavHeader.buffer.asUint8List());
  wavFile.setRange(44, fileSize, pcmData);

  return wavFile;
}

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
