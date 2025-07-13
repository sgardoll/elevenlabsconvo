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
      _elevenLabsSignedUrl =
          await secureStorage.getString('ff_elevenLabsSignedUrl') ??
              _elevenLabsSignedUrl;
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
  }

  String _wsConnectionState = 'disconnected';
  String get wsConnectionState => _wsConnectionState;
  set wsConnectionState(String value) {
    _wsConnectionState = value;
  }

  bool _isRecording = false;
  bool get isRecording => _isRecording;
  set isRecording(bool value) {
    _isRecording = value;
  }

  String _elevenLabsSignedUrl = '';
  String get elevenLabsSignedUrl => _elevenLabsSignedUrl;
  set elevenLabsSignedUrl(String value) {
    _elevenLabsSignedUrl = value;
    secureStorage.setString('ff_elevenLabsSignedUrl', value);
  }

  void deleteElevenLabsSignedUrl() {
    secureStorage.delete(key: 'ff_elevenLabsSignedUrl');
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
