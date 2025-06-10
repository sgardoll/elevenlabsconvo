import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:csv/csv.dart';
import 'package:synchronized/synchronized.dart';
import 'flutter_flow/flutter_flow_util.dart';

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
      _conversationMessages =
          (await secureStorage.getStringList('ff_conversationMessages'))
                  ?.map((x) {
                try {
                  return jsonDecode(x);
                } catch (e) {
                  print("Can't decode persisted json. Error: $e.");
                  return {};
                }
              }).toList() ??
              _conversationMessages;
    });
    await _safeInitAsync(() async {
      _lastAudioResponse =
          await secureStorage.getString('ff_lastAudioResponse') ??
              _lastAudioResponse;
    });
    await _safeInitAsync(() async {
      _elevenLabsApiKey =
          await secureStorage.getString('ff_elevenLabsApiKey') ??
              _elevenLabsApiKey;
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

  List<dynamic> _conversationMessages = [];
  List<dynamic> get conversationMessages => _conversationMessages;
  set conversationMessages(List<dynamic> value) {
    _conversationMessages = value;
    secureStorage.setStringList(
        'ff_conversationMessages', value.map((x) => jsonEncode(x)).toList());
  }

  void deleteConversationMessages() {
    secureStorage.delete(key: 'ff_conversationMessages');
  }

  void addToConversationMessages(dynamic value) {
    conversationMessages.add(value);
    secureStorage.setStringList('ff_conversationMessages',
        _conversationMessages.map((x) => jsonEncode(x)).toList());
  }

  void removeFromConversationMessages(dynamic value) {
    conversationMessages.remove(value);
    secureStorage.setStringList('ff_conversationMessages',
        _conversationMessages.map((x) => jsonEncode(x)).toList());
  }

  void removeAtIndexFromConversationMessages(int index) {
    conversationMessages.removeAt(index);
    secureStorage.setStringList('ff_conversationMessages',
        _conversationMessages.map((x) => jsonEncode(x)).toList());
  }

  void updateConversationMessagesAtIndex(
    int index,
    dynamic Function(dynamic) updateFn,
  ) {
    conversationMessages[index] = updateFn(_conversationMessages[index]);
    secureStorage.setStringList('ff_conversationMessages',
        _conversationMessages.map((x) => jsonEncode(x)).toList());
  }

  void insertAtIndexInConversationMessages(int index, dynamic value) {
    conversationMessages.insert(index, value);
    secureStorage.setStringList('ff_conversationMessages',
        _conversationMessages.map((x) => jsonEncode(x)).toList());
  }

  String _lastAudioResponse = '';
  String get lastAudioResponse => _lastAudioResponse;
  set lastAudioResponse(String value) {
    _lastAudioResponse = value;
    secureStorage.setString('ff_lastAudioResponse', value);
  }

  void deleteLastAudioResponse() {
    secureStorage.delete(key: 'ff_lastAudioResponse');
  }

  String _wsConnectionState = 'disconnected';
  String get wsConnectionState => _wsConnectionState;
  set wsConnectionState(String value) {
    _wsConnectionState = value;
  }

  String _elevenLabsApiKey =
      'sk_2c1a496751bfc66846d746c17bc8d74b6150c64d5307ab56';
  String get elevenLabsApiKey => _elevenLabsApiKey;
  set elevenLabsApiKey(String value) {
    _elevenLabsApiKey = value;
    secureStorage.setString('ff_elevenLabsApiKey', value);
  }

  void deleteElevenLabsApiKey() {
    secureStorage.delete(key: 'ff_elevenLabsApiKey');
  }

  String _elevenLabsAgentId = 'agent_01jx0a0wsseybb7vb9972j46bq';
  String get elevenLabsAgentId => _elevenLabsAgentId;
  set elevenLabsAgentId(String value) {
    _elevenLabsAgentId = value;
    secureStorage.setString('ff_elevenLabsAgentId', value);
  }

  void deleteElevenLabsAgentId() {
    secureStorage.delete(key: 'ff_elevenLabsAgentId');
  }

  bool _isRecording = false;
  bool get isRecording => _isRecording;
  set isRecording(bool value) {
    _isRecording = value;
  }
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
