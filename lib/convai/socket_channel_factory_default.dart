import 'package:web_socket_channel/web_socket_channel.dart';

/// Opens a ConvAI WebSocket channel on platforms without custom upgrade
/// headers (web). Header-based authentication is unavailable in browsers, so
/// hosts must use signed-URL mode there; [headers] is accepted for signature
/// compatibility and ignored.
WebSocketChannel openConvAiSocket(Uri uri, Map<String, String>? headers) =>
    WebSocketChannel.connect(uri);
