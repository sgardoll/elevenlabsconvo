# AGENTS.md - FlutterFlow ElevenLabs Conversational AI

## Build, Lint, Test Commands

### Build
```bash
flutter build apk      # Android APK
flutter build ios      # iOS (requires macOS)
flutter build web      # Web
flutter build macos    # macOS (requires macOS)
flutter build windows  # Windows
flutter build linux    # Linux
```

### Test
```bash
flutter test                    # Run all tests
flutter test test/widget_test.dart  # Run specific test file
flutter test --plain-name "Counter increments"  # Run single test by name
flutter test --coverage         # Run with coverage
```

### Lint & Format
```bash
flutter analyze                 # Run static analysis
dart format .                   # Format all Dart files
dart format lib/ --set-exit-if-changed  # Format and exit with error if changes
```

### Dependencies
```bash
flutter pub get                 # Install dependencies
flutter pub upgrade             # Upgrade dependencies
flutter clean                   # Clean build artifacts
```

---

## Code Style Guidelines

### Imports
- Use absolute imports with `package:` for external dependencies
- Use relative imports with `/` prefix for project files (e.g., `/flutter_flow/flutter_flow_util.dart`)
- Order: FlutterFlow automatic imports → custom code → SDK imports
- Custom widgets/actions must start with automatic FlutterFlow block:
  ```dart
  // Automatic FlutterFlow imports
  import '/backend/schema/structs/index.dart';
  import '/flutter_flow/flutter_flow_theme.dart';
  import '/flutter_flow/flutter_flow_util.dart';
  import 'index.dart';
  import '/custom_code/actions/index.dart';
  import 'package:flutter/material.dart';
  // Begin custom widget code
  // DO NOT REMOVE OR MODIFY THE CODE ABOVE!
  ```

### Formatting
- 2-space indentation
- No trailing whitespace
- Line length: 80-100 characters (be consistent with surrounding code)
- Minimal comments - code should be self-documenting

### Types & Null Safety
- Dart 3.0.0+ with full null safety
- Explicit types for class members: `String`, `bool`, `List<T>`, etc.
- Use `late` for deferred initialization when needed
- Use `final` for immutable variables, `var` for local when type is obvious
- Nullable types with `?` suffix: `String?`, `DateTime?`

### Naming Conventions
- Variables/methods: `camelCase`
- Classes/types: `PascalCase`
- Files/directories: `snake_case`
- Private members: prefix with `_`
- Constants: `lowerCamelCase` or `UPPER_SNAKE_CASE` for global constants

### Patterns & Architecture
- Singleton pattern for services:
  ```dart
  class FFAppState extends ChangeNotifier {
    static FFAppState _instance = FFAppState._internal();
    factory FFAppState() => _instance;
    FFAppState._internal();
  }
  ```
- State management: Provider with `ChangeNotifier`, FFAppState singleton
- Async: Use `Future<T>` returns, `async/await`, wrap with `try-catch`
- Error handling: Return error strings prefixed with `'error: '`
- State updates: Always use `safeSetState(() { ... })` which checks `mounted`
- Disposal: Cancel stream subscriptions and dispose controllers in `dispose()`
- Platform checks: `kIsWeb`, `Platform.isAndroid`, `Platform.isiOS`

### FlutterFlow Specifics
- `lib/custom_code/**` and `lib/flutter_flow/custom_functions.dart` are excluded from analysis
- Model file pattern: `*_widget.dart` + `*_model.dart`
- Use `wrapWithModel()` for widget models
- App State integration: `FFAppState()` singleton for global state
- Theme integration: `FlutterFlowTheme.of(context)` for theme colors

### Key Utilities
- `safeSetState()`: Wrapper that checks `mounted` before calling `setState()`
- `valueOrDefault<T>(value, defaultValue)`: Safe null coalescing
- `dateTimeFormat()`: Format DateTime with locale support
- `showSnackbar()`: Display snackbar with optional loading state
- `debugPrint()`: For logging (preferred over `print()`)

### Stream & Subscription Management
- Always assign stream subscriptions to fields: `StreamSubscription<T>? _subscription`
- Cancel subscriptions in `dispose()`: `_subscription?.cancel()`
- Check `mounted` before `setState()` in stream callbacks
- Use `if (mounted) setState(...)` pattern

### Platform Permissions
- Use `requestPermission(microphonePermission)` before initialization
- Android: Add permissions to `AndroidManifest.xml`
- iOS: Add permissions to `Info.plist` (NSMicrophoneUsageDescription, UIBackgroundModes)

### Error Handling Pattern
```dart
try {
  final result = await someAsyncOperation();
  debugPrint('Operation result: $result');
  return result;
} catch (e) {
  debugPrint('Error: $e');
  return 'error: ${e.toString()}';
}
```

### Widget Lifecycle
- `initState()`: Set up streams, controllers, listeners
- `dispose()`: Cancel subscriptions, dispose controllers, stop animations
- `build()`: Use `context.watch<FFAppState>()` for reactive state
- Always check `mounted` before `setState()` in async callbacks
