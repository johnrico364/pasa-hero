import 'package:geolocator/geolocator.dart';
import 'location_api_service.dart';

/// Service for caching user location to avoid recalibration when navigating.
/// 
/// This service:
/// - Caches location in memory with timestamp
/// - Checks if cached location is still valid (less than 1 minute old)
/// - Provides methods to save/retrieve cached location
/// - Can be extended to save to server/database
class LocationCacheService {
  static LocationCacheService? _instance;
  static LocationCacheService get instance {
    _instance ??= LocationCacheService._();
    return _instance!;
  }

  LocationCacheService._();

  // In-memory cache
  Position? _cachedPosition;
  DateTime? _cacheTimestamp;
  
  // Cache duration - 1 minute as requested
  static const Duration _cacheDuration = Duration(minutes: 1);

  /// Gets the cached location if it's still valid (less than 1 minute old).
  /// 
  /// Returns:
  /// - [Position] if cached location exists and is less than 1 minute old
  /// - `null` if no cache or cache is expired
  Position? getCachedLocation() {
    if (_cachedPosition == null || _cacheTimestamp == null) {
      print('📦 [LocationCache] No cached location available');
      return null;
    }

    final age = DateTime.now().difference(_cacheTimestamp!);
    
    if (age < _cacheDuration) {
      print('📦 [LocationCache] Using cached location (${age.inSeconds} seconds old)');
      return _cachedPosition;
    } else {
      print('📦 [LocationCache] Cached location expired (${age.inSeconds} seconds old, max: ${_cacheDuration.inSeconds}s)');
      // Clear expired cache
      _cachedPosition = null;
      _cacheTimestamp = null;
      return null;
    }
  }

  /// Saves a location to cache with current timestamp.
  /// 
  /// Parameters:
  /// - [position]: The position to cache
  /// 
  /// This will also trigger server save if configured.
  Future<void> saveLocation(Position position) async {
    _cachedPosition = position;
    _cacheTimestamp = DateTime.now();
    
    print('📦 [LocationCache] Location cached:');
    print('   Latitude: ${position.latitude}');
    print('   Longitude: ${position.longitude}');
    print('   Timestamp: $_cacheTimestamp');
    
    // Save to server (async, don't wait for it)
    _saveToServer(position);
  }

  /// Checks if cached location is still valid.
  /// 
  /// Returns `true` if cached location exists and is less than 1 minute old.
  bool hasValidCache() {
    if (_cachedPosition == null || _cacheTimestamp == null) {
      return false;
    }
    
    final age = DateTime.now().difference(_cacheTimestamp!);
    return age < _cacheDuration;
  }

  /// Gets the age of the cached location.
  /// 
  /// Returns [Duration] since cache was created, or `null` if no cache.
  Duration? getCacheAge() {
    if (_cacheTimestamp == null) {
      return null;
    }
    return DateTime.now().difference(_cacheTimestamp!);
  }

  /// Clears the cached location.
  void clearCache() {
    print('📦 [LocationCache] Cache cleared');
    _cachedPosition = null;
    _cacheTimestamp = null;
  }

  /// Saves location to server (async, non-blocking).
  /// 
  /// This calls the LocationApiService to save to your backend.
  Future<void> _saveToServer(Position position) async {
    try {
      // Save to server asynchronously (don't wait for it)
      final success = await LocationApiService.instance.saveLocationToServer(position);
      if (success) {
        print('📦 [LocationCache] Location saved to server successfully');
      } else {
        print('⚠️ [LocationCache] Failed to save location to server');
      }
    } catch (e) {
      print('⚠️ [LocationCache] Error saving to server: $e');
      // Don't throw - server save failure shouldn't break the app
    }
  }

  /// Gets cached location or null if expired/not available.
  /// 
  /// This is a convenience method that combines getCachedLocation() and hasValidCache().
  Position? getValidCachedLocation() {
    if (hasValidCache()) {
      return getCachedLocation();
    }
    return null;
  }

  /// Gets cached location with custom duration check.
  /// 
  /// Parameters:
  /// - [maxAge]: Maximum age of cached location to consider valid
  /// 
  /// Returns cached location if it exists and is less than [maxAge] old, null otherwise.
  Position? getCachedLocationWithMaxAge(Duration maxAge) {
    if (_cachedPosition == null || _cacheTimestamp == null) {
      return null;
    }

    final age = DateTime.now().difference(_cacheTimestamp!);
    
    if (age < maxAge) {
      print('📦 [LocationCache] Using cached location (${age.inMinutes} min old, max: ${maxAge.inMinutes} min)');
      return _cachedPosition;
    } else {
      print('📦 [LocationCache] Cached location expired (${age.inMinutes} min old, max: ${maxAge.inMinutes} min)');
      return null;
    }
  }
}
