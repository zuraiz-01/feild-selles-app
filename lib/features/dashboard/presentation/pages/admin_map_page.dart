import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_theme.dart';

class AdminMapPage extends StatelessWidget {
  const AdminMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = FirebaseFirestore.instance
        .collection('locationSessions')
        .where('status', isEqualTo: 'active')
        .snapshots();
    final alerts = FirebaseFirestore.instance
        .collection('alerts')
        .orderBy('createdAt', descending: true)
        .limit(20)
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
                          child: Tooltip(
                            message: doc.id,
                            child: const Icon(
                              Icons.location_on,
                              color: AppTheme.accent,
                              size: 32,
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
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: alerts,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text(snapshot.error.toString()));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(child: Text('No alerts.'));
                  }
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final dsfId = (data['dsfId'] as String?) ?? '';
                      final distance =
                          (data['distanceMeters'] as num?)?.toDouble() ?? 0;
                      final createdAt = data['createdAt'];
                      final ts = createdAt is Timestamp
                          ? createdAt.toDate()
                          : null;
                      return GlassCard(
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
                                color: AppTheme.warmSoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: AppTheme.warm,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DSF $dsfId left geofence',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Text(
                                    'Distance: ${distance.toStringAsFixed(0)} m'
                                    '${ts != null ? ' • ${ts.toLocal()}' : ''}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
