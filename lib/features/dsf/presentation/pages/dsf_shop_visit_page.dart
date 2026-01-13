import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../../../../app/ui/app_shell.dart';
import '../../../../app/ui/app_theme.dart';
import '../../../../core/services/session/session_service.dart';

class DsfShopVisitPage extends StatefulWidget {
  const DsfShopVisitPage({super.key});

  @override
  State<DsfShopVisitPage> createState() => _DsfShopVisitPageState();
}

class _DsfShopVisitPageState extends State<DsfShopVisitPage> {
  static const Duration _minVisitDuration = Duration(minutes: 10);
  static const double _requiredDistanceMeters = 120;

  final _stockController = TextEditingController();
  final _paymentController = TextEditingController();
  final _notesController = TextEditingController();

  StreamSubscription<Position>? _posSub;
  Timer? _ticker;

  Position? _position;
  DateTime? _visitStartedAt;
  String? _error;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
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
    _stockController.dispose();
    _paymentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _startTracking() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _error = 'Location service is off.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _error = 'Location permission denied.');
        return;
      }
      final settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
      _posSub = Geolocator.getPositionStream(locationSettings: settings).listen(
        (pos) {
          setState(() {
            _position = pos;
            _error = null;
          });
        },
        onError: (_) => setState(() => _error = 'Unable to track location.'),
      );
      final initial = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() => _position = initial);
    } catch (_) {
      setState(() => _error = 'Unable to access location.');
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
    return distanceMeters <= _requiredDistanceMeters;
  }

  void _maybeStartTimer(double? distanceMeters) {
    if (_visitStartedAt != null) return;
    if (!_isInside(distanceMeters)) return;
    _visitStartedAt = DateTime.now();
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
    final stock = double.tryParse(_stockController.text.trim());
    final payment = double.tryParse(_paymentController.text.trim());
    if (stock == null || payment == null) {
      Get.snackbar(
        'Missing data',
        'Enter stock and payment (numbers).',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (_elapsed() < _minVisitDuration) {
      Get.snackbar(
        'Wait required',
        'You can submit after ${_minVisitDuration.inMinutes} minutes.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (!_isInside(distanceMeters)) {
      Get.snackbar(
        'Not at shop',
        'Move closer to the shop to submit.',
        snackPosition: SnackPosition.BOTTOM,
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
      await ref.set({
        'dutyId': dutyId,
        'dsfId': dsfId,
        'distributorId': distributorId,
        'tsaId': tsaId,
        'shopId': shopId,
        'shopTitle': shopTitle,
        'stock': stock,
        'payment': payment,
        'notes': _notesController.text.trim(),
        'visitStartedAt': _visitStartedAt?.toIso8601String(),
        'submittedAt': now,
        'filer': filer,
        'discountPct': discountPct,
        if (distanceMeters != null) 'distanceMeters': distanceMeters,
        if (pos != null)
          'submittedLocation': {'lat': pos.latitude, 'lng': pos.longitude},
      }, SetOptions(merge: true));
      Get.snackbar(
        'Saved',
        'Visit submitted.',
        snackPosition: SnackPosition.BOTTOM,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      Get.snackbar(
        'Save failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
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

    return Scaffold(
      appBar: AppBar(title: Text(shopTitle)),
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
            final discountPct =
                (shopData?['discountPct'] as num?)?.toDouble() ?? (filer ? 0.05 : 0.025);
            final distanceMeters = _distanceToShopMeters(shopData);
            _maybeStartTimer(distanceMeters);

            final hasLocation = shopData?['location'] is Map;
            final canSubmit =
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
                          filer ? 'Filer shop (5% discount)' : 'Non-filer (2.5% discount)',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Minimum wait: ${_minVisitDuration.inMinutes} minutes',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      const SizedBox(height: 8),
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
                                style: Theme.of(context).textTheme.bodySmall,
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
                            TextField(
                              controller: _stockController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Current stock',
                              ),
                              enabled: _elapsed() >= _minVisitDuration,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _paymentController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Payment',
                              ),
                              enabled: _elapsed() >= _minVisitDuration,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _notesController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Notes (optional)',
                              ),
                              enabled: _elapsed() >= _minVisitDuration,
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
                                      _elapsed() < _minVisitDuration
                                          ? 'Wait ${_formatMmSs(_remaining())}'
                                          : 'Submit',
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
        ),
      ),
    );
  }
}
