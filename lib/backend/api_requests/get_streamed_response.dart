import 'package:http/http.dart';

Future<StreamedResponse> getStreamedResponse(
  Request request, {
  Client? client,
}) =>
    (client ?? Client()).send(request);
