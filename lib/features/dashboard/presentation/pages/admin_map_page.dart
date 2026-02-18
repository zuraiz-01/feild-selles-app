import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_toast.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../../app/ui/theme_mode_toggle_button.dart';

class AdminMapPage extends StatefulWidget {
  const AdminMapPage({super.key});

  @override
  State<AdminMapPage> createState() => _AdminMapPageState();
}

class _AdminMapPageState extends State<AdminMapPage> {
  String? _selectedDsfId;

  void _ensureSelection(List<String> options) {
    if (options.isEmpty) return;
    if (_selectedDsfId != null && options.contains(_selectedDsfId)) {
      return;
    }
    final next = options.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _selectedDsfId = next);
    });
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  LatLng? _latLngFromMap(dynamic raw) {
    if (raw is! Map) return null;
    final lat = _toDouble(raw['lat'] ?? raw['latitude']);
    final lng = _toDouble(raw['lng'] ?? raw['longitude']);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  DateTime? _toDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  DateTime _activeSessionMoment(_ActiveSession session) {
    return session.updatedAt ??
        session.lastPointAt ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  @override
  Widget build(BuildContext context) {
    final sessions = FirebaseFirestore.instance
        .collection('locationSessions')
        .where('status', isEqualTo: 'active')
        .snapshots();
    final alerts = FirebaseFirestore.instance
        .collection('alerts')
        .orderBy('createdAt', descending: true)
        .limit(60)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Get.offAllNamed(AppRoutes.adminDashboard),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to dashboard',
        ),
        titleSpacing: 20,
        toolbarHeight: 70,
        title: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: AppTheme.warmSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.map_outlined, color: AppTheme.accent),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Tracking',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                SizedBox(height: 2),
                Text(
                  'Recent users and last activity',
                  style: TextStyle(color: AppTheme.mutedInk, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: const [ThemeModeToggleButton(), SizedBox(width: 8)],
      ),
      body: AppShell(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: sessions,
          builder: (context, sessionsSnap) {
            if (sessionsSnap.hasError) {
              return Center(child: Text(sessionsSnap.error.toString()));
            }
            if (!sessionsSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final activeByDsf = <String, _ActiveSession>{};
            for (final doc in sessionsSnap.data!.docs) {
              final data = doc.data();
              final dsfId = (data['dsfId'] as String?)?.trim();
              if (dsfId == null || dsfId.isEmpty) continue;
              final lastPoint = data['lastPoint'];
              activeByDsf[dsfId] = _ActiveSession(
                dutyId: doc.id,
                lastPoint: _latLngFromMap(lastPoint),
                lastPointAt: lastPoint is Map
                    ? _toDate(lastPoint['recordedAt'])
                    : null,
                updatedAt: _toDate(data['updatedAt']),
              );
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: alerts,
              builder: (context, alertsSnap) {
                if (alertsSnap.hasError) {
                  return Center(child: Text(alertsSnap.error.toString()));
                }
                if (!alertsSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('seedTsas')
                      .snapshots(),
                  builder: (context, tsaSnap) {
                    if (tsaSnap.hasError) {
                      return Center(child: Text(tsaSnap.error.toString()));
                    }
                    if (!tsaSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final tsaIds = tsaSnap.data!.docs
                        .map((doc) => doc.id.trim())
                        .where((id) => id.isNotEmpty)
                        .toSet();

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('dsfAccounts')
                          .snapshots(),
                      builder: (context, dsfSnap) {
                        if (dsfSnap.hasError) {
                          return Center(child: Text(dsfSnap.error.toString()));
                        }
                        if (!dsfSnap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final canonicalByDsfId = <String, String>{};
                        final displayNameByDsfId = <String, String>{};
                        for (final dsfDoc in dsfSnap.data!.docs) {
                          final data = dsfDoc.data();
                          final dsfAccountId = dsfDoc.id.trim();
                          final linkedTsaId =
                              (data['tsaId'] as String?)?.trim() ??
                              dsfAccountId;
                          if (!tsaIds.contains(linkedTsaId)) continue;
                          final uid = (data['uid'] as String?)?.trim();
                          final canonicalId = (uid != null && uid.isNotEmpty)
                              ? uid
                              : dsfAccountId;
                          if (canonicalId.isEmpty) continue;

                          if (dsfAccountId.isNotEmpty) {
                            canonicalByDsfId[dsfAccountId] = canonicalId;
                          }
                          canonicalByDsfId[canonicalId] = canonicalId;
                          if (uid != null && uid.isNotEmpty) {
                            canonicalByDsfId[uid] = canonicalId;
                          }

                          final dsfName = (data['name'] as String?)?.trim();
                          displayNameByDsfId[canonicalId] =
                              (dsfName != null && dsfName.isNotEmpty)
                              ? dsfName
                              : (dsfAccountId.isNotEmpty
                                    ? dsfAccountId
                                    : canonicalId);
                        }

                        final canonicalActiveByDsf = <String, _ActiveSession>{};
                        for (final entry in activeByDsf.entries) {
                          final canonicalId = canonicalByDsfId[entry.key];
                          if (canonicalId == null) continue;
                          final existing = canonicalActiveByDsf[canonicalId];
                          if (existing == null ||
                              _activeSessionMoment(
                                entry.value,
                              ).isAfter(_activeSessionMoment(existing))) {
                            canonicalActiveByDsf[canonicalId] = entry.value;
                          }
                        }

                        final recentByDsf = <String, _RecentUserActivity>{};
                        for (final doc in alertsSnap.data!.docs) {
                          final data = doc.data();
                          final dsfId = (data['dsfId'] as String?)?.trim();
                          if (dsfId == null || dsfId.isEmpty) continue;
                          final canonicalId = canonicalByDsfId[dsfId];
                          if (canonicalId == null) continue;
                          if (recentByDsf.containsKey(canonicalId)) continue;
                          recentByDsf[canonicalId] = _RecentUserActivity(
                            dsfId: canonicalId,
                            type: (data['type'] as String?)?.trim(),
                            createdAt: _toDate(data['createdAt']),
                            shopTitle: (data['shopTitle'] as String?)?.trim(),
                            locationLabel: (data['locationLabel'] as String?)
                                ?.trim(),
                            distanceMeters: (data['distanceMeters'] as num?)
                                ?.toDouble(),
                            missedShops: (data['missedShops'] as num?)?.toInt(),
                            point: _latLngFromMap({
                              'lat': data['lat'],
                              'lng': data['lng'],
                            }),
                          );
                        }

                        final optionSet = <String>{};
                        optionSet.addAll(recentByDsf.keys);
                        optionSet.addAll(canonicalActiveByDsf.keys);
                        final options = optionSet.toList()
                          ..sort((a, b) {
                            final aName = (displayNameByDsfId[a] ?? a)
                                .toLowerCase();
                            final bName = (displayNameByDsfId[b] ?? b)
                                .toLowerCase();
                            final byName = aName.compareTo(bName);
                            if (byName != 0) return byName;
                            return a.compareTo(b);
                          });

                        if (options.isEmpty) {
                          return const Center(
                            child: Text('No activity for existing DSFs yet.'),
                          );
                        }

                        _ensureSelection(options);
                        final selectedId = _selectedDsfId ?? options.first;
                        final active = canonicalActiveByDsf[selectedId];
                        final recent = recentByDsf[selectedId];
                        final selectedName =
                            displayNameByDsfId[selectedId] ?? selectedId;
                        final inactiveCount =
                            (options.length - canonicalActiveByDsf.length)
                                .clamp(0, options.length);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        height: 42,
                                        width: 42,
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentSoft,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.person_pin_circle_outlined,
                                          color: AppTheme.accent,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Live Users',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.ink,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Pick a user to inspect map, alerts, and actions.',
                                              style: TextStyle(
                                                color: AppTheme.mutedInk,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _TopStatChip(
                                        icon: Icons.route_outlined,
                                        label: 'Active',
                                        value: '${activeByDsf.length}',
                                      ),
                                      _TopStatChip(
                                        icon:
                                            Icons.notifications_active_outlined,
                                        label: 'Alerts',
                                        value: '${recentByDsf.length}',
                                      ),
                                      _TopStatChip(
                                        icon: Icons.people_outline,
                                        label: 'Idle',
                                        value: '$inactiveCount',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 98,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: options.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 10),
                                      itemBuilder: (context, index) {
                                        final dsfId = options[index];
                                        return _UserPickerChip(
                                          key: ValueKey('user-chip-$dsfId'),
                                          name:
                                              displayNameByDsfId[dsfId] ??
                                              dsfId,
                                          subtitle:
                                              recentByDsf[dsfId]?.title ??
                                              'No recent alert',
                                          isActive: canonicalActiveByDsf
                                              .containsKey(dsfId),
                                          selected: dsfId == selectedId,
                                          onTap: () {
                                            setState(
                                              () => _selectedDsfId = dsfId,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _SelectedUserView(
                                dsfId: selectedId,
                                displayName: selectedName,
                                active: active,
                                recent: recent,
                                pointFromMap: _latLngFromMap,
                                dateFromRaw: _toDate,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _TopStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TopStatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 94),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x16000000)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.sky),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$label: $value',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppTheme.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserPickerChip extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool isActive;
  final bool selected;
  final VoidCallback onTap;

  const _UserPickerChip({
    super.key,
    required this.name,
    required this.subtitle,
    required this.isActive,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppTheme.accent : const Color(0x18000000);
    final bgColor = selected ? AppTheme.accentSoft : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          width: 240,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.accentSoft : AppTheme.skySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isActive ? 'LIVE' : 'IDLE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isActive ? AppTheme.accent : AppTheme.mutedInk,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.mutedInk, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedUserView extends StatelessWidget {
  final String dsfId;
  final String displayName;
  final _ActiveSession? active;
  final _RecentUserActivity? recent;
  final LatLng? Function(dynamic raw) pointFromMap;
  final DateTime? Function(dynamic raw) dateFromRaw;

  static final Map<String, String> _lastVisitToastByDsf = <String, String>{};
  static final Map<String, String> _lastPointToastByDsf = <String, String>{};
  static final Map<String, DateTime> _lastPointToastAtByDsf =
      <String, DateTime>{};

  const _SelectedUserView({
    required this.dsfId,
    required this.displayName,
    required this.active,
    required this.recent,
    required this.pointFromMap,
    required this.dateFromRaw,
  });

  String _two(int value) => value.toString().padLeft(2, '0');

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    final local = dt.toLocal();
    return '${local.year}-${_two(local.month)}-${_two(local.day)} ${_two(local.hour)}:${_two(local.minute)}';
  }

  String _formatSince(DateTime? dt) {
    if (dt == null) return 'N/A';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatDateWithSince(DateTime? dt) {
    if (dt == null) return 'N/A';
    return '${_formatDate(dt)} - ${_formatSince(dt)}';
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  Stream<List<LatLng>> _trackingPointsStream(String dutyId) {
    return FirebaseFirestore.instance
        .collection('locationSessions')
        .doc(dutyId)
        .collection('points')
        .orderBy('recordedAt', descending: false)
        .limit(1200)
        .snapshots()
        .map((snap) {
          final points = <LatLng>[];
          for (final doc in snap.docs) {
            final data = doc.data();
            final lat = _toDouble(data['lat']);
            final lng = _toDouble(data['lng']);
            if (lat == null || lng == null) continue;
            points.add(LatLng(lat, lng));
          }
          return points;
        });
  }

  void _emitRealtimeToasts({
    required String displayName,
    required DateTime? visitSubmittedAt,
    required String visitTitle,
    required DateTime? pointAt,
    required LatLng? point,
  }) {
    if (visitSubmittedAt != null) {
      final visitKey = visitSubmittedAt.toUtc().toIso8601String();
      final oldVisitKey = _lastVisitToastByDsf[dsfId];
      if (oldVisitKey == null) {
        _lastVisitToastByDsf[dsfId] = visitKey;
      } else if (oldVisitKey != visitKey) {
        _lastVisitToastByDsf[dsfId] = visitKey;
        AppToast.success(
          'Shop visit updated',
          message: '$displayName: $visitTitle',
        );
      }
    }

    if (point != null && pointAt != null) {
      final pointKey = pointAt.toUtc().toIso8601String();
      final oldPointKey = _lastPointToastByDsf[dsfId];
      if (oldPointKey == null) {
        _lastPointToastByDsf[dsfId] = pointKey;
        return;
      }
      if (oldPointKey == pointKey) return;

      final now = DateTime.now();
      final lastToastAt = _lastPointToastAtByDsf[dsfId];
      if (lastToastAt == null || now.difference(lastToastAt).inSeconds >= 45) {
        _lastPointToastByDsf[dsfId] = pointKey;
        _lastPointToastAtByDsf[dsfId] = now;
        AppToast.info(
          'Live location updated',
          message:
              '$displayName: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
        );
      } else {
        _lastPointToastByDsf[dsfId] = pointKey;
      }
    }
  }

  Widget _buildResponsivePanel({
    required BuildContext context,
    required Widget summaryCard,
    required Widget mapCard,
    required Widget activityCard,
    required Widget coverageCard,
    required Widget actionsCard,
    Widget? logoutCard,
  }) {
    final isWide = kIsWeb && MediaQuery.of(context).size.width >= 1120;
    if (!isWide) {
      return ListView(
        children: [
          summaryCard,
          const SizedBox(height: 12),
          mapCard,
          const SizedBox(height: 12),
          activityCard,
          const SizedBox(height: 12),
          coverageCard,
          const SizedBox(height: 12),
          actionsCard,
          if (logoutCard != null) ...[const SizedBox(height: 12), logoutCard],
        ],
      );
    }

    return ListView(
      children: [
        summaryCard,
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: mapCard),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  activityCard,
                  const SizedBox(height: 12),
                  coverageCard,
                  const SizedBox(height: 12),
                  actionsCard,
                  if (logoutCard != null) ...[
                    const SizedBox(height: 12),
                    logoutCard,
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dutyStream = FirebaseFirestore.instance
        .collection('duties')
        .where('dsfId', isEqualTo: dsfId)
        // Avoid composite-index dependency (`where + orderBy`) on web.
        // We fetch recent duties and pick latest in memory by `startAt`.
        .limit(80)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: dutyStream,
      builder: (context, dutySnap) {
        final resolvedName = displayName.trim().isEmpty ? dsfId : displayName;
        String? dutyId;
        Map<String, dynamic>? duty;
        if (dutySnap.hasData && dutySnap.data!.docs.isNotEmpty) {
          final docs = dutySnap.data!.docs.toList()
            ..sort((a, b) {
              final aStart = dateFromRaw(a.data()['startAt']);
              final bStart = dateFromRaw(b.data()['startAt']);
              if (aStart == null && bStart == null) return 0;
              if (aStart == null) return 1;
              if (bStart == null) return -1;
              return bStart.compareTo(aStart);
            });
          final doc = docs.first;
          dutyId = doc.id;
          duty = doc.data();
        }

        final dutyStatus =
            (duty?['status'] as String?) ??
            (active != null ? 'active' : 'ended');
        final startLoc = pointFromMap(duty?['startLocation']);
        final endLoc = pointFromMap(duty?['endLocation']);

        final lastUpdated =
            active?.updatedAt ?? active?.lastPointAt ?? recent?.createdAt;

        if (dutyId == null) {
          final summaryCard = _UserSummaryCard(
            name: resolvedName,
            status: dutyStatus,
            updatedAt: lastUpdated,
            updatedLabel: _formatDateWithSince(lastUpdated),
          );
          final mapCard = _MapCard(
            title: resolvedName,
            status: dutyStatus,
            subtitle: 'No duty session found.',
            point:
                active?.lastPoint ??
                recent?.point ??
                endLoc ??
                startLoc ??
                const LatLng(24.8607, 67.0011),
            pointLabel: active?.lastPoint != null
                ? 'Live location'
                : (recent?.point != null
                      ? 'Recent alert location'
                      : 'Last known location'),
          );
          final activityCard = _ActivityCard(
            lastVisitTitle: 'No shop visits yet.',
            lastVisitTime: 'N/A',
            lastAlertTitle: recent?.title ?? 'No recent alerts.',
            lastAlertTime: _formatDateWithSince(recent?.createdAt),
          );
          final actionsCard = _AlertsAdminActionsCard(
            dsfId: dsfId,
            dsfName: resolvedName,
          );
          final coverageCard = _VisitCoverageCard(
            dsfId: dsfId,
            dutyId: dutyId,
            duty: duty,
            dateFromRaw: dateFromRaw,
          );
          final logoutCard = recent?.type == 'dsf_logout'
              ? _LogoutPendingShopsCard(
                  dsfId: dsfId,
                  dutyId: dutyId,
                  duty: duty,
                  recent: recent,
                  dateFromRaw: dateFromRaw,
                )
              : null;

          return _buildResponsivePanel(
            context: context,
            summaryCard: summaryCard,
            mapCard: mapCard,
            activityCard: activityCard,
            coverageCard: coverageCard,
            actionsCard: actionsCard,
            logoutCard: logoutCard,
          );
        }

        final visitsStream = FirebaseFirestore.instance
            .collection('duties')
            .doc(dutyId)
            .collection('shopVisits')
            .orderBy('submittedAt', descending: true)
            .limit(1)
            .snapshots();
        final trackingPointsStream = _trackingPointsStream(dutyId);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: visitsStream,
          builder: (context, visitSnap) {
            Map<String, dynamic>? visit;
            if (visitSnap.hasData && visitSnap.data!.docs.isNotEmpty) {
              visit = visitSnap.data!.docs.first.data();
            }

            final visitPoint = pointFromMap(visit?['submittedLocation']);
            final hasLivePoint = active?.lastPoint != null;
            final hasVisitPoint = visitPoint != null;
            final mapPoint =
                active?.lastPoint ??
                visitPoint ??
                recent?.point ??
                endLoc ??
                startLoc ??
                const LatLng(24.8607, 67.0011);

            final visitTitle =
                (visit?['shopTitle'] as String?)?.trim().isNotEmpty == true
                ? visit!['shopTitle'] as String
                : 'No shop visits yet.';
            final visitSubmittedAt = dateFromRaw(visit?['submittedAt']);
            final visitTime = _formatDateWithSince(visitSubmittedAt);
            final alertTitle = recent?.title ?? 'No recent alerts.';
            final alertTime = _formatDateWithSince(recent?.createdAt);
            _emitRealtimeToasts(
              displayName: resolvedName,
              visitSubmittedAt: visitSubmittedAt,
              visitTitle: visitTitle,
              pointAt: active?.lastPointAt ?? active?.updatedAt,
              point: active?.lastPoint,
            );

            return StreamBuilder<List<LatLng>>(
              stream: trackingPointsStream,
              builder: (context, trackingSnap) {
                final trailPoints = trackingSnap.data ?? const <LatLng>[];
                final summaryCard = _UserSummaryCard(
                  name: resolvedName,
                  status: dutyStatus,
                  updatedAt: lastUpdated,
                  updatedLabel: _formatDateWithSince(lastUpdated),
                );
                final mapCard = _MapCard(
                  title: resolvedName,
                  status: dutyStatus,
                  subtitle: 'Duty $dutyId',
                  point: mapPoint,
                  pointLabel: hasLivePoint
                      ? 'Live location'
                      : (hasVisitPoint
                            ? 'Last shop location'
                            : (recent?.point != null
                                  ? 'Recent alert location'
                                  : 'Last known location')),
                  trailPoints: trailPoints,
                );
                final activityCard = _ActivityCard(
                  lastVisitTitle: visitTitle,
                  lastVisitTime: visitTime,
                  lastAlertTitle: alertTitle,
                  lastAlertTime: alertTime,
                );
                final actionsCard = _AlertsAdminActionsCard(
                  dsfId: dsfId,
                  dsfName: resolvedName,
                );
                final coverageCard = _VisitCoverageCard(
                  dsfId: dsfId,
                  dutyId: dutyId,
                  duty: duty,
                  dateFromRaw: dateFromRaw,
                );
                final logoutCard = recent?.type == 'dsf_logout'
                    ? _LogoutPendingShopsCard(
                        dsfId: dsfId,
                        dutyId: dutyId,
                        duty: duty,
                        recent: recent,
                        dateFromRaw: dateFromRaw,
                      )
                    : null;

                return _buildResponsivePanel(
                  context: context,
                  summaryCard: summaryCard,
                  mapCard: mapCard,
                  activityCard: activityCard,
                  coverageCard: coverageCard,
                  actionsCard: actionsCard,
                  logoutCard: logoutCard,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AlertsAdminActionsCard extends StatefulWidget {
  final String dsfId;
  final String dsfName;

  const _AlertsAdminActionsCard({required this.dsfId, required this.dsfName});

  @override
  State<_AlertsAdminActionsCard> createState() =>
      _AlertsAdminActionsCardState();
}

class _AlertsAdminActionsCardState extends State<_AlertsAdminActionsCard> {
  bool _isDeleting = false;

  Future<int> _deleteAllUserAlerts() async {
    final firestore = FirebaseFirestore.instance;
    var deleted = 0;

    while (true) {
      final snap = await firestore
          .collection('alerts')
          .where('dsfId', isEqualTo: widget.dsfId)
          .limit(300)
          .get();
      if (snap.docs.isEmpty) break;

      final batch = firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      deleted += snap.docs.length;

      if (snap.docs.length < 300) break;
    }

    return deleted;
  }

  Future<void> _confirmAndDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete user alerts'),
        content: Text(
          'Delete all alerts for "${widget.dsfName}"?\n\n'
          "This removes this user's alert history from Live Alerts.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      final count = await _deleteAllUserAlerts();
      if (!mounted) return;
      AppToast.success(
        count == 0 ? 'No alerts found' : 'Alerts deleted',
        message: count == 0
            ? 'No alerts found for ${widget.dsfName}.'
            : 'Deleted $count alert(s) for ${widget.dsfName}.',
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.error('Delete failed', message: e.toString());
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 760;

    final actionButton = ElevatedButton.icon(
      onPressed: _isDeleting ? null : () => _confirmAndDelete(context),
      icon: _isDeleting
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.delete_outline),
      label: Text(_isDeleting ? 'Deleting...' : 'Delete Alerts'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.error,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin Actions',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Remove this user's alerts from Live Alerts panel.",
                  style: TextStyle(color: AppTheme.mutedInk, fontSize: 12),
                ),
                const SizedBox(height: 12),
                actionButton,
              ],
            )
          : Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Actions',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Remove this user's alerts from Live Alerts panel.",
                        style: TextStyle(
                          color: AppTheme.mutedInk,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                actionButton,
              ],
            ),
    );
  }
}

class _LogoutPendingShopsCard extends StatelessWidget {
  final String dsfId;
  final String? dutyId;
  final Map<String, dynamic>? duty;
  final _RecentUserActivity? recent;
  final DateTime? Function(dynamic raw) dateFromRaw;

  const _LogoutPendingShopsCard({
    required this.dsfId,
    required this.dutyId,
    required this.duty,
    required this.recent,
    required this.dateFromRaw,
  });

  String _dayKeyFromDate(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'mon';
      case DateTime.tuesday:
        return 'tue';
      case DateTime.wednesday:
        return 'wed';
      case DateTime.thursday:
        return 'thu';
      case DateTime.friday:
        return 'fri';
      case DateTime.saturday:
        return 'sat';
      case DateTime.sunday:
        return 'sun';
      default:
        return 'mon';
    }
  }

  String _dayLabel(String dayKey) {
    switch (dayKey) {
      case 'mon':
        return 'Monday';
      case 'tue':
        return 'Tuesday';
      case 'wed':
        return 'Wednesday';
      case 'thu':
        return 'Thursday';
      case 'fri':
        return 'Friday';
      case 'sat':
        return 'Saturday';
      case 'sun':
        return 'Sunday';
      default:
        return dayKey;
    }
  }

  Future<String?> _resolveDsfAccountId() async {
    final col = FirebaseFirestore.instance.collection('dsfAccounts');
    final direct = await col.doc(dsfId).get();
    if (direct.exists) return direct.id;

    final byUid = await col.where('uid', isEqualTo: dsfId).limit(1).get();
    if (byUid.docs.isEmpty) return null;
    return byUid.docs.first.id;
  }

  @override
  Widget build(BuildContext context) {
    if (recent?.type != 'dsf_logout') {
      return const SizedBox.shrink();
    }

    final logoutAt = recent?.createdAt;
    final dutyEndAt = dateFromRaw(duty?['endAt']);
    final dutyStartAt = dateFromRaw(duty?['startAt']);
    final baseDate = (logoutAt ?? dutyEndAt ?? dutyStartAt ?? DateTime.now())
        .toLocal();
    final dayKey = _dayKeyFromDate(baseDate);
    final dayLabel = _dayLabel(dayKey);

    return FutureBuilder<String?>(
      future: _resolveDsfAccountId(),
      builder: (context, dsfSnap) {
        if (dsfSnap.connectionState == ConnectionState.waiting) {
          return GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: const [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('Checking unvisited shops...'),
              ],
            ),
          );
        }

        final dsfAccountId = dsfSnap.data;
        if (dsfAccountId == null || dsfAccountId.trim().isEmpty) {
          return GlassCard(
            padding: const EdgeInsets.all(16),
            child: const Text(
              'DSF account not found for unvisited shop check.',
            ),
          );
        }

        final trimmedDutyId = dutyId?.trim();
        if (trimmedDutyId == null || trimmedDutyId.isEmpty) {
          return GlassCard(
            padding: const EdgeInsets.all(16),
            child: Text('No duty session found for logout day ($dayLabel).'),
          );
        }

        final assignmentsStream = FirebaseFirestore.instance
            .collection('seedTsas')
            .doc(dsfAccountId)
            .collection('dailyAssignments')
            .doc(dayKey)
            .collection('shops')
            .snapshots();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: assignmentsStream,
          builder: (context, assignSnap) {
            if (assignSnap.hasError) {
              return GlassCard(
                padding: const EdgeInsets.all(16),
                child: Text(assignSnap.error.toString()),
              );
            }
            if (!assignSnap.hasData) {
              return const GlassCard(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final assignedShopIds = assignSnap.data!.docs
                .map((doc) => doc.id.trim())
                .where((id) => id.isNotEmpty)
                .toSet();

            if (assignedShopIds.isEmpty) {
              return GlassCard(
                padding: const EdgeInsets.all(16),
                child: Text('No shops were assigned for $dayLabel.'),
              );
            }

            final visitsStream = FirebaseFirestore.instance
                .collection('duties')
                .doc(trimmedDutyId)
                .collection('shopVisits')
                .snapshots();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: visitsStream,
              builder: (context, visitSnap) {
                if (visitSnap.hasError) {
                  return GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Text(visitSnap.error.toString()),
                  );
                }
                if (!visitSnap.hasData) {
                  return const GlassCard(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final visitedShopIds = visitSnap.data!.docs
                    .map((doc) {
                      final data = doc.data();
                      final byField = (data['shopId'] as String?)?.trim();
                      if (byField != null && byField.isNotEmpty) {
                        return byField;
                      }
                      return doc.id.trim();
                    })
                    .where((id) => id.isNotEmpty)
                    .toSet();

                final unvisitedShopIds =
                    assignedShopIds
                        .where((id) => !visitedShopIds.contains(id))
                        .toList()
                      ..sort();

                if (unvisitedShopIds.isEmpty) {
                  return GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'All assigned shops were visited on $dayLabel.',
                    ),
                  );
                }

                final preview = unvisitedShopIds.take(8).toList();
                return GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unvisited Shops (after logout)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$dayLabel: ${unvisitedShopIds.length} shops not visited.',
                        style: const TextStyle(
                          color: AppTheme.mutedInk,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final shopId in preview)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.storefront,
                                size: 16,
                                color: AppTheme.sky,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  shopId,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (unvisitedShopIds.length > preview.length)
                        Text(
                          '+${unvisitedShopIds.length - preview.length} more',
                          style: const TextStyle(
                            color: AppTheme.mutedInk,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _VisitCoverageCard extends StatelessWidget {
  final String dsfId;
  final String? dutyId;
  final Map<String, dynamic>? duty;
  final DateTime? Function(dynamic raw) dateFromRaw;

  const _VisitCoverageCard({
    required this.dsfId,
    required this.dutyId,
    required this.duty,
    required this.dateFromRaw,
  });

  String _dayKeyFromDate(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'mon';
      case DateTime.tuesday:
        return 'tue';
      case DateTime.wednesday:
        return 'wed';
      case DateTime.thursday:
        return 'thu';
      case DateTime.friday:
        return 'fri';
      case DateTime.saturday:
        return 'sat';
      case DateTime.sunday:
        return 'sun';
      default:
        return 'mon';
    }
  }

  String _dayLabel(String dayKey) {
    switch (dayKey) {
      case 'mon':
        return 'Monday';
      case 'tue':
        return 'Tuesday';
      case 'wed':
        return 'Wednesday';
      case 'thu':
        return 'Thursday';
      case 'fri':
        return 'Friday';
      case 'sat':
        return 'Saturday';
      case 'sun':
        return 'Sunday';
      default:
        return dayKey;
    }
  }

  Future<String?> _resolveDsfAccountId() async {
    final col = FirebaseFirestore.instance.collection('dsfAccounts');
    final direct = await col.doc(dsfId).get();
    if (direct.exists) return direct.id;

    final byUid = await col.where('uid', isEqualTo: dsfId).limit(1).get();
    if (byUid.docs.isEmpty) return null;
    return byUid.docs.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final trimmedDutyId = dutyId?.trim();
    if (trimmedDutyId == null || trimmedDutyId.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        child: const Text('Visit coverage will appear after duty starts.'),
      );
    }

    final startAt = dateFromRaw(duty?['startAt']) ?? DateTime.now();
    final dayKey = _dayKeyFromDate(startAt.toLocal());
    final dayLabel = _dayLabel(dayKey);

    return FutureBuilder<String?>(
      future: _resolveDsfAccountId(),
      builder: (context, dsfSnap) {
        if (dsfSnap.connectionState == ConnectionState.waiting) {
          return const GlassCard(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final dsfAccountId = dsfSnap.data?.trim();
        if (dsfAccountId == null || dsfAccountId.isEmpty) {
          return const GlassCard(
            padding: EdgeInsets.all(16),
            child: Text('Unable to resolve DSF account for coverage.'),
          );
        }

        final assignmentsStream = FirebaseFirestore.instance
            .collection('seedTsas')
            .doc(dsfAccountId)
            .collection('dailyAssignments')
            .doc(dayKey)
            .collection('shops')
            .snapshots();

        final visitsStream = FirebaseFirestore.instance
            .collection('duties')
            .doc(trimmedDutyId)
            .collection('shopVisits')
            .snapshots();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: assignmentsStream,
          builder: (context, assignSnap) {
            if (assignSnap.hasError) {
              return GlassCard(
                padding: const EdgeInsets.all(16),
                child: Text(assignSnap.error.toString()),
              );
            }
            if (!assignSnap.hasData) {
              return const GlassCard(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final assignedShopIds = assignSnap.data!.docs
                .map((doc) => doc.id.trim())
                .where((id) => id.isNotEmpty)
                .toSet();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: visitsStream,
              builder: (context, visitSnap) {
                if (visitSnap.hasError) {
                  return GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Text(visitSnap.error.toString()),
                  );
                }
                if (!visitSnap.hasData) {
                  return const GlassCard(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final visitedShopIds = visitSnap.data!.docs
                    .map((doc) {
                      final data = doc.data();
                      final byField = (data['shopId'] as String?)?.trim();
                      if (byField != null && byField.isNotEmpty) {
                        return byField;
                      }
                      return doc.id.trim();
                    })
                    .where((id) => id.isNotEmpty)
                    .toSet();

                final visitedInPlan =
                    assignedShopIds.where(visitedShopIds.contains).toList()
                      ..sort();
                final remainingInPlan =
                    assignedShopIds
                        .where((id) => !visitedShopIds.contains(id))
                        .toList()
                      ..sort();

                return GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Visit Coverage',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$dayLabel · Assigned ${assignedShopIds.length} · Visited ${visitedInPlan.length} · Remaining ${remainingInPlan.length}',
                        style: const TextStyle(
                          color: AppTheme.mutedInk,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (visitedInPlan.isNotEmpty) ...[
                        const Text(
                          'Visited',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.bangladeshGreen,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: visitedInPlan
                              .take(6)
                              .map(
                                (id) => _MetaPill(
                                  icon: Icons.check_circle_outline,
                                  label: id,
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 10),
                      ],
                      const Text(
                        'Remaining',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (remainingInPlan.isEmpty)
                        const Text(
                          'No remaining shops. All assigned shops visited.',
                          style: TextStyle(color: AppTheme.mutedInk),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: remainingInPlan
                              .take(8)
                              .map(
                                (id) => _MetaPill(
                                  icon: Icons.storefront_outlined,
                                  label: id,
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _MapCard extends StatefulWidget {
  final String title;
  final String status;
  final String subtitle;
  final LatLng point;
  final String pointLabel;
  final List<LatLng> trailPoints;

  const _MapCard({
    required this.title,
    required this.status,
    required this.subtitle,
    required this.point,
    required this.pointLabel,
    this.trailPoints = const <LatLng>[],
  });

  @override
  State<_MapCard> createState() => _MapCardState();
}

class _MapCardState extends State<_MapCard> {
  final MapController _mapController = MapController();
  double _zoom = 14;

  static const double _minZoom = 4;
  static const double _maxZoom = 18;

  bool _samePoint(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 0.000001 &&
        (a.longitude - b.longitude).abs() < 0.000001;
  }

  @override
  void didUpdateWidget(covariant _MapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_samePoint(oldWidget.point, widget.point)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(widget.point, _zoom);
    });
  }

  void _changeZoom(double delta) {
    final nextZoom = (_zoom + delta).clamp(_minZoom, _maxZoom).toDouble();
    if (nextZoom == _zoom) return;
    setState(() => _zoom = nextZoom);
    _mapController.move(widget.point, _zoom);
  }

  void _recenter() {
    _mapController.move(widget.point, _zoom);
  }

  Widget _mapControlButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark
          ? AppTheme.darkGreen.withValues(alpha: 0.82)
          : Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      shadowColor: const Color(0x26000000),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip ?? '',
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              icon,
              size: 19,
              color: isDark ? AppTheme.antiFlashWhite : AppTheme.darkGreen,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = kIsWeb && MediaQuery.of(context).size.width >= 1120;
    final mapHeight = isWide ? 360.0 : 300.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = widget.status == 'active';
    final statusColor = isActive ? AppTheme.accent : AppTheme.mutedInk;
    final statusBg = isActive ? AppTheme.accentSoft : AppTheme.skySoft;
    final frameBorderColor = isDark
        ? AppTheme.mountainMeadow.withValues(alpha: 0.46)
        : AppTheme.bangladeshGreen.withValues(alpha: 0.26);
    final trailColor = isDark
        ? AppTheme.caribbeanGreen
        : AppTheme.bangladeshGreen;
    final mapPath = <LatLng>[...widget.trailPoints];
    if (mapPath.isEmpty || !_samePoint(mapPath.last, widget.point)) {
      mapPath.add(widget.point);
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: AppTheme.skySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.map_outlined, color: AppTheme.sky),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor == AppTheme.accent
                        ? AppTheme.richBlack
                        : statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.accent : AppTheme.mutedInk,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isActive ? 'Live TAS signal' : 'No active TAS signal',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: frameBorderColor),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (isDark ? AppTheme.darkGreen : AppTheme.accentSoft)
                      .withValues(alpha: isDark ? 0.24 : 0.16),
                  (isDark ? AppTheme.bangladeshGreen : AppTheme.warmSoft)
                      .withValues(alpha: isDark ? 0.12 : 0.1),
                ],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: mapHeight,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: widget.point,
                        initialZoom: _zoom,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'field_sales_app',
                        ),
                        if (mapPath.length > 1)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: mapPath,
                                strokeWidth: 4.6,
                                color: trailColor.withValues(alpha: 0.92),
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            if (mapPath.length > 1)
                              Marker(
                                point: mapPath.first,
                                width: 22,
                                height: 22,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: trailColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppTheme.antiFlashWhite,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            Marker(
                              point: widget.point,
                              width: 48,
                              height: 48,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppTheme.caribbeanGreen.withValues(
                                        alpha: 0.28,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.caribbeanGreen,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0x33000000),
                                          blurRadius: 12,
                                          offset: Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.place_rounded,
                                      color: AppTheme.antiFlashWhite,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                (isDark ? AppTheme.darkGreen : Colors.white)
                                    .withValues(alpha: isDark ? 0.07 : 0.02),
                                Colors.transparent,
                                (isDark ? Colors.black : AppTheme.warmSoft)
                                    .withValues(alpha: isDark ? 0.05 : 0.03),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkGreen.withValues(alpha: 0.88)
                              : AppTheme.antiFlashWhite.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: isDark
                                ? AppTheme.mountainMeadow.withValues(
                                    alpha: 0.42,
                                  )
                                : AppTheme.bangladeshGreen.withValues(
                                    alpha: 0.22,
                                  ),
                          ),
                        ),
                        child: Text(
                          widget.pointLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? (isDark
                                      ? AppTheme.caribbeanGreen
                                      : AppTheme.bangladeshGreen)
                                : (isDark
                                      ? AppTheme.antiFlashWhite
                                      : AppTheme.ink),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Column(
                        children: [
                          _mapControlButton(
                            icon: Icons.add,
                            onTap: () => _changeZoom(1),
                            tooltip: 'Zoom in',
                          ),
                          const SizedBox(height: 8),
                          _mapControlButton(
                            icon: Icons.remove,
                            onTap: () => _changeZoom(-1),
                            tooltip: 'Zoom out',
                          ),
                          const SizedBox(height: 8),
                          _mapControlButton(
                            icon: Icons.my_location,
                            onTap: _recenter,
                            tooltip: 'Center',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaPill(
                icon: Icons.place_outlined,
                label:
                    'Lat ${widget.point.latitude.toStringAsFixed(5)}, Lng ${widget.point.longitude.toStringAsFixed(5)}',
              ),
              _MetaPill(icon: Icons.info_outline, label: widget.pointLabel),
              _MetaPill(
                icon: Icons.alt_route,
                label: 'Trail ${mapPath.length} points',
              ),
              _MetaPill(
                icon: Icons.zoom_in,
                label: 'Zoom ${_zoom.toStringAsFixed(1)}x',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String lastVisitTitle;
  final String lastVisitTime;
  final String lastAlertTitle;
  final String lastAlertTime;

  const _ActivityCard({
    required this.lastVisitTitle,
    required this.lastVisitTime,
    required this.lastAlertTitle,
    required this.lastAlertTime,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: AppTheme.skySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.timeline, color: AppTheme.sky),
              ),
              const SizedBox(width: 10),
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ActivityRow(
            icon: Icons.storefront,
            label: 'Last shop visit',
            title: lastVisitTitle,
            subtitle: lastVisitTime,
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _ActivityRow(
            icon: Icons.notifications_active,
            label: 'Last alert',
            title: lastAlertTitle,
            subtitle: lastAlertTime,
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String title;
  final String subtitle;

  const _ActivityRow({
    required this.icon,
    required this.label,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: AppTheme.skySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.sky),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.mutedInk,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.skySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.sky),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserSummaryCard extends StatelessWidget {
  final String name;
  final String status;
  final DateTime? updatedAt;
  final String updatedLabel;

  const _UserSummaryCard({
    required this.name,
    required this.status,
    required this.updatedAt,
    required this.updatedLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'active';
    final statusColor = isActive ? AppTheme.accent : AppTheme.mutedInk;
    final initials = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: AppTheme.accentSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.ink,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Last updated: $updatedLabel',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive ? AppTheme.accent : AppTheme.mutedInk,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      updatedAt == null
                          ? 'No recent signal'
                          : 'Signal received',
                      style: const TextStyle(
                        color: AppTheme.mutedInk,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? AppTheme.accentSoft : AppTheme.skySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveSession {
  final String dutyId;
  final LatLng? lastPoint;
  final DateTime? lastPointAt;
  final DateTime? updatedAt;

  const _ActiveSession({
    required this.dutyId,
    required this.lastPoint,
    required this.lastPointAt,
    required this.updatedAt,
  });
}

class _RecentUserActivity {
  final String dsfId;
  final String? type;
  final DateTime? createdAt;
  final String? shopTitle;
  final String? locationLabel;
  final double? distanceMeters;
  final int? missedShops;
  final LatLng? point;

  const _RecentUserActivity({
    required this.dsfId,
    required this.type,
    required this.createdAt,
    this.shopTitle,
    this.locationLabel,
    this.distanceMeters,
    this.missedShops,
    this.point,
  });

  String get title {
    switch (type) {
      case 'dsf_login':
        return locationLabel != null && locationLabel!.isNotEmpty
            ? 'Logged in (${locationLabel!})'
            : 'Logged in';
      case 'dsf_logout':
        return 'Logged out';
      case 'out_of_geofence':
        if (distanceMeters != null) {
          return 'Left geofence (${distanceMeters!.toStringAsFixed(0)}m)';
        }
        return 'Left geofence';
      case 'duty_start':
        return 'Duty started';
      case 'duty_end':
        return 'Duty ended';
      case 'shop_visit':
        if (shopTitle != null && shopTitle!.isNotEmpty) {
          return 'Visited $shopTitle';
        }
        return 'Visited shop';
      case 'shop_added':
        if (shopTitle != null && shopTitle!.isNotEmpty) {
          return 'Added shop $shopTitle';
        }
        return 'Added shop';
      case 'shops_missed':
        if (missedShops != null) {
          return 'Missed ${missedShops!} shops';
        }
        return 'Missed assigned shops';
      default:
        return 'Activity update';
    }
  }
}
