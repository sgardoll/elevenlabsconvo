

class FFLibraryValues {
  static FFLibraryValues _instance = FFLibraryValues._internal();

  factory FFLibraryValues() {
    return _instance;
  }

  FFLibraryValues._internal();

  static void reset() {
    _instance = FFLibraryValues._internal();
  }

  // TODO: Move to environment config before deployment
  late String agentId = '';
  late String endpoint = 'https://[YOUR_BACKEND]/eleven-labs-credentials';
}
