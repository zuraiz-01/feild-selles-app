import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:convert';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../../core/services/session/session_service.dart';
import '../../../../core/utils/map_location_url_parser.dart';

class ShopsToVisitPage extends StatefulWidget {
  const ShopsToVisitPage({super.key});

  @override
  State<ShopsToVisitPage> createState() => _ShopsToVisitPageState();
}

class _ShopsToVisitPageState extends State<ShopsToVisitPage> {
  String _currentDayKey = '';
  String? _dsfAccountId;

  String _dayKeyFromDateKey(String? dateKey) {
    DateTime? parsed;
    if (dateKey != null && dateKey.trim().isNotEmpty) {
      parsed = DateTime.tryParse(dateKey);
    }
    final now = parsed ?? DateTime.now();
    switch (now.weekday) {
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

  String _labelForDayKey(String key) {
    switch (key) {
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
        return key;
    }
  }

  bool _isScheduledForDay(Map<String, dynamic> data, String dayKey) {
    final schedule = data['schedule'];
    if (schedule is! Map) {
      // Keep older docs visible when schedule is not available.
      return true;
    }
    return schedule[dayKey] == true;
  }

  void _openShopVisit({
    required String tsaId,
    required String shopId,
    required String shopTitle,
  }) {
    final session = Get.find<SessionService>();
    final dutyId = session.activeDutyId;
    if (dutyId == null || dutyId.trim().isEmpty) {
      Get.snackbar(
        'Duty required',
        'Start duty first to open shop visit form.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    Get.toNamed(
      AppRoutes.dsfShopVisit,
      arguments: {'tsaId': tsaId, 'shopId': shopId, 'shopTitle': shopTitle},
    );
  }

  Widget _buildGlobalAssignedShops({
    required String dsfAccountId,
    required String dsfUid,
    required String dayLabel,
    required String dayKey,
  }) {
    final byIdStream = FirebaseFirestore.instance
        .collection('shops')
        .where('assignedDsfId', isEqualTo: dsfAccountId)
        .snapshots();
    final byUidStream = FirebaseFirestore.instance
        .collection('shops')
        .where('assignedDsfUid', isEqualTo: dsfUid)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: byIdStream,
      builder: (context, byIdSnap) {
        if (byIdSnap.hasError) {
          return Center(child: Text(byIdSnap.error.toString()));
        }
        if (!byIdSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: byUidStream,
          builder: (context, byUidSnap) {
            if (byUidSnap.hasError) {
              return Center(child: Text(byUidSnap.error.toString()));
            }
            if (!byUidSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final merged = <String, Map<String, dynamic>>{};
            for (final doc in byIdSnap.data!.docs) {
              merged[doc.id] = doc.data();
            }
            for (final doc in byUidSnap.data!.docs) {
              merged[doc.id] = doc.data();
            }

            final entries =
                merged.entries
                    .where((e) => _isScheduledForDay(e.value, dayKey))
                    .toList()
                  ..sort((a, b) {
                    final aCode = (a.value['code'] as String?) ?? a.key;
                    final bCode = (b.value['code'] as String?) ?? b.key;
                    return aCode.compareTo(bCode);
                  });

            if (entries.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'No shops assigned for $dayLabel yet.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Expanded(child: Center(child: Text('No shops found.'))),
                ],
              );
            }

            return ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final shopId = entries[index].key;
                final data = entries[index].value;
                final code = (data['code'] as String?) ?? shopId;
                final name = (data['name'] as String?) ?? '';
                final area = (data['area'] as String?) ?? '';
                final title = name.isEmpty ? code : '$name ($code)';

                return GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: area.isEmpty
                        ? null
                        : Text(
                            area,
                            style: const TextStyle(color: AppTheme.mutedInk),
                          ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openShopVisit(
                      tsaId: '',
                      shopId: shopId,
                      shopTitle: name.isEmpty ? code : name,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _addShopForDay({
    required BuildContext context,
    required String dsfAccountId,
    required String dsfUid,
    required String dayKey,
  }) async {
    final result = await _openCreateShopDialog(context);
    if (result == null) return;

    final shopsCol = FirebaseFirestore.instance.collection('shops');
    final shopId = result.code.toLowerCase();
    final now = FieldValue.serverTimestamp();
    final seedTsaRef = FirebaseFirestore.instance
        .collection('seedTsas')
        .doc(dsfAccountId);
    final dsfAccountDoc = await FirebaseFirestore.instance
        .collection('dsfAccounts')
        .doc(dsfAccountId)
        .get();
    final dsfName = (dsfAccountDoc.data()?['name'] as String?)?.trim() ?? '';
    final seedTsaSnap = await seedTsaRef.get();
    final isNewSeedTsa = !seedTsaSnap.exists;

    final globalPayload = <String, dynamic>{
      'code': result.code,
      'name': result.name,
      'area': result.area,
      'filer': result.filer,
      'discountPct': result.filer ? 0.05 : 0.025,
      'assignedDsfId': dsfAccountId,
      'assignedDsfUid': dsfUid,
      'updatedAt': now,
      'createdAt': now,
    };
    if (result.lat != null && result.lng != null) {
      globalPayload['location'] = {'lat': result.lat, 'lng': result.lng};
    }

    final tsaShopRef = FirebaseFirestore.instance
        .collection('seedTsas')
        .doc(dsfAccountId)
        .collection('shops')
        .doc(shopId);

    final assignmentRef = FirebaseFirestore.instance
        .collection('seedTsas')
        .doc(dsfAccountId)
        .collection('dailyAssignments')
        .doc(dayKey)
        .collection('shops')
        .doc(shopId);

    await FirebaseFirestore.instance.runTransaction((txn) async {
      txn.set(seedTsaRef, {
        'type': 'tsa',
        'tsaId': dsfAccountId,
        if (dsfName.isNotEmpty) 'name': dsfName,
        'updatedAt': now,
        if (isNewSeedTsa) 'createdAt': now,
      }, SetOptions(merge: true));
      txn.set(shopsCol.doc(shopId), globalPayload, SetOptions(merge: true));
      txn.set(tsaShopRef, {
        'shopId': shopId,
        'code': result.code,
        'name': result.name,
        if (result.area.isNotEmpty) 'area': result.area,
        if (result.lat != null && result.lng != null)
          'location': {'lat': result.lat, 'lng': result.lng},
        'tsaId': dsfAccountId,
        'source': 'dsf_self',
        'createdAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));
      txn.set(assignmentRef, {'assignedAt': now}, SetOptions(merge: true));
    });

    if (!context.mounted) return;
    Get.snackbar(
      'Shop added',
      '${result.code} assigned for ${_labelForDayKey(dayKey)}',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<_CreateShopResult?> _openCreateShopDialog(BuildContext context) async {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final areaController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    bool filer = false;
    LatLng? picked;

    final result = await showDialog<_CreateShopResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add shop'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: codeController,
                            decoration: const InputDecoration(
                              labelText: 'Code',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: areaController,
                            decoration: const InputDecoration(
                              labelText: 'Area',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: filer,
                        onChanged: (v) => setState(() => filer = v),
                        title: const Text('Filer (5% discount)'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Location',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: latController,
                                  decoration: const InputDecoration(
                                    labelText: 'Lat',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: lngController,
                                  decoration: const InputDecoration(
                                    labelText: 'Lng',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final initial = _readLatLng(
                                latController.text,
                                lngController.text,
                              );
                              final res = await _pickOnMap(
                                context,
                                initial: picked ?? initial,
                              );
                              if (res == null) return;
                              setState(() {
                                picked = res;
                                latController.text = res.latitude
                                    .toStringAsFixed(6);
                                lngController.text = res.longitude
                                    .toStringAsFixed(6);
                              });
                            },
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Pick on map'),
                          ),
                          if (picked != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Picked: ${picked!.latitude.toStringAsFixed(6)}, ${picked!.longitude.toStringAsFixed(6)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final code = codeController.text.trim();
                    if (code.isEmpty) return;
                    Navigator.of(context).pop(
                      _CreateShopResult(
                        code: code,
                        name: nameController.text.trim(),
                        area: areaController.text.trim(),
                        lat: double.tryParse(latController.text.trim()),
                        lng: double.tryParse(lngController.text.trim()),
                        filer: filer,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  LatLng? _readLatLng(String lat, String lng) {
    final latVal = double.tryParse(lat.trim());
    final lngVal = double.tryParse(lng.trim());
    if (latVal == null || lngVal == null) return null;
    return LatLng(latVal, lngVal);
  }

  Future<LatLng?> _pickOnMap(BuildContext context, {LatLng? initial}) async {
    final result = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ShopMapPickerSheet(
        initialCenter: initial ?? const LatLng(23.8103, 90.4125),
      ),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionService>();
    final profile = session.profile;
    final baseDateKey = session.activeDutyDateKey;
    final hasActiveDutyDay =
        baseDateKey != null && baseDateKey.trim().isNotEmpty;
    final dayKey = _dayKeyFromDateKey(hasActiveDutyDay ? baseDateKey : null);
    if (_currentDayKey != dayKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _currentDayKey = dayKey);
      });
    }
    final dayLabel = _labelForDayKey(dayKey);

    if (profile == null) {
      return const Scaffold(
        body: Center(child: Text('Session missing. Please login again.')),
      );
    }
    final dsfAccountStream = FirebaseFirestore.instance
        .collection('dsfAccounts')
        .where('uid', isEqualTo: profile.uid)
        .limit(1)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          hasActiveDutyDay
              ? 'Shops for $dayLabel'
              : 'Shops for $dayLabel (preview)',
        ),
        actions: [
          IconButton(
            onPressed: _dsfAccountId != null
                ? () => _addShopForDay(
                    context: context,
                    dsfAccountId: _dsfAccountId!,
                    dsfUid: profile.uid,
                    dayKey: dayKey,
                  )
                : null,
            icon: const Icon(Icons.add_business),
            tooltip: 'Add shop',
          ),
        ],
      ),
      body: AppShell(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: dsfAccountStream,
          builder: (context, dsfSnap) {
            if (dsfSnap.hasError) {
              return Center(child: Text(dsfSnap.error.toString()));
            }
            if (!dsfSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (dsfSnap.data!.docs.isEmpty) {
              return const Center(child: Text('DSF profile not found.'));
            }
            final dsfDoc = dsfSnap.data!.docs.first;
            final dsfAccountId = dsfDoc.id;
            if (_dsfAccountId != dsfAccountId) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() => _dsfAccountId = dsfAccountId);
              });
            }

            final assignments = FirebaseFirestore.instance
                .collection('seedTsas')
                .doc(dsfAccountId)
                .collection('dailyAssignments')
                .doc(dayKey)
                .collection('shops')
                .snapshots();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: assignments,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return _buildGlobalAssignedShops(
                    dsfAccountId: dsfAccountId,
                    dsfUid: profile.uid,
                    dayLabel: dayLabel,
                    dayKey: dayKey,
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final assign = docs[index];
                    final shopRef = FirebaseFirestore.instance
                        .collection('seedTsas')
                        .doc(dsfAccountId)
                        .collection('shops')
                        .doc(assign.id);
                    return StreamBuilder<
                      DocumentSnapshot<Map<String, dynamic>>
                    >(
                      stream: shopRef.snapshots(),
                      builder: (context, shopSnap) {
                        if (shopSnap.hasError) {
                          return GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Text('Error loading shop ${assign.id}'),
                          );
                        }
                        if (!shopSnap.hasData || !shopSnap.data!.exists) {
                          return GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Text('Shop ${assign.id} not found'),
                          );
                        }
                        final data = shopSnap.data!.data()!;
                        final code = (data['code'] as String?) ?? assign.id;
                        final name = (data['name'] as String?) ?? '';
                        final area = (data['area'] as String?) ?? '';
                        final title = name.isEmpty ? code : '$name ($code)';
                        return GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            subtitle: area.isEmpty
                                ? null
                                : Text(
                                    area,
                                    style: const TextStyle(
                                      color: AppTheme.mutedInk,
                                    ),
                                  ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openShopVisit(
                              tsaId: dsfAccountId,
                              shopId: assign.id,
                              shopTitle: name.isEmpty ? code : name,
                            ),
                          ),
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

class _CreateShopResult {
  final String code;
  final String name;
  final String area;
  final double? lat;
  final double? lng;
  final bool filer;

  const _CreateShopResult({
    required this.code,
    required this.name,
    required this.area,
    required this.lat,
    required this.lng,
    required this.filer,
  });
}

class _ShopMapPickerSheet extends StatefulWidget {
  final LatLng initialCenter;

  const _ShopMapPickerSheet({required this.initialCenter});

  @override
  State<_ShopMapPickerSheet> createState() => _ShopMapPickerSheetState();
}

class _ShopMapPickerSheetState extends State<_ShopMapPickerSheet> {
  late LatLng _center;
  final _mapController = MapController();
  final _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isLocating = false;
  String? _error;
  List<_PlaceResult> _results = [];

  @override
  void initState() {
    super.initState();
    _center = widget.initialCenter;
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchPlace(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    if (_tryMoveToSharedLocation(trimmed)) return;

    setState(() {
      _isSearching = true;
      _error = null;
    });
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'json',
        'q': trimmed,
        'limit': '5',
      });
      final response = await http.get(
        uri,
        headers: const {'User-Agent': 'field_sales_app/1.0 (shop picker)'},
      );
      if (response.statusCode != 200) {
        throw StateError('Search failed (${response.statusCode}).');
      }
      final raw = jsonDecode(response.body);
      if (raw is! List) {
        throw StateError('Unexpected search response.');
      }
      final parsed = <_PlaceResult>[];
      for (final item in raw) {
        final place = _PlaceResult.fromJson(item);
        if (place != null) parsed.add(place);
      }
      setState(() {
        _results = parsed;
        _error = parsed.isEmpty ? 'No results found.' : null;
      });
    } catch (_) {
      setState(() {
        _error = 'Search failed. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _error = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permission denied.';
        });
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
        _results = [];
      });
      _mapController.move(_center, 16);
    } catch (_) {
      setState(() {
        _error = 'Unable to get current location.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  void _selectPlace(_PlaceResult place) {
    setState(() {
      _center = LatLng(place.lat, place.lng);
      _results = [];
      _error = null;
    });
    _mapController.move(_center, 16);
  }

  bool _tryMoveToSharedLocation(String raw) {
    final parsed = MapLocationUrlParser.tryParse(raw);
    if (parsed == null) return false;
    setState(() {
      _center = LatLng(parsed.lat, parsed.lng);
      _results = [];
      _error = null;
    });
    _mapController.move(_center, 16);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.82;
    return Container(
      height: height,
      decoration: const BoxDecoration(color: Colors.transparent),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pick shop location',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _searchPlace,
              decoration: InputDecoration(
                hintText: 'Search location or paste map URL',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (_searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _results = [];
                                  _error = null;
                                });
                              },
                              icon: const Icon(Icons.clear),
                            )),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLocating ? null : _useCurrentLocation,
                    icon: _isLocating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: const Text('Use current location'),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            ],
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final place = _results[index];
                    return ListTile(
                      title: Text(
                        place.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _selectPlace(place),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 15,
                    onTap: (tapPosition, latLng) {
                      setState(() {
                        _center = latLng;
                      });
                    },
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
                          point: _center,
                          width: 42,
                          height: 42,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.accent,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 12,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_center),
              child: const Text('Use this location'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceResult {
  final String label;
  final double lat;
  final double lng;

  const _PlaceResult({
    required this.label,
    required this.lat,
    required this.lng,
  });

  static _PlaceResult? fromJson(Object? value) {
    if (value is! Map) return null;
    final displayName = value['display_name'];
    final latRaw = value['lat'];
    final lngRaw = value['lon'];
    if (displayName is! String || latRaw == null || lngRaw == null) {
      return null;
    }
    final lat = double.tryParse(latRaw.toString());
    final lng = double.tryParse(lngRaw.toString());
    if (lat == null || lng == null) return null;
    return _PlaceResult(label: displayName, lat: lat, lng: lng);
  }
}
