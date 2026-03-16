import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/services/directions_service.dart';

/// Service for managing routes on the map.
/// 
/// Handles:
/// - Fetching routes from Google Directions API
/// - Drawing route polylines
/// - Calculating accurate route distances
class RouteService {
  final DirectionsService _directionsService = DirectionsService();

  /// Fetches route from Directions API and returns route information.
  /// 
  /// Parameters:
  /// - [origin]: Starting point (POINT_A - nearest bus stop)
  /// - [destination]: End point (POINT_B - destination)
  /// 
  /// Returns [RouteResult] with polyline, distance, and duration, or null if route cannot be calculated.
  Future<RouteResult?> getRouteWithDistance(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final routeResult = await _directionsService.getRouteWithDistance(origin, destination);
      
      if (routeResult != null) {
        print('📍 [RouteService] Route calculated:');
        print('   Distance: ${routeResult.distanceText} (${routeResult.distanceMeters.toStringAsFixed(0)} meters)');
        if (routeResult.durationText != null) {
          print('   Duration: ${routeResult.durationText}');
        }
      }
      
      return routeResult;
    } catch (e) {
      print('❌ [RouteService] Error getting route: $e');
      return null;
    }
  }

  /// Creates a polyline from route result.
  /// 
  /// Parameters:
  /// - [routeResult]: The route result containing polyline points
  /// - [color]: Color of the polyline (default: blue)
  /// - [width]: Width of the polyline (default: 5)
  /// 
  /// Returns a [Polyline] ready to be displayed on the map, or null if route is invalid.
  Polyline? createPolylineFromRoute(
    RouteResult? routeResult, {
    Color color = Colors.blue,
    int width = 5,
  }) {
    if (routeResult == null || routeResult.polyline.isEmpty) {
      return null;
    }

    return Polyline(
      polylineId: const PolylineId('route_origin_to_destination'),
      points: routeResult.polyline,
      color: color,
      width: width,
    );
  }

  /// Calculates bounds from a list of points for camera fitting.
  /// 
  /// Parameters:
  /// - [points]: List of LatLng points
  /// 
  /// Returns [LatLngBounds] that encompasses all points.
  LatLngBounds calculateBoundsFromPoints(List<LatLng> points) {
    if (points.isEmpty) {
      // Return default bounds if no points
      return LatLngBounds(
        southwest: const LatLng(10.25, 123.75),
        northeast: const LatLng(10.45, 124.05),
      );
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}
