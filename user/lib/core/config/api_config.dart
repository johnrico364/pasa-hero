/// Google API key for Places API (transit/bus stops). Use the same key as in AndroidManifest (com.google.android.geo.API_KEY).
/// Enable "Places API" in Google Cloud Console: https://console.cloud.google.com/apis/library/places-backend.googleapis.com
const String kGoogleApiKey = String.fromEnvironment(
  'GOOGLE_API_KEY',
  defaultValue: 'AIzaSyBzDrQL0XaiYRIoUoDC_UBDQuxpcEWg1UE', // Set to your key (same as AndroidManifest) or run with --dart-define=GOOGLE_API_KEY=your_key
);

/// Optional WebSocket relay for user notification push updates.
/// When empty, the app falls back to periodic polling.
const String kUserNotificationWsUrl = String.fromEnvironment(
  'USER_NOTIFICATION_WS_URL',
  defaultValue: '',
);

/// Interval (seconds) for periodic inbox refreshes: used when no WebSocket URL is set,
/// and also as a **backup** while WebSocket is connected (so a silent socket still syncs).
const int kUserNotificationPollSeconds = int.fromEnvironment(
  'USER_NOTIFICATION_POLL_SECONDS',
  defaultValue: 30,
);
