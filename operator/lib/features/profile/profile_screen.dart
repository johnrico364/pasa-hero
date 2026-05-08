import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/backend_api_service.dart';
import '../../../core/services/operator_bus_assignment_service.dart';
import '../../../core/services/operator_location_sync_service.dart';
import '../../../core/services/operator_assignment_live_sync_service.dart';
import '../../../core/services/operator_session_service.dart';
import 'modal/free_ride.dart';
import 'screen/profile_screen_data.dart';

/// Operator profile screen shown after login.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const String routeName = '/profile';

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _refreshingAssignment = false;

  /// From terminal bus assignment (`GET .../pending/operator/...` + route detail).
  String? _terminalRouteName;
  String? _terminalRouteCode;
  String? _terminalBusLabel;
  String? _terminalDriverName;
  bool _terminalRouteFreeRide = false;
  String? _terminalAssignmentError;

  final BackendApiService _backendApi = BackendApiService();
  StreamSubscription<void>? _assignmentLiveSub;

  /// Avoid overlapping the first [initial] load with [silent] polls (out-of-order completion could drop good data).
  bool _assignmentInitialFetchFinished = false;

  /// Latest silent refresh wins; older completions are ignored.
  int _silentAssignmentRefreshGen = 0;

  @override
  void initState() {
    super.initState();
    OperatorAssignmentLiveSyncService.instance.acquire();
    _assignmentLiveSub =
        OperatorAssignmentLiveSyncService.instance.refreshes.listen((_) {
      if (!mounted || !_assignmentInitialFetchFinished) return;
      _loadTerminalAssignment(silent: true);
    });
    _loadTerminalAssignment(initial: true).whenComplete(() {
      _assignmentInitialFetchFinished = true;
    });
  }

  @override
  void dispose() {
    _assignmentLiveSub?.cancel();
    OperatorAssignmentLiveSyncService.instance.release();
    super.dispose();
  }

  Future<({String? routeCode, bool isFreeRide})?> _fetchRouteMeta(
    String routeId,
  ) async {
    final res = await _backendApi.get(
      '/api/routes/${Uri.encodeComponent(routeId)}',
    );
    if (!res.success || res.data == null) return null;
    final data = res.data!['data'];
    if (data is! Map) return null;
    final m = Map<String, dynamic>.from(data);
    final code = m['route_code']?.toString() ??
        m['routeCode']?.toString() ??
        m['code']?.toString();
    final free = m['is_free_ride'] == true;
    return (routeCode: code, isFreeRide: free);
  }

  Future<void> _loadTerminalAssignment({
    bool initial = false,
    bool silent = false,
  }) async {
    final int? silentGen;
    if (silent) {
      silentGen = ++_silentAssignmentRefreshGen;
    } else {
      _silentAssignmentRefreshGen++; // drop in-flight silent completions
      silentGen = null;
    }

    if (silent) {
      // Background live-sync: update route card without spinners.
    } else if (initial) {
      setState(() {
        _isLoading = true;
        _terminalAssignmentError = null;
      });
    } else {
      setState(() => _refreshingAssignment = true);
    }

    await OperatorSessionService.instance.loadFromPrefs();
    final result =
        await OperatorBusAssignmentService.instance.fetchMyAssignments();

    String? routeName;
    String? routeCode;
    String? busLabel;
    String? driverName;
    var freeRide = false;
    String? err = result.errorHint;

    if (result.items.isNotEmpty) {
      final a = result.items.first;
      routeName = a.routeName;
      busLabel = a.busLabel;
      driverName = a.driverName;
      final rid = a.routeId;
      if (rid != null && rid.isNotEmpty) {
        final meta = await _fetchRouteMeta(rid);
        routeCode = meta?.routeCode;
        freeRide = meta?.isFreeRide ?? false;
      }
    }

    if (!mounted) return;

    if (silent) {
      if (silentGen != _silentAssignmentRefreshGen) return;
      if (err != null) {
        // Transient failures on poll/WS must not replace a good assignment with an error.
        return;
      }
    }

    setState(() {
      if (!silent) {
        _isLoading = false;
        _refreshingAssignment = false;
      }
      _terminalAssignmentError = err;
      _terminalRouteName = routeName;
      _terminalRouteCode = routeCode;
      _terminalBusLabel = busLabel;
      _terminalDriverName = driverName;
      _terminalRouteFreeRide = freeRide;
    });
    if (routeCode != null && routeCode.trim().isNotEmpty) {
      unawaited(ProfileDataService.syncAssignedRouteFromTerminal(routeCode));
    }
  }

  Future<void> _showProfileInformation() async {
    final user = FirebaseAuth.instance.currentUser;
    final profile = await ProfileDataService.getOperatorProfile();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Email', user?.email ?? 'N/A'),
              const SizedBox(height: 12),
              _buildInfoRow('Role', profile?['role'] ?? 'operator'),
              const SizedBox(height: 12),
              _buildInfoRow(
                'Assigned route (terminal)',
                _terminalRouteCode ?? '—',
              ),
              if (_terminalRouteName != null) ...[
                const SizedBox(height: 12),
                _buildInfoRow('Route name', _terminalRouteName!),
              ],
              if (_terminalBusLabel != null) ...[
                const SizedBox(height: 12),
                _buildInfoRow('Bus', _terminalBusLabel!),
              ],
              if (_terminalDriverName != null) ...[
                const SizedBox(height: 12),
                _buildInfoRow('Driver', _terminalDriverName!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeRideCard() {
    return FreeRideCard(
      currentRouteCode: _terminalRouteCode,
      isDesignatedFreeRideRoute: _terminalRouteFreeRide,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('Profile'),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            actions: [
              if (_refreshingAssignment)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              else
                IconButton(
                  tooltip: 'Refresh assignment',
                  icon: const Icon(Icons.refresh),
                  onPressed: _isLoading ? null : () => _loadTerminalAssignment(),
                ),
            ],
          ),
          body: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    const SizedBox(height: 24),
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.blue.shade100,
                      child: Icon(Icons.person, size: 56, color: Colors.blue.shade700),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Operator',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email,
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    // Profile Information Button
                    Card(
                      elevation: 2,
                      child: ListTile(
                        leading: const Icon(Icons.info_outline, color: Colors.blue),
                        title: const Text('Profile Information'),
                        subtitle: const Text('View your account details'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _showProfileInformation,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      child: ListTile(
                        leading: const Icon(Icons.route, color: Colors.blue),
                        title: const Text('Assigned route'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _terminalAssignmentError != null
                                  ? 'Could not load assignment: $_terminalAssignmentError'
                                  : _terminalRouteName != null ||
                                          _terminalRouteCode != null
                                      ? [
                                          if (_terminalRouteName != null)
                                            _terminalRouteName!,
                                          if (_terminalRouteCode != null)
                                            'Code: $_terminalRouteCode',
                                          if (_terminalBusLabel != null)
                                            'Bus: $_terminalBusLabel',
                                          if (_terminalDriverName != null)
                                            'Driver: $_terminalDriverName',
                                        ].join('\n')
                                      : 'No active assignment yet. Your terminal admin assigns your route; pull refresh (↻) to update.',
                              style: TextStyle(
                                color: _terminalAssignmentError != null
                                    ? Colors.red.shade800
                                    : null,
                              ),
                            ),
                            if (_terminalRouteFreeRide &&
                                _terminalRouteCode != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.amber.shade700,
                                  ),
                                ),
                                child: Text(
                                  'Free ride route',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        isThreeLine: _terminalRouteFreeRide &&
                            _terminalRouteCode != null,
                        trailing: Icon(
                          Icons.lock_outline,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Free Ride indicator card
                    _buildFreeRideCard(),
                    const SizedBox(height: 48),
                    OutlinedButton.icon(
                      onPressed: () => _signOut(context),
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign out'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final db = FirebaseFirestore.instance;
      // Mark operator account offline before sign out.
      await db.collection('users').doc(user.uid).set({
        'status': 0,
        'online': 0,
        'last_seen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Mark operator live location offline then remove it from live map.
      await db.collection(operatorLocationsCollection).doc(user.uid).set({
        'status': 0,
        'online': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await db.collection(operatorLocationsCollection).doc(user.uid).delete();
    }
    OperatorLocationSyncService.instance.stop();
    ProfileDataService.resetTerminalAssignmentFirebaseSyncDedupe();
    await OperatorSessionService.instance.clear();
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }
}
