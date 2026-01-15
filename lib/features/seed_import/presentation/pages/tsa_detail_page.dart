import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:convert';

import '../../../../app/routes/app_routes.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_theme.dart';

class TsaDetailPage extends StatelessWidget {
  const TsaDetailPage({super.key});

  Future<String?> _pickDateKey(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return null;
    final y = picked.year.toString().padLeft(4, '0');
    final m = picked.month.toString().padLeft(2, '0');
    final d = picked.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _assignShopsForDay(
    BuildContext context, {
    required String tsaId,
    required String dateKey,
  }) async {
    final shopsCol = FirebaseFirestore.instance
        .collection('seedTsas')
        .doc(tsaId)
        .collection('shops');
    final assignmentRoot = FirebaseFirestore.instance
        .collection('seedTsas')
        .doc(tsaId)
        .collection('dailyAssignments')
        .doc(dateKey)
        .collection('shops');

    final shopsSnap = await shopsCol.orderBy('code').get();
    final currentAssignedSnap = await assignmentRoot.get();
    if (!context.mounted) return;
    final selected = currentAssignedSnap.docs.map((d) => d.id).toSet();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final working = Set<String>.from(selected);
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Assign shops ($dateKey)'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final doc in shopsSnap.docs)
                      CheckboxListTile(
                        value: working.contains(doc.id),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              working.add(doc.id);
                            } else {
                              working.remove(doc.id);
                            }
                          });
                        },
                        title: Text(
                          ((doc.data()['name'] as String?)?.trim().isNotEmpty ??
                                  false)
                              ? '${doc.data()['name']} (${doc.data()['code'] ?? doc.id})'
                              : (doc.data()['code'] as String?) ?? doc.id,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final batch = FirebaseFirestore.instance.batch();
                    for (final doc in currentAssignedSnap.docs) {
                      batch.delete(doc.reference);
                    }
                    for (final id in working) {
                      batch.set(assignmentRoot.doc(id), {
                        'assignedAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));
                    }
                    await batch.commit();
                    if (!context.mounted) return;
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      Get.snackbar(
        'Saved',
        'Assignments updated for $dateKey.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
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

  Future<void> _createShop(BuildContext context, String tsaId) async {
    final dsfOptions = await FirebaseFirestore.instance
        .collection('dsfAccounts')
        .orderBy('name')
        .get();
    final shopsCol = FirebaseFirestore.instance.collection('shops');
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final areaController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    String? selectedDsf = dsfOptions.docs.any((d) => d.id == tsaId)
        ? tsaId
        : null;
    var schedule = {
      'mon': true,
      'tue': true,
      'wed': true,
      'thu': true,
      'fri': true,
      'sat': false,
      'sun': false,
    };
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
                              final res = await _pickOnMap(
                                context,
                                initial: picked,
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
                          DropdownButtonFormField<String>(
                            value:
                                (selectedDsf != null &&
                                    dsfOptions.docs.any(
                                      (d) => d.id == selectedDsf,
                                    ))
                                ? selectedDsf
                                : '',
                            decoration: const InputDecoration(
                              labelText: 'Assigned DSF',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('Unassigned'),
                              ),
                              ...dsfOptions.docs.map(
                                (d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text(
                                    ((d.data()['name'] as String?)
                                                ?.trim()
                                                .isNotEmpty ??
                                            false)
                                        ? '${d.data()['name']} (${d.id})'
                                        : d.id,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(
                              () => selectedDsf = (v == null || v.isEmpty)
                                  ? null
                                  : v,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () async {
                                final pickedSchedule = await _pickSchedule(
                                  context,
                                  schedule,
                                );
                                if (pickedSchedule != null) {
                                  setState(() {
                                    schedule = pickedSchedule;
                                  });
                                }
                              },
                              icon: const Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                              ),
                              label: const Text('Pick days'),
                            ),
                          ),
                          const Text(
                            'Schedule',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: schedule.keys
                                .map(
                                  (d) => FilterChip(
                                    label: Text(d.toUpperCase()),
                                    selected: schedule[d] == true,
                                    onSelected: (v) {
                                      setState(() {
                                        schedule[d] = v;
                                      });
                                    },
                                  ),
                                )
                                .toList(),
                          ),
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
                        lat:
                            double.tryParse(latController.text.trim()) ??
                            picked?.latitude,
                        lng:
                            double.tryParse(lngController.text.trim()) ??
                            picked?.longitude,
                        filer: filer,
                        dsfId: selectedDsf,
                        schedule: schedule,
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

    if (result == null) return;

    final payload = <String, dynamic>{
      'code': result.code,
      'name': result.name,
      'area': result.area,
      'filer': result.filer,
      'discountPct': result.filer ? 0.05 : 0.025,
      'assignedDsfId': result.dsfId ?? '',
      'schedule': result.schedule,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (result.lat != null && result.lng != null) {
      payload['location'] = {'lat': result.lat, 'lng': result.lng};
    }
    final shopId = result.code.toLowerCase();
    await shopsCol.doc(shopId).set(payload, SetOptions(merge: true));

    // Also add into TSA shops for immediate use.
    final tsaShopRef = FirebaseFirestore.instance
        .collection('seedTsas')
        .doc(tsaId)
        .collection('shops')
        .doc(shopId);
    await tsaShopRef.set({
      'shopId': shopId,
      'code': result.code,
      'name': result.name,
      if (result.area.isNotEmpty) 'area': result.area,
      if (result.lat != null && result.lng != null)
        'location': {'lat': result.lat, 'lng': result.lng},
      'tsaId': tsaId,
      'source': 'admin_dialog',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    Get.snackbar(
      'Shop added',
      result.code,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> _addExistingShop(BuildContext context, String tsaId) async {
    final globalShops = await FirebaseFirestore.instance
        .collection('shops')
        .orderBy('code')
        .get();
    if (!context.mounted) return;
    if (globalShops.docs.isEmpty) {
      Get.snackbar(
        'You don’t have any shops',
        'Add a shop first, then pick from existing.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    String? selectedId;
    final picked = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Choose a shop'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: globalShops.docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = globalShops.docs[index];
                    final data = doc.data();
                    final code = (data['code'] as String?) ?? doc.id;
                    final name = (data['name'] as String?) ?? '';
                    final title = '$code ${name.isEmpty ? '' : '• $name'}';
                    return RadioListTile<String>(
                      value: doc.id,
                      groupValue: selectedId,
                      onChanged: (v) => setState(() => selectedId = v),
                      title: Text(title),
                      subtitle: (data['area'] as String?)?.isNotEmpty == true
                          ? Text(data['area'] as String)
                          : null,
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedId == null
                      ? null
                      : () => Navigator.of(context).pop(selectedId),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
    if (!context.mounted || picked == null) return;
    final doc = globalShops.docs.firstWhere((d) => d.id == picked);
    final data = doc.data();
    final code = (data['code'] as String?) ?? doc.id;
    final name = (data['name'] as String?) ?? '';
    final area = (data['area'] as String?) ?? '';
    final tsaShopRef = FirebaseFirestore.instance
        .collection('seedTsas')
        .doc(tsaId)
        .collection('shops')
        .doc(doc.id);
    await tsaShopRef.set({
      'shopId': doc.id,
      'code': code,
      'name': name,
      if (area.isNotEmpty) 'area': area,
      if (data['location'] is Map) 'location': data['location'],
      'tsaId': tsaId,
      'source': 'global_shops',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    Get.snackbar(
      'Shop added',
      '$code added from existing shops',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> _openAddShopChoice(BuildContext context, String tsaId) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add shop'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('existing'),
            child: const ListTile(
              leading: Icon(Icons.store_mall_directory_outlined),
              title: Text('From existing shops'),
              subtitle: Text('Pick a shop already added in admin'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('new'),
            child: const ListTile(
              leading: Icon(Icons.add_location_alt_outlined),
              title: Text('Add new shop'),
              subtitle: Text('Create a new shop with location'),
            ),
          ),
        ],
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == 'existing') {
      await _addExistingShop(context, tsaId);
    } else if (choice == 'new') {
      await _createShop(context, tsaId);
    }
  }

  Future<Map<String, bool>?> _pickSchedule(
    BuildContext context,
    Map<String, bool> current,
  ) async {
    final working = Map<String, bool>.from(current);
    final result = await showDialog<Map<String, bool>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pick visiting days'),
          content: Wrap(
            spacing: 8,
            children: working.keys
                .map(
                  (d) => FilterChip(
                    label: Text(d.toUpperCase()),
                    selected: working[d] == true,
                    onSelected: (v) => working[d] = v,
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(working),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final args = (Get.arguments as Map?)?.cast<String, dynamic>() ?? const {};
    final tsaId = (args['tsaId'] as String?) ?? '';
    final tsaName = (args['tsaName'] as String?) ?? tsaId;

    if (tsaId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Missing tsaId')));
    }

    final shopsCol = FirebaseFirestore.instance
        .collection('seedTsas')
        .doc(tsaId)
        .collection('shops');

    return Scaffold(
      appBar: AppBar(
        title: Text(tsaName),
        actions: [
          IconButton(
            onPressed: () async {
              final dateKey = await _pickDateKey(context);
              if (dateKey == null) return;
              if (!context.mounted) return;
              await _assignShopsForDay(context, tsaId: tsaId, dateKey: dateKey);
            },
            icon: const Icon(Icons.event_available),
            tooltip: 'Assign shops for a day',
          ),
          IconButton(
            onPressed: () => authController.logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddShopChoice(context, tsaId),
        child: const Icon(Icons.add),
      ),
      body: AppShell(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: shopsCol.orderBy('code').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No shops found.'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _openAddShopChoice(context, tsaId),
                      icon: const Icon(Icons.add),
                      label: const Text('Add shop'),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final code = (data['code'] as String?) ?? doc.id;
                final name = (data['name'] as String?) ?? '';
                final area = (data['area'] as String?) ?? '';
                final title = '$code ${name.isEmpty ? '' : '• $name'}';

                return GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 46,
                        width: 46,
                        decoration: BoxDecoration(
                          color: AppTheme.warmSoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.store, color: AppTheme.warm),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (area.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                area,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Get.toNamed(
                          AppRoutes.seedShopDetail,
                          arguments: {
                            'tsaId': tsaId,
                            'shopId': doc.id,
                            'shopTitle': title,
                          },
                        ),
                        icon: const Icon(Icons.arrow_forward_ios, size: 18),
                      ),
                    ],
                  ),
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
  final String? dsfId;
  final Map<String, bool> schedule;

  const _CreateShopResult({
    required this.code,
    required this.name,
    required this.area,
    this.lat,
    this.lng,
    this.filer = false,
    this.dsfId,
    this.schedule = const {},
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
                hintText: 'Search location',
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
