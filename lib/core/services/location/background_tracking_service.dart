import 'dart:convert';
import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'location_service.dart';
import '../session/session_service.dart';
import '../../../features/tracking/data/datasources/tracking_remote_ds.dart';

class BackgroundTrackingService {
  static const _queuePrefix = 'trackingQueue_';

  final LocationService _locationService;
  final TrackingRemoteDataSource _remote;
  final SessionService _sessionService;

  StreamSubscription<Position>? _sub;
  bool _running = false;

  BackgroundTrackingService(
    this._locationService,
    this._remote,
    this._sessionService,
  );

  bool get isRunning => _running;

  Future<void> start({required String dutyId}) async {
    if (_running) return;

    final profile = _sessionService.profile;
    if (profile == null) {
      throw StateError('Cannot start tracking: no session');
    }

    _running = true;

    _sub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 25,
          ),
        ).listen((pos) {
          _handlePoint(
            dutyId: dutyId,
            dsfId: profile.uid,
            distributorId: profile.distributorId,
            lat: pos.latitude,
            lng: pos.longitude,
            recordedAtUtc: DateTime.now().toUtc(),
          );
        });

    final pos = await _locationService.getCurrentPosition();
    await _handlePoint(
      dutyId: dutyId,
      dsfId: profile.uid,
      distributorId: profile.distributorId,
      lat: pos.latitude,
      lng: pos.longitude,
      recordedAtUtc: DateTime.now().toUtc(),
    );
  }

  Future<void> stop({required String dutyId}) async {
    if (!_running) return;
    _running = false;

    await _sub?.cancel();
    _sub = null;

    await flushQueue(dutyId: dutyId);
    await _remote.markSessionEnded(dutyId: dutyId);
  }

  Future<void> flushQueue({required String dutyId}) async {
    final profile = _sessionService.profile;
    if (profile == null) return;

    final prefs = await SharedPreferences.getInstance();
    final key = '$_queuePrefix$dutyId';
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return;

    final list = jsonDecode(raw);
    if (list is! List) return;

    final remaining = <Map<String, dynamic>>[];

    for (final item in list) {
      if (item is! Map) continue;
      try {
        final lat = (item['lat'] as num).toDouble();
        final lng = (item['lng'] as num).toDouble();
        final recordedAt = DateTime.parse(
          item['recordedAtUtc'] as String,
        ).toUtc();

        await _remote.addPoint(
          dutyId: dutyId,
          dsfId: profile.uid,
          distributorId: profile.distributorId,
          lat: lat,
          lng: lng,
          recordedAtUtc: recordedAt,
        );
      } catch (_) {
        remaining.add(Map<String, dynamic>.from(item.cast<String, dynamic>()));
      }
    }

    await prefs.setString(key, jsonEncode(remaining));
  }

  Future<void> _handlePoint({
    required String dutyId,
    required String dsfId,
    required String distributorId,
    required double lat,
    required double lng,
    required DateTime recordedAtUtc,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_queuePrefix$dutyId';

    final point = {
      'lat': lat,
      'lng': lng,
      'recordedAtUtc': recordedAtUtc.toIso8601String(),
    };

    final existingRaw = prefs.getString(key);
    final list = <dynamic>[];
    if (existingRaw != null && existingRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(existingRaw);
        if (decoded is List) {
          list.addAll(decoded);
        }
      } catch (_) {}
    }
    list.add(point);
    await prefs.setString(key, jsonEncode(list));

    try {
      await flushQueue(dutyId: dutyId);
    } catch (_) {}
  }
}
