import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../directions_service.dart';

/// Map utilities for the operator app (same defaults as user app).
class MapService {
  static final DirectionsService _directionsService = DirectionsService();
  static MapType getDefaultMapType() => MapType.normal;

  static CameraPosition getDefaultCameraPosition() {
    return const CameraPosition(
      target: LatLng(10.3157, 123.8854),
      zoom: 12.0,
    );
  }

  static CameraPosition cameraPositionFromLatLng(double lat, double lng, {double zoom = 15.0}) {
    return CameraPosition(
      target: LatLng(lat, lng),
      zoom: zoom,
    );
  }

  /// Creates a camera position from a Position object.
  static CameraPosition cameraPositionFromPosition(Position position, {double zoom = 15.0}) {
    return CameraPosition(
      target: LatLng(position.latitude, position.longitude),
      zoom: zoom,
    );
  }

  /// Creates a camera update to move to a position (instant, no animation).
  static CameraUpdate createInstantCameraUpdate(Position position, {double zoom = 15.0}) {
    return CameraUpdate.newCameraPosition(
      cameraPositionFromPosition(position, zoom: zoom),
    );
  }

  /// Creates a camera update to animate to a position.
  static CameraUpdate createCameraUpdate(Position position, {double zoom = 15.0}) {
    return CameraUpdate.newCameraPosition(
      cameraPositionFromPosition(position, zoom: zoom),
    );
  }

  /// Gets accurate street distance between two points using Google Maps API.
  /// This replaces inaccurate equation-based calculations with real street routing.
  /// 
  /// Returns the distance in meters, or null if the route cannot be calculated.
  /// 
  /// Example usage:
  /// ```dart
  /// final distance = await MapService.getAccurateStreetDistance(
  ///   LatLng(10.3157, 123.8854), // Origin
  ///   LatLng(10.3200, 123.8900), // Destination
  /// );
  /// if (distance != null) {
  ///   print('Distance: ${distance / 1000} km');
  /// }
  /// ```
  static Future<double?> getAccurateStreetDistance(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final result = await _directionsService.getRouteWithDistance(origin, destination);
      if (result != null) {
        print('✅ [MapService] Accurate street distance: ${result.distanceMeters}m (${result.distanceText})');
        return result.distanceMeters;
      } else {
        print('⚠️ [MapService] Could not calculate route distance');
        return null;
      }
    } catch (e) {
      print('❌ [MapService] Error getting accurate distance: $e');
      return null;
    }
  }

  /// Gets accurate street distance with full route information.
  /// Returns a RouteResult with distance, duration, and polyline points.
  static Future<RouteResult?> getRouteWithDistance(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final result = await _directionsService.getRouteWithDistance(origin, destination);
      if (result != null) {
        print('✅ [MapService] Route calculated: ${result.distanceText}, ${result.durationText ?? "N/A"}');
      }
      return result;
    } catch (e) {
      print('❌ [MapService] Error getting route: $e');
      return null;
    }
  }
}
