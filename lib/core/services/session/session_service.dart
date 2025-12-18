import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_role.dart';

class SessionUserProfile {
  final String uid;
  final UserRole role;
  final String distributorId;

  const SessionUserProfile({
    required this.uid,
    required this.role,
    required this.distributorId,
  });
}

class SessionService {
  static const _kActiveDutyId = 'activeDutyId';

  SessionUserProfile? _profile;
  String? _activeDutyId;

  SessionUserProfile? get profile => _profile;
  String? get activeDutyId => _activeDutyId;

  bool get isLoggedIn => _profile != null;

  Future<void> loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    _activeDutyId = prefs.getString(_kActiveDutyId);
  }

  Future<void> setActiveDutyId(String? dutyId) async {
    _activeDutyId = dutyId;
    final prefs = await SharedPreferences.getInstance();
    if (dutyId == null) {
      await prefs.remove(_kActiveDutyId);
    } else {
      await prefs.setString(_kActiveDutyId, dutyId);
    }
  }

  void setProfile(SessionUserProfile? profile) {
    _profile = profile;
  }

  Future<void> clear() async {
    _profile = null;
    await setActiveDutyId(null);
  }
}
