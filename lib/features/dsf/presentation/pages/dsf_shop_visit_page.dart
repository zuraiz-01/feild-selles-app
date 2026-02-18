import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_toast.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../../app/ui/theme_mode_toggle_button.dart';
import '../../../../core/services/session/session_service.dart';

class DsfShopVisitPage extends StatefulWidget {
  const DsfShopVisitPage({super.key});

  @override
  State<DsfShopVisitPage> createState() => _DsfShopVisitPageState();
}

class _DsfShopVisitPageState extends State<DsfShopVisitPage> {
  Duration _minVisitDuration = const Duration(minutes: 5);
  double? _requiredDistanceMeters;

  final _paymentController = TextEditingController();
  final _notesController = TextEditingController();
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _stockItems = [];
  bool _hasStock = false;
  String _paymentType = 'cash';
  XFile? _chequeImage;

  StreamSubscription<Position>? _posSub;
  Timer? _ticker;

  Position? _position;
  DateTime? _visitStartedAt;
  String? _error;
  bool _isSaving = false;

  void _setStateSafe(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _loadDsfVisitConfig();
    _startTracking();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _posSub?.cancel();
    _paymentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _resolveDsfAccountDoc(
    String uid,
  ) async {
    final col = FirebaseFirestore.instance.collection('dsfAccounts');
    final direct = await col.doc(uid).get();
    if (direct.exists) return direct;
    final byUid = await col.where('uid', isEqualTo: uid).limit(1).get();
    if (byUid.docs.isNotEmpty) return byUid.docs.first;
    return null;
  }

  Future<void> _loadDsfVisitConfig() async {
    try {
      final session = Get.find<SessionService>();
      final profile = session.profile;
      if (profile == null) return;
      final dsfDoc = await _resolveDsfAccountDoc(profile.uid);
      final data = dsfDoc?.data();
      final geo = data?['geofence'];
      final rad = (geo is Map && geo['radiusMeters'] is num)
          ? (geo['radiusMeters'] as num).toDouble()
          : null;
      final waitSecondsRaw = _readInt(data?['shopVisitWaitSeconds']);
      final waitDuration = Duration(
        seconds: (waitSecondsRaw != null && waitSecondsRaw >= 0)
            ? waitSecondsRaw
            : 300,
      );
      _setStateSafe(() {
        _requiredDistanceMeters = rad ?? 120;
        _minVisitDuration = waitDuration;
      });
    } catch (_) {
      _setStateSafe(() {
        _requiredDistanceMeters = 120;
        _minVisitDuration = const Duration(minutes: 5);
      });
    }
  }

  Future<void> _startTracking() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setStateSafe(() => _error = 'Location service is off.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setStateSafe(() => _error = 'Location permission denied.');
        return;
      }
      final settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
      _posSub = Geolocator.getPositionStream(locationSettings: settings).listen(
        (pos) {
          if (!mounted) return;
          setState(() {
            _position = pos;
            _error = null;
          });
        },
        onError: (_) =>
            _setStateSafe(() => _error = 'Unable to track location.'),
      );
      final initial = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _setStateSafe(() => _position = initial);
    } catch (_) {
      _setStateSafe(() => _error = 'Unable to access location.');
    }
  }

  Duration _elapsed() {
    final start = _visitStartedAt;
    if (start == null) return Duration.zero;
    return DateTime.now().difference(start);
  }

  Duration _remaining() {
    final remaining = _minVisitDuration - _elapsed();
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String _formatMmSs(Duration d) {
    final total = d.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatWaitDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes > 0 && seconds > 0) return '${minutes}m ${seconds}s';
    if (minutes > 0) return '${minutes}m';
    return '${seconds}s';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = _twoDigits(local.month);
    final d = _twoDigits(local.day);
    final hh = _twoDigits(local.hour);
    final mm = _twoDigits(local.minute);
    return '$y-$m-$d $hh:$mm';
  }

  DateTime? _readDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  bool _isVisitSubmitted(Map<String, dynamic>? visitData) {
    if (visitData == null) return false;
    return visitData['submittedAt'] != null;
  }

  double? _distanceToShopMeters(Map<String, dynamic>? shopData) {
    final pos = _position;
    if (pos == null) return null;
    if (shopData == null) return null;
    final loc = shopData['location'];
    if (loc is! Map) return null;
    final lat = loc['lat'];
    final lng = loc['lng'];
    if (lat is! num || lng is! num) return null;
    return Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      lat.toDouble(),
      lng.toDouble(),
    );
  }

  bool _isInside(double? distanceMeters) {
    if (distanceMeters == null) return false;
    final req = _requiredDistanceMeters ?? 120;
    return distanceMeters <= req;
  }

  void _maybeStartTimer(double? distanceMeters) {
    if (_visitStartedAt != null) return;
    if (!_isInside(distanceMeters)) return;
    _visitStartedAt = DateTime.now();
  }

  Future<void> _openOrderPage() async {
    final result = await Get.toNamed(
      AppRoutes.dsfAddOrder,
      arguments: {'existing': _orders},
    );
    if (result is! List) return;
    final normalized = <Map<String, dynamic>>[];
    for (final item in result) {
      if (item is Map) {
        normalized.add(item.cast<String, dynamic>());
      }
    }
    _setStateSafe(() => _orders = normalized);
  }

  Future<void> _openStockDialog() async {
    final result = await Get.toNamed(
      AppRoutes.dsfAddStock,
      arguments: {'existing': _stockItems},
    );
    if (result is! List) return;
    final normalized = <Map<String, dynamic>>[];
    for (final item in result) {
      if (item is Map) normalized.add(item.cast<String, dynamic>());
    }
    _setStateSafe(() {
      _stockItems = normalized;
      _hasStock = _stockItems.isNotEmpty;
    });
  }

  Future<void> _openRecoveryDialog() async {
    final amountController = TextEditingController(
      text: _paymentController.text,
    );
    String paymentType = _paymentType;
    XFile? chequeImage = _chequeImage;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Add recovery'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: paymentType,
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      paymentType = v;
                      if (paymentType == 'cash') chequeImage = null;
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: paymentType == 'cash'
                        ? 'Cash amount'
                        : 'Cheque amount',
                  ),
                ),
                if (paymentType == 'cheque') ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await ImagePicker().pickImage(
                        source: ImageSource.camera,
                      );
                      if (picked != null) {
                        setState(() => chequeImage = picked);
                      }
                    },
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(
                      chequeImage == null ? 'Add cheque photo' : 'Change photo',
                    ),
                  ),
                  if (chequeImage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Attached: ${chequeImage!.name}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
    if (ok == true) {
      _setStateSafe(() {
        _paymentType = paymentType;
        _chequeImage = chequeImage;
        _paymentController.text = amountController.text.trim();
      });
    }
  }

  Future<void> _saveVisit({
    required String dutyId,
    required String dsfId,
    required String distributorId,
    required String tsaId,
    required String shopId,
    required String shopTitle,
    required double? distanceMeters,
    required bool filer,
    required double discountPct,
  }) async {
    if (_orders.isEmpty) {
      AppToast.warning('Missing data', message: 'Add at least one order.');
      return;
    }
    if (!_hasStock || _stockItems.isEmpty) {
      AppToast.warning('Missing data', message: 'Add current stock.');
      return;
    }
    final amount = double.tryParse(_paymentController.text.trim());
    if (amount == null) {
      AppToast.warning(
        'Missing data',
        message: 'Add recovery amount (number).',
      );
      return;
    }
    if (_elapsed() < _minVisitDuration) {
      AppToast.warning(
        'Wait required',
        message:
            'You can submit after ${_formatWaitDuration(_minVisitDuration)}.',
      );
      return;
    }
    if (!_isInside(distanceMeters)) {
      AppToast.warning(
        'Not at shop',
        message: 'Move closer to the shop to submit.',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final pos = _position;
      final now = FieldValue.serverTimestamp();
      final ref = FirebaseFirestore.instance
          .collection('duties')
          .doc(dutyId)
          .collection('shopVisits')
          .doc(shopId);
      String? chequeUrl;
      if (_paymentType == 'cheque' && _chequeImage != null) {
        final uploadRef = FirebaseStorage.instance.ref().child(
          'cheques/$tsaId/$shopId/$dutyId.jpg',
        );
        await uploadRef.putData(await _chequeImage!.readAsBytes());
        chequeUrl = await uploadRef.getDownloadURL();
      }
      await ref.set({
        'dutyId': dutyId,
        'dsfId': dsfId,
        'distributorId': distributorId,
        'tsaId': tsaId,
        'shopId': shopId,
        'shopTitle': shopTitle,
        'orders': _orders,
        'stockItems': _stockItems,
        'recovery': {
          'type': _paymentType,
          'amount': amount,
          if (_paymentType == 'cheque') 'chequeImageUrl': chequeUrl,
        },
        'notes': _notesController.text.trim(),
        'visitStartedAt': _visitStartedAt?.toIso8601String(),
        'submittedAt': now,
        'filer': filer,
        'discountPct': discountPct,
        if (distanceMeters != null) 'distanceMeters': distanceMeters,
        if (pos != null)
          'submittedLocation': {'lat': pos.latitude, 'lng': pos.longitude},
      }, SetOptions(merge: true));
      try {
        await FirebaseFirestore.instance.collection('alerts').add({
          'type': 'shop_visit',
          'dutyId': dutyId,
          'dsfId': dsfId,
          'distributorId': distributorId,
          'shopId': shopId,
          'shopTitle': shopTitle,
          if (distanceMeters != null) 'distanceMeters': distanceMeters,
          if (pos != null) 'lat': pos.latitude,
          if (pos != null) 'lng': pos.longitude,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // ignore alert logging failures
      }
      AppToast.success('Saved', message: 'Visit submitted.');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      AppToast.error('Save failed', message: e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionService>();
    final profile = session.profile;
    final dutyId = session.activeDutyId;
    final args = (Get.arguments as Map?)?.cast<String, dynamic>() ?? const {};
    final tsaId = (args['tsaId'] as String?) ?? '';
    final shopId = (args['shopId'] as String?) ?? '';
    final shopTitle = (args['shopTitle'] as String?) ?? shopId;

    if (profile == null || dutyId == null) {
      return const Scaffold(
        body: Center(child: Text('No active duty. Start duty first.')),
      );
    }
    if (shopId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Missing shop info.')));
    }

    final shopRef = tsaId.isNotEmpty
        ? FirebaseFirestore.instance
              .collection('seedTsas')
              .doc(tsaId)
              .collection('shops')
              .doc(shopId)
        : FirebaseFirestore.instance.collection('shops').doc(shopId);
    final visitRef = FirebaseFirestore.instance
        .collection('duties')
        .doc(dutyId)
        .collection('shopVisits')
        .doc(shopId);

    return Scaffold(
      appBar: AppBar(
        title: Text(shopTitle),
        actions: const [ThemeModeToggleButton()],
      ),
      body: AppShell(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: shopRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final shopData = snapshot.data!.data();
            final filer = (shopData?['filer'] as bool?) ?? false;
            final discountEnabled =
                (shopData?['discountEnabled'] as bool?) ?? true;
            final storedDiscountPct = (shopData?['discountPct'] as num?)
                ?.toDouble();
            final fallbackDiscountPct = filer ? 0.05 : 0.025;
            final discountPct = discountEnabled
                ? (storedDiscountPct ?? fallbackDiscountPct)
                : 0.0;
            final discountLabel = discountEnabled
                ? '${(discountPct * 100).toStringAsFixed(1)}% discount'
                : 'Discount disabled';
            final distanceMeters = _distanceToShopMeters(shopData);

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: visitRef.snapshots(),
              builder: (context, visitSnapshot) {
                if (visitSnapshot.hasError) {
                  return Center(child: Text(visitSnapshot.error.toString()));
                }
                final visitData = visitSnapshot.data?.data();
                final alreadySubmitted = _isVisitSubmitted(visitData);
                final submittedAt = _readDate(visitData?['submittedAt']);
                if (!alreadySubmitted) {
                  _maybeStartTimer(distanceMeters);
                }

                final hasLocation = shopData?['location'] is Map;
                final actionsEnabled =
                    !alreadySubmitted &&
                    _elapsed() >= _minVisitDuration &&
                    !_isSaving;
                final canSubmit =
                    !alreadySubmitted &&
                    hasLocation &&
                    _elapsed() >= _minVisitDuration &&
                    _isInside(distanceMeters) &&
                    !_isSaving;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            filer
                                ? 'Filer shop ($discountLabel)'
                                : 'Non-filer ($discountLabel)',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Minimum wait: ${_formatWaitDuration(_minVisitDuration)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (alreadySubmitted)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accentSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                submittedAt == null
                                    ? 'Visit already submitted. Actions are locked.'
                                    : 'Visit already submitted on ${_formatDateTime(submittedAt)}. Actions are locked.',
                                style: const TextStyle(
                                  color: AppTheme.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (alreadySubmitted) const SizedBox(height: 8),
                          if (!hasLocation)
                            const Text(
                              'Shop location is missing. Ask admin to set location on map.',
                              style: TextStyle(color: Color(0xFFD05353)),
                            )
                          else ...[
                            Text(
                              _position == null
                                  ? 'Getting your location...'
                                  : 'Distance: ${distanceMeters?.toStringAsFixed(0) ?? '--'} m',
                              style: const TextStyle(color: AppTheme.mutedInk),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isInside(distanceMeters)
                                        ? AppTheme.accentSoft
                                        : AppTheme.warmSoft,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _isInside(distanceMeters)
                                        ? 'At shop'
                                        : 'Move closer',
                                    style: TextStyle(
                                      color: _isInside(distanceMeters)
                                          ? AppTheme.ink
                                          : AppTheme.ink,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _visitStartedAt == null
                                        ? 'Timer starts when you reach the shop.'
                                        : 'Time left: ${_formatMmSs(_remaining())}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: const TextStyle(color: Color(0xFFD05353)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView(
                        children: [
                          GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Actions',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: actionsEnabled
                                        ? _openOrderPage
                                        : null,
                                    child: const Text('Add order'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: actionsEnabled
                                        ? _openRecoveryDialog
                                        : null,
                                    child: const Text('Add recovery'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: actionsEnabled
                                        ? _openStockDialog
                                        : null,
                                    child: const Text('Add current stock'),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (_orders.isNotEmpty)
                                  Text(
                                    'Orders added: ${_orders.length}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                if (_hasStock)
                                  Text(
                                    'Stock items: ${_stockItems.length}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                if (_paymentController.text.trim().isNotEmpty)
                                  Text(
                                    'Recovery: ${_paymentType.toUpperCase()} ${_paymentController.text}'
                                    '${_paymentType == 'cheque' && _chequeImage != null ? ' (photo attached)' : ''}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _notesController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Notes (optional)',
                                  ),
                                  enabled: actionsEnabled,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: canSubmit
                                      ? () => _saveVisit(
                                          dutyId: dutyId,
                                          dsfId: profile.uid,
                                          distributorId: profile.distributorId,
                                          tsaId: tsaId,
                                          shopId: shopId,
                                          shopTitle: shopTitle,
                                          distanceMeters: distanceMeters,
                                          filer: filer,
                                          discountPct: discountPct,
                                        )
                                      : null,
                                  child: _isSaving
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          alreadySubmitted
                                              ? 'Already submitted'
                                              : (_elapsed() < _minVisitDuration
                                                    ? 'Wait ${_formatMmSs(_remaining())}'
                                                    : 'Submit'),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
