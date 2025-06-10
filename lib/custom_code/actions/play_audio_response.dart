// Automatic FlutterFlow imports
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

Future<String> playAudioResponse(
  BuildContext context,
  String base64AudioData,
) async {
  try {
    final player = AudioPlayer();
    final audioBytes = base64Decode(base64AudioData);

    // Save to temporary file
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/temp_audio.wav');
    await tempFile.writeAsBytes(audioBytes);

    // Play audio
    await player.setFilePath(tempFile.path);
    await player.play();

    // Clean up when done
    player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        player.dispose();
        tempFile.deleteSync();
      }
    });

    return 'success';
  } catch (e) {
    return 'error: ${e.toString()}';
  }
}

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
