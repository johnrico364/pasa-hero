import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../features/profile/screen/profile_screen_data.dart';
import 'location_service.dart';

/// Firestore collection where operators publish live GPS (read by passenger app).
const String operatorLocationsCollection = 'operator_locations';

/// Periodically writes the signed-in operator's position to Firestore so riders
/// can see buses near them.
class OperatorLocationSyncService {
  OperatorLocationSyncService._();
  static final OperatorLocationSyncService instance = OperatorLocationSyncService._();

  final LocationService _locationService = LocationService();
  Timer? _timer;
  bool _tickInProgress = false;
  int _session = 0;

  void start({Duration interval = const Duration(seconds: 8)}) {
    stop();
    final sid = _session;
    // Defer first publish slightly so RouteScreen / profile can set [locationSyncRouteFallback]
    // before we write [operator_locations.routeCode] (avoids one empty-route write on cold start).
    Future<void> kickoff() async {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (sid != _session) return;
      await _tick();
      if (sid != _session) return;
      _timer = Timer.periodic(interval, (_) => _tick());
    }

    unawaited(kickoff());
  }

  void stop() {
    _session++;
    _timer?.cancel();
    _timer = null;
    _tickInProgress = false;
    unawaited(_markOperatorLocationOffline());
  }

  /// Passenger map reads [operator_locations]; mark offline when sync stops (e.g. app backgrounded)
  /// so riders do not keep seeing a "live" bus until staleness TTL.
  Future<void> _markOperatorLocationOffline() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection(operatorLocationsCollection)
          .doc(user.uid)
          .set(
        {
          'uid': user.uid,
          'online': 0,
          'status': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e, st) {
      debugPrint('[OperatorLocationSync] mark offline failed: $e\n$st');
    }
  }

  Future<bool> _ensureForegroundLocationPermission() async {
    try {
      return await _locationService.requestPermission();
    } catch (e) {
      debugPrint('[OperatorLocationSync] permission check failed: $e');
      return false;
    }
  }

  Future<void> _publishLocation(User user, Position pos, String codeForFirestore) async {
    // Never write empty route fields on GPS ticks — that would overwrite a good
    // [mergeRouteCodeIntoOperatorLocation] / profile route until the next merge.
    final payload = <String, dynamic>{
      'uid': user.uid,
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'accuracyMeters': pos.accuracy,
      'online': 1,
      'status': 1,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final rc = codeForFirestore.trim();
    if (rc.isNotEmpty) {
      final upper = rc.toUpperCase();
      payload['routeCode'] = upper;
      payload['route_code'] = upper;
    }
    await FirebaseFirestore.instance
        .collection(operatorLocationsCollection)
        .doc(user.uid)
        .set(payload, SetOptions(merge: true));
  }

  /// Merges the new route into [operator_locations] right away so riders are not stuck
  /// on the previous [routeCode] until the next periodic GPS tick (~8s).
  Future<void> mergeRouteCodeIntoOperatorLocation(String routeCode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final trimmed = routeCode.trim();
    if (trimmed.isEmpty) return;
    final upper = trimmed.toUpperCase();
    try {
      await FirebaseFirestore.instance
          .collection(operatorLocationsCollection)
          .doc(user.uid)
          .set(
        {
          'uid': user.uid,
          'routeCode': upper,
          'route_code': upper,
          'online': 1,
          'status': 1,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      debugPrint(
        '[OperatorLocationSync] merged route into operator_locations: $upper',
      );
    } catch (e, st) {
      debugPrint(
        '[OperatorLocationSync] mergeRouteCodeIntoOperatorLocation failed: $e\n$st',
      );
    }
  }

  /// If a full GPS fix fails, still publish last known coordinates so riders see the bus.
  Future<void> _tryLastKnownFallback(User user) async {
    try {
      final last = await Geolocator.getLastKnownPosition().timeout(
        const Duration(seconds: 8),
      );
      if (last == null) return;
      final age = DateTime.now().difference(last.timestamp);
      if (age > const Duration(hours: 2)) return;

      final codeForFirestore = await ProfileDataService.resolveRouteCodeForLocationPublish();

      await _publishLocation(user, last, codeForFirestore);
      debugPrint(
        '[OperatorLocationSync] published last-known fallback (age ${age.inMinutes}m)',
      );
    } catch (e) {
      debugPrint('[OperatorLocationSync] last-known fallback failed: $e');
    }
  }

  Future<void> _tick() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_tickInProgress) return;
    _tickInProgress = true;
    try {
      final ok = await _ensureForegroundLocationPermission();
      if (!ok) {
        await _tryLastKnownFallback(user);
        return;
      }

      final pos = await _locationService.getCurrentPosition(
        preferLowAccuracy: false,
        useCachedPosition: true,
        forceRefresh: false,
      );
      final codeForFirestore = await ProfileDataService.resolveRouteCodeForLocationPublish();

      await _publishLocation(user, pos, codeForFirestore);
    } catch (e, st) {
      debugPrint('[OperatorLocationSync] tick failed: $e\n$st');
      await _tryLastKnownFallback(user);
    } finally {
      _tickInProgress = false;
    }
  }
}
