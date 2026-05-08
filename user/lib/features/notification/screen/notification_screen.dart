import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpException, SocketException;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/services/driver_status_read_service.dart';
import '../../../core/services/notification_badge_service.dart';
import '../../../core/services/notification_live_sync_service.dart';
import '../../../core/services/system_inbox_notification_service.dart';
import '../../../core/services/nearby_operators_service.dart';
import '../../../core/services/operator_route_options_service.dart';
import '../../../core/services/subscription_ids_service.dart';
import '../../../core/themes/validation_theme.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _MergedNotificationRow {
  _MergedNotificationRow._({
    required this.sortTime,
    this.inboxItem,
    this.followedRouteCode,
    this.freeRide,
    this.followedCatalogFreeRouteCode,
    this.liveBusFollowedRouteCode,
    this.freeRidePromoIsOnFollowedRoute = true,
  });

  factory _MergedNotificationRow.fromInbox(
    Map<String, dynamic> item,
    DateTime sortTime,
  ) {
    return _MergedNotificationRow._(
      sortTime: sortTime,
      inboxItem: item,
    );
  }

  factory _MergedNotificationRow.fromFollowedFreeRide({
    required String routeCode,
    required FreeRideStatusSnapshot freeRide,
    bool promoIsOnFollowedRoute = true,
  }) {
    return _MergedNotificationRow._(
      sortTime: freeRide.startTime ??
          freeRide.updatedAt ??
          DateTime.now(),
      followedRouteCode: routeCode,
      freeRide: freeRide,
      freeRidePromoIsOnFollowedRoute: promoIsOnFollowedRoute,
    );
  }

  factory _MergedNotificationRow.fromFollowedCatalogFreeLine({
    required String routeCode,
    required DateTime sortTime,
  }) {
    return _MergedNotificationRow._(
      sortTime: sortTime,
      followedCatalogFreeRouteCode: routeCode,
    );
  }

  factory _MergedNotificationRow.fromLiveBusOnFollowedRoute({
    required String routeCode,
    required DateTime sortTime,
  }) {
    return _MergedNotificationRow._(
      sortTime: sortTime,
      liveBusFollowedRouteCode: routeCode,
    );
  }

  final DateTime sortTime;
  final Map<String, dynamic>? inboxItem;
  final String? followedRouteCode;
  final FreeRideStatusSnapshot? freeRide;
  /// Mongo free-ride line the user follows (no live Firestore promo yet).
  final String? followedCatalogFreeRouteCode;
  /// Followed route with a live bus in [operator_locations].
  final String? liveBusFollowedRouteCode;

  /// False when this row is an operator promo on a route the user does not follow.
  final bool freeRidePromoIsOnFollowedRoute;

  bool get isFollowedFreeRide =>
      freeRide != null &&
      freeRide!.isActive &&
      followedRouteCode != null;

  bool get isFollowedCatalogFreeLine =>
      followedCatalogFreeRouteCode != null &&
      followedCatalogFreeRouteCode!.isNotEmpty;

  bool get isLiveBusOnFollowedRoute =>
      liveBusFollowedRouteCode != null &&
      liveBusFollowedRouteCode!.isNotEmpty;
}

class _NotificationScreenState extends State<NotificationScreen> {
  static const String _notificationsInboxApiBase =
      'https://pasa-hero-server.vercel.app/api/notifications/inbox';

  /// Keep the Older section short so the inbox stays scannable.
  static const int _maxOlderNotifications = 10;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _inboxItems = const [];

  /// Followed route code (uppercase) → latest free ride snapshot from Firestore.
  final Map<String, FreeRideStatusSnapshot?> _freeRideByRouteCode = {};

  /// Full [driver_status] listener (doc id may differ from subscription route code).
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _driverStatusSub;
  StreamSubscription<void>? _notificationLiveSub;

  Set<String> _followedRouteCodesUpper = {};
  Set<String> _catalogFreeRouteCodesUpper = {};
  Set<String> _followedRoutesWithLiveBus = {};

  final OperatorRouteOptionsService _routeOptionsService =
      OperatorRouteOptionsService();
  final NearbyOperatorsService _nearbyOperatorsService =
      NearbyOperatorsService();

  int _lastInboxUnread = 0;
  String? _activeInboxUserId;
  Timer? _liveInboxDebounce;

  @override
  void initState() {
    super.initState();
    NotificationBadgeService.instance.setOnTabOpenedHandler(_onNotificationTabOpened);
    _notificationLiveSub = NotificationLiveSyncService.instance.refreshes.listen(
      (_) {
        if (!mounted) return;
        _liveInboxDebounce?.cancel();
        _liveInboxDebounce = Timer(const Duration(milliseconds: 450), () {
          if (!mounted) return;
          unawaited(_loadInbox(showLoading: false));
        });
      },
    );
    _loadInbox();
  }

  @override
  void dispose() {
    NotificationBadgeService.instance.setOnTabOpenedHandler(null);
    _liveInboxDebounce?.cancel();
    _notificationLiveSub?.cancel();
    _driverStatusSub?.cancel();
    super.dispose();
  }

  void _onNotificationTabOpened() {
    unawaited(_applyViewedNotifications());
  }

  /// Parses API read flag from [is_read] / [isRead] / numeric / string.
  static bool? _parseReadFlag(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().trim().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0' || s.isEmpty) return false;
    return null;
  }

  static bool _inboxItemIsRead(Map<String, dynamic> item) {
    final flag =
        _parseReadFlag(item['is_read']) ?? _parseReadFlag(item['isRead']);
    return flag == true;
  }

  static String? _inboxRowId(Map<String, dynamic> item) {
    final raw = item['_id'];
    if (raw != null) {
      if (raw is Map) {
        final oid = raw[r'$oid'];
        if (oid != null) {
          final s = oid.toString().trim();
          if (s.isNotEmpty) return s;
        }
      } else {
        final s = raw.toString().trim();
        if (s.isNotEmpty && s != 'null') return s;
      }
    }
    final id = item['id']?.toString().trim();
    if (id != null && id.isNotEmpty) return id;
    return null;
  }

  Future<void> _applyViewedNotifications() async {
    await NotificationBadgeService.instance.markNotificationsTabOpened();
    _lastInboxUnread = 0;

    final userId = _activeInboxUserId;
    if (userId == null || userId.isEmpty) return;

    final ids = <String>[];
    for (final item in _inboxItems) {
      if (_inboxItemIsRead(item)) continue;
      final id = _inboxRowId(item);
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    if (ids.isEmpty) return;

    try {
      final uri = Uri.parse(
        'https://pasa-hero-server.vercel.app/api/user-notifications/read',
      );
      final response = await http
          .patch(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'user_id': userId,
              'user_notification_ids': ids,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          mounted) {
        setState(() {
          _inboxItems = _inboxItems.map((item) {
            if (_inboxItemIsRead(item)) return item;
            final copy = Map<String, dynamic>.from(item);
            copy['is_read'] = true;
            return copy;
          }).toList();
        });
      }
    } catch (_) {}
  }

  void _syncNavBadge() {
    NotificationBadgeService.instance.setServerUnreadCount(_lastInboxUnread);
    NotificationBadgeService.instance.setFreeRideMap(_freeRideByRouteCode);
  }

  void _cancelFreeRideSubscriptions() {
    _driverStatusSub?.cancel();
    _driverStatusSub = null;
    _freeRideByRouteCode.clear();
  }

  void _attachFreeRideListeners(Set<String> routeCodesUpper) {
    _cancelFreeRideSubscriptions();
    final upper = routeCodesUpper
        .map((c) => c.trim().toUpperCase())
        .where((c) => c.isNotEmpty)
        .toSet();

    _driverStatusSub = FirebaseFirestore.instance
        .collection(driverStatusCollection)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;
        final global = DriverStatusReadService.instance
            .mapAllActiveFreeRidePromos(snapshot);
        final followed = upper.isEmpty
            ? <String, FreeRideStatusSnapshot?>{}
            : DriverStatusReadService.instance
                .mapActiveFreeRidesForFollowedRoutes(snapshot, upper);

        final merged = Map<String, FreeRideStatusSnapshot?>.from(global);
        for (final e in followed.entries) {
          merged[e.key] = e.value;
        }

        setState(() {
          _freeRideByRouteCode
            ..clear()
            ..addAll(merged);
        });
        _syncNavBadge();
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {});
        _syncNavBadge();
      },
    );
  }

  Future<void> _loadInbox({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          if (showLoading) _error = 'Please sign in first.';
        });
        _cancelFreeRideSubscriptions();
        _followedRouteCodesUpper = {};
        _catalogFreeRouteCodesUpper = {};
        _followedRoutesWithLiveBus = {};
        _lastInboxUnread = 0;
        _activeInboxUserId = null;
        NotificationBadgeService.instance.setServerUnreadCount(0);
        NotificationBadgeService.instance.setFreeRideMap({});
        SystemInboxNotificationService.instance.resetForLogout();
        return;
      }

      final routeFuture = SubscriptionIdsService.fetchRouteIdByCodeMap();
      final backendFuture = SubscriptionIdsService.backendUserIdForFirebaseUid(
        firebaseUser.uid,
        email: firebaseUser.email,
      );
      final catalogFuture = _routeOptionsService.fetchAvailableRoutes();
      final routeIdByCode = await routeFuture;
      final backendUserId = await backendFuture;

      final idsToTry = <String>[];
      if (backendUserId != null && backendUserId.trim().isNotEmpty) {
        idsToTry.add(backendUserId.trim());
      }

      final followedRouteCodes =
          await SubscriptionIdsService.fetchSubscribedRouteCodesMerged(
        backendMongoUserId: backendUserId,
        routeIdByCode: routeIdByCode,
      );
      final catalog = await catalogFuture;
      final catalogFree = <String>{};
      for (final o in catalog) {
        if (!o.isFreeRideRoute) continue;
        final raw = o.code.trim();
        if (raw.isEmpty) continue;
        catalogFree.add(raw.toUpperCase());
        final alnum = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
        if (alnum.isNotEmpty) {
          catalogFree.add(alnum);
          if (alnum.startsWith('ROUTE') && alnum.length > 5) {
            catalogFree.add(alnum.substring(5));
          }
        }
      }
      final followedUpper = followedRouteCodes;

      final liveOnFollowed =
          await _nearbyOperatorsService.followedRoutesWithLiveOnlineBus(
        followedUpper,
      );

      if (!mounted) return;
      _attachFreeRideListeners(followedUpper);
      setState(() {
        _followedRouteCodesUpper = followedUpper;
        _catalogFreeRouteCodesUpper = catalogFree;
        _followedRoutesWithLiveBus = liveOnFollowed;
      });
      _syncNavBadge();

      List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
      String? lastError;
      var serverUnread = 0;
      String? successInboxUserId;
      // Sequential inbox requests avoid burst connections that trigger
      // "Software caused connection abort" on some mobile networks.
      for (final id in idsToTry) {
        final result = await _fetchInboxByUserId(id);
        if (result.error != null) {
          lastError = result.error;
          continue;
        }
        items = result.items;
        serverUnread = result.unreadCount;
        successInboxUserId = id;
        break;
      }

      if (!mounted) return;
      _lastInboxUnread = serverUnread;
      _activeInboxUserId = successInboxUserId;
      setState(() {
        _inboxItems = items;
        _loading = false;
        if (showLoading &&
            lastError != null &&
            items.isEmpty &&
            followedUpper.isEmpty) {
          _error = lastError;
        } else if (showLoading) {
          _error = null;
        }
      });

      _syncNavBadge();
      unawaited(
        SystemInboxNotificationService.instance
            .onInboxReloaded(List<Map<String, dynamic>>.from(items)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (showLoading) {
          _error = e.toString().replaceFirst('Exception: ', '');
        }
      });
    }
  }

  bool _isRetryableInboxNetworkError(Object e) {
    if (e is TimeoutException) return true;
    if (e is SocketException) return true;
    if (e is HttpException) return true;
    if (e is http.ClientException) return true;
    final m = e.toString().toLowerCase();
    return m.contains('connection abort') ||
        m.contains('connection closed') ||
        m.contains('connection reset') ||
        m.contains('broken pipe') ||
        m.contains('socketexception') ||
        m.contains('failed host lookup') ||
        m.contains('network is unreachable');
  }

  String _userVisibleInboxError(Object e) {
    if (e is TimeoutException) {
      return 'Request timed out. Check your network and tap Retry.';
    }
    final m = e.toString().toLowerCase();
    if (m.contains('connection abort') ||
        m.contains('connection closed') ||
        m.contains('clientexception') ||
        m.contains('socketexception') ||
        m.contains('broken pipe')) {
      return 'Connection interrupted. Check your network and tap Retry.';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  Future<_InboxFetchResult> _fetchInboxByUserId(String userId) async {
    if (userId.trim().isEmpty) {
      return const _InboxFetchResult(
        items: [],
        error: 'Missing user id for inbox',
      );
    }
    final uri = Uri.parse(
      '$_notificationsInboxApiBase/${Uri.encodeComponent(userId.trim())}',
    );
    const timeout = Duration(seconds: 22);
    Object? lastError;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        if (attempt > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 600));
        }
        final response = await http
            .get(
              uri,
              headers: const {'Accept': 'application/json'},
            )
            .timeout(timeout);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          return _InboxFetchResult(
            items: const [],
            error: 'Failed to load notifications (${response.statusCode})',
          );
        }

        final decoded = jsonDecode(response.body);
        final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
        final inbox = data is Map<String, dynamic> ? data['inbox'] : null;
        final items = <Map<String, dynamic>>[];
        if (inbox is List) {
          for (final item in inbox) {
            if (item is Map<String, dynamic>) {
              items.add(item);
            }
          }
        }
        var unreadCount = 0;
        final counts = data is Map<String, dynamic> ? data['counts'] : null;
        if (counts is Map<String, dynamic>) {
          final u = counts['unread'];
          if (u is num) unreadCount = u.toInt();
        }
        return _InboxFetchResult(items: items, unreadCount: unreadCount);
      } catch (e) {
        lastError = e;
        if (attempt == 0 && _isRetryableInboxNetworkError(e)) {
          continue;
        }
        break;
      }
    }

    return _InboxFetchResult(
      items: const [],
      error: _userVisibleInboxError(lastError ?? 'Unknown error'),
    );
  }

  bool _catalogFreeMatchesFollowed(String followedCode) {
    for (final free in _catalogFreeRouteCodesUpper) {
      if (NearbyOperatorsService.routesLooselySameLine(followedCode, free)) {
        return true;
      }
    }
    return false;
  }

  bool _promoRouteMatchesFollowed(String promoCode) {
    for (final f in _followedRouteCodesUpper) {
      if (NearbyOperatorsService.routesLooselySameLine(f, promoCode)) {
        return true;
      }
    }
    return false;
  }

  String _freeRideSignature(FreeRideStatusSnapshot s) {
    final e = s.endTime?.millisecondsSinceEpoch ?? 0;
    final st = s.startTime?.millisecondsSinceEpoch ?? 0;
    final u = s.updatedAt?.millisecondsSinceEpoch ?? 0;
    final o = s.operatorId ?? '';
    return '$o|$e|$st|$u';
  }

  bool _isInboxUnread(Map<String, dynamic> item) {
    final flag =
        _parseReadFlag(item['is_read']) ?? _parseReadFlag(item['isRead']);
    if (flag == true) return false;
    if (flag == false) return true;
    // Unknown / missing flag: do not assume unread (avoids stale rows stuck in "New").
    return false;
  }

  /// New = unread inbox + active timed free ride on followed routes.
  /// Older = read inbox + route context cards (catalog free line, live bus) that are not discrete events.
  ({List<_MergedNotificationRow> fresh, List<_MergedNotificationRow> older})
      _partitionNewAndOlder() {
    final fresh = <_MergedNotificationRow>[];
    final older = <_MergedNotificationRow>[];

    for (final item in _inboxItems) {
      final t = _resolveCreatedAt(item) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final row = _MergedNotificationRow.fromInbox(item, t);
      if (_isInboxUnread(item)) {
        fresh.add(row);
      } else {
        older.add(row);
      }
    }

    final seenPromoSignatures = <String>{};
    for (final e in _freeRideByRouteCode.entries) {
      final snap = e.value;
      if (snap == null || !snap.isActive) continue;
      final code = e.key;
      if (code.isEmpty) continue;
      if (!seenPromoSignatures.add(_freeRideSignature(snap))) continue;
      fresh.add(
        _MergedNotificationRow.fromFollowedFreeRide(
          routeCode: code,
          freeRide: snap,
          promoIsOnFollowedRoute: _promoRouteMatchesFollowed(code),
        ),
      );
    }

    for (final code in _followedRouteCodesUpper) {
      if (code.isEmpty) continue;
      final promo = _freeRideByRouteCode[code];
      if (promo != null && promo.isActive) continue;

      if (_followedRoutesWithLiveBus.contains(code)) {
        older.add(
          _MergedNotificationRow.fromLiveBusOnFollowedRoute(
            routeCode: code,
            sortTime: DateTime.now(),
          ),
        );
        continue;
      }

      if (_catalogFreeMatchesFollowed(code)) {
        older.add(
          _MergedNotificationRow.fromFollowedCatalogFreeLine(
            routeCode: code,
            sortTime: DateTime.now().subtract(const Duration(minutes: 1)),
          ),
        );
      }
    }

    fresh.sort((a, b) => b.sortTime.compareTo(a.sortTime));
    older.sort((a, b) => b.sortTime.compareTo(a.sortTime));
    return (fresh: fresh, older: older);
  }

  String _resolveTitle(Map<String, dynamic> item) {
    final notification = item['notification_id'];
    if (notification is Map<String, dynamic>) {
      final title = notification['title']?.toString().trim();
      if (title != null && title.isNotEmpty) {
        return title;
      }
    }
    return 'Notification';
  }

  String _resolveDescription(Map<String, dynamic> item) {
    final notification = item['notification_id'];
    if (notification is Map<String, dynamic>) {
      final message = notification['message']?.toString().trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
    return 'No details available.';
  }

  DateTime? _resolveCreatedAt(Map<String, dynamic> item) {
    final notification = item['notification_id'];
    final raw = (notification is Map<String, dynamic>)
        ? notification['createdAt'] ?? item['createdAt']
        : item['createdAt'];
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  String _freeRideDescription(
    FreeRideStatusSnapshot snap,
    String routeCode, {
    required bool onFollowedRoute,
  }) {
    final until = snap.endTime;
    String base;
    if (until != null) {
      final local = until.toLocal();
      final now = DateTime.now();
      final sameDay = local.year == now.year &&
          local.month == now.month &&
          local.day == now.day;
      final datePart =
          sameDay ? 'today' : '${local.month}/${local.day}/${local.year}';
      final hm =
          '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      base = 'Free ride is active on route $routeCode until $hm on $datePart. '
          'Board while the promo is on.';
    } else {
      base = 'A free ride is active right now on route $routeCode.';
    }
    if (onFollowedRoute) return base;
    return '$base Follow this route under Routes to pin these updates.';
  }

  Color _statusColorForInbox(Map<String, dynamic> item) {
    final notification = item['notification_id'];
    if (notification is! Map<String, dynamic>) {
      return ValidationTheme.primaryBlue;
    }
    final type = notification['notification_type']?.toString().toLowerCase();
    switch (type) {
      case 'delay':
      case 'full':
      case 'skipped_stop':
        return ValidationTheme.errorRed;
      case 'arrival_reported':
      case 'arrival_confirmed':
      case 'departure_reported':
      case 'departure_confirmed':
        return ValidationTheme.successGreen;
      default:
        return ValidationTheme.primaryBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final partitioned = _partitionNewAndOlder();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: ValidationTheme.gradientDecoration,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.05,
                  vertical: 20,
                ),
                child: const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: ValidationTheme.textLight,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                  child: _buildBody(partitioned),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    ({List<_MergedNotificationRow> fresh, List<_MergedNotificationRow> older})
        partitioned,
  ) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ValidationTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadInbox,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final fresh = partitioned.fresh;
    final olderAll = partitioned.older;
    final olderTruncated = olderAll.length > _maxOlderNotifications;
    final older = olderTruncated
        ? olderAll.sublist(0, _maxOlderNotifications)
        : olderAll;
    if (fresh.isEmpty && older.isEmpty) {
      return const Center(
        child: Text(
          'No notifications yet.',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: ValidationTheme.textPrimary,
          ),
        ),
      );
    }

    final children = <Widget>[];
    if (fresh.isNotEmpty) {
      children.add(_sectionHeader('New'));
      for (var i = 0; i < fresh.length; i++) {
        if (i > 0) children.add(const SizedBox(height: 12));
        children.add(_rowToCard(fresh[i], emphasizeNew: true));
      }
    }
    if (older.isNotEmpty) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 20));
      }
      children.add(_sectionHeader('Older'));
      for (var i = 0; i < older.length; i++) {
        if (i > 0) children.add(const SizedBox(height: 12));
        children.add(_rowToCard(older[i], emphasizeNew: false));
      }
      if (olderTruncated) {
        children.add(const SizedBox(height: 12));
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Showing $_maxOlderNotifications most recent older items.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: ValidationTheme.textPrimary.withOpacity(0.65),
              ),
            ),
          ),
        );
      }
    }

    return RefreshIndicator(
      color: ValidationTheme.textPrimary,
      onRefresh: _loadInbox,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: children,
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: ValidationTheme.textPrimary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _rowToCard(_MergedNotificationRow row, {required bool emphasizeNew}) {
    if (row.isFollowedFreeRide) {
      final snap = row.freeRide!;
      final code = row.followedRouteCode!;
      return _buildNotificationCard(
        title: row.freeRidePromoIsOnFollowedRoute
            ? 'Free ride — Route $code'
            : 'Free ride promo — Route $code',
        description: _freeRideDescription(
          snap,
          code,
          onFollowedRoute: row.freeRidePromoIsOnFollowedRoute,
        ),
        timestamp: _formatTimestamp(
          snap.startTime ?? snap.updatedAt ?? snap.endTime,
        ),
        statusColor: ValidationTheme.successGreen,
        emphasizeNew: emphasizeNew,
      );
    }
    if (row.isLiveBusOnFollowedRoute) {
      final code = row.liveBusFollowedRouteCode!;
      return _buildNotificationCard(
        title: 'Bus live on route you follow — $code',
        description:
            'A driver on route $code is online with a recent location. Open Near Me to see them on the map.',
        timestamp: 'Live',
        statusColor: ValidationTheme.successGreen,
        emphasizeNew: emphasizeNew,
      );
    }
    if (row.isFollowedCatalogFreeLine) {
      final code = row.followedCatalogFreeRouteCode!;
      return _buildNotificationCard(
        title: 'Free-ride route you follow — $code',
        description:
            'Route $code is a free-ride line. When an operator starts a promo, timing will show in a green card above. Open Near Me for live buses.',
        timestamp: '',
        statusColor: ValidationTheme.primaryBlue,
        emphasizeNew: emphasizeNew,
      );
    }
    final item = row.inboxItem;
    if (item != null) {
      return _buildNotificationCard(
        title: _resolveTitle(item),
        description: _resolveDescription(item),
        timestamp: _formatTimestamp(_resolveCreatedAt(item)),
        statusColor: _statusColorForInbox(item),
        emphasizeNew: emphasizeNew,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildNotificationCard({
    required String title,
    required String description,
    required String timestamp,
    required Color statusColor,
    bool emphasizeNew = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: emphasizeNew
            ? ValidationTheme.backgroundWhite
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: emphasizeNew
            ? Border.all(
                color: ValidationTheme.primaryBlue.withOpacity(0.35),
                width: 1,
              )
            : Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ValidationTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: ValidationTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  timestamp,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ValidationTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxFetchResult {
  const _InboxFetchResult({
    required this.items,
    this.unreadCount = 0,
    this.error,
  });

  final List<Map<String, dynamic>> items;
  final int unreadCount;
  final String? error;
}
