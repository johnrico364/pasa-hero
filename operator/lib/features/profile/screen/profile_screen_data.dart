import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Route information model for operator profiles.
class RouteInfo {
  final String code;
  final String name;
  final String description;

  const RouteInfo({
    required this.code,
    required this.name,
    required this.description,
  });
}

/// Route coordinates for mapping.
class RouteCoordinates {
  final LatLng startPoint;
  final LatLng endPoint;

  const RouteCoordinates({
    required this.startPoint,
    required this.endPoint,
  });
}

/// Available routes for operators.
class AvailableRoutes {
  static const List<RouteInfo> routes = [
    RouteInfo(
      code: '25',
      name: 'Liloan - White Gold Terminal',
      description: 'Route from Liloan to White Gold Terminal',
    ),
    // Add more routes here as needed
    // RouteInfo(
    //   code: '01K',
    //   name: 'Route 01K',
    //   description: 'Description here',
    // ),
  ];

  /// Get route coordinates by code.
  /// Returns the start and end points for drawing the route on the map.
  static RouteCoordinates? getRouteCoordinates(String code) {
    switch (code) {
      case '25':
        // Liloan to White Gold Terminal coordinates (Cebu area)
        return const RouteCoordinates(
          startPoint: LatLng(10.4100, 123.9700), // Liloan approximate coordinates
          endPoint: LatLng(10.3157, 123.8854), // White Gold Terminal approximate coordinates
        );
      // Add more route coordinates here
      default:
        return null;
    }
  }

  /// Get route by code.
  static RouteInfo? getRouteByCode(String code) {
    try {
      return routes.firstWhere((route) => route.code == code);
    } catch (_) {
      return null;
    }
  }

  /// Get all route codes.
  static List<String> getRouteCodes() {
    return routes.map((route) => route.code).toList();
  }
}

/// Service for managing operator profile data in Firestore.
class ProfileDataService {
  static const String _usersCollection = 'users';

  /// Get current operator's route code from Firestore.
  static Future<String?> getOperatorRouteCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        // Try both field names for compatibility
        return data?['routeCode'] as String? ?? data?['route_code'] as String?;
      }
      return null;
    } catch (e) {
      print('❌ [ProfileDataService] Error getting route code: $e');
      return null;
    }
  }

  /// Update operator's route code in Firestore.
  static Future<bool> updateOperatorRouteCode(String routeCode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid)
          .update({
        'routeCode': routeCode.trim().toUpperCase(),
        'route_code': routeCode.trim().toUpperCase(), // Also store as snake_case
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ [ProfileDataService] Route code updated: $routeCode');
      return true;
    } catch (e) {
      print('❌ [ProfileDataService] Error updating route code: $e');
      return false;
    }
  }

  /// Get operator's full profile data.
  static Future<Map<String, dynamic>?> getOperatorProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(user.uid)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('❌ [ProfileDataService] Error getting profile: $e');
      return null;
    }
  }
}
