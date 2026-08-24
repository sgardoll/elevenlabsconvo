import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Opens a ConvAI WebSocket channel on dart:io platforms, attaching
/// [headers] (the `xi-api-key` authentication header) to the upgrade request.
WebSocketChannel openConvAiSocket(Uri uri, Map<String, String>? headers) =>
    IOWebSocketChannel.connect(uri, headers: headers);
