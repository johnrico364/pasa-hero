import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/models/bus_stop.dart';
import 'bus_stop_icon_service.dart';
import '../models/sample_bus_stops.dart';

/// Service for creating and managing bus stop markers on the map.
class BusStopMarkerService {
  final BusStopIconService _iconService = BusStopIconService.instance;

  /// Creates markers from a list of bus stops.
  /// 
  /// Parameters:
  /// - [stops]: List of bus stops to create markers for
  /// - [closestStopId]: Optional ID of the closest stop (will use different icon)
  /// 
  /// Returns a set of markers ready to be displayed on the map.
  Set<Marker> createMarkersFromStops(
    List<BusStop> stops, {
    String? closestStopId,
  }) {
    final Set<Marker> markers = {};
    for (final stop in stops) {
      final isClosest = closestStopId != null && stop.id == closestStopId;
      markers.add(Marker(
        markerId: MarkerId('bus_stop_${stop.id}'),
        position: stop.position,
        icon: isClosest ? _iconService.closestIcon : _iconService.defaultIcon,
        infoWindow: InfoWindow(
          title: isClosest ? '${stop.name} (closest)' : stop.name,
          snippet: stop.route.isEmpty
              ? stop.name
              : 'Stop ${stop.stopCode} · Route ${stop.route}',
        ),
      ));
    }
    return markers;
  }

  /// Creates markers from sample Cebu bus stops data.
  /// Used as fallback when real data is not available.
  Set<Marker> createSampleMarkers() {
    final Set<Marker> markers = {};
    for (final stop in SampleBusStops.cebuStops) {
      final id = stop['id'] as String;
      final name = stop['name'] as String;
      final route = stop['route'] as String;
      final lat = (stop['lat'] as num).toDouble();
      final lng = (stop['lng'] as num).toDouble();
      markers.add(Marker(
        markerId: MarkerId('bus_stop_$id'),
        position: LatLng(lat, lng),
        icon: _iconService.defaultIcon,
        infoWindow: InfoWindow(
          title: name,
          snippet: 'Stop $id · Route $route',
        ),
      ));
    }
    return markers;
  }
}
