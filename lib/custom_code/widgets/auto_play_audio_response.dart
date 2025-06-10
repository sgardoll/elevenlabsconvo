// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:just_audio/just_audio.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AutoPlayAudioResponse extends StatefulWidget {
  final String? base64Audio;
  final double height;
  final double width;

  const AutoPlayAudioResponse({
    Key? key,
    this.base64Audio,
    this.height = 0,
    this.width = 0,
  }) : super(key: key);

  @override
  State<AutoPlayAudioResponse> createState() => _AutoPlayAudioResponseState();
}

class _AutoPlayAudioResponseState extends State<AutoPlayAudioResponse> {
  AudioPlayer? _player;
  String? _lastPlayed;

  @override
  void didUpdateWidget(covariant AutoPlayAudioResponse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.base64Audio != null &&
        widget.base64Audio!.isNotEmpty &&
        widget.base64Audio != _lastPlayed) {
      _playAudio(widget.base64Audio!);
      _lastPlayed = widget.base64Audio;
    }
  }

  Future<void> _playAudio(String base64Audio) async {
    try {
      _player?.dispose();
      _player = AudioPlayer();

      final bytes = base64Decode(base64Audio);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/temp_audio.wav');
      await file.writeAsBytes(bytes);

      await _player!.setFilePath(file.path);
      await _player!.play();

      _player!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _player?.dispose();
          file.delete();
        }
      });
    } catch (e) {
      debugPrint('❌ Audio playback error: $e');
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: widget.width,
    );
  }
}
