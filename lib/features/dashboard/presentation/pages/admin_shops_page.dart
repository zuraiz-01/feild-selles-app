import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_theme.dart';

class AdminShopsPage extends StatelessWidget {
  const AdminShopsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final shopsCol = FirebaseFirestore.instance.collection('shops');
    return Scaffold(
      appBar: AppBar(title: const Text('Shops')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context, shopsCol: shopsCol),
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
              return const Center(child: Text('No shops yet.'));
            }
            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final code = (data['code'] as String?) ?? doc.id;
                final name = (data['name'] as String?) ?? '';
                final filer = (data['filer'] as bool?) ?? false;
                final discount = (data['discountPct'] as num?)?.toDouble();
                final assigned = (data['assignedDsfId'] as String?) ?? '';
                return GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('$code ${name.isEmpty ? '' : '- $name'}'),
                    subtitle: Text(
                      [
                        filer ? 'Filer' : 'Non-filer',
                        if (discount != null)
                          'Discount ${(discount * 100).toStringAsFixed(1)}%',
                        if (assigned.isNotEmpty) 'DSF $assigned',
                      ].join(' • '),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _openForm(
                        context,
                        shopsCol: shopsCol,
                        existingId: doc.id,
                        existing: data,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context, {
    required CollectionReference<Map<String, dynamic>> shopsCol,
    String? existingId,
    Map<String, dynamic>? existing,
  }) async {
    final dsfOptions = await _loadDsfs();
    final codeController = TextEditingController(
      text: existing?['code'] as String? ?? existingId ?? '',
    );
    final nameController = TextEditingController(
      text: existing?['name'] as String? ?? '',
    );
    final areaController = TextEditingController(
      text: existing?['area'] as String? ?? '',
    );
    final latController = TextEditingController(
      text: _readNum(existing, 'location.lat'),
    );
    final lngController = TextEditingController(
      text: _readNum(existing, 'location.lng'),
    );
    LatLng? picked;
    final initialLoc = _readLatLng(latController.text, lngController.text);
    final existingAssigned = (existing?['assignedDsfId'] as String?)?.trim();
    final existingAssignedUid = (existing?['assignedDsfUid'] as String?)
        ?.trim();
    String? selectedDsf = _resolveSelectedDsfId(
      dsfOptions,
      preferredId: existingAssigned,
      preferredUid: existingAssignedUid,
    );
    var schedule = Map<String, bool>.fromEntries(
      const [
        'mon',
        'tue',
        'wed',
        'thu',
        'fri',
        'sat',
        'sun',
      ].map((d) => MapEntry(d, (existing?['schedule'] as Map?)?[d] == true)),
    );
    bool filer = existing?['filer'] == true;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existingId == null ? 'Add shop' : 'Edit shop'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 460,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SectionCard(
                        child: Column(
                          children: [
                            TextField(
                              controller: codeController,
                              decoration: const InputDecoration(
                                labelText: 'Code',
                              ),
                              readOnly: existingId != null,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                              ),
                            ),
                            const SizedBox(height: 16),
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
                      _SectionCard(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: filer,
                          onChanged: (v) => setState(() => filer = v),
                          title: const Text('Filer (5% discount)'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SectionCard(
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
                                  initial: picked ?? initialLoc,
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
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              value:
                                  (selectedDsf != null &&
                                      dsfOptions.any(
                                        (o) => o.id == selectedDsf,
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
                                ...dsfOptions.map(
                                  (d) => DropdownMenuItem(
                                    value: d.id,
                                    child: Text(
                                      d.name.isNotEmpty
                                          ? '${d.name} (${d.id})'
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
                            const SizedBox(height: 6),
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final code = codeController.text.trim();
                    if (code.isEmpty) return;
                    if (selectedDsf != null &&
                        !schedule.values.any((v) => v == true)) {
                      final pickedSchedule = await _pickSchedule(
                        context,
                        schedule,
                      );
                      if (pickedSchedule == null ||
                          !pickedSchedule.values.any((v) => v == true)) {
                        return;
                      }
                      schedule = pickedSchedule;
                      setState(() {});
                    }
                    final payload = <String, dynamic>{
                      'code': code,
                      'name': nameController.text.trim(),
                      'area': areaController.text.trim(),
                      'filer': filer,
                      'discountPct': filer ? 0.05 : 0.025,
                      'assignedDsfId': selectedDsf ?? '',
                      'assignedDsfUid': _resolveSelectedDsfUid(
                        dsfOptions,
                        selectedDsf,
                      ),
                      'schedule': schedule,
                      'updatedAt': FieldValue.serverTimestamp(),
                    };
                    final lat = double.tryParse(latController.text.trim());
                    final lng = double.tryParse(lngController.text.trim());
                    if (lat != null && lng != null) {
                      payload['location'] = {'lat': lat, 'lng': lng};
                    }
                    if (existingId == null) {
                      payload['createdAt'] = FieldValue.serverTimestamp();
                    }
                    await shopsCol
                        .doc(existingId ?? code.toLowerCase())
                        .set(payload, SetOptions(merge: true));
                    if (context.mounted) Navigator.of(context).pop();
                    Get.snackbar(
                      'Saved',
                      'Shop $code saved',
                      snackPosition: SnackPosition.BOTTOM,
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
  }

  String _readNum(Map<String, dynamic>? data, String path) {
    if (data == null) return '';
    dynamic cur = data;
    for (final part in path.split('.')) {
      if (cur is Map && cur.containsKey(part)) {
        cur = cur[part];
      } else {
        return '';
      }
    }
    if (cur is num) return cur.toString();
    return '';
  }

  LatLng? _readLatLng(String lat, String lng) {
    final latVal = double.tryParse(lat);
    final lngVal = double.tryParse(lng);
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

  Future<List<_DsfOption>> _loadDsfs() async {
    final snap = await FirebaseFirestore.instance
        .collection('dsfAccounts')
        .orderBy('name')
        .get();
    return snap.docs
        .map(
          (d) => _DsfOption(
            id: d.id,
            name: (d.data()['name'] as String?)?.trim() ?? '',
            uid: (d.data()['uid'] as String?)?.trim() ?? d.id,
          ),
        )
        .toList();
  }

  String? _resolveSelectedDsfId(
    List<_DsfOption> options, {
    required String? preferredId,
    required String? preferredUid,
  }) {
    final id = preferredId?.trim();
    if (id != null && id.isNotEmpty) {
      final direct = options.any((o) => o.id == id);
      if (direct) return id;
      final byUid = options.where((o) => o.uid == id).toList();
      if (byUid.length == 1) return byUid.single.id;
    }
    final uid = preferredUid?.trim();
    if (uid != null && uid.isNotEmpty) {
      final byUid = options.where((o) => o.uid == uid).toList();
      if (byUid.length == 1) return byUid.single.id;
    }
    return null;
  }

  String _resolveSelectedDsfUid(List<_DsfOption> options, String? selectedId) {
    final id = selectedId?.trim();
    if (id == null || id.isEmpty) return '';
    final match = options.where((o) => o.id == id).toList();
    if (match.length == 1) return match.single.uid;
    return '';
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
                    onSelected: (v) {
                      working[d] = v;
                    },
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

  Widget _SectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _DsfOption {
  final String id;
  final String name;
  final String uid;

  const _DsfOption({required this.id, required this.name, required this.uid});
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
