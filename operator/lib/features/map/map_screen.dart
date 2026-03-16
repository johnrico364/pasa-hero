import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/services/location_service.dart';
import '../../core/services/map/map_service.dart';
import '../../core/services/directions_service.dart';
import '../profile/screen/profile_screen_data.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  static const String routeName = '/map';

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LocationService _locationService = LocationService();
  final DirectionsService _directionsService = DirectionsService();
  GoogleMapController? _mapController;
  bool _isLoading = true;
  Position? _currentPosition;
  CameraPosition? _initialCameraPosition;
  Set<Marker> _markers = {};
  Set<Polyline> _routePolylines = {};
  bool _isLocationRequestInProgress = false;

  @override
  void initState() {
    super.initState();
    // Set initial camera position immediately so map shows right away
    _initialCameraPosition = MapService.getDefaultCameraPosition();
    // Load operator route code and then initialize location
    _loadOperatorRoute();
  }

  /// Loads the operator's route code from Firestore and highlights the route if set.
  Future<void> _loadOperatorRoute() async {
    try {
      final routeCode = await ProfileDataService.getOperatorRouteCode();
      if (mounted && routeCode != null) {
        await _highlightRoute(routeCode);
      }
    } catch (e) {
      print('⚠️ [MapScreen] Error loading route code: $e');
    }
    // Initialize location after loading route
    _initializeLocation();
  }

  /// Highlights the route on the map based on the route code.
  Future<void> _highlightRoute(String routeCode) async {
    final coordinates = AvailableRoutes.getRouteCoordinates(routeCode);
    if (coordinates == null) {
      print('⚠️ [MapScreen] No coordinates found for route code: $routeCode');
      return;
    }

    try {
      // Get route polyline from Google Directions API
      final routeResult = await _directionsService.getRouteWithDistance(
        coordinates.startPoint,
        coordinates.endPoint,
      );

      if (routeResult == null || routeResult.polyline.isEmpty) {
        print('⚠️ [MapScreen] Could not get route polyline for code: $routeCode');
        return;
      }

      // Get route info for display
      final routeInfo = AvailableRoutes.getRouteByCode(routeCode);

      if (mounted) {
        setState(() {
          // Add route polyline
          _routePolylines = {
            Polyline(
              polylineId: PolylineId('operator_route_$routeCode'),
              points: routeResult.polyline,
              color: Colors.blue,
              width: 5,
              patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            ),
          };

          // Add start and end markers
          _markers = {
            // Start point marker
            Marker(
              markerId: const MarkerId('route_start'),
              position: coordinates.startPoint,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: InfoWindow(
                title: routeInfo?.name ?? 'Route Start',
                snippet: 'Start: ${routeInfo?.name ?? routeCode}',
              ),
            ),
            // End point marker
            Marker(
              markerId: const MarkerId('route_end'),
              position: coordinates.endPoint,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(
                title: 'Route End',
                snippet: 'End: ${routeInfo?.name ?? routeCode}',
              ),
            ),
          };
        });

        // Fit camera to show the entire route
        if (_mapController != null && routeResult.polyline.isNotEmpty) {
          try {
            final bounds = _calculateBounds(routeResult.polyline);
            await _mapController!.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 100),
            );
          } catch (e) {
            print('⚠️ [MapScreen] Error fitting camera to route: $e');
          }
        }

        print('✅ [MapScreen] Route highlighted: ${routeInfo?.name ?? routeCode}');
      }
    } catch (e) {
      print('❌ [MapScreen] Error highlighting route: $e');
    }
  }

  /// Calculates bounds from a list of points.
  LatLngBounds _calculateBounds(List<LatLng> points) {
    if (points.isEmpty) {
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

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  /// Initializes location services and gets operator's current position.
  /// 
  /// This method:
  /// 1. Checks if location services are enabled
  /// 2. Requests location permission if needed
  /// 3. Gets current GPS position (or last known, or default)
  /// 4. Centers map on operator location
  Future<void> _initializeLocation({bool showError = true}) async {
    print('🗺️ [MapScreen] _initializeLocation() called (showError: $showError)');
    
    // Prevent concurrent location requests
    if (_isLocationRequestInProgress) {
      print('   ⚠️ Location request already in progress, skipping...');
      return;
    }
    
    _isLocationRequestInProgress = true;
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if location services are enabled
      print('🗺️ [MapScreen] Step 1: Checking if location services are enabled...');
      bool serviceEnabled = await _locationService.isLocationServiceEnabled();
      print('   📍 Location services enabled: $serviceEnabled');
      
      if (!serviceEnabled) {
        print('   ❌ Location services are DISABLED - using default location');
        // If location services disabled, use default location silently
        setState(() {
          _initialCameraPosition = MapService.getDefaultCameraPosition();
          _isLoading = false;
        });
        if (showError && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services disabled. Using default location.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        _isLocationRequestInProgress = false; // Reset guard
        return;
      }

      // Request permission
      print('🗺️ [MapScreen] Step 2: Requesting location permission...');
      bool hasPermission = await _locationService.requestPermission();
      print('   📍 Permission granted: $hasPermission');
      
      if (!hasPermission) {
        print('   ❌ Permission NOT granted - using default location');
        // If no permission, use default location silently
        setState(() {
          _initialCameraPosition = MapService.getDefaultCameraPosition();
          _isLoading = false;
        });
        if (showError && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission not granted. Using default location.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        _isLocationRequestInProgress = false; // Reset guard
        return;
      }

      // Get current position (optimized for low-end devices)
      print('🗺️ [MapScreen] Step 3: Getting current position (optimized mode)...');
      Position position = await _locationService.getCurrentPosition(
        preferLowAccuracy: true,
        useCachedPosition: true,
      );
      print('   ✅ Position received:');
      print('      Latitude: ${position.latitude}');
      print('      Longitude: ${position.longitude}');
      print('      Accuracy: ${position.accuracy}m');
      
      // Check if this is a cached/old position
      final positionAge = DateTime.now().difference(position.timestamp);
      final isCachedPosition = positionAge.inMinutes > 3;
      
      // Update state first (without marker to avoid blocking)
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _initialCameraPosition = MapService.cameraPositionFromPosition(position);
          _isLoading = false;
        });
      }
      
      // Add marker for operator location (but preserve route markers if they exist)
      _addOperatorMarker(position);
      
      // Show appropriate message based on position freshness
      if (mounted && isCachedPosition) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Using cached location (${positionAge.inMinutes} min old). Move to get fresh GPS fix.',
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Center map on operator location after controller is ready
      if (_mapController != null) {
        print('🗺️ [MapScreen] Map controller is ready, moving camera to location...');
        try {
          await _mapController!.moveCamera(
            MapService.createInstantCameraUpdate(position),
          );
          print('   ✅ Camera moved to operator location');
        } catch (e) {
          print('   ⚠️ Error moving camera: $e');
          // Don't throw - camera move is not critical
        }
      } else {
        print('   ⚠️ Map controller is not ready yet - will center when ready');
      }
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location found!'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('   ❌ [MapScreen] _initializeLocation() ERROR: $e');
      print('   📋 Error type: ${e.runtimeType}');
      print('   📋 Error toString: ${e.toString()}');
      
      // Check if it's a timeout error
      bool isTimeout = e.toString().contains('timed out') || 
                       e.toString().contains('TimeoutException');
      print('   📋 Is timeout error: $isTimeout');
      
      // For timeout, show helpful message and use default location
      if (isTimeout) {
        print('   🔄 Handling timeout - using default location');
        
        setState(() {
          _isLoading = false;
          _initialCameraPosition = MapService.getDefaultCameraPosition();
        });
        
        if (showError && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'GPS timeout. Using default location.\n\nIf using emulator, set a mock location in emulator settings.',
              ),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _initializeLocation(showError: true),
              ),
            ),
          );
        }
      } else {
        print('   🔄 Handling other error - showing error message');
        // For other errors, show error message
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        setState(() {
          _isLoading = false;
          _initialCameraPosition = MapService.getDefaultCameraPosition();
        });
        
        if (showError && mounted) {
          final isPermanentlyDenied = errorMessage.contains('permanently denied');
          final isServiceDisabled = errorMessage.contains('services are disabled');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 5),
              action: isPermanentlyDenied || isServiceDisabled
                  ? SnackBarAction(
                      label: 'Settings',
                      onPressed: () async {
                        if (isPermanentlyDenied) {
                          await _locationService.openAppSettings();
                        } else if (isServiceDisabled) {
                          await _locationService.openLocationSettings();
                        }
                      },
                    )
                  : SnackBarAction(
                      label: 'Retry',
                      onPressed: () => _initializeLocation(showError: true),
                    ),
            ),
          );
        }
      }
    } finally {
      // Always reset the guard
      _isLocationRequestInProgress = false;
    }
  }

  /// Adds a marker for the operator's location.
  /// Preserves existing route markers if they exist.
  void _addOperatorMarker(Position position) {
    setState(() {
      // Keep existing markers (route start/end) and add operator location
      final operatorMarker = Marker(
        markerId: const MarkerId('operator_location'),
        position: LatLng(position.latitude, position.longitude),
        infoWindow: const InfoWindow(
          title: 'Your Location',
          snippet: 'Operator current location',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );
      
      // Remove old operator marker if it exists, then add new one
      _markers.removeWhere((m) => m.markerId.value == 'operator_location');
      _markers.add(operatorMarker);
    });
  }

  /// Gets accurate street distance between two points using Google Maps API.
  /// This replaces inaccurate equation-based calculations with real street routing.
  /// 
  /// Returns the distance in meters, or null if the route cannot be calculated.
  /// 
  /// Example usage:
  /// ```dart
  /// final distance = await _getAccurateStreetDistance(
  ///   LatLng(10.3157, 123.8854), // Origin
  ///   LatLng(10.3200, 123.8900), // Destination
  /// );
  /// if (distance != null) {
  ///   print('Distance: ${distance / 1000} km');
  /// }
  /// ```
  Future<double?> getAccurateStreetDistance(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final result = await _directionsService.getRouteWithDistance(origin, destination);
      if (result != null) {
        print('✅ [MapScreen] Accurate street distance: ${result.distanceMeters}m (${result.distanceText})');
        return result.distanceMeters;
      } else {
        print('⚠️ [MapScreen] Could not calculate route distance');
        return null;
      }
    } catch (e) {
      print('❌ [MapScreen] Error getting accurate distance: $e');
      return null;
    }
  }

  /// Gets accurate street distance with full route information.
  /// Returns a RouteResult with distance, duration, and polyline points.
  Future<RouteResult?> getRouteWithDistance(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final result = await _directionsService.getRouteWithDistance(origin, destination);
      if (result != null) {
        print('✅ [MapScreen] Route calculated: ${result.distanceText}, ${result.durationText ?? "N/A"}');
      }
      return result;
    } catch (e) {
      print('❌ [MapScreen] Error getting route: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Center on my location',
            onPressed: _isLocationRequestInProgress ? null : () => _initializeLocation(),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCameraPosition ?? MapService.getDefaultCameraPosition(),
            onMapCreated: (c) {
              _mapController = c;
              // If we already have a position, center the map on it
              if (_currentPosition != null) {
                _mapController!.moveCamera(
                  MapService.createInstantCameraUpdate(_currentPosition!),
                );
              }
            },
            mapType: MapService.getDefaultMapType(),
            zoomControlsEnabled: true,
            compassEnabled: true,
            myLocationEnabled: false,
            markers: _markers,
            polylines: _routePolylines,
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
