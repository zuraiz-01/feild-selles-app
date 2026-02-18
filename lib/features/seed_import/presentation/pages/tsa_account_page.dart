import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:convert';

import '../../data/dsf_account_service.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../../core/utils/map_location_url_parser.dart';
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
    return _RecentOfficeLocation(lat: lat, lng: lng, radiusMeters: radius);
  }
}

class _OfficePickResult {
  final LatLng center;
  final double radiusMeters;

  const _OfficePickResult({required this.center, required this.radiusMeters});
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
    if (await _tryMoveToSharedLocation(trimmed)) return;

    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'json',
        'q': trimmed,
        'limit': '5',
      });
      final response = await http.get(
        uri,
        headers: const {'User-Agent': 'field_sales_app/1.0 (map picker)'},
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

  Future<bool> _tryMoveToSharedLocation(String raw) async {
    final parsed = await MapLocationUrlParser.tryParseSmart(raw);
    if (parsed == null) return false;
    setState(() {
      _center = LatLng(parsed.lat, parsed.lng);
      _searchResults = [];
      _searchError = null;
    });
    _mapController.move(_center, 15);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.75;
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
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
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
                          color: AppTheme.accent.withValues(alpha: 0.15),
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
  static const int _defaultShopWaitSeconds = 300;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _distributorId = TextEditingController();
  final _officeLat = TextEditingController();
  final _officeLng = TextEditingController();
  final _officeRadius = TextEditingController();
  final _shopWaitMinutes = TextEditingController();
  final _shopWaitSeconds = TextEditingController();
  final _imagePicker = ImagePicker();

  bool _isWorking = false;
  bool _isEditMode = false;
  bool _isPhotoUploading = false;
  String? _status;
  DsfAccount? _lastAccount;
  bool _showCredentialPassword = false;
  bool _showFormPassword = false;
  String? _photoUrl;
  bool _removePhotoOnSave = false;
  Map<String, String>? _editSnapshot;
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
    _shopWaitMinutes.dispose();
    _shopWaitSeconds.dispose();
    super.dispose();
  }

  void _setWaitControllersFromTotalSeconds(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    _shopWaitMinutes.text = (safe ~/ 60).toString();
    _shopWaitSeconds.text = (safe % 60).toString().padLeft(2, '0');
  }

  int? _readWaitSecondsFromInputs() {
    final min = int.tryParse(_shopWaitMinutes.text.trim());
    final sec = int.tryParse(_shopWaitSeconds.text.trim());
    if (min == null || sec == null) return null;
    if (min < 0 || sec < 0 || sec > 59) return null;
    return (min * 60) + sec;
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

  Widget _buildProfileAvatar({double size = 56}) {
    final url = _photoUrl?.trim();
    final hasPhoto = url != null && url.isNotEmpty;
    final borderRadius = BorderRadius.circular(size / 2.5);
    if (!hasPhoto) {
      return Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: AppTheme.skySoft,
          borderRadius: borderRadius,
        ),
        child: const Icon(Icons.person, color: AppTheme.sky),
      );
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        url,
        height: size,
        width: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          decoration: BoxDecoration(
            color: AppTheme.skySoft,
            borderRadius: borderRadius,
          ),
          child: const Icon(Icons.person, color: AppTheme.sky),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadProfilePhoto({required String tsaId}) async {
    if (_isPhotoUploading) return;
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1280,
    );
    if (picked == null) return;

    setState(() {
      _isPhotoUploading = true;
      _status = null;
    });
    try {
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        throw StateError('Selected image is empty.');
      }
      final ref = FirebaseStorage.instance.ref().child(
        'dsf_profiles/$tsaId/profile.jpg',
      );
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      setState(() {
        _photoUrl = url;
        _removePhotoOnSave = false;
        _status = _lastAccount == null
            ? 'Photo attached. Create account to save it.'
            : 'Photo ready. Press Update to save changes.';
      });
    } catch (e) {
      setState(() {
        _status = 'Photo upload failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPhotoUploading = false;
        });
      }
    }
  }

  Future<void> _removeProfilePhoto({required bool hasExistingAccount}) async {
    final current = _photoUrl?.trim();
    if (current == null || current.isEmpty) return;
    if (_isPhotoUploading) return;

    setState(() {
      _isPhotoUploading = true;
      _status = null;
    });
    try {
      try {
        await FirebaseStorage.instance.refFromURL(current).delete();
      } catch (_) {
        // ignore storage deletion errors; Firestore value removal is enough
      }
      setState(() {
        _photoUrl = null;
        _removePhotoOnSave = hasExistingAccount;
        _status = hasExistingAccount
            ? 'Photo removed. Press Update to save changes.'
            : 'Photo removed.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPhotoUploading = false;
        });
      }
    }
  }

  void _captureEditSnapshot() {
    _editSnapshot = {
      'name': _name.text,
      'email': _email.text,
      'password': _password.text,
      'distributorId': _distributorId.text,
      'photoUrl': _photoUrl ?? '',
      'removePhotoOnSave': _removePhotoOnSave ? '1' : '0',
      'officeLat': _officeLat.text,
      'officeLng': _officeLng.text,
      'officeRadius': _officeRadius.text,
      'waitMinutes': _shopWaitMinutes.text,
      'waitSeconds': _shopWaitSeconds.text,
    };
  }

  void _restoreEditSnapshot() {
    final snap = _editSnapshot;
    if (snap == null) return;
    _name.text = snap['name'] ?? '';
    _email.text = snap['email'] ?? '';
    _password.text = snap['password'] ?? '';
    _distributorId.text = snap['distributorId'] ?? '';
    _photoUrl = (snap['photoUrl'] ?? '').trim().isEmpty
        ? null
        : snap['photoUrl'];
    _removePhotoOnSave = snap['removePhotoOnSave'] == '1';
    _officeLat.text = snap['officeLat'] ?? '';
    _officeLng.text = snap['officeLng'] ?? '';
    _officeRadius.text = snap['officeRadius'] ?? '';
    _shopWaitMinutes.text = snap['waitMinutes'] ?? '';
    _shopWaitSeconds.text = snap['waitSeconds'] ?? '';
  }

  void _enterEditMode() {
    setState(() {
      _captureEditSnapshot();
      _status = null;
      _isEditMode = true;
      _showFormPassword = false;
    });
  }

  void _cancelEditMode() {
    setState(() {
      _restoreEditSnapshot();
      _status = null;
      _isEditMode = false;
      _showFormPassword = false;
    });
  }

  void _syncControllers({
    required String tsaId,
    required String tsaName,
    DsfAccount? account,
  }) {
    if (account != null) {
      final hasChanged =
          _lastAccount == null ||
          _lastAccount!.uid != account.uid ||
          _lastAccount!.email != account.email ||
          _lastAccount!.password != account.password ||
          _lastAccount!.name != account.name ||
          _lastAccount!.distributorId != account.distributorId ||
          _lastAccount!.photoUrl != account.photoUrl ||
          _lastAccount!.shopVisitWaitSeconds != account.shopVisitWaitSeconds;
      if (hasChanged && !_isEditMode) {
        _name.text = account.name.isEmpty ? tsaName : account.name;
        _email.text = account.email;
        if (account.password.isNotEmpty || _password.text.trim().isEmpty) {
          _password.text = account.password;
        }
        _distributorId.text = account.distributorId.isEmpty
            ? tsaId
            : account.distributorId;
        _photoUrl = account.photoUrl;
        _removePhotoOnSave = false;
        _setWaitControllersFromTotalSeconds(
          account.shopVisitWaitSeconds ?? _defaultShopWaitSeconds,
        );
      }
      _lastAccount = account;
      if (!_isEditMode) {
        _loadOfficeGeofence(_distributorId.text.trim());
      }
      return;
    }

    if (_lastAccount == null) {
      _name.text = tsaName;
      _email.text = _service.emailForTsa(tsaId);
      _password.text = '';
      _distributorId.text = tsaId;
      _photoUrl = null;
      _removePhotoOnSave = false;
      _setWaitControllersFromTotalSeconds(_defaultShopWaitSeconds);
      if (!_isEditMode) {
        _loadOfficeGeofence(_distributorId.text.trim());
      }
    }
  }

  Future<void> _create({required String tsaId, required String tsaName}) async {
    final officeLat = double.tryParse(_officeLat.text.trim());
    final officeLng = double.tryParse(_officeLng.text.trim());
    final officeRadius = double.tryParse(_officeRadius.text.trim());
    if (officeLat == null || officeLng == null || officeRadius == null) {
      setState(() {
        _status = 'Office geofence (lat/lng/radius) is required.';
      });
      return;
    }
    final shopWaitSeconds = _readWaitSecondsFromInputs();
    if (shopWaitSeconds == null) {
      setState(() {
        _status =
            'Shop wait time is invalid. Use minutes >= 0 and seconds 0..59.';
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
        photoUrl: _photoUrl,
        officeLat: officeLat,
        officeLng: officeLng,
        officeRadiusMeters: officeRadius,
        shopVisitWaitSeconds: shopWaitSeconds,
      );
      _status = 'Created DSF: ${account.email}';
      _isEditMode = false;
      _removePhotoOnSave = false;
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
      final password = _password.text.trim();
      if (officeLat == null || officeLng == null || officeRadius == null) {
        setState(() {
          _status = 'Office geofence (lat/lng/radius) is required.';
        });
        return;
      }
      if (password.isEmpty) {
        setState(() {
          _status = 'Password is required.';
        });
        return;
      }
      final shopWaitSeconds = _readWaitSecondsFromInputs();
      if (shopWaitSeconds == null) {
        setState(() {
          _status =
              'Shop wait time is invalid. Use minutes >= 0 and seconds 0..59.';
        });
        return;
      }
      final account = await _service.updateAccount(
        tsaId: tsaId,
        name: _name.text,
        email: _email.text,
        password: password,
        distributorId: _distributorId.text,
        photoUrl: _photoUrl,
        clearPhoto: _removePhotoOnSave,
        officeLat: officeLat,
        officeLng: officeLng,
        officeRadiusMeters: officeRadius,
        shopVisitWaitSeconds: shopWaitSeconds,
      );
      _status = 'Updated DSF: ${account.email}';
      _isEditMode = false;
      _removePhotoOnSave = false;
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
      _isEditMode = false;
      _photoUrl = null;
      _removePhotoOnSave = false;
    } catch (e) {
      _status = 'Delete failed: $e';
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  Future<void> _confirmDelete({required String tsaId}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete DSF account'),
        content: const Text(
          'This will permanently delete this DSF login and profile. Continue?',
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
    if (ok != true) return;
    await _delete(tsaId: tsaId);
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Get.offAllNamed(AppRoutes.adminDashboard),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to dashboard',
        ),
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
            final isEditable = account == null || _isEditMode;

            return ListView(
              children: [
                SectionTitle(
                  title: 'TSA Profile',
                  subtitle: isEditable
                      ? 'Manage DSF credentials and access.'
                      : 'View-only mode. Press Edit to update account.',
                ),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          _buildProfileAvatar(size: 52),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tsaName,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'TSA ID: $tsaId',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (isEditable)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isPhotoUploading
                                  ? null
                                  : () => _pickAndUploadProfilePhoto(
                                      tsaId: tsaId,
                                    ),
                              icon: _isPhotoUploading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.photo_library_outlined),
                              label: Text(
                                _photoUrl == null ||
                                        (_photoUrl?.trim().isEmpty ?? true)
                                    ? 'Add photo'
                                    : 'Update photo',
                              ),
                            ),
                            if (_photoUrl != null &&
                                (_photoUrl?.trim().isNotEmpty ?? false))
                              OutlinedButton.icon(
                                onPressed: _isPhotoUploading
                                    ? null
                                    : () => _removeProfilePhoto(
                                        hasExistingAccount: account != null,
                                      ),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete photo'),
                              ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      ExpansionTile(
                        title: const Text('Credentials'),
                        childrenPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        children: [
                          SelectableText(
                            'Email: ${account?.email ?? _email.text}',
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  _showCredentialPassword
                                      ? 'Password: ${account?.password ?? _password.text}'
                                      : 'Password: ••••••••',
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _showCredentialPassword =
                                        !_showCredentialPassword;
                                  });
                                },
                                icon: Icon(
                                  _showCredentialPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                tooltip: _showCredentialPassword
                                    ? 'Hide password'
                                    : 'Show password',
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
                        readOnly: !isEditable,
                        decoration: const InputDecoration(
                          labelText: 'DSF name',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _email,
                        readOnly: !isEditable,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _password,
                        readOnly: !isEditable,
                        obscureText: !_showFormPassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _showFormPassword = !_showFormPassword;
                              });
                            },
                            icon: Icon(
                              _showFormPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            tooltip: _showFormPassword
                                ? 'Hide password'
                                : 'Show password',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _distributorId,
                        readOnly: !isEditable,
                        decoration: const InputDecoration(
                          labelText: 'Distributor ID',
                          prefixIcon: Icon(Icons.map_outlined),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _officeLat,
                        readOnly: !isEditable,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Office latitude',
                          prefixIcon: Icon(Icons.my_location),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _officeLng,
                        readOnly: !isEditable,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Office longitude',
                          prefixIcon: Icon(Icons.my_location),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _officeRadius,
                        readOnly: !isEditable,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Office radius (meters)',
                          prefixIcon: Icon(Icons.circle_outlined),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Shop arrival wait time',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _shopWaitMinutes,
                              readOnly: !isEditable,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Minutes',
                                prefixIcon: Icon(Icons.timer_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _shopWaitSeconds,
                              readOnly: !isEditable,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Seconds (0-59)',
                                prefixIcon: Icon(Icons.timelapse_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_recentLoaded && _recentLocations.isNotEmpty) ...[
                        DropdownButtonFormField<_RecentOfficeLocation>(
                          initialValue: _selectedRecent,
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
                            if (!isEditable) return;
                            if (value == null) return;
                            _applyRecent(value);
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      OutlinedButton.icon(
                        onPressed: isEditable
                            ? () => _openMapPicker(context)
                            : null,
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Pick on map'),
                      ),
                      const SizedBox(height: 12),
                      if (account == null)
                        ElevatedButton(
                          onPressed: _isWorking
                              ? null
                              : () => _create(tsaId: tsaId, tsaName: tsaName),
                          child: const Text('Create user account'),
                        )
                      else if (!isEditable)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isWorking ? null : _enterEditMode,
                                child: const Text('Edit'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isWorking
                                    ? null
                                    : () => _confirmDelete(tsaId: tsaId),
                                child: const Text('Delete'),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isWorking
                                    ? null
                                    : () => _update(tsaId: tsaId),
                                child: const Text('Update'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isWorking ? null : _cancelEditMode,
                                child: const Text('Cancel'),
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
