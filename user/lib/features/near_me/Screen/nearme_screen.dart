import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/models/bus_stop.dart';
import '../../../core/services/bus_stops_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/location_cache_service.dart';
import '../../../core/services/map/map_service.dart';
import '../../../shared/bottom_navBar.dart';
import '../../map/map.dart';
import '../Module/free_ride.dart';
import '../Module/from_to_form.dart';
import '../Module/nearby_terminal.dart';

class NearMeScreen extends StatelessWidget {
  const NearMeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MainNavigationScreen(
      nearMeContent: const _NearMeContent(),
    );
  }
}

class _NearMeContent extends StatefulWidget {
  const _NearMeContent();

  @override
  State<_NearMeContent> createState() => _NearMeContentState();
}

class _NearMeContentState extends State<_NearMeContent> {
  late DraggableScrollableController _sheetController;
  bool _showFreeRideDetails = false;
  double _sheetExtent = 0.38;
  bool _showFreeRide = true;
  bool _showStopsContent = true;
  static const double _minSheetExtent = 0.10;

  Map<String, dynamic>? _selectedTo;
  List<Map<String, dynamic>> _destinations = [];
  LatLng? _closestStopLatLng;
  Position? _userPosition;
  LatLng? _routeOrigin;
  LatLng? _routeDestination;
  bool _destinationsLoading = true;
  double? _routeDistanceMeters; // Distance from POINT_A (nearest bus stop) to POINT_B (destination)
  String? _routeDistanceText; // Formatted distance text
  bool _isCalculatingDistance = false;
  bool _hasLoadedOnce = false; // Track if we've loaded data at least once

  final LocationService _locationService = LocationService();
  final BusStopsService _busStopsService = BusStopsService();
  final LocationCacheService _locationCache = LocationCacheService.instance;

  /// Fallback list when API hasn't loaded yet; includes lat/lng for route drawing.
  static const List<Map<String, dynamic>> _terminalsFallback = [
    {'terminalName': 'Pacific Terminal', 'location': 'Pacific Mall, Mandaue', 'lat': 10.3232, 'lng': 123.9456, 'routes': ['01K', '13B', '01F', '46E'], 'distance': '0.6 Km', 'isHighlighted': true},
    {'terminalName': 'Marpa', 'location': 'Maguikay, Mandaue City', 'lat': 10.3312, 'lng': 123.9388, 'routes': ['01K', '13B', '01F', '46E'], 'distance': '0.6 Km', 'isHighlighted': false},
    {'terminalName': 'Jmall', 'location': 'Jmall, Mandaue City', 'lat': 10.3289, 'lng': 123.9321, 'routes': ['01K', '13B', '01F', '46E'], 'distance': '0.7 Km', 'isHighlighted': false},
    {'terminalName': 'Ayala Terminal', 'location': 'Ayala Center, Cebu City', 'lat': 10.3192, 'lng': 123.9076, 'routes': ['02A', '04B', '12C'], 'distance': '1.2 Km', 'isHighlighted': false},
    {'terminalName': 'SM Terminal', 'location': 'SM City, Cebu', 'lat': 10.3156, 'lng': 123.9182, 'routes': ['03D', '05E', '08F'], 'distance': '1.5 Km', 'isHighlighted': false},
  ];

  void _updateFromSheetExtent(double extent) {
    setState(() {
      _sheetExtent = extent;
      _showFreeRide = extent > _minSheetExtent && extent < 0.70;
      _showStopsContent = extent > 0.15;
    });
  }

  @override
  void initState() {
    super.initState();
    _destinations = List<Map<String, dynamic>>.from(_terminalsFallback);
    _sheetController = DraggableScrollableController();
    _sheetController.addListener(() => _updateFromSheetExtent(_sheetController.size));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateFromSheetExtent(_sheetController.size);
        // Try to load from cache first, then fetch if needed
        _loadFromCacheOrFetch();
      }
    });
  }

  /// Loads from cache first, then fetches if cache is expired or unavailable.
  Future<void> _loadFromCacheOrFetch() async {
    // Check if we have cached location (valid for up to 5 minutes for near me page)
    // Use longer cache duration for near me page to avoid reloading when navigating back
    const cacheDuration = Duration(minutes: 5);
    final cachedPosition = _locationCache.getCachedLocationWithMaxAge(cacheDuration);
    
    // Use cached location if available and valid
    if (cachedPosition != null) {
      final cacheAge = _locationCache.getCacheAge();
      print('📍 [NearMe] Using cached location (${cacheAge?.inMinutes ?? 0} min old)');
      if (mounted) {
        setState(() {
          _userPosition = cachedPosition;
          _destinationsLoading = true;
        });
        // Load bus stops with cached location
        await _loadBusStopsWithPosition(cachedPosition);
        _hasLoadedOnce = true;
        return;
      }
    }
    
    // If no valid cache or first load, fetch fresh location
    await _loadBusStopsAsDestinations();
  }

  /// Loads bus stops and sets them as destination options; also captures closest stop for route origin.
  /// Fetches fresh location if cache is not available.
  Future<void> _loadBusStopsAsDestinations() async {
    if (_hasLoadedOnce && _userPosition != null) {
      // If we already have data and it's been loaded once, don't reload
      print('📍 [NearMe] Data already loaded, skipping reload');
      return;
    }
    
    try {
      Position? position;
      try {
        final enabled = await _locationService.isLocationServiceEnabled();
        final hasPermission = await _locationService.requestPermission();
        if (enabled && hasPermission) {
          final fetchedPosition = await _locationService.getCurrentPosition(
            preferLowAccuracy: true,
            useCachedPosition: true,
          ).timeout(const Duration(seconds: 8));
          
          position = fetchedPosition;
          
          // Save to cache after getting position
          await _locationCache.saveLocation(fetchedPosition);
          print('📍 [NearMe] Location saved to cache');
        }
      } catch (_) {
        // Position remains null if fetch fails
      }
      
      if (position != null && mounted) {
        await _loadBusStopsWithPosition(position);
        _hasLoadedOnce = true;
        return;
      }
      
      // Fallback: load Cebu stops without location
      final result = await _busStopsService.getBusStopsInCebu();
      if (!mounted) return;
      _applyDestinationsFromStops(result.stops, null);
      _hasLoadedOnce = true;
    } catch (e) {
      if (mounted) {
        setState(() => _destinationsLoading = false);
      }
    }
  }

  /// Loads bus stops using the provided position.
  Future<void> _loadBusStopsWithPosition(Position position) async {
    if (!mounted) return;
    
    setState(() {
      _userPosition = position;
      _destinationsLoading = true;
    });
    
    try {
      final result = await _busStopsService.getBusStopsWithClosestHighlighted(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      _applyDestinationsFromStops(result.stops, result.closestStopId);
    } catch (e) {
      print('⚠️ [NearMe] Error loading bus stops: $e');
      if (mounted) {
        setState(() => _destinationsLoading = false);
      }
    }
  }

  void _applyDestinationsFromStops(List<BusStop> stops, String? closestStopId) {
    if (stops.isEmpty) return;
    final list = stops.map((stop) {
      final location = stop.route.isNotEmpty ? 'Route ${stop.route}' : stop.stopCode;
      return <String, dynamic>{
        'terminalName': stop.name,
        'location': location,
        'lat': stop.lat,
        'lng': stop.lng,
      };
    }).toList();
    LatLng? closestLatLng;
    if (closestStopId != null) {
      for (final s in stops) {
        if (s.id == closestStopId) {
          closestLatLng = s.position;
          break;
        }
      }
    }
    setState(() {
      _destinations = list;
      _closestStopLatLng = closestLatLng;
      _destinationsLoading = false;
    });
  }

  /// Calculates accurate street distance from POINT_A (nearest bus stop) to POINT_B (destination)
  /// using Google Maps API.
  Future<void> _calculateRouteDistance(LatLng pointA, LatLng pointB) async {
    if (!mounted) return;
    
    setState(() {
      _isCalculatingDistance = true;
    });
    
    if (_isCalculatingDistance) {
      print('📍 [NearMe] Starting distance calculation...');
    }
    
    try {
      print('📍 [NearMe] Calculating distance from POINT_A (nearest bus stop) to POINT_B (destination)');
      print('   POINT_A: (${pointA.latitude}, ${pointA.longitude})');
      print('   POINT_B: (${pointB.latitude}, ${pointB.longitude})');
      
      final routeResult = await MapService.getRouteWithDistance(pointA, pointB);
      
      if (!mounted) return;
      
      if (routeResult != null) {
        setState(() {
          _routeDistanceMeters = routeResult.distanceMeters;
          _routeDistanceText = routeResult.distanceText;
          _isCalculatingDistance = false;
        });
        
        print('✅ [NearMe] Route distance calculated:');
        print('   Distance: ${routeResult.distanceText} (${_routeDistanceMeters?.toStringAsFixed(0) ?? 'N/A'} meters)');
        if (routeResult.durationText != null) {
          print('   Duration: ${routeResult.durationText}');
        }
        
        // Log stored distance for debugging
        if (_routeDistanceMeters != null) {
          print('   Stored distance: ${_routeDistanceMeters!.toStringAsFixed(0)} meters');
        }
        
        // Show snackbar with distance information using stored fields
        if (mounted && _routeDistanceText != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Route distance: $_routeDistanceText${routeResult.durationText != null ? ' • ${routeResult.durationText}' : ''}',
              ),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } else {
        setState(() {
          _isCalculatingDistance = false;
        });
        print('⚠️ [NearMe] Could not calculate route distance');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCalculatingDistance = false;
      });
      print('❌ [NearMe] Error calculating route distance: $e');
    }
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  /// Builds the scrollable list of terminals (uses fallback list with routes/distance for card display)
  Widget _buildTerminalsList(ScrollController scrollController) {
    final terminals = _terminalsFallback;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final terminal = terminals[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == terminals.length - 1 ? 24 : 12,
              left: 16,
              right: 16,
            ),
            child: NearbyTerminalCard(
              terminalName: terminal['terminalName'] as String,
              location: terminal['location'] as String,
              routes: terminal['routes'] as List<String>,
              distance: terminal['distance'] as String,
              isHighlighted: terminal['isHighlighted'] as bool,
            ),
          );
        },
        childCount: terminals.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🔹 Map background (route from closest bus stop to selected destination)
          Positioned.fill(
            child: MapWidget(
              routeOrigin: _routeOrigin,
              routeDestination: _routeDestination,
            ),
          ),

          // 🔹 Destination form (bus stops as options)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: FromToForm(
                  destinations: _destinations,
                  selectedDestination: _selectedTo,
                  isLoading: _destinationsLoading,
                  onDestinationSelected: (t) async {
                    final lat = t['lat'];
                    final lng = t['lng'];
                    final hasCoords = lat != null && lng != null && lat is num && lng is num;
                    
                    setState(() {
                      _selectedTo = t;
                      _routeDistanceMeters = null;
                      _routeDistanceText = null;
                      _isCalculatingDistance = false;
                      
                      if (hasCoords) {
                        _routeDestination = LatLng(lat.toDouble(), lng.toDouble());
                        _routeOrigin = _closestStopLatLng ??
                            (_userPosition != null
                                ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
                                : null);
                      } else {
                        _routeOrigin = null;
                        _routeDestination = null;
                      }
                    });
                    
                    // Calculate accurate distance from POINT_A (nearest bus stop) to POINT_B (destination)
                    if (hasCoords && _routeOrigin != null && _routeDestination != null) {
                      _calculateRouteDistance(_routeOrigin!, _routeDestination!);
                    }
                  },
                ),
              ),
            ),
          ),

           // 🔹 Free Ride banner (floating above bottom sheet, follows sheet movement with fade animation)
          // Only show when sheet is visible (not at 0)
          // Use IgnorePointer to ensure it doesn't block sheet dragging
          if (_sheetExtent > 0.0)
            Positioned(
              left: 16,
              right: 16,
              bottom: (_sheetExtent * MediaQuery.of(context).size.height) + 16,
              child: IgnorePointer(
                ignoring: false, // Allow banner interactions
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                  opacity: _showFreeRide ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_showFreeRide,
                    child: FreeRideBanner(
                      showDetails: _showFreeRideDetails,
                      onViewTap: () {
                        setState(() {
                          _showFreeRideDetails = !_showFreeRideDetails;
                        });
                      },
                      onClose: () {
                        setState(() {
                          _showFreeRideDetails = false;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),


           // 🔹 Bottom draggable sheet - min 10% so user always sees swipe hint
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.38,
            minChildSize: _minSheetExtent, // 10% peek with swipe icon
            maxChildSize: 0.85,
            snap: true, // Enable snapping to sizes
            snapSizes: const [_minSheetExtent, 0.38, 0.85], // Snap: peek, initial, max
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: CustomScrollView(
                  controller: scrollController, // Use sheet's scroll controller for entire content
                  physics: const ClampingScrollPhysics(), // Important for DraggableScrollableSheet
                  slivers: [
                    // 🔹 Drag handle + swipe hint icon (always visible so user knows they can swipe)
                    SliverToBoxAdapter(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Always show arrow: up when minimized, down when card is up
                              Icon(
                                _sheetExtent <= _minSheetExtent + 0.02
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 28,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 🔹 Title - only show when sheet is above minimum threshold
                    if (_sheetExtent > 0.15)
                      SliverToBoxAdapter(
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Nearby Stops and Terminal',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                    if (_sheetExtent > 0.15)
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 12),
                      ),

                    // 🔹 List - Scrollable list of terminals (shown when sheet is up so user sees data on load)
                    if (_sheetExtent > 0.15 && _showStopsContent)
                      _buildTerminalsList(scrollController),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
