import 'package:flutter/foundation.dart' show kIsWeb;

/// Base URL for the Node.js backend API.
/// Set via: flutter run --dart-define=BACKEND_URL=https://your-api.com
/// - Local: http://localhost:3000
/// - Android Emulator: http://10.0.2.2:3000
/// - Physical device / same network: http://YOUR_IP:3000
const String kBackendBaseUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'http://localhost:3000',
);

/// Google API key for Directions API (route distance).
/// Set via: flutter run --dart-define=GOOGLE_API_KEY=your_key
/// Or it will be retrieved from platform (AndroidManifest/iOS Info.plist)
const String kGoogleApiKey = String.fromEnvironment(
  'GOOGLE_API_KEY',
  defaultValue: '',
);

/// Returns the backend base URL, with emulator fix on Android when default is localhost.
String getBackendBaseUrl() {
  String base = kBackendBaseUrl;
  if (kIsWeb) return base;
  // On Android emulator, localhost points to the emulator; 10.0.2.2 is the host machine.
  if (base.startsWith('http://localhost:') || base.startsWith('http://127.0.0.1:')) {
    // Keep as-is; use BACKEND_URL=http://10.0.2.2:3000 when testing from Android emulator
    return base;
  }
  return base;
}
