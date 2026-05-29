import 'api_manager.dart';

export 'api_manager.dart' show ApiCallResponse;

class GetSignedURLViaBuildShipCallCall {
  static Future<ApiCallResponse> call({
    String? agentId = '',
    String? endpoint = '',
  }) async {
    final ffApiRequestBody = '''
{
  "agentId": "${escapeStringForJson(agentId)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'GetSignedURLViaBuildShipCall',
      apiUrl: '${endpoint}',
      callType: ApiCallType.POST,
      headers: {
        'Content-Type': 'application/json',
      },
      params: {
        'agentId': agentId,
      },
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ApiPagingParams {
  int nextPageNumber = 0;
  int numItems = 0;
  dynamic lastResponse;

  ApiPagingParams({
    required this.nextPageNumber,
    required this.numItems,
    required this.lastResponse,
  });

  @override
  String toString() =>
      'PagingParams(nextPageNumber: $nextPageNumber, numItems: $numItems, lastResponse: $lastResponse,)';
}

String? escapeStringForJson(String? input) {
  if (input == null) {
    return null;
  }
  return input
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n')
      .replaceAll('\t', '\\t');
}
