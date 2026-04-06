import 'package:flutter/material.dart';
import '/backend/schema/structs/index.dart';
import '/backend/api_requests/api_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:csv/csv.dart';
import 'package:synchronized/synchronized.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'dart:convert';

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future initializePersistedState() async {
    secureStorage = FlutterSecureStorage();
    await _safeInitAsync(() async {
      _endpoint = await secureStorage.getString('ff_endpoint') ?? _endpoint;
    });
    await _safeInitAsync(() async {
      _isSignedUrlExpired =
          await secureStorage.getBool('ff_isSignedUrlExpired') ??
              _isSignedUrlExpired;
    });
    await _safeInitAsync(() async {
      _cachedSignedUrl = await secureStorage.getString('ff_cachedSignedUrl') ??
          _cachedSignedUrl;
    });
    await _safeInitAsync(() async {
      _signedUrlExpirationTime =
          await secureStorage.read(key: 'ff_signedUrlExpirationTime') != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  (await secureStorage.getInt('ff_signedUrlExpirationTime'))!)
              : _signedUrlExpirationTime;
    });
    await _safeInitAsync(() async {
      _elevenLabsAgentId =
          await secureStorage.getString('ff_elevenLabsAgentId') ??
              _elevenLabsAgentId;
    });
  }

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  late FlutterSecureStorage secureStorage;

  late LoggableList<dynamic> _conversationMessages = LoggableList([]);
  List<dynamic> get conversationMessages =>
      _conversationMessages?..logger = () => debugLogAppState(this);
  set conversationMessages(List<dynamic> value) {
    if (value != null) {
      _conversationMessages = LoggableList(value);
    }

    debugLogAppState(this);
  }

  void addToConversationMessages(dynamic value) {
    conversationMessages.add(value);
  }

  void removeFromConversationMessages(dynamic value) {
    conversationMessages.remove(value);
  }

  void removeAtIndexFromConversationMessages(int index) {
    conversationMessages.removeAt(index);
  }

  void updateConversationMessagesAtIndex(
    int index,
    dynamic Function(dynamic) updateFn,
  ) {
    conversationMessages[index] = updateFn(_conversationMessages[index]);
  }

  void insertAtIndexInConversationMessages(int index, dynamic value) {
    conversationMessages.insert(index, value);
  }

  String _lastAudioResponse = '';
  String get lastAudioResponse => _lastAudioResponse;
  set lastAudioResponse(String value) {
    _lastAudioResponse = value;

    debugLogAppState(this);
  }

  String _wsConnectionState = 'disconnected';
  String get wsConnectionState => _wsConnectionState;
  set wsConnectionState(String value) {
    _wsConnectionState = value;

    debugLogAppState(this);
  }

  bool _isRecording = false;
  bool get isRecording => _isRecording;
  set isRecording(bool value) {
    _isRecording = value;

    debugLogAppState(this);
  }

  String _endpoint = '';
  String get endpoint => _endpoint;
  set endpoint(String value) {
    _endpoint = value;
    secureStorage.setString('ff_endpoint', value);
    debugLogAppState(this);
  }

  void deleteEndpoint() {
    secureStorage.delete(key: 'ff_endpoint');
  }

  bool _isSignedUrlExpired = false;
  bool get isSignedUrlExpired => _isSignedUrlExpired;
  set isSignedUrlExpired(bool value) {
    _isSignedUrlExpired = value;
    secureStorage.setBool('ff_isSignedUrlExpired', value);
    debugLogAppState(this);
  }

  void deleteIsSignedUrlExpired() {
    secureStorage.delete(key: 'ff_isSignedUrlExpired');
  }

  String _cachedSignedUrl = '';
  String get cachedSignedUrl => _cachedSignedUrl;
  set cachedSignedUrl(String value) {
    _cachedSignedUrl = value;
    secureStorage.setString('ff_cachedSignedUrl', value);
    debugLogAppState(this);
  }

  void deleteCachedSignedUrl() {
    secureStorage.delete(key: 'ff_cachedSignedUrl');
  }

  DateTime? _signedUrlExpirationTime;
  DateTime? get signedUrlExpirationTime => _signedUrlExpirationTime;
  set signedUrlExpirationTime(DateTime? value) {
    _signedUrlExpirationTime = value;
    value != null
        ? secureStorage.setInt(
            'ff_signedUrlExpirationTime', value.millisecondsSinceEpoch)
        : secureStorage.remove('ff_signedUrlExpirationTime');
    debugLogAppState(this);
  }

  void deleteSignedUrlExpirationTime() {
    secureStorage.delete(key: 'ff_signedUrlExpirationTime');
  }

  bool _isInConversation = false;
  bool get isInConversation => _isInConversation;
  set isInConversation(bool value) {
    _isInConversation = value;

    debugLogAppState(this);
  }

  bool _isAgentSpeaking = false;
  bool get isAgentSpeaking => _isAgentSpeaking;
  set isAgentSpeaking(bool value) {
    _isAgentSpeaking = value;

    debugLogAppState(this);
  }

  String _lastUserTranscript = '';
  String get lastUserTranscript => _lastUserTranscript;
  set lastUserTranscript(String value) {
    _lastUserTranscript = value;

    debugLogAppState(this);
  }

  String _lastAgentResponse = '';
  String get lastAgentResponse => _lastAgentResponse;
  set lastAgentResponse(String value) {
    _lastAgentResponse = value;

    debugLogAppState(this);
  }

  double _lastVadScore = 0.0;
  double get lastVadScore => _lastVadScore;
  set lastVadScore(double value) {
    _lastVadScore = value;

    debugLogAppState(this);
  }

  String _lastSignedUrl = '';
  String get lastSignedUrl => _lastSignedUrl;
  set lastSignedUrl(String value) {
    _lastSignedUrl = value;

    debugLogAppState(this);
  }

  String _elevenLabsAgentId = '';
  String get elevenLabsAgentId => _elevenLabsAgentId;
  set elevenLabsAgentId(String value) {
    _elevenLabsAgentId = value;
    secureStorage.setString('ff_elevenLabsAgentId', value);
    debugLogAppState(this);
  }

  void deleteElevenLabsAgentId() {
    secureStorage.delete(key: 'ff_elevenLabsAgentId');
  }

  Map<String, DebugDataField> toDebugSerializableMap() => {
        'conversationMessages': debugSerializeParam(
          conversationMessages,
          ParamType.JSON,
          isList: true,
          link:
              'https://beta.flutterflow.io/project/elevenlabs-conversational2-x2dkep?tab=appValues&appValuesTab=state',
          searchReference:
              'reference=CioKIAoUY29udmVyc2F0aW9uTWVzc2FnZXMSCDFkOTN3OHpncgQSAggJegBaFGNvbnZlcnNhdGlvbk1lc3NhZ2Vz',
          name: 'dynamic',
          nullable: false,
        ),
        'lastAudioResponse': debugSerializeParam(
          lastAudioResponse,
          ParamType.String,
          link:
              'https://beta.flutterflow.io/project/elevenlabs-conversational2-x2dkep?tab=appValues&appValuesTab=state',
          searchReference:
              'reference=CiUKHQoRbGFzdEF1ZGlvUmVzcG9uc2USCDdrOTJlZTM2cgIIA3oAWhFsYXN0QXVkaW9SZXNwb25zZQ==',
          name: 'String',
          nullable: false,
        ),
        'wsConnectionState': debugSerializeParam(
          wsConnectionState,
          ParamType.String,
          link:
              'https://beta.flutterflow.io/project/elevenlabs-conversational2-x2dkep?tab=appValues&appValuesTab=state',
          searchReference:
              'reference=CiUKHQoRd3NDb25uZWN0aW9uU3RhdGUSCGUwMnJ5aG5kcgIIA3oAWhF3c0Nvbm5lY3Rpb25TdGF0ZQ==',
          name: 'String',
          nullable: false,
        ),
        'isRecording': debugSerializeParam(
          isRecording,
          ParamType.bool,
          link:
              'https://beta.flutterflow.io/project/elevenlabs-conversational2-x2dkep?tab=appValues&appValuesTab=state',
          searchReference:
              'reference=Ch8KFwoLaXNSZWNvcmRpbmcSCG9razcxN2g5cgIIBXoAWgtpc1JlY29yZGluZw==',
          name: 'bool',
          nullable: false,
        ),
        'endpoint': debugSerializeParam(
          endpoint,
          ParamType.String,
          link:
              'https://beta.flutterflow.io/project/elevenlabs-conversational2-x2dkep?tab=appValues&appValuesTab=state',
          searchReference:
              'reference=ChwKFAoIZW5kcG9pbnQSCGg2eDNpY2hycgIIA3oAWghlbmRwb2ludA==',
          name: 'String',
          nullable: false,
        ),
        'isSignedUrlExpired': debugSerializeParam(
          isSignedUrlExpired,
          ParamType.bool,
          link:
              'https://beta.flutterflow.io/project/elevenlabs-conversational2-x2dkep?tab=appValues&appValuesTab=state',
          searchReference:
              'reference=CiYKHgoSaXNTaWduZWRVcmxFeHBpcmVkEghtNDkxaGhwOXICCAV6AFoSaXNTaWduZWRVcmxFeHBpcmVk',
          name: 'bool',
          nullable: false,
        ),
        'cachedSignedUrl': debugSerializeParam(
          cachedSignedUrl,
          ParamType.String,
          link:
              'https://beta.flutterflow.io/project/elevenlabs-conversational2-x2dkep?tab=appValues&appValuesTab=state',
          searchReference:
              'reference=CiMKGwoPY2FjaGVkU2lnbmVkVXJsEgg0cW01MmxmdXICCAN6AFoPY2FjaGVkU2lnbmVkVXJs',
          name: 'String',
          nullable: false,
        ),
        'signedUrlExpirationTime': debugSerializeParam(
          signedUrlExpirationTime,
          ParamType.DateTime,
          link:
              'https://beta.flutterflow.io/project/elevenlabs-conversational2-x2dkep?tab=appValues&appValuesTab=state',
          searchReference:
              'reference=CkwKIwoXc2lnbmVkVXJsRXhwaXJhdGlvblRpbWUSCDZvc3VqNnR4ciMICCofOh0KE0NvbnZlcnNhdGlvblNlcnZpY2UiBjFuYnU4MnoAWhdzaWduZWRVcmxFeHBpcmF0aW9uVGltZQ==',
          name: 'DateTime',
          nullable: false,
        ),
        'isInConversation': debugSerializeParam(
          isInConversation,
          ParamType.bool,
          link:
              'https://beta.flutterflow.io/project/elevenlabs-conversational2-x2dkep?tab=appValues&appValuesTab=state',
          searchReference:
              'reference=CiQKHAoQaXNJbkNvbnZlcnNhdGlvbhIIem1hZ2dwNHZyAggFegBaEGlzSW5Db252ZXJzYXRpb24=',
          name: 'bool',
          nullable: false,
        ),
        'isAgentSpeaking': debugSerializeParam(
          isAgentSpeaking,
          ParamType.bool,
          link:
              'https://beta.flutterflow.io/project/elevenlabs-conversational2-x2dkep?tab=appValues&appValuesTab=state',
          searchReference:
              'reference=CiMKGwoPaXNBZ2VudFNwZWFraW5nEghtejg3NG56eHICCAV6AFoPaXNBZ2VudFNwZWFraW5n',
          name: 'bool',
          nullable: false,
        ),
        'lastUserTranscript': debugSerializeParam(
          lastUserTranscript,
          ParamType.String,
          link:
              'https://beta.flutterflow.io/project/elevenlabs-conversational2-x2dkep?tab=appValues&appValuesTab=state',
          searchReference:
              'reference=CiYKHgoSbGFzdFVzZXJUcmFuc2NyaXB0EghhZG00Zm92ZHICCAN6AFoSbGFzdFVzZXJUcmFuc2NyaXB0',
          name: 'String',
          nullable: false,
        ),
        'lastAgentResponse': debugSerializeParam(
          lastAgentResponse,
          ParamType.String,
          link:
              'https://beta.flutterflow.io/project/elevenlabs-conversational2-x2dkep?tab=appValues&appValuesTab=state',
          searchReference:
              'reference=CiUKHQoRbGFzdEFnZW50UmVzcG9uc2USCHk3YjBydGpscgIIA3oAWhFsYXN0QWdlbnRSZXNwb25zZQ==',
          name: 'String',
          nullable: false,
        ),
        'lastVadScore': debugSerializeParam(
          lastVadScore,
          ParamType.double,
          link:
              'https://beta.flutterflow.io/project/elevenlabs-conversational2-x2dkep?tab=appValues&appValuesTab=state',
          searchReference:
              'reference=CiAKGAoMbGFzdFZhZFNjb3JlEggxaTJvMGxmdXICCAJ6AFoMbGFzdFZhZFNjb3Jl',
          name: 'double',
          nullable: false,
        ),
        'lastSignedUrl': debugSerializeParam(
          lastSignedUrl,
          ParamType.String,
          link:
              'https://beta.flutterflow.io/project/elevenlabs-conversational2-x2dkep?tab=appValues&appValuesTab=state',
          searchReference:
              'reference=CiEKGQoNbGFzdFNpZ25lZFVybBIINDZlN3V5b3FyAggDegBaDWxhc3RTaWduZWRVcmw=',
          name: 'String',
          nullable: false,
        ),
        'elevenLabsAgentId': debugSerializeParam(
          elevenLabsAgentId,
          ParamType.String,
          link:
              'https://beta.flutterflow.io/project/elevenlabs-conversational2-x2dkep?tab=appValues&appValuesTab=state',
          searchReference:
              'reference=CiUKHQoRZWxldmVuTGFic0FnZW50SWQSCHFlM2RlaHI2cgIIA3oAWhFlbGV2ZW5MYWJzQWdlbnRJZA==',
          name: 'String',
          nullable: false,
        )
      };
}

void _safeInit(Function() initializeField) {
  try {
    initializeField();
  } catch (_) {}
}

Future _safeInitAsync(Function() initializeField) async {
  try {
    await initializeField();
  } catch (_) {}
}

extension FlutterSecureStorageExtensions on FlutterSecureStorage {
  static final _lock = Lock();

  Future<void> writeSync({required String key, String? value}) async =>
      await _lock.synchronized(() async {
        await write(key: key, value: value);
      });

  void remove(String key) => delete(key: key);

  Future<String?> getString(String key) async => await read(key: key);
  Future<void> setString(String key, String value) async =>
      await writeSync(key: key, value: value);

  Future<bool?> getBool(String key) async => (await read(key: key)) == 'true';
  Future<void> setBool(String key, bool value) async =>
      await writeSync(key: key, value: value.toString());

  Future<int?> getInt(String key) async =>
      int.tryParse(await read(key: key) ?? '');
  Future<void> setInt(String key, int value) async =>
      await writeSync(key: key, value: value.toString());

  Future<double?> getDouble(String key) async =>
      double.tryParse(await read(key: key) ?? '');
  Future<void> setDouble(String key, double value) async =>
      await writeSync(key: key, value: value.toString());

  Future<List<String>?> getStringList(String key) async =>
      await read(key: key).then((result) {
        if (result == null || result.isEmpty) {
          return null;
        }
        return CsvToListConverter()
            .convert(result)
            .first
            .map((e) => e.toString())
            .toList();
      });
  Future<void> setStringList(String key, List<String> value) async =>
      await writeSync(key: key, value: ListToCsvConverter().convert([value]));
}
