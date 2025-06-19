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

  bool _isRecording = false;
  bool get isRecording => _isRecording;
  set isRecording(bool value) {
    _isRecording = value;
  }

  String _elevenLabsApiKey = '';
  String get elevenLabsApiKey => _elevenLabsApiKey;
  set elevenLabsApiKey(String value) {
    _elevenLabsApiKey = value;
    secureStorage.setString('ff_elevenLabsApiKey', value);
  }

  void deleteElevenLabsApiKey() {
    secureStorage.delete(key: 'ff_elevenLabsApiKey');
  }

  String _elevenLabsAgentId = '';
  String get elevenLabsAgentId => _elevenLabsAgentId;
  set elevenLabsAgentId(String value) {
    _elevenLabsAgentId = value;
    secureStorage.setString('ff_elevenLabsAgentId', value);
  }

  void deleteElevenLabsAgentId() {
    secureStorage.delete(key: 'ff_elevenLabsAgentId');
  }

  String _conversationState = 'disconnected';
  String get conversationState => _conversationState;
  set conversationState(String value) {
    _conversationState = value;
  }

  String _lastTranscript = '';
  String get lastTranscript => _lastTranscript;
  set lastTranscript(String value) {
    _lastTranscript = value;
  }

  String _lastError = '';
  String get lastError => _lastError;
  set lastError(String value) {
    _lastError = value;
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
