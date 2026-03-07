// Stub file for BrowserClient on non-web platforms
// This file is used when dart.library.io is available (mobile/desktop)
import 'package:http/http.dart' as http;

/// Stub implementation of BrowserClient for non-web platforms.
/// This class provides the same interface as the real BrowserClient
/// but withCredentials is a no-op on non-web platforms.
///
/// Note: This stub is never actually instantiated on non-web platforms
/// (the code uses http.Client() instead), but it's needed for type compatibility.
class BrowserClient extends http.BaseClient {
  bool _withCredentials = false;

  /// Controls whether credentials are sent with cross-site requests.
  /// This is a no-op on non-web platforms (mobile/desktop).
  bool get withCredentials => _withCredentials;
  set withCredentials(bool value) {
    _withCredentials = value;
  }

  // REQUIRED: BaseClient is abstract and requires send() to be implemented
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Delegate to a standard client (this should never be called on non-web)
    return http.Client().send(request);
  }
  // OPTIONAL: close() has a default empty implementation in BaseClient
  // We can omit it since BaseClient provides a default
}
