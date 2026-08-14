import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single place the user has picked in the Location Picker.
class RecentLocation {
  const RecentLocation({
    required this.label,
    required this.lat,
    required this.lng,
    required this.usedAt,
  });

  final String label;
  final double lat;
  final double lng;
  final DateTime usedAt;

  factory RecentLocation.fromJson(Map<String, dynamic> json) {
    return RecentLocation(
      label: json['label'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      usedAt: DateTime.tryParse(json['used_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'lat': lat,
        'lng': lng,
        'used_at': usedAt.toIso8601String(),
      };
}

/// Notification category preferences, defaulting to spec Section 4 defaults:
/// trip reminders ON, budget warnings ON, trip status ON, marketing OFF.
/// Marketing must be independently controllable and OFF by default.
class NotificationPrefs {
  const NotificationPrefs({
    this.tripReminder = true,
    this.budgetWarning = true,
    this.tripStatus = true,
    this.marketing = false,
    this.fcmToken,
  });

  final bool tripReminder;
  final bool budgetWarning;
  final bool tripStatus;
  final bool marketing;
  final String? fcmToken;

  NotificationPrefs copyWith({
    bool? tripReminder,
    bool? budgetWarning,
    bool? tripStatus,
    bool? marketing,
    String? fcmToken,
    bool clearFcmToken = false,
  }) {
    return NotificationPrefs(
      tripReminder: tripReminder ?? this.tripReminder,
      budgetWarning: budgetWarning ?? this.budgetWarning,
      tripStatus: tripStatus ?? this.tripStatus,
      marketing: marketing ?? this.marketing,
      fcmToken: clearFcmToken ? null : (fcmToken ?? this.fcmToken),
    );
  }

  bool get anyEnabled => tripReminder || budgetWarning || tripStatus || marketing;

  Map<String, dynamic> toJson() => {
        'trip_reminder': tripReminder,
        'budget_warning': budgetWarning,
        'trip_status': tripStatus,
        'marketing': marketing,
        if (fcmToken != null) 'fcm_token': fcmToken,
      };
}

/// Client-side preferences + local cache. Everything that belongs to local
/// device state (not user-owned cloud data) lives here: onboarding seen,
/// recent picked locations, notification category toggles, guest draft trip.
class PreferencesStore {
  PreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  static const _onboardingCompleteKey = 'onboarding_complete';
  static const _recentLocationsKey = 'recent_locations';
  static const _notificationPrefsKey = 'notification_prefs';
  static const _lastGuestTripKey = 'last_guest_trip';

  bool get onboardingComplete =>
      _prefs.getBool(_onboardingCompleteKey) ?? false;

  Future<void> setOnboardingComplete() =>
      _prefs.setBool(_onboardingCompleteKey, true);

  List<RecentLocation> getRecentLocations() {
    final raw = _prefs.getString(_recentLocationsKey);
    if (raw == null) return const [];
    final list = (jsonDecode(raw) as List<dynamic>? ?? const []);
    return list
        .map((e) => RecentLocation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertRecentLocation(RecentLocation loc) async {
    final updated = [
      loc,
      ...getRecentLocations().where((l) => l.label != loc.label),
    ].take(10).toList();
    await _prefs.setString(
      _recentLocationsKey,
      jsonEncode(updated.map((e) => e.toJson()).toList()),
    );
  }

  NotificationPrefs getNotificationPrefs() {
    final raw = _prefs.getString(_notificationPrefsKey);
    if (raw == null) return const NotificationPrefs();
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return NotificationPrefs(
      tripReminder: map['trip_reminder'] as bool? ?? true,
      budgetWarning: map['budget_warning'] as bool? ?? true,
      tripStatus: map['trip_status'] as bool? ?? true,
      marketing: map['marketing'] as bool? ?? false,
      fcmToken: map['fcm_token'] as String?,
    );
  }

  Future<void> saveNotificationPrefs(NotificationPrefs prefs) =>
      _prefs.setString(_notificationPrefsKey, jsonEncode(prefs.toJson()));

  Map<String, dynamic>? getLastGuestTrip() {
    final raw = _prefs.getString(_lastGuestTripKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>?;
  }

  Future<void> saveLastGuestTrip(Map<String, dynamic>? trip) async {
    if (trip == null) {
      await _prefs.remove(_lastGuestTripKey);
    } else {
      await _prefs.setString(_lastGuestTripKey, jsonEncode(trip));
    }
  }
}

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final preferencesStoreProvider = FutureProvider<PreferencesStore>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return PreferencesStore(prefs);
});