

class FFLibraryValues {
  static FFLibraryValues _instance = FFLibraryValues._internal();

  factory FFLibraryValues() {
    return _instance;
  }

  FFLibraryValues._internal();

  static void reset() {
    _instance = FFLibraryValues._internal();
  }

  late String agentId = 'agent_01jzmvwhxhf6kaya6n6zbtd0s1';
  late String endpoint = 'https://4tgke4.buildship.run/eleven-labs-credentials';
}
