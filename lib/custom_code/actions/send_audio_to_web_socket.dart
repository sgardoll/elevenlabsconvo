import 'dart:io';
import 'package:flutter/foundation.dart'; // Or your preferred way for debugPrint
import '../websocket_manager.dart'; // Adjust path if necessary
// Keep other existing FlutterFlow imports if they were there and are still needed.

Future<String> sendAudioToWebSocket(String? filePath) async {
  if (filePath == null || filePath.isEmpty) {
    debugPrint('❌ Send Audio: No file path provided');
    return 'error: No file path provided';
  }

  final file = File(filePath);
  if (!await file.exists()) {
    debugPrint('❌ Send Audio: File does not exist: $filePath');
    return 'error: File does not exist';
  }

  debugPrint('🎙️ Preparing to stream audio file: $filePath');

  try {
    Stream<List<int>> audioStream = file.openRead();
    await WebSocketManager.instance.sendAudio(audioStream);
    debugPrint('🎙️ Audio stream sent to WebSocketManager for file: $filePath');

    // Optional: Clean up temporary file
    // If you want to delete the file after sending, uncomment the following block.
    // Be cautious with this, ensure the file is intended to be temporary.
    /*
    try {
      await file.delete();
      debugPrint('🎙️ Temporary file deleted: $filePath');
    } catch (e) {
      debugPrint('⚠️ Error deleting temporary file $filePath: $e');
    }
    */

    return 'success';
  } catch (e) {
    debugPrint('❌ Error streaming audio to WebSocket for file $filePath: $e');
    return 'error: ${e.toString()}';
  }
}
