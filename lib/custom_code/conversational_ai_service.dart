import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart';

enum ConversationState {
  idle,
  connecting,
  connected,
  recording,
  playing,
  error
}

List<int> _wavHeaderForPCM16Mono(int pcmDataLength, {int sampleRate = 16000}) {
  final totalDataLen = pcmDataLength + 36;
  final byteRate = sampleRate * 2;
  final header = BytesBuilder();
  header.add(utf8.encode('RIFF'));
  header.add([
    totalDataLen & 0xff,
    (totalDataLen >> 8) & 0xff,
    (totalDataLen >> 16) & 0xff,
    (totalDataLen >> 24) & 0xff,
  ]);
  header.add(utf8.encode('WAVE'));
  header.add(utf8.encode('fmt '));
  header.add([16, 0, 0, 0]);
  header.add([1, 0]);
  header.add([1, 0]);
  header.add([
    sampleRate & 0xff,
    (sampleRate >> 8) & 0xff,
    (sampleRate >> 16) & 0xff,
    (sampleRate >> 24) & 0xff
  ]);
  header.add([
    byteRate & 0xff,
    (byteRate >> 8) & 0xff,
    (byteRate >> 16) & 0xff,
    (byteRate >> 24) & 0xff
  ]);
  header.add([2, 0]);
  header.add([16, 0]);
  header.add(utf8.encode('data'));
  header.add([
    pcmDataLength & 0xff,
    (pcmDataLength >> 8) & 0xff,
    (pcmDataLength >> 16) & 0xff,
    (pcmDataLength >> 24) & 0xff
  ]);
  return header.toBytes();
}

class ConversationalAIService {
  static final ConversationalAIService _instance =
      ConversationalAIService._internal();
  factory ConversationalAIService() => _instance;
  ConversationalAIService._internal();

  IOWebSocketChannel? _channel;
  StreamSubscription? _wsSub;

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  late final ConcatenatingAudioSource _playlist =
      ConcatenatingAudioSource(children: []);
  final Lock _audioLock = Lock();

  String _agentId = '';
  String _endpoint = '';
  String? _conversationId;
  String _agentOutputFormat = 'pcm_16000';
  int _agentPcmRate = 16000;

  bool _isConnected = false;
  bool _isRecording = false;
  bool _isAgentSpeaking = false;
  bool _disposed = false;

  final _stateController = StreamController<ConversationState>.broadcast();
  Stream<ConversationState> get stateStream => _stateController.stream;

  final List<File> _tempAudioFiles = [];

  Future<String> initialize({
    required String agentId,
    required String endpoint,
    String? firstMessage,
    String language = 'en',
    bool keepMicHotDuringAgent = true,
    bool autoStartMic = false,
  }) async {
    _agentId = agentId;
    _endpoint = endpoint;
    _disposed = false;
    _stateController.add(ConversationState.connecting);
    FFAppState().update(() {
      FFAppState().wsConnectionState = 'connecting';
      FFAppState().isRecording = false;
      FFAppState().isInConversation = false;
      FFAppState().isAgentSpeaking = false;
    });

    final signedUrl = await getSignedUrl(agentId, endpoint);
    if (signedUrl == null) {
      _stateController.add(ConversationState.error);
      FFAppState().update(() {
        FFAppState().wsConnectionState = 'error:no_url';
      });
      return 'error:no_signed_url';
    }

    try {
      final ws = await WebSocket.connect(
        signedUrl,
        compression: CompressionOptions.compressionOff,
      );
      _channel = IOWebSocketChannel(ws);
      _isConnected = true;
      _stateController.add(ConversationState.connected);
      FFAppState().update(() {
        FFAppState().wsConnectionState = 'connected';
      });

      await _player.setAudioSource(_playlist);
      _player.playbackEventStream.listen((_) {}, onError: (e, st) {
        debugPrint('just_audio error: $e');
      });

      _wsSub = _channel!.stream.listen(
        _onMessage,
        onDone: _onWsDone,
        onError: (e, st) {
          debugPrint('WS error: $e');
          _stateController.add(ConversationState.error);
          FFAppState().update(() {
            FFAppState().wsConnectionState = 'error:${e.toString()}';
          });
        },
        cancelOnError: true,
      );

      final initPayload = {
        "type": "conversation_initiation_client_data",
        "conversation_config_override": {
          "agent": {
            "first_message":
                firstMessage ?? "Hi! Tap the mic when you’re ready to talk.",
            "language": language,
          }
        }
      };
      _send(initPayload);

      if (autoStartMic) {
        await startRecording(keepMicHotDuringAgent: keepMicHotDuringAgent);
      }

      return 'success';
    } catch (e) {
      debugPrint('WS connect failed: $e');
      _stateController.add(ConversationState.error);
      FFAppState().update(() {
        FFAppState().wsConnectionState = 'error:${e.toString()}';
      });
      return 'error:${e.toString()}';
    }
  }

  Future<String> toggleMic({bool keepMicHotDuringAgent = true}) async {
    if (!_isConnected) return 'error:not_connected';
    if (_isRecording) {
      await stopRecording();
      FFAppState().update(() {
        FFAppState().isInConversation = true;
      });
      return 'stopped';
    } else {
      await startRecording(keepMicHotDuringAgent: keepMicHotDuringAgent);
      FFAppState().update(() {
        FFAppState().isInConversation = true;
      });
      return 'recording';
    }
  }

  Future<String> startRecording({bool keepMicHotDuringAgent = true}) async {
    if (!_isConnected) return 'error:not_connected';
    if (_isRecording) return 'success';

    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      final ok = await _recorder.hasPermission();
      if (!ok) return 'error:no_mic_permission';
    }

    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _agentPcmRate,
        numChannels: 1,
      ),
    );

    _isRecording = true;
    _stateController.add(ConversationState.recording);
    FFAppState().update(() {
      FFAppState().isRecording = true;
      FFAppState().isInConversation = true;
    });

    stream.listen((chunk) {
      if (!_isRecording) return;
      final b64 = base64Encode(chunk);
      _send({"user_audio_chunk": b64});
      _sendUserActivity();
    });

    return 'success';
  }

  Future<String> stopRecording() async {
    try {
      if (_isRecording) {
        await _recorder.stop();
      }
      _isRecording = false;
      _stateController.add(_isAgentSpeaking
          ? ConversationState.playing
          : ConversationState.connected);
      FFAppState().update(() {
        FFAppState().isRecording = false;
      });
      return 'success';
    } catch (e) {
      debugPrint('stopRecording error: $e');
      return 'error:${e.toString()}';
    }
  }

  Future<void> interrupt() async {
    _sendUserActivity();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await stopRecording();
    } catch (_) {}
    try {
      await _wsSub?.cancel();
    } catch (_) {}
    try {
      await _channel?.sink.close();
    } catch (_) {}
    try {
      await _player.stop();
      await _player.dispose();
    } catch (_) {}
    try {
      await _recorder.dispose();
    } catch (_) {}
    for (final f in _tempAudioFiles) {
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    _tempAudioFiles.clear();

    _isConnected = false;
    _stateController.add(ConversationState.idle);
    FFAppState().update(() {
      FFAppState().wsConnectionState = 'idle';
      FFAppState().isRecording = false;
      FFAppState().isAgentSpeaking = false;
      FFAppState().isInConversation = false;
    });
  }

  void _send(dynamic payload) {
    try {
      _channel?.sink.add(jsonEncode(payload));
    } catch (e) {
      debugPrint('WS send error: $e');
    }
  }

  void _sendUserActivity() {
    _send({"type": "user_activity"});
  }

  Future<void> _onMessage(dynamic data) async {
    if (data is! String) return;
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = msg['type'];

    if (type == 'conversation_initiation_metadata') {
      final meta = msg['conversation_initiation_metadata_event'] ?? {};
      _conversationId = meta['conversation_id'];
      _agentOutputFormat =
          (meta['agent_output_audio_format'] ?? 'pcm_16000').toString();
      if (_agentOutputFormat.startsWith('pcm_')) {
        final parts = _agentOutputFormat.split('_');
        _agentPcmRate =
            parts.length == 2 ? int.tryParse(parts[1]) ?? 16000 : 16000;
      }
      return;
    }

    if (type == 'user_transcript') {
      final t =
          msg['user_transcription_event']?['user_transcript']?.toString() ?? '';
      FFAppState().update(() {
        FFAppState().lastUserTranscript = t;
      });
      return;
    }

    if (type == 'agent_response') {
      final a =
          msg['agent_response_event']?['agent_response']?.toString() ?? '';
      FFAppState().update(() {
        FFAppState().lastAgentResponse = a;
        FFAppState().isAgentSpeaking = true;
      });
      _isAgentSpeaking = true;
      _stateController.add(ConversationState.playing);
      return;
    }

    if (type == 'interruption') {
      FFAppState().update(() {
        FFAppState().isAgentSpeaking = false;
      });
      _isAgentSpeaking = false;
      return;
    }

    if (type == 'vad_score') {
      final scoreStr =
          (msg['vad_score_event']?['vad_score'])?.toString() ?? '0';
      FFAppState().update(() {
        FFAppState().lastVadScore = double.tryParse(scoreStr) ?? 0.0;
      });
      return;
    }

    if (type == 'audio') {
      final event = msg['audio_event'] ?? {};
      final base64Audio = event['audio_base_64']?.toString();
      if (base64Audio == null || base64Audio.isEmpty) return;
      final chunk = base64Decode(base64Audio);
      await _queuePlayableChunk(chunk);
      return;
    }

    if (type == 'ping') {
      final id = msg['ping_event']?['event_id'];
      _send({"type": "pong", "event_id": id});
      return;
    }

    if (type == 'client_tool_call') {
      return;
    }
  }

  void _onWsDone() {
    _isConnected = false;
    _stateController.add(ConversationState.idle);
    FFAppState().update(() {
      FFAppState().wsConnectionState = 'closed';
      FFAppState().isAgentSpeaking = false;
      FFAppState().isRecording = false;
    });
  }

  Future<void> _queuePlayableChunk(List<int> raw) async {
    await _audioLock.synchronized(() async {
      try {
        File f;
        if (_agentOutputFormat.startsWith('pcm_')) {
          final wavBytes = BytesBuilder();
          wavBytes.add(
              _wavHeaderForPCM16Mono(raw.length, sampleRate: _agentPcmRate));
          wavBytes.add(raw);
          final dir = await getTemporaryDirectory();
          f = File(
              '${dir.path}/el_pcm_${DateTime.now().microsecondsSinceEpoch}.wav');
          await f.writeAsBytes(wavBytes.toBytes(), flush: true);
        } else {
          final dir = await getTemporaryDirectory();
          f = File(
              '${dir.path}/el_${_agentOutputFormat}_${DateTime.now().microsecondsSinceEpoch}');
          await f.writeAsBytes(raw, flush: true);
        }

        _tempAudioFiles.add(f);
        final src = AudioSource.uri(Uri.file(f.path));
        await _playlist.add(src);

        if (_player.playerState.processingState == ProcessingState.idle ||
            !_player.playing) {
          await _player.play();
        }

        _isAgentSpeaking = true;
        FFAppState().update(() {
          FFAppState().isAgentSpeaking = true;
        });

        _player.processingStateStream
            .firstWhere((s) => s == ProcessingState.completed)
            .then((_) {
          _isAgentSpeaking = false;
          FFAppState().update(() {
            FFAppState().isAgentSpeaking = false;
          });
          _stateController.add(_isRecording
              ? ConversationState.recording
              : ConversationState.connected);
        }).catchError((_) {});
      } catch (e) {
        debugPrint('queuePlayableChunk error: $e');
      }
    });
  }
}
