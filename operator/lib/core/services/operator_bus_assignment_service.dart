import 'package:shared_preferences/shared_preferences.dart';

import 'backend_api_service.dart';
import 'operator_session_service.dart';

/// Mongo/API assignment state for the logged-in operator (bus assignments).
class OperatorBusAssignmentSnapshot {
  const OperatorBusAssignmentSnapshot({
    required this.id,
    required this.assignmentStatus,
    required this.assignmentResult,
    this.routeName,
    this.busLabel,
    this.driverName,
    this.busId,
    this.routeId,
  });

  final String id;
  final String assignmentStatus;
  final String assignmentResult;
  final String? routeName;
  final String? busLabel;
  /// From API [driver_name] (assigned driver for this bus).
  final String? driverName;
  /// From list row `bus_id` — required for `POST /api/terminal-logs`.
  final String? busId;
  /// From list row `route_id` — used to resolve start/end terminals for logs.
  final String? routeId;
}

/// Fetches pending operator assignments from
/// `GET /api/bus-assignments/pending/operator/:operator_id` and applies PATCH updates.
class OperatorBusAssignmentService {
  OperatorBusAssignmentService._();
  static final OperatorBusAssignmentService instance = OperatorBusAssignmentService._();

  final BackendApiService _api = BackendApiService();

  static const _prefDepartedPrefix = 'operator_bus_assignment_departed_';

  Future<bool> _localDepartedFlag(String assignmentId) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('$_prefDepartedPrefix$assignmentId') == true;
  }

  Future<void> _setLocalDeparted(String assignmentId, bool value) async {
    final p = await SharedPreferences.getInstance();
    if (value) {
      await p.setBool('$_prefDepartedPrefix$assignmentId', true);
    } else {
      await p.remove('$_prefDepartedPrefix$assignmentId');
    }
  }

  Map<String, String> _authHeaders() {
    final jwt = OperatorSessionService.instance.jwt?.trim();
    if (jwt == null || jwt.isEmpty) return {};
    return {'Authorization': 'Bearer $jwt'};
  }

  static String? _stringId(dynamic raw) {
    if (raw == null) return null;
    if (raw is String && raw.isNotEmpty) return raw;
    if (raw is Map) {
      final o = raw[r'$oid'] ?? raw['oid'];
      if (o is String && o.isNotEmpty) return o;
    }
    final s = raw.toString();
    return s.isEmpty ? null : s;
  }

  /// Active **pending** assignments for this operator (`assignment_status` active,
  /// `assignment_result` pending). Requires JWT; [operator_id] must equal JWT `userId` on the server.
  ///
  /// [errorHint] is set when the request fails (401/403, wrong route, etc.) so the UI is not silent.
  Future<({List<OperatorBusAssignmentSnapshot> items, String? errorHint})>
      fetchMyAssignments() async {
    await OperatorSessionService.instance.loadFromPrefs();
    final session = OperatorSessionService.instance;
    if (!session.hasValidJwt) {
      return (items: <OperatorBusAssignmentSnapshot>[], errorHint: null);
    }

    final opId = session.resolveMongoUserId();
    if (opId == null || opId.isEmpty) {
      return (
        items: <OperatorBusAssignmentSnapshot>[],
        errorHint:
            'Could not read your operator id. Sign out and sign in again.',
      );
    }

    if (session.jwt == null || session.jwt!.trim().isEmpty) {
      return (
        items: <OperatorBusAssignmentSnapshot>[],
        errorHint: 'Not signed in to the API.',
      );
    }

    final encoded = Uri.encodeComponent(opId);
    final res = await _api.get(
      '/api/bus-assignments/pending/operator/$encoded',
      headers: _authHeaders(),
    );

    if (!res.success) {
      final msg = res.data?['message'] as String? ??
          res.error ??
          'Assignments request failed (HTTP ${res.statusCode}).';
      return (items: <OperatorBusAssignmentSnapshot>[], errorHint: msg);
    }

    final data = res.data?['data'];
    if (data is! List) {
      return (
        items: <OperatorBusAssignmentSnapshot>[],
        errorHint: 'Unexpected assignments response from server.',
      );
    }

    final out = <OperatorBusAssignmentSnapshot>[];
    for (final row in data) {
      if (row is! Map) continue;
      final m = Map<String, dynamic>.from(row);
      final snap = _snapshotFromListRow(m);
      if (snap != null) out.add(snap);
    }
    return (items: out, errorHint: null);
  }

  OperatorBusAssignmentSnapshot? _snapshotFromListRow(Map<String, dynamic> m) {
    final id = _stringId(m['_id']);
    if (id == null) return null;
    final statusRaw = (m['status'] ?? 'inactive').toString();
    final resultRaw = (m['result'] ?? 'pending').toString();
    final status = statusRaw == 'active' ? 'active' : 'inactive';

    final rn = m['route_name']?.toString();
    final routeName =
        (rn == null || rn.isEmpty || rn == '—') ? null : rn;

    final bn = m['bus_number']?.toString();
    final plate = m['plate_number']?.toString();
    final hasBn = bn != null && bn.isNotEmpty && bn != '—';
    final hasPlate = plate != null && plate.isNotEmpty && plate != '—';
    String? busLabel;
    if (hasBn) {
      busLabel = hasPlate ? '$bn · $plate' : bn;
    } else if (hasPlate) {
      busLabel = plate;
    }

    final dn = m['driver_name']?.toString();
    final driverName =
        (dn == null || dn.isEmpty || dn == '—') ? null : dn.trim();

    return OperatorBusAssignmentSnapshot(
      id: id,
      assignmentStatus: status,
      assignmentResult: resultRaw,
      routeName: routeName,
      busLabel: busLabel,
      driverName: driverName,
      busId: _stringId(m['bus_id']),
      routeId: _stringId(m['route_id']),
    );
  }

  /// PATCH arrive only: inactive + completed. Departure does not PATCH the assignment.
  Future<BackendResponse> patchArrive(String assignmentId) async {
    await OperatorSessionService.instance.loadFromPrefs();
    return _api.patch(
      '/api/bus-assignments/$assignmentId',
      body: {
        'assignment_status': 'inactive',
        'assignment_result': 'completed',
      },
      headers: _authHeaders(),
    );
  }

  /// Whether this device marked [assignmentId] as departed after a successful Depart call
  /// (server stays `pending` until Arrive; local flag selects Arrive vs Depart).
  Future<bool> hasLocalDeparted(String assignmentId) =>
      _localDepartedFlag(assignmentId);

  Future<void> markLocalDeparted(String assignmentId) =>
      _setLocalDeparted(assignmentId, true);

  Future<void> clearLocalDeparted(String assignmentId) =>
      _setLocalDeparted(assignmentId, false);
}
