import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bus_stop.dart';
import 'google_places_service.dart';

/// Loads bus stops from the Firestore collection [bus_stops].
const String busStopsCollection = 'bus_stops';

/// Approximate km per degree at mid-latitudes; used for distance filtering.
const double _kmPerDegree = 111.0;

/// Max radius in km to consider "near" the user.
const double _nearRadiusKm = 10.0;

/// Cebu (Metro Cebu) bounding box for filtering.
const double _cebuLatMin = 10.25;
const double _cebuLatMax = 10.45;
const double _cebuLngMin = 123.75;
const double _cebuLngMax = 124.05;

/// Result of loading bus stops. [closestStopId] is set when using user location + Places (closest stop to highlight).
class CebuStopsResult {
  final List<BusStop> stops;
  final bool isRealData;
  final String? closestStopId;
  const CebuStopsResult({
    required this.stops,
    required this.isRealData,
    this.closestStopId,
  });
}

class BusStopsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GooglePlacesService _placesService = GooglePlacesService();

  /// Cebu City center for Places API search.
  static const double _cebuCenterLat = 10.3157;
  static const double _cebuCenterLng = 123.8854;

  /// Load bus stops using user location: closest stop (rankby=distance) + up to 60 in radius; highlights closest.
  /// Falls back to Firestore stops with Haversine distance calculation if Places API fails.
  Future<CebuStopsResult> getBusStopsWithClosestHighlighted(double userLat, double userLng) async {
    final result = await _placesService.getStopsWithClosest(userLat, userLng, cityRadiusMeters: 50000);
    if (result.stops.isNotEmpty && result.closestStopId != null) {
      // Verify the closest stop is actually the nearest using Haversine
      BusStop? verifiedClosest;
      double minDistance = double.infinity;
      
      for (final stop in result.stops) {
        final distance = _approxDistanceKm(userLat, userLng, stop.lat, stop.lng);
        if (distance < minDistance) {
          minDistance = distance;
          verifiedClosest = stop;
        }
      }
      
      // If the verified closest is different from what Places API said, use the verified one
      final finalClosestId = verifiedClosest?.id ?? result.closestStopId;
      
      if (verifiedClosest != null && verifiedClosest.id != result.closestStopId) {
        print('⚠️ [BusStops] Places API closest (${result.closestStopId}) differs from verified closest (${verifiedClosest.id})');
        print('   Using verified closest: ${verifiedClosest.name} (${minDistance.toStringAsFixed(2)} km)');
      }
      
      return CebuStopsResult(
        stops: result.stops,
        isRealData: true,
        closestStopId: finalClosestId,
      );
    }
    
    // Fallback: Try Firestore stops and find nearest using Haversine
    print('📍 [BusStops] Places API returned no stops, trying Firestore fallback...');
    try {
      final snapshot = await _firestore
          .collection(busStopsCollection)
          .get()
          .timeout(const Duration(seconds: 5));
      final all = snapshot.docs
          .map((doc) => BusStop.fromFirestore(doc.id, doc.data()))
          .where((stop) => stop.lat != 0.0 && stop.lng != 0.0)
          .toList();
      
      if (all.isNotEmpty) {
        // Find nearest using Haversine formula
        BusStop? nearest;
        double minDist = double.infinity;
        
        for (final stop in all) {
          final dist = _approxDistanceKm(userLat, userLng, stop.lat, stop.lng);
          if (dist < minDist) {
            minDist = dist;
            nearest = stop;
          }
        }
        
        if (nearest != null) {
          print('✅ [BusStops] Found nearest from Firestore: ${nearest.name} (${minDist.toStringAsFixed(2)} km)');
          return CebuStopsResult(
            stops: all,
            isRealData: true,
            closestStopId: nearest.id,
          );
        }
      }
    } catch (e) {
      print('⚠️ [BusStops] Firestore fallback failed: $e');
    }
    
    return getBusStopsInCebu();
  }

  /// Load all bus stops in Cebu (center). Uses Google Places API first, then Firestore, then sample data.
  Future<CebuStopsResult> getBusStopsInCebu() async {
    final fromPlaces = await _placesService.getTransitStationsNear(_cebuCenterLat, _cebuCenterLng);
    if (fromPlaces.isNotEmpty) return CebuStopsResult(stops: fromPlaces, isRealData: true);

    // 2. Try Firestore (your own bus_stops collection)
    try {
      final snapshot = await _firestore
          .collection(busStopsCollection)
          .get()
          .timeout(const Duration(seconds: 5));
      final all = snapshot.docs
          .map((doc) => BusStop.fromFirestore(doc.id, doc.data()))
          .where((stop) => stop.lat != 0.0 && stop.lng != 0.0)
          .toList();
      final inCebu = all.where((s) {
        return s.lat >= _cebuLatMin && s.lat <= _cebuLatMax &&
               s.lng >= _cebuLngMin && s.lng <= _cebuLngMax;
      }).toList();
      if (inCebu.isNotEmpty) return CebuStopsResult(stops: inCebu, isRealData: true);
    } catch (e) {
      assert(() {
        print('⚠️ [BusStopsService] Firestore read failed: $e');
        return true;
      }());
    }

    // 3. Fallback: sample Cebu stops (only when Places + Firestore have no data)
    return CebuStopsResult(stops: _getSampleBusStopsCebu(), isRealData: false);
  }

  /// Load bus stops near [lat], [lng]. From Firestore: filters by distance and returns nearest first.
  /// Falls back to sample stops around the given point when Firestore is empty or fails.
  Future<List<BusStop>> getBusStopsNear(double lat, double lng) async {
    try {
      final snapshot = await _firestore
          .collection(busStopsCollection)
          .get()
          .timeout(const Duration(seconds: 5));
      final all = snapshot.docs
          .map((doc) => BusStop.fromFirestore(doc.id, doc.data()))
          .where((stop) => stop.lat != 0.0 && stop.lng != 0.0)
          .toList();
      if (all.isEmpty) return _getSampleBusStopsNear(lat, lng);
      final near = _filterAndSortByDistance(all, lat, lng);
      return near.isNotEmpty ? near : _getSampleBusStopsNear(lat, lng);
    } catch (e) {
      assert(() {
        print('⚠️ [BusStopsService] Firestore read failed: $e');
        return true;
      }());
      return _getSampleBusStopsNear(lat, lng);
    }
  }

  /// One-time load of all bus stops (no location filter). Uses sample data when empty or fails.
  Future<List<BusStop>> getBusStops() async {
    return getBusStopsNear(14.5995, 120.9842);
  }

  List<BusStop> _filterAndSortByDistance(List<BusStop> stops, double lat, double lng) {
    final radiusDeg = _nearRadiusKm / _kmPerDegree;
    final near = stops.where((s) {
      final dLat = (s.lat - lat).abs();
      final dLng = (s.lng - lng).abs();
      return dLat <= radiusDeg && dLng <= radiusDeg;
    }).toList();
    near.sort((a, b) {
      final da = _approxDistanceKm(lat, lng, a.lat, a.lng);
      final db = _approxDistanceKm(lat, lng, b.lat, b.lng);
      return da.compareTo(db);
    });
    return near;
  }

  /// Calculate distance between two points using Haversine formula (accurate for Earth's curvature).
  /// Returns distance in kilometers.
  double _approxDistanceKm(double lat1, double lng1, double lat2, double lng2) {
    // Haversine formula for calculating great-circle distance between two points
    const double earthRadiusKm = 6371.0; // Earth's radius in kilometers
    
    final double dLat = (lat2 - lat1) * math.pi / 180.0;
    final double dLng = (lng2 - lng1) * math.pi / 180.0;
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
        math.cos(lat2 * math.pi / 180.0) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final double distance = earthRadiusKm * c;
    
    return distance;
  }

  /// Sample bus stops around [lat], [lng] (~0.5–1.5 km away) for fallback.
  static List<BusStop> _getSampleBusStopsNear(double lat, double lng) {
    const offset = 0.008; // ~0.8 km
    return [
      BusStop(id: 'BS-001', name: 'Bus Stop 1', route: '01K', lat: lat + offset, lng: lng),
      BusStop(id: 'BS-002', name: 'Bus Stop 2', route: '02A', lat: lat - offset * 0.5, lng: lng + offset),
      BusStop(id: 'BS-003', name: 'Bus Stop 3', route: '03D', lat: lat + offset * 0.5, lng: lng - offset),
      BusStop(id: 'BS-004', name: 'Bus Stop 4', route: '01K', lat: lat - offset, lng: lng - offset * 0.5),
      BusStop(id: 'BS-005', name: 'Bus Stop 5', route: '13B', lat: lat, lng: lng + offset),
    ];
  }

  /// Sample bus stops in Cebu (Metro Cebu area) for fallback when Firestore is empty.
  static List<BusStop> _getSampleBusStopsCebu() {
    return [
      const BusStop(id: 'CEB-001', name: 'Pacific Terminal', route: '01K', lat: 10.3232, lng: 123.9456),
      const BusStop(id: 'CEB-002', name: 'Ayala Center Cebu', route: '02A', lat: 10.3192, lng: 123.9076),
      const BusStop(id: 'CEB-003', name: 'SM City Cebu', route: '03D', lat: 10.3156, lng: 123.9182),
      const BusStop(id: 'CEB-004', name: 'Jmall Mandaue', route: '01K', lat: 10.3289, lng: 123.9321),
      const BusStop(id: 'CEB-005', name: 'Marpa Terminal', route: '13B', lat: 10.3312, lng: 123.9388),
      const BusStop(id: 'CEB-006', name: 'Cebu South Bus Terminal', route: '04B', lat: 10.2986, lng: 123.8994),
      const BusStop(id: 'CEB-007', name: 'Colon Street', route: '12C', lat: 10.2945, lng: 123.9012),
      const BusStop(id: 'CEB-008', name: 'IT Park', route: '02A', lat: 10.3234, lng: 123.9089),
      const BusStop(id: 'CEB-009', name: 'Park Mall', route: '01K', lat: 10.3345, lng: 123.9123),
      const BusStop(id: 'CEB-010', name: 'Gaisano Capital', route: '13B', lat: 10.3178, lng: 123.8912),
    ];
  }

  /// Real-time stream of bus stops (updates when collection changes).
  Stream<List<BusStop>> busStopsStream() {
    return _firestore.collection(busStopsCollection).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => BusStop.fromFirestore(doc.id, doc.data()))
          .where((stop) => stop.lat != 0.0 && stop.lng != 0.0)
          .toList();
    });
  }
}
