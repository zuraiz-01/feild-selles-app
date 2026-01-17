import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_theme.dart';

class AdminMapPage extends StatelessWidget {
  const AdminMapPage({super.key});

  void _openSessionDetails(BuildContext context, String dutyId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LiveSessionSheet(dutyId: dutyId),
    );
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
        .limit(30)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Live Tracking')),
      body: AppShell(
        child: Column(
          children: [
            SizedBox(
              height: 320,
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: sessions,
                builder: (context, snapshot) {
                  final markers = <Marker>[];
                  if (snapshot.hasData) {
                    for (final doc in snapshot.data!.docs) {
                      final last = doc.data()['lastPoint'];
                      if (last is! Map) continue;
                      final lat = (last['lat'] as num?)?.toDouble();
                      final lng = (last['lng'] as num?)?.toDouble();
                      if (lat == null || lng == null) continue;
                      markers.add(
                        Marker(
                          point: LatLng(lat, lng),
                          width: 46,
                          height: 46,
                          child: GestureDetector(
                            onTap: () => _openSessionDetails(context, doc.id),
                            child: Tooltip(
                              message: doc.id,
                              child: const Icon(
                                Icons.location_on,
                                color: AppTheme.accent,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  }
                  final center = markers.isNotEmpty
                      ? markers.first.point
                      : const LatLng(24.8607, 67.0011);
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: 12,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'field_sales_app',
                        ),
                        MarkerLayer(markers: markers),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  const SectionTitle(
                    title: 'Active duty',
                    subtitle: 'DSFs currently on duty.',
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: sessions,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(snapshot.error.toString());
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return const Text('No active duty sessions.');
                      }
                      return Column(
                        children: docs.map((doc) {
                          final data = doc.data();
                          final dsfId = (data['dsfId'] as String?) ?? '';
                          final distributorId =
                              (data['distributorId'] as String?) ?? '';
                          final last = data['lastPoint'];
                          final lat = last is Map ? (last['lat'] as num?) : null;
                          final lng = last is Map ? (last['lng'] as num?) : null;
                          final updatedAt = data['updatedAt'];
                          final ts = updatedAt is Timestamp
                              ? updatedAt.toDate()
                              : null;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GlassCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  dsfId.isEmpty
                                      ? 'DSF ${doc.id}'
                                      : 'DSF $dsfId',
                                ),
                                subtitle: Text(
                                  [
                                    if (distributorId.isNotEmpty)
                                      'Distributor $distributorId',
                                    if (lat != null && lng != null)
                                      'Last ${lat.toDouble().toStringAsFixed(4)}, ${lng.toDouble().toStringAsFixed(4)}',
                                    if (ts != null) ts.toLocal().toString(),
                                  ].join(' • '),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () =>
                                    _openSessionDetails(context, doc.id),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  const SectionTitle(
                    title: 'Recent activity',
                    subtitle: 'Login/logout and geofence alerts.',
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: alerts,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(snapshot.error.toString());
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return const Text('No alerts yet.');
                      }
                      return Column(
                        children: docs.map((doc) {
                          final data = doc.data();
                          final type = (data['type'] as String?) ?? 'event';
                          final dsfId = (data['dsfId'] as String?) ?? '';
                          final createdAt = data['createdAt'];
                          final ts =
                              createdAt is Timestamp ? createdAt.toDate() : null;
                          final lat = (data['lat'] as num?)?.toDouble();
                          final lng = (data['lng'] as num?)?.toDouble();
                          final locationLabel =
                              (data['locationLabel'] as String?)?.trim();
                          final distance =
                              (data['distanceMeters'] as num?)?.toDouble();

                          String title;
                          switch (type) {
                            case 'dsf_login':
                              title = 'DSF $dsfId logged in';
                              break;
                            case 'dsf_logout':
                              title = 'DSF $dsfId logged out';
                              break;
                            case 'out_of_geofence':
                              title = 'DSF $dsfId left geofence';
                              break;
                            default:
                              title = 'DSF $dsfId activity';
                          }

                          final subtitleParts = <String>[];
                          if (type == 'dsf_login' &&
                              locationLabel != null &&
                              locationLabel.isNotEmpty) {
                            subtitleParts.add(locationLabel);
                          } else if (lat != null && lng != null) {
                            subtitleParts.add(
                              '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                            );
                          }
                          if (distance != null) {
                            subtitleParts.add(
                              'Distance ${distance.toStringAsFixed(0)}m',
                            );
                          }
                          if (ts != null) {
                            subtitleParts.add(ts.toLocal().toString());
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GlassCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    height: 44,
                                    width: 44,
                                    decoration: BoxDecoration(
                                      color: type == 'out_of_geofence'
                                          ? AppTheme.warmSoft
                                          : AppTheme.skySoft,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      type == 'out_of_geofence'
                                          ? Icons.warning_amber_rounded
                                          : Icons.notifications_active,
                                      color: type == 'out_of_geofence'
                                          ? AppTheme.warm
                                          : AppTheme.sky,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        if (subtitleParts.isNotEmpty)
                                          Text(
                                            subtitleParts.join(' • '),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveSessionSheet extends StatelessWidget {
  final String dutyId;

  const _LiveSessionSheet({required this.dutyId});

  @override
  Widget build(BuildContext context) {
    final sessionDoc = FirebaseFirestore.instance
        .collection('locationSessions')
        .doc(dutyId);
    final visitsStream = FirebaseFirestore.instance
        .collection('duties')
        .doc(dutyId)
        .collection('shopVisits')
        .orderBy('submittedAt', descending: true)
        .snapshots();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.accentSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.my_location,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Duty $dutyId',
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: sessionDoc.snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data();
                  final last = data?['lastPoint'];
                  final lat = last is Map ? (last['lat'] as num?) : null;
                  final lng = last is Map ? (last['lng'] as num?) : null;
                  final recordedAt = last is Map ? last['recordedAt'] : null;
                  final ts = recordedAt is Timestamp
                      ? recordedAt.toDate()
                      : null;
                  if (lat == null || lng == null) {
                    return const Text('Live location not available yet.');
                  }
                  final point = LatLng(lat.toDouble(), lng.toDouble());
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                          height: 220,
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: point,
                              initialZoom: 15,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'field_sales_app',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: point,
                                    width: 46,
                                    height: 46,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: AppTheme.accent,
                                      size: 32,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Last: ${lat.toDouble().toStringAsFixed(5)}, ${lng.toDouble().toStringAsFixed(5)}'
                        '${ts != null ? ' • ${ts.toLocal()}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Visited shops',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: visitsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(snapshot.error.toString());
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Text('No shop visits yet.');
                  }
                  return Column(
                    children: docs.map((doc) {
                      final data = doc.data();
                      final title =
                          (data['shopTitle'] as String?) ?? doc.id;
                      final submittedAt = data['submittedAt'];
                      final ts = submittedAt is Timestamp
                          ? submittedAt.toDate()
                          : null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: AppTheme.skySoft,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.storefront,
                                  color: AppTheme.sky,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    if (ts != null)
                                      Text(
                                        ts.toLocal().toString(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
