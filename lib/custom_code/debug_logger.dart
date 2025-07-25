import 'package:flutter/foundation.dart';

class DebugLogger {
  static const String _tag = '🤖 ConversationalAI';

  static void log(String message, {String level = 'INFO'}) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String().substring(11, 23);
      debugPrint('[$timestamp] $_tag [$level] $message');
    }
  }

  static void info(String message) => log(message, level: 'INFO');
  static void error(String message) => log(message, level: 'ERROR');
  static void warning(String message) => log(message, level: 'WARN');
  static void debug(String message) => log(message, level: 'DEBUG');

  static void logServiceState(String state, {Map<String, dynamic>? details}) {
    final detailsStr = details != null ? ' - ${details.toString()}' : '';
    info('Service State: $state$detailsStr');
  }

  static void logAudioEvent(String event, {Map<String, dynamic>? details}) {
    final detailsStr = details != null ? ' - ${details.toString()}' : '';
    info('Audio Event: $event$detailsStr');
  }

  static void logConnection(String status, {String? error}) {
    final errorStr = error != null ? ' - Error: $error' : '';
    info('Connection: $status$errorStr');
  }
}
