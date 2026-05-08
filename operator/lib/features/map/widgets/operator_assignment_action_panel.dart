import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/operator_assignment_live_sync_service.dart';
import '../../../core/services/operator_bus_assignment_service.dart';
import '../../../core/services/operator_session_service.dart';
import '../../../core/services/operator_terminal_log_service.dart';

enum _TripAction { depart, arrive, completedNone }

_TripAction _resolveAction(
  OperatorBusAssignmentSnapshot s,
  bool localDeparted,
) {
  final st = s.assignmentStatus;
  final res = s.assignmentResult;

  if (st == 'active' && res == 'pending' && !localDeparted) {
    return _TripAction.depart;
  }
  if (st == 'active' && res == 'pending' && localDeparted) {
    return _TripAction.arrive;
  }
  if (st == 'inactive' && res == 'completed') {
    return _TripAction.completedNone;
  }
  if (res == 'cancelled') {
    return _TripAction.completedNone;
  }
  if (st == 'inactive') {
    return _TripAction.completedNone;
  }
  if (st == 'active' && res == 'completed') {
    return _TripAction.completedNone;
  }
  return _TripAction.completedNone;
}

/// One dynamic Depart / Arrive / Completed control for a single bus assignment.
class OperatorAssignmentActionButton extends StatefulWidget {
  const OperatorAssignmentActionButton({
    super.key,
    required this.assignment,
    this.compact = false,
    this.onStateChanged,
  });

  final OperatorBusAssignmentSnapshot assignment;
  final bool compact;
  final VoidCallback? onStateChanged;

  @override
  State<OperatorAssignmentActionButton> createState() =>
      _OperatorAssignmentActionButtonState();
}

class _OperatorAssignmentActionButtonState
    extends State<OperatorAssignmentActionButton> {
  bool _localDeparted = false;
  bool _loadingPrefs = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadLocal();
  }

  @override
  void didUpdateWidget(covariant OperatorAssignmentActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assignment.id != widget.assignment.id) {
      _loadLocal();
    }
  }

  Future<void> _loadLocal() async {
    final v = await OperatorBusAssignmentService.instance
        .hasLocalDeparted(widget.assignment.id);
    if (!mounted) return;
    setState(() {
      _localDeparted = v;
      _loadingPrefs = false;
    });
  }

  Future<void> _onPressed(_TripAction action) async {
    if (_submitting) return;
    final svc = OperatorBusAssignmentService.instance;
    final id = widget.assignment.id;
    final s = widget.assignment;

    if (action == _TripAction.depart) {
      if (s.assignmentStatus != 'active' || s.assignmentResult != 'pending') {
        return;
      }
      if (_localDeparted) return;
    }
    if (action == _TripAction.arrive) {
      if (s.assignmentStatus != 'active') return;
      if (s.assignmentResult != 'pending' || !_localDeparted) return;
    }

    setState(() => _submitting = true);

    final busId = s.busId;
    final routeId = s.routeId;

    if (action == _TripAction.depart) {
      // Departure: terminal log only — do not PATCH assignment (already active + pending).
      if (busId == null ||
          busId.isEmpty ||
          routeId == null ||
          routeId.isEmpty) {
        if (mounted) {
          setState(() => _submitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Cannot report departure: missing bus or route on assignment.',
              ),
            ),
          );
        }
        return;
      }

      final logRes = await OperatorTerminalLogService.instance.reportDeparture(
        busAssignmentId: id,
        busId: busId,
        routeId: routeId,
      );
      if (!mounted) return;

      if (logRes.success) {
        await svc.markLocalDeparted(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Departure reported.')),
          );
          setState(() {
            _localDeparted = true;
            _submitting = false;
          });
        }
        widget.onStateChanged?.call();
      } else {
        final err = logRes.error ??
            logRes.data?['message'] as String? ??
            'HTTP ${logRes.statusCode}';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Departure report failed: $err'),
              backgroundColor: Colors.red.shade800,
            ),
          );
          setState(() => _submitting = false);
        }
      }
      return;
    }

    // Arrive: terminal log (arrival) then close assignment — no redundant pending PATCH.
    if (busId == null ||
        busId.isEmpty ||
        routeId == null ||
        routeId.isEmpty) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot report arrival: missing bus or route on assignment.',
            ),
          ),
        );
      }
      return;
    }

    final arrivalLog = await OperatorTerminalLogService.instance.reportArrival(
      busAssignmentId: id,
      busId: busId,
      routeId: routeId,
    );
    if (!mounted) return;

    if (!arrivalLog.success) {
      final err = arrivalLog.error ??
          arrivalLog.data?['message'] as String? ??
          'HTTP ${arrivalLog.statusCode}';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Arrival log failed: $err'),
            backgroundColor: Colors.orange.shade900,
          ),
        );
        setState(() => _submitting = false);
      }
      return;
    }

    final patchRes = await svc.patchArrive(id);
    if (!mounted) return;

    if (patchRes.success) {
      await svc.clearLocalDeparted(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arrival reported and trip completed.')),
        );
        setState(() {
          _localDeparted = false;
          _submitting = false;
        });
      }
      widget.onStateChanged?.call();
    } else {
      final msg = patchRes.error ?? 'Could not complete assignment';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Arrival logged, but closing assignment failed: $msg',
            ),
            backgroundColor: Colors.orange.shade900,
          ),
        );
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPrefs) {
      return SizedBox(
        height: widget.compact ? 36 : 44,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final action = _resolveAction(widget.assignment, _localDeparted);
    final label = switch (action) {
      _TripAction.depart => 'Depart',
      _TripAction.arrive => 'Arrive',
      _TripAction.completedNone => 'Completed',
    };
    final disabled = action == _TripAction.completedNone || _submitting;

    final child = _submitting
        ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          )
        : Text(label);

    if (widget.compact) {
      return FilledButton(
        onPressed: disabled ? null : () => _onPressed(action),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: child,
      );
    }

    return FilledButton(
      onPressed: disabled ? null : () => _onPressed(action),
      child: child,
    );
  }
}

/// Loads the signed-in operator’s assignments and shows one row per assignment
/// (route/bus summary + [OperatorAssignmentActionButton]).
class OperatorAssignmentActionPanel extends StatefulWidget {
  const OperatorAssignmentActionPanel({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  State<OperatorAssignmentActionPanel> createState() =>
      _OperatorAssignmentActionPanelState();
}

class _OperatorAssignmentActionPanelState extends State<OperatorAssignmentActionPanel>
    with WidgetsBindingObserver {
  bool _loading = true;
  List<OperatorBusAssignmentSnapshot> _items = const [];
  String? _error;
  StreamSubscription<void>? _liveSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    OperatorAssignmentLiveSyncService.instance.acquire();
    _liveSub = OperatorAssignmentLiveSyncService.instance.refreshes.listen((_) {
      if (!mounted) return;
      _refresh(showLoading: false);
    });
    _refresh(showLoading: true);
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    OperatorAssignmentLiveSyncService.instance.release();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh(showLoading: false);
    }
  }

  /// [showLoading] true only on first load or manual refresh — background polls stay smooth.
  Future<void> _refresh({bool showLoading = true}) async {
    await OperatorSessionService.instance.loadFromPrefs();
    if (!OperatorSessionService.instance.hasValidJwt) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = const [];
        _error = null;
      });
      return;
    }

    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final result =
          await OperatorBusAssignmentService.instance.fetchMyAssignments();
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _loading = false;
        _error = result.errorHint;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      );
    }

    if (!OperatorSessionService.instance.hasValidJwt) {
      return const SizedBox.shrink();
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Assignments: $_error',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'No bus assignment yet.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.25,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Refresh now',
                  onPressed: () => _refresh(showLoading: true),
                  icon: Icon(Icons.refresh, size: 22, color: theme.colorScheme.primary),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Bus assignment',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Refresh',
              onPressed: () => _refresh(showLoading: false),
              icon: Icon(Icons.refresh, size: 20, color: theme.colorScheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final a in _items) ...[
          _AssignmentCard(
            assignment: a,
            compact: widget.compact,
            onStateChanged: () => _refresh(showLoading: false),
          ),
          if (a != _items.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.assignment,
    required this.compact,
    required this.onStateChanged,
  });

  final OperatorBusAssignmentSnapshot assignment;
  final bool compact;
  final VoidCallback onStateChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final route = assignment.routeName ?? 'Route';
    final bus = assignment.busLabel ?? 'Bus';
    final driver = assignment.driverName?.trim();
    final driverLine =
        driver != null && driver.isNotEmpty ? 'Driver: $driver' : null;

    if (compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  bus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (driverLine != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    driverLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          OperatorAssignmentActionButton(
            assignment: assignment,
            compact: true,
            onStateChanged: onStateChanged,
          ),
        ],
      );
    }

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bus,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (driverLine != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      driverLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            OperatorAssignmentActionButton(
              assignment: assignment,
              onStateChanged: onStateChanged,
            ),
          ],
        ),
      ),
    );
  }
}
