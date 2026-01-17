import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:convert';

import '../../data/dsf_account_service.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class TsaAccountPage extends StatefulWidget {
  const TsaAccountPage({super.key});

  @override
  State<TsaAccountPage> createState() => _TsaAccountPageState();
}

const String _recentLocationsKey = 'recent_office_locations_v1';

class _RecentOfficeLocation {
  final double lat;
  final double lng;
  final double radiusMeters;

  const _RecentOfficeLocation({
    required this.lat,
    required this.lng,
    required this.radiusMeters,
  });

  String get label =>
      '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)} • ${radiusMeters.toStringAsFixed(0)}m';

  bool matches(_RecentOfficeLocation other) {
    return (lat - other.lat).abs() < 0.000001 &&
        (lng - other.lng).abs() < 0.000001 &&
        (radiusMeters - other.radiusMeters).abs() < 0.1;
  }

  String toStorage() {
    return '${lat.toStringAsFixed(6)}|${lng.toStringAsFixed(6)}|${radiusMeters.toStringAsFixed(1)}';
  }

  static _RecentOfficeLocation? fromStorage(String value) {
    final parts = value.split('|');
    if (parts.length != 3) return null;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    final radius = double.tryParse(parts[2]);
    if (lat == null || lng == null || radius == null) return null;
    return _RecentOfficeLocation(
      lat: lat,
      lng: lng,
      radiusMeters: radius,
    );
  }
}

class _OfficePickResult {
  final LatLng center;
  final double radiusMeters;

  const _OfficePickResult({
    required this.center,
    required this.radiusMeters,
  });
}

class _OfficeMapPickerSheet extends StatefulWidget {
  final LatLng initialCenter;
  final double initialRadius;

  const _OfficeMapPickerSheet({
    required this.initialCenter,
    required this.initialRadius,
  });

  @override
  State<_OfficeMapPickerSheet> createState() => _OfficeMapPickerSheetState();
}

class _OfficeMapPickerSheetState extends State<_OfficeMapPickerSheet> {
  late LatLng _center;
  late double _radius;
  final _mapController = MapController();
  final _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isLocating = false;
  String? _searchError;
  List<_PlaceResult> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _center = widget.initialCenter;
    _radius = widget.initialRadius;
    _searchController.addListener(() {
      setState(() {});
    });
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
        _searchResults = [];
        _searchError = null;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {
          'format': 'json',
          'q': trimmed,
          'limit': '5',
        },
      );
      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'field_sales_app/1.0 (map picker)',
        },
      );
      if (response.statusCode != 200) {
        throw StateError('Search failed (${response.statusCode}).');
      }
      final raw = jsonDecode(response.body);
      if (raw is! List) {
        throw StateError('Unexpected search response.');
      }
      final results = <_PlaceResult>[];
      for (final item in raw) {
        final parsed = _PlaceResult.fromJson(item);
        if (parsed != null) {
          results.add(parsed);
        }
      }
      setState(() {
        _searchResults = results;
        _searchError = results.isEmpty ? 'No results found.' : null;
      });
    } catch (e) {
      setState(() {
        _searchError = 'Search failed. Try again.';
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
      _searchError = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _searchError = 'Location permission denied.';
        });
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
        _searchResults = [];
      });
      _mapController.move(_center, 15);
    } catch (_) {
      setState(() {
        _searchError = 'Unable to get current location.';
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
      _searchResults = [];
      _searchError = null;
    });
    _mapController.move(_center, 15);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.75;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pick office location',
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
                                _searchResults = [];
                                _searchError = null;
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
            if (_searchError != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _searchError!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            if (_searchResults.isNotEmpty) ...[
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
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final place = _searchResults[index];
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
            const SizedBox(height: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 14,
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
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _center,
                          color: AppTheme.accent.withOpacity(0.15),
                          borderColor: AppTheme.accent,
                          borderStrokeWidth: 2,
                          radius: _radius,
                          useRadiusInMeter: true,
                        ),
                      ],
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
            Row(
              children: [
                const Text(
                  'Radius',
                  style: TextStyle(color: AppTheme.mutedInk),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _radius.clamp(50, 2000),
                    min: 50,
                    max: 2000,
                    divisions: 39,
                    label: '${_radius.toStringAsFixed(0)} m',
                    onChanged: (value) {
                      setState(() {
                        _radius = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(
                  _OfficePickResult(center: _center, radiusMeters: _radius),
                );
              },
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

class _TsaAccountPageState extends State<TsaAccountPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _distributorId = TextEditingController();
  final _officeLat = TextEditingController();
  final _officeLng = TextEditingController();
  final _officeRadius = TextEditingController();

  bool _isWorking = false;
  String? _status;
  DsfAccount? _lastAccount;
  bool _showPassword = false;
  String? _loadedOfficeFor;
  final List<_RecentOfficeLocation> _recentLocations = [];
  _RecentOfficeLocation? _selectedRecent;
  bool _recentLoaded = false;

  DsfAccountService get _service => Get.find<DsfAccountService>();

  @override
  void initState() {
    super.initState();
    _loadRecentLocations();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _distributorId.dispose();
    _officeLat.dispose();
    _officeLng.dispose();
    _officeRadius.dispose();
    super.dispose();
  }

  Future<void> _loadOfficeGeofence(String distributorId) async {
    if (distributorId.isEmpty) return;
    if (_loadedOfficeFor == distributorId) return;
    _loadedOfficeFor = distributorId;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('distributors')
          .doc(distributorId)
          .get();
      final data = doc.data();
      if (data == null) return;
      final office = data['officeGeofence'];
      if (office is! Map<String, dynamic>) return;
      final center = office['center'];
      final radiusMeters = office['radiusMeters'];
      if (center is! Map<String, dynamic> || radiusMeters is! num) return;
      final lat = center['lat'];
      final lng = center['lng'];
      if (lat is! num || lng is! num) return;
      if (_officeLat.text.trim().isEmpty) {
        _officeLat.text = lat.toString();
      }
      if (_officeLng.text.trim().isEmpty) {
        _officeLng.text = lng.toString();
      }
      if (_officeRadius.text.trim().isEmpty) {
        _officeRadius.text = radiusMeters.toString();
      }
    } catch (_) {
      // ignore; optional prefill
    }
  }

  Future<void> _loadRecentLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_recentLocationsKey) ?? <String>[];
    final parsed = <_RecentOfficeLocation>[];
    for (final entry in raw) {
      final item = _RecentOfficeLocation.fromStorage(entry);
      if (item != null) {
        parsed.add(item);
      }
    }
    setState(() {
      _recentLocations
        ..clear()
        ..addAll(parsed);
      _recentLoaded = true;
      if (_recentLocations.isNotEmpty) {
        _selectedRecent = _recentLocations.first;
      }
    });
  }

  Future<void> _saveRecentLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = _recentLocations.map((e) => e.toStorage()).toList();
    await prefs.setStringList(_recentLocationsKey, serialized);
  }

  Future<void> _addRecentLocation(_RecentOfficeLocation location) async {
    _recentLocations.removeWhere((item) => item.matches(location));
    _recentLocations.insert(0, location);
    if (_recentLocations.length > 8) {
      _recentLocations.removeLast();
    }
    _selectedRecent = location;
    await _saveRecentLocations();
    setState(() {});
  }

  void _applyRecent(_RecentOfficeLocation location) {
    setState(() {
      _selectedRecent = location;
      _officeLat.text = location.lat.toStringAsFixed(6);
      _officeLng.text = location.lng.toStringAsFixed(6);
      _officeRadius.text = location.radiusMeters.toStringAsFixed(0);
    });
  }

  Future<void> _openMapPicker(BuildContext context) async {
    final initialLat = double.tryParse(_officeLat.text.trim()) ?? 23.8103;
    final initialLng = double.tryParse(_officeLng.text.trim()) ?? 90.4125;
    final initialRadius = double.tryParse(_officeRadius.text.trim()) ?? 250;

    final result = await showModalBottomSheet<_OfficePickResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OfficeMapPickerSheet(
        initialCenter: LatLng(initialLat, initialLng),
        initialRadius: initialRadius,
      ),
    );

    if (result == null) return;
    await _addRecentLocation(
      _RecentOfficeLocation(
        lat: result.center.latitude,
        lng: result.center.longitude,
        radiusMeters: result.radiusMeters,
      ),
    );
    setState(() {
      _officeLat.text = result.center.latitude.toStringAsFixed(6);
      _officeLng.text = result.center.longitude.toStringAsFixed(6);
      _officeRadius.text = result.radiusMeters.toStringAsFixed(0);
    });
  }

  void _syncControllers({
    required String tsaId,
    required String tsaName,
    DsfAccount? account,
  }) {
    if (account != null) {
      final hasChanged = _lastAccount == null ||
          _lastAccount!.uid != account.uid ||
          _lastAccount!.email != account.email ||
          _lastAccount!.password != account.password ||
          _lastAccount!.name != account.name ||
          _lastAccount!.distributorId != account.distributorId;
      if (hasChanged) {
        _name.text = account.name.isEmpty ? tsaName : account.name;
        _email.text = account.email;
        _password.text = account.password;
        _distributorId.text =
            account.distributorId.isEmpty ? tsaId : account.distributorId;
      }
      _lastAccount = account;
      return;
    }

    if (_lastAccount == null) {
      _name.text = tsaName;
      _email.text = _service.emailForTsa(tsaId);
      _password.text = _service.generatePassword();
      _distributorId.text = tsaId;
    }
  }

  Future<void> _create({
    required String tsaId,
    required String tsaName,
  }) async {
    final officeLat = double.tryParse(_officeLat.text.trim());
    final officeLng = double.tryParse(_officeLng.text.trim());
    final officeRadius = double.tryParse(_officeRadius.text.trim());
    if (officeLat == null || officeLng == null || officeRadius == null) {
      setState(() {
        _status = 'Office geofence (lat/lng/radius) is required.';
      });
      return;
    }
    setState(() {
      _isWorking = true;
      _status = null;
    });
    try {
      final account = await _service.createAccount(
        tsaId: tsaId,
        name: _name.text,
        email: _email.text,
        password: _password.text,
        distributorId: _distributorId.text,
        officeLat: officeLat,
        officeLng: officeLng,
        officeRadiusMeters: officeRadius,
      );
      _status = 'Created DSF: ${account.email}';
    } catch (e) {
      _status = 'Create failed: $e';
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  Future<void> _update({required String tsaId}) async {
    setState(() {
      _isWorking = true;
      _status = null;
    });
    try {
      final officeLat = double.tryParse(_officeLat.text.trim());
      final officeLng = double.tryParse(_officeLng.text.trim());
      final officeRadius = double.tryParse(_officeRadius.text.trim());
      final account = await _service.updateAccount(
        tsaId: tsaId,
        name: _name.text,
        email: _email.text,
        password: _password.text,
        distributorId: _distributorId.text,
        officeLat: officeLat,
        officeLng: officeLng,
        officeRadiusMeters: officeRadius,
      );
      _status = 'Updated DSF: ${account.email}';
    } catch (e) {
      _status = 'Update failed: $e';
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  Future<void> _delete({required String tsaId}) async {
    setState(() {
      _isWorking = true;
      _status = null;
    });
    try {
      await _service.deleteAccount(tsaId: tsaId);
      _status = 'Deleted DSF account for TSA';
      _lastAccount = null;
    } catch (e) {
      _status = 'Delete failed: $e';
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
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

    _loadOfficeGeofence(_distributorId.text.trim());

    return Scaffold(
      appBar: AppBar(
        title: Text(tsaName),
        actions: [
          IconButton(
            onPressed: () => authController.logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: AppShell(
        child: StreamBuilder<DsfAccount?>(
          stream: _service.watchByTsaId(tsaId),
          builder: (context, snapshot) {
            final account = snapshot.data;
            _syncControllers(tsaId: tsaId, tsaName: tsaName, account: account);

            return ListView(
              children: [
                SectionTitle(
                  title: 'TSA Profile',
                  subtitle: 'Manage DSF credentials and access.',
                ),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 46,
                            width: 46,
                            decoration: BoxDecoration(
                              color: AppTheme.skySoft,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.person, color: AppTheme.sky),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tsaName, style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text('TSA ID: $tsaId', style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ExpansionTile(
                        title: const Text('Credentials'),
                        childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
                        children: [
                          SelectableText('Email: ${account?.email ?? _email.text}'),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  _showPassword
                                      ? 'Password: ${account?.password ?? _password.text}'
                                      : 'Password: ••••••••',
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _showPassword = !_showPassword;
                                  });
                                },
                                icon: Icon(
                                  _showPassword ? Icons.visibility_off : Icons.visibility,
                                ),
                                tooltip:
                                    _showPassword ? 'Hide password' : 'Show password',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'DSF name',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _password,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _password.text = _service.generatePassword();
                                  });
                                },
                                icon: const Icon(Icons.refresh),
                                tooltip: 'Generate random password',
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _showPassword = !_showPassword;
                                  });
                                },
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                tooltip:
                                    _showPassword ? 'Hide password' : 'Show password',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _distributorId,
                        decoration: const InputDecoration(
                          labelText: 'Distributor ID',
                          prefixIcon: Icon(Icons.map_outlined),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _officeLat,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Office latitude',
                          prefixIcon: Icon(Icons.my_location),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _officeLng,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Office longitude',
                          prefixIcon: Icon(Icons.my_location),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _officeRadius,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Office radius (meters)',
                          prefixIcon: Icon(Icons.circle_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_recentLoaded && _recentLocations.isNotEmpty) ...[
                        DropdownButtonFormField<_RecentOfficeLocation>(
                          value: _selectedRecent,
                          decoration: const InputDecoration(
                            labelText: 'Recent locations',
                            prefixIcon: Icon(Icons.history),
                          ),
                          items: _recentLocations
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            _applyRecent(value);
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      OutlinedButton.icon(
                        onPressed: () => _openMapPicker(context),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Pick on map'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isWorking
                                  ? null
                                  : account == null
                                      ? () =>
                                          _create(tsaId: tsaId, tsaName: tsaName)
                                      : () => _update(tsaId: tsaId),
                              child: Text(account == null ? 'Create' : 'Update'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isWorking || account == null
                                  ? null
                                  : () => _delete(tsaId: tsaId),
                              child: const Text('Delete'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => Get.toNamed(
                    AppRoutes.seedTsaDetail,
                    arguments: {'tsaId': tsaId, 'tsaName': tsaName},
                  ),
                  icon: const Icon(Icons.storefront),
                  label: const Text('View Shops'),
                ),
                if (_isWorking) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (_status != null) ...[
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _status!,
                      style: const TextStyle(color: AppTheme.mutedInk),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
