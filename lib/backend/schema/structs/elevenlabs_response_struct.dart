// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ElevenlabsResponseStruct extends BaseStruct {
  ElevenlabsResponseStruct({
    String? type,
    String? content,
    int? timestamp,
  })  : _type = type,
        _content = content,
        _timestamp = timestamp;

  // "type" field.
  String? _type;
  String get type => _type ?? '';
  set type(String? val) => _type = val;

  bool hasType() => _type != null;

  // "content" field.
  String? _content;
  String get content => _content ?? '';
  set content(String? val) => _content = val;

  bool hasContent() => _content != null;

  // "timestamp" field.
  int? _timestamp;
  int get timestamp => _timestamp ?? 0;
  set timestamp(int? val) => _timestamp = val;

  void incrementTimestamp(int amount) => timestamp = timestamp + amount;

  bool hasTimestamp() => _timestamp != null;

  static ElevenlabsResponseStruct fromMap(Map<String, dynamic> data) =>
      ElevenlabsResponseStruct(
        type: data['type'] as String?,
        content: data['content'] as String?,
        timestamp: castToType<int>(data['timestamp']),
      );

  static ElevenlabsResponseStruct? maybeFromMap(dynamic data) => data is Map
      ? ElevenlabsResponseStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'type': _type,
        'content': _content,
        'timestamp': _timestamp,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'type': serializeParam(
          _type,
          ParamType.String,
        ),
        'content': serializeParam(
          _content,
          ParamType.String,
        ),
        'timestamp': serializeParam(
          _timestamp,
          ParamType.int,
        ),
      }.withoutNulls;

  static ElevenlabsResponseStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      ElevenlabsResponseStruct(
        type: deserializeParam(
          data['type'],
          ParamType.String,
          false,
        ),
        content: deserializeParam(
          data['content'],
          ParamType.String,
          false,
        ),
        timestamp: deserializeParam(
          data['timestamp'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'ElevenlabsResponseStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is ElevenlabsResponseStruct &&
        type == other.type &&
        content == other.content &&
        timestamp == other.timestamp;
  }

  @override
  int get hashCode => const ListEquality().hash([type, content, timestamp]);
}

ElevenlabsResponseStruct createElevenlabsResponseStruct({
  String? type,
  String? content,
  int? timestamp,
}) =>
    ElevenlabsResponseStruct(
      type: type,
      content: content,
      timestamp: timestamp,
    );
