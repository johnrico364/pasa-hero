import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/models/bus_stop.dart';
import '../../core/services/bus_stops_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/map/map_service.dart';
import 'services/bus_stop_icon_service.dart';
import 'services/bus_stop_marker_service.dart';
import 'services/route_service.dart';
import 'services/map_style_service.dart';

/// Main map screen: transportation-focused map with bus stops from Firestore.
///
/// - Custom map style hides POIs, transit icons, building/admin labels; keeps roads.
/// - Markers from Firestore [bus_stops] (name, stop code, route).
/// - User location remains visible (blue dot).
/// - When [routeOrigin] and [routeDestination] are set, draws driving route polyline.
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    this.routeOrigin,
    this.routeDestination,
  });

  /// Start of the route (e.g. closest bus stop to user). When set with [routeDestination], route is drawn.
  final LatLng? routeOrigin;

  /// End of the route (e.g. selected destination bus stop).
  final LatLng? routeDestination;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Services
  final LocationService _locationService = LocationService();
  
  // Map controller
  GoogleMapController? _mapController;
  
  // State variables
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  Position? _currentPosition;
  CameraPosition? _initialCameraPosition;
  
  Set<Marker> _markers = {};
  Set<Marker> _busStopMarkers = {};
  Set<Polyline> _routePolylines = {};
  Set<Circle> _userLocationCircles = {};
  String? _mapStyleJson;

  /// Radius in meters for the faded blue "you are here" glow when away from a bus stop.
  static const double _userLocationGlowRadiusMeters = 120.0;

  final BusStopsService _busStopsService = BusStopsService();
  final BusStopMarkerService _markerService = BusStopMarkerService();
  final RouteService _routeService = RouteService();
  final MapStyleService _mapStyleService = MapStyleService();
  final BusStopIconService _iconService = BusStopIconService.instance;

  // Guard to prevent concurrent location requests
  bool _isLocationRequestInProgress = false;
  
  // Location stream subscription for real-time updates
  StreamSubscription<Position>? _positionStreamSubscription;
  
  // Track if initial camera position has been set (only set once on first load)
  bool _hasSetInitialCameraPosition = false;
  
  // Performance optimization flags
  static const bool _enableTrafficLayer = true; // Show current traffic on roads
  static const bool _useInstantCameraUpdates = true; // Use moveCamera instead of animateCamera for better performance
  static const bool _preferLowAccuracy = true; // Use low accuracy for faster, battery-efficient location
  static const bool _useCachedPosition = true; // Use cached positions when available
  static const bool _enableCustomMarker = true; // Enable custom marker now that location is working
  
  // Debug info
  bool _showDebugInfo = false; // Set to false by default for better performance
  String _locationStatus = 'Initializing...'; // Status message for debug

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    // Load custom bus stop icons asynchronously
    _iconService.loadIcons().then((_) {
      // Reload markers after icons are loaded
      if (mounted) {
        setState(() {
          if (_busStopMarkers.isNotEmpty) {
            _applyMarkers();
          }
        });
      }
    });
    // Show all Cebu bus stops (sample on first frame, then from Firestore)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _busStopMarkers.isEmpty) {
        _applySampleBusStopMarkersCebu();
      }
      if (mounted && widget.routeOrigin != null && widget.routeDestination != null) {
        _fetchAndDrawRoute(widget.routeOrigin!, widget.routeDestination!);
      }
    });
    _loadAllCebuBusStops();
    _initializeLocation();
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeOrigin != widget.routeOrigin ||
        oldWidget.routeDestination != widget.routeDestination) {
      if (widget.routeOrigin != null && widget.routeDestination != null) {
        _fetchAndDrawRoute(widget.routeOrigin!, widget.routeDestination!);
      } else {
        setState(() => _routePolylines = {});
      }
    }
  }

  /// Fetches route from Directions API and draws polyline on the map.
  /// Also calculates accurate distance from POINT_A (nearest bus stop) to POINT_B (destination).
  Future<void> _fetchAndDrawRoute(LatLng origin, LatLng destination) async {
    // Use route service to get route information
    final routeResult = await _routeService.getRouteWithDistance(origin, destination);
    if (!mounted) return;
    
    // Create polyline from route result
    final polyline = _routeService.createPolylineFromRoute(routeResult);
    
    if (polyline == null) {
      setState(() {
        _routePolylines = {};
      });
      return;
    }
    
    // Log the accurate distance from POINT_A to POINT_B
    if (routeResult != null) {
      print('📍 [MapScreen] Route distance from nearest bus stop (POINT_A) to destination (POINT_B):');
      print('   Distance: ${routeResult.distanceText} (${routeResult.distanceMeters.toStringAsFixed(0)} meters)');
      if (routeResult.durationText != null) {
        print('   Duration: ${routeResult.durationText}');
      }
    }
    
    setState(() {
      _routePolylines = {polyline};
    });
    
    // Optionally fit camera to show the full route
    if (_mapController != null && routeResult != null && routeResult.polyline.isNotEmpty) {
      try {
        final bounds = _routeService.calculateBoundsFromPoints(routeResult.polyline);
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 80),
        );
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    // Cancel location stream subscription
    _positionStreamSubscription?.cancel();
    // Dispose map controller to prevent memory leaks
    _mapController?.dispose();
    super.dispose();
  }

  /// Initializes location services and gets user's current position.
  /// 
  /// This method:
  /// 1. Checks if location services are enabled
  /// 2. Requests location permission if needed
  /// 3. Gets current GPS position (or last known, or default)
  /// 4. Centers map on user location
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
      _hasError = false;
      _errorMessage = null;
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
          _hasError = false;
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
          _hasError = false;
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
        preferLowAccuracy: _preferLowAccuracy,
        useCachedPosition: _useCachedPosition,
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
          _hasError = false;
          if (isCachedPosition) {
            _locationStatus = 'Using cached location (${positionAge.inMinutes}m old, ${position.accuracy.toStringAsFixed(0)}m accuracy)';
          } else {
            _locationStatus = 'Location found! (${position.accuracy.toStringAsFixed(0)}m accuracy)';
          }
        });
      }
      
      // Add marker asynchronously after state is updated (non-blocking)
      if (_enableCustomMarker) {
        _addMarkerAsync(position);
      }
      
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

      // Center map on user location ONLY if this is the first time (initial load)
      // Don't move camera on subsequent location updates - only update marker
      if (_mapController != null && !_hasSetInitialCameraPosition) {
        print('🗺️ [MapScreen] Setting initial camera position (first load only)...');
        try {
          if (_useInstantCameraUpdates) {
            await _mapController!.moveCamera(
              MapService.createInstantCameraUpdate(position),
            );
            print('   ✅ Initial camera position set');
          } else {
            await _mapController!.animateCamera(
              MapService.createCameraUpdate(position),
            );
            print('   ✅ Initial camera position animated');
          }
          _hasSetInitialCameraPosition = true;
        } catch (e) {
          print('   ⚠️ Error setting initial camera position: $e');
          // Don't throw - camera move is not critical
        }
      } else if (!_hasSetInitialCameraPosition) {
        print('   ⚠️ Map controller is not ready yet - will set initial position when ready');
      } else {
        print('   ℹ️ Initial camera position already set - skipping camera movement');
      }
      
      // Set up location stream listener for real-time updates (after initial position is set)
      if (!_hasSetInitialCameraPosition || _positionStreamSubscription == null) {
        _setupLocationStream();
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
      print('   📋 Stack trace: ${StackTrace.current}');
      
      // Check if it's a timeout error
      bool isTimeout = e.toString().contains('timed out') || 
                       e.toString().contains('TimeoutException');
      print('   📋 Is timeout error: $isTimeout');
      
      // For timeout, show helpful message and use default location
      if (isTimeout) {
        print('   🔄 Handling timeout - using default location');
        print('   💡 TIP: If using an emulator, set a mock location:');
        print('      Android: Emulator menu (⋮) → Location → Set coordinates');
        print('      iOS: Xcode → Debug → Simulate Location');
        print('      Or use ADB: adb emu geo fix 120.9842 14.5995');
        print('   💡 TIP: For physical device, try:');
        print('      - Move to area with better GPS signal (near window/outdoors)');
        print('      - Ensure WiFi/network location is enabled in device settings');
        print('      - Wait a bit longer and tap "My Location" button');
        
        setState(() {
          _isLoading = false;
          _hasError = false; // Don't show error overlay for timeout
          _initialCameraPosition = MapService.getDefaultCameraPosition();
          _locationStatus = 'GPS timeout - using default location. Tap "My Location" to retry.';
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
        print('   🔄 Handling other error - showing error overlay');
        // For other errors, show error overlay
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _initialCameraPosition = MapService.getDefaultCameraPosition();
        });
      }
    } finally {
      // Always reset the guard
      _isLocationRequestInProgress = false;
    }
  }

  /// Centers the map on the user's current location.
  /// 
  /// This is called when:
  /// - The map controller is initialized
  /// - User taps the "My Location" button
  Future<void> _centerMapOnUserLocation() async {
    print('🗺️ [MapScreen] _centerMapOnUserLocation() called');
    
    // Prevent concurrent location requests
    if (_isLocationRequestInProgress) {
      print('   ⚠️ Location request already in progress, skipping...');
      return;
    }
    
    if (_mapController == null) {
      print('   ❌ Map controller is null, cannot center');
      return;
    }

    _isLocationRequestInProgress = true;
    // Show loading state
    setState(() {
      _isLoading = true;
    });

    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Getting your current location...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      print('🗺️ [MapScreen] Getting position for centering (optimized mode)...');
      // Get position (optimized for performance)
      Position position = await _locationService.getCurrentPosition(
        preferLowAccuracy: _preferLowAccuracy,
        useCachedPosition: _useCachedPosition,
      );
      print('   ✅ Position received for centering:');
      print('      Latitude: ${position.latitude}');
      print('      Longitude: ${position.longitude}');
      
      // Check if this is a cached/old position
      final positionAge = DateTime.now().difference(position.timestamp);
      final isCachedPosition = positionAge.inMinutes > 3;
      
      print('🗺️ [MapScreen] Moving camera to position...');
      // Use instant camera update for better performance on low-end devices
      if (_useInstantCameraUpdates) {
        await _mapController!.moveCamera(
          MapService.createInstantCameraUpdate(position),
        );
        print('   ✅ Camera moved instantly (performance optimized)');
      } else {
        await _mapController!.animateCamera(
          MapService.createCameraUpdate(position),
        );
        print('   ✅ Camera animation completed');
      }

      // Update marker position immediately (manual re-center should update marker right away)
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _hasError = false;
          _isLoading = false;
        });
        // Update marker immediately for manual re-center
        _applyMarkers();
        // Reload bus stops near the new position
        _loadBusStopsNearUser(position.latitude, position.longitude);
      }
      
      // Set up location stream if not already set up
      if (_positionStreamSubscription == null) {
        _setupLocationStream();
      }

      // Show appropriate message based on position freshness
      if (mounted) {
        if (isCachedPosition) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Using cached location (${positionAge.inMinutes} min old). Move to get fresh GPS.',
              ),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Location updated successfully!'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('   ❌ [MapScreen] _centerMapOnUserLocation() ERROR: $e');
      print('   📋 Error type: ${e.runtimeType}');
      print('   📋 Error toString: ${e.toString()}');
      
      setState(() {
        _isLoading = false;
      });
      
      // Check if it's a timeout
      bool isTimeout = e.toString().contains('timed out') || 
                       e.toString().contains('TimeoutException');
      print('   📋 Is timeout error: $isTimeout');
      
      // Show error but don't block the UI
      if (mounted) {
        String errorMsg = isTimeout
            ? 'Location request timed out. Make sure:\n• GPS is enabled\n• You\'re in an area with GPS signal\n• Try moving to an open area'
            : 'Could not update location: ${e.toString().replaceAll('Exception: ', '')}';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _centerMapOnUserLocation,
            ),
          ),
        );
      }
    } finally {
      // Always reset the guard
      _isLocationRequestInProgress = false;
    }
  }

  /// Called when the map is created and controller is available.
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_mapStyleJson != null) {
      controller.setMapStyle(_mapStyleJson);
    }
    // Ensure markers (including bus stops) are applied when map is ready
    if (_busStopMarkers.isNotEmpty || _currentPosition != null) {
      setState(() => _applyMarkers());
    }
    // Set initial camera position if we have a position and haven't set it yet
    if (_currentPosition != null && !_hasSetInitialCameraPosition) {
      if (_enableCustomMarker) {
        _addMarkerAsync(_currentPosition!);
      }
      Future.microtask(() async {
        if (_mapController != null && _currentPosition != null && !_hasSetInitialCameraPosition) {
          try {
            if (_useInstantCameraUpdates) {
              await _mapController!.moveCamera(
                MapService.createInstantCameraUpdate(_currentPosition!),
              );
            } else {
              await _mapController!.animateCamera(
                MapService.createCameraUpdate(_currentPosition!),
              );
            }
            _hasSetInitialCameraPosition = true;
            print('🗺️ [MapScreen] Initial camera position set from map created callback');
          } catch (e) {
            print('⚠️ [MapScreen] Error setting initial camera position: $e');
          }
        }
      });
    }
  }
  
  /// Sets up a location stream listener for real-time position updates.
  /// Updates marker position without moving the camera automatically.
  void _setupLocationStream() async {
    // Cancel existing subscription if any
    await _positionStreamSubscription?.cancel();
    
    try {
      // Check permissions first
      final hasPermission = await _locationService.requestPermission();
      final serviceEnabled = await _locationService.isLocationServiceEnabled();
      
      if (!hasPermission || !serviceEnabled) {
        print('⚠️ [MapScreen] Cannot set up location stream: permission or service not available');
        return;
      }
      
      // Set up location stream with low accuracy for battery efficiency
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 10, // Only update if moved at least 10 meters
        ),
      ).listen(
        (Position position) {
          // Update marker position without moving camera
          _updateUserLocationMarker(position);
        },
        onError: (error) {
          print('⚠️ [MapScreen] Location stream error: $error');
        },
      );
      
      print('✅ [MapScreen] Location stream listener set up successfully');
    } catch (e) {
      print('❌ [MapScreen] Error setting up location stream: $e');
    }
  }
  
  /// Updates the user location marker position without moving the camera.
  /// This is called by the location stream listener for real-time updates.
  void _updateUserLocationMarker(Position position) {
    if (!mounted) return;
    
    print('📍 [MapScreen] Location updated: (${position.latitude}, ${position.longitude}) - updating marker only');
    
    setState(() {
      _currentPosition = position;
      _applyMarkers(); // This updates the marker position in the Set<Marker>
    });
    
    // Optionally reload bus stops near the new position (but don't move camera)
    _loadBusStopsNearUser(position.latitude, position.longitude);
  }

  Future<void> _loadMapStyle() async {
    final json = await _mapStyleService.loadTransportationStyle();
    if (mounted && json != null) {
      _mapStyleJson = json;
      setState(() {});
      if (_mapController != null) {
        _mapController!.setMapStyle(_mapStyleJson);
      }
    }
  }

  /// Fallback: create markers from sample Cebu bus stops.
  void _applySampleBusStopMarkersCebu() {
    final markers = _markerService.createSampleMarkers();
    setState(() {
      _busStopMarkers = markers;
      _applyMarkers();
    });
    print('📍 [MapScreen] Applied ${markers.length} Cebu bus stop markers');
  }

  /// Rebuild _markers and _userLocationCircles from user location + bus stop markers.
  void _applyMarkers() {
    final Set<Marker> next = Set<Marker>.from(_busStopMarkers);
    final Set<Circle> nextCircles = {};
    if (_currentPosition != null) {
      final pos = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      next.add(Marker(
        markerId: const MarkerId('user_location'),
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Your Location', snippet: 'You are here'),
        anchor: const Offset(0.5, 0.5),
      ));
      // Faded blue glow so user knows where they are when away from a bus stop
      nextCircles.add(Circle(
        circleId: const CircleId('user_location_glow'),
        center: pos,
        radius: _userLocationGlowRadiusMeters,
        fillColor: Colors.blue.withOpacity(0.18),
        strokeColor: Colors.blue.withOpacity(0.35),
        strokeWidth: 2,
      ));
    }
    _markers = next;
    _userLocationCircles = nextCircles;
  }

  /// Build bus stop markers; uses green icon for the stop with [closestStopId].
  void _applyBusStopMarkers(List<BusStop> stops, {String? closestStopId}) {
    final markers = _markerService.createMarkersFromStops(stops, closestStopId: closestStopId);
    setState(() {
      _busStopMarkers = markers;
      _applyMarkers();
    });
  }

  /// Load all bus stops in Cebu (center). Used when user location is not yet available.
  Future<void> _loadAllCebuBusStops() async {
    try {
      final result = await _busStopsService.getBusStopsInCebu();
      if (mounted) {
        _applyBusStopMarkers(result.stops, closestStopId: result.closestStopId);
        print('📍 [MapScreen] Loaded ${result.stops.length} Cebu bus stops ${result.isRealData ? "(real)" : "(demo)"}');
        if (!result.isRealData) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Showing demo bus stops. Enable "Places API" in Google Cloud Console to see real stops.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      print('⚠️ [MapScreen] Error loading Cebu bus stops: $e');
      if (mounted) _applySampleBusStopMarkersCebu();
    }
  }

  /// Load bus stops using user location: closest (rankby=distance) + up to 60 in radius; highlight closest in green.
  Future<void> _loadBusStopsNearUser(double userLat, double userLng) async {
    try {
      final result = await _busStopsService.getBusStopsWithClosestHighlighted(userLat, userLng);
      if (mounted && result.stops.isNotEmpty) {
        _applyBusStopMarkers(result.stops, closestStopId: result.closestStopId);
        print('📍 [MapScreen] Loaded ${result.stops.length} stops; closest highlighted');
        if (!result.isRealData) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Showing demo bus stops. Enable "Places API" to see real stops and closest to you.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      print('⚠️ [MapScreen] Error loading stops near user: $e');
    }
  }

  /// Adds user location marker and reloads bus stops using user location (closest + city radius, highlight closest).
  void _addMarkerAsync(Position position) {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || _mapController == null) return;
      setState(() {
        _currentPosition = position;
        _applyMarkers();
      });
      _loadBusStopsNearUser(position.latitude, position.longitude);
      print('📍 [MapScreen] User at (${position.latitude}, ${position.longitude}); loading stops with closest highlighted');
    });
  }

  /// Opens app settings so user can manually enable location permission.
  Future<void> _openAppSettings() async {
    await _locationService.openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map with bus stop markers (key forces update when marker count changes)
          GoogleMap(
            key: ValueKey('map_${_busStopMarkers.isNotEmpty}_${_routePolylines.length}'),
            initialCameraPosition:
                _initialCameraPosition ?? MapService.getDefaultCameraPosition(),
            onMapCreated: _onMapCreated,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _markers,
            circles: _userLocationCircles,
            polylines: _routePolylines,
            trafficEnabled: _enableTrafficLayer,
            mapType: MapService.getDefaultMapType(),
            zoomControlsEnabled: false,
            compassEnabled: true,
            liteModeEnabled: false,
            buildingsEnabled: true,
            indoorViewEnabled: false,
          ),

          // Loading indicator overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Getting your location...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Error overlay (only for non-timeout errors)
          if (_hasError && !_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_off,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Location Error',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage ?? 'Unknown error occurred',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () => _initializeLocation(showError: true),
                            child: const Text('Retry'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _hasError = false;
                                _initialCameraPosition = MapService.getDefaultCameraPosition();
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Use Default'),
                          ),
                          if (_errorMessage?.contains('permanently denied') == true)
                            const SizedBox(width: 12),
                          if (_errorMessage?.contains('permanently denied') == true)
                            ElevatedButton(
                              onPressed: _openAppSettings,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Settings'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // My Location button (bottom right)
          if (!_isLoading && !_hasError)
            Positioned(
              bottom: 24,
              right: 16,
              child: FloatingActionButton(
                onPressed: _centerMapOnUserLocation,
                backgroundColor: Colors.white,
                child: const Icon(
                  Icons.my_location,
                  color: Colors.blue,
                ),
              ),
            ),

          // Debug info overlay (top left) - tap to toggle
          // Only render when visible to save performance
          if (_showDebugInfo && !_isLoading)
            Positioned(
              top: 16,
              left: 16,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showDebugInfo = !_showDebugInfo;
                    });
                  },
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 250),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bug_report, color: Colors.yellow, size: 16),
                            const SizedBox(width: 8),
                            const Flexible(
                              child: Text(
                                'DEBUG INFO',
                                style: TextStyle(
                                  color: Colors.yellow,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showDebugInfo = false;
                                });
                              },
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildDebugLine('Status', _isLoading ? 'Loading...' : (_hasError ? 'Error' : (_currentPosition != null ? 'Ready ✓' : 'Ready (No GPS)'))),
                        _buildDebugLine('Info', _locationStatus),
                        if (_currentPosition != null) ...[
                          _buildDebugLine('Lat', _currentPosition!.latitude.toStringAsFixed(6)),
                          _buildDebugLine('Lng', _currentPosition!.longitude.toStringAsFixed(6)),
                          _buildDebugLine('Accuracy', '${_currentPosition!.accuracy.toStringAsFixed(1)}m'),
                          _buildDebugLine('Source', _currentPosition!.accuracy > 100 ? 'Network/WiFi' : 'GPS'),
                        ] else ...[
                          _buildDebugLine('Position', 'Not available'),
                          _buildDebugLine('Location', 'Using default'),
                          _buildDebugLine('Action', 'Tap "My Location"'),
                        ],
                        if (_errorMessage != null)
                          _buildDebugLine('Last Error', _errorMessage!.length > 40 
                            ? '${_errorMessage!.substring(0, 40)}...' 
                            : _errorMessage!),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap to hide',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDebugLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
