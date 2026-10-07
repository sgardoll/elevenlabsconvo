/// Platform split for opening the ConvAI socket.
///
/// Native (dart:io) builds route to [openConvAiSocket] from
/// `socket_channel_factory_io.dart`, which attaches the `xi-api-key`
/// authentication header to the WebSocket upgrade request. Web builds route
/// to the default implementation, where browsers forbid custom headers and
/// signed-URL query-token authentication is used instead.
library;

export 'socket_channel_factory_default.dart'
    if (dart.library.io) 'socket_channel_factory_io.dart';
