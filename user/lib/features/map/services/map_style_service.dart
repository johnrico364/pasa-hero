import 'package:flutter/services.dart';

/// Service for loading and managing map styles.
class MapStyleService {
  /// Path to the transportation map style JSON file.
  static const String _transportationStylePath =
      'assets/map_styles/transportation_map_style.json';

  /// Loads the transportation map style from assets.
  /// 
  /// Returns the JSON string of the map style, or null if loading fails.
  Future<String?> loadTransportationStyle() async {
    try {
      final json = await rootBundle.loadString(_transportationStylePath);
      print('✅ [MapStyleService] Map style loaded successfully');
      return json;
    } catch (e) {
      print('⚠️ [MapStyleService] Could not load map style: $e');
      return null;
    }
  }
}
