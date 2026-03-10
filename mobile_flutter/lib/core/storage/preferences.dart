import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys for shared preferences entries.
class _PrefKeys {
  static const lastSyncedAt         = 'last_synced_at';
  static const selectedOrganization = 'selected_organization_id';
  static const themeMode             = 'theme_mode';
  static const fcmToken              = 'fcm_token';
  static const onboardingComplete    = 'onboarding_complete';
}

/// Wraps [SharedPreferences] with typed accessors for user preferences.
class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  // ── Sync tracking ──────────────────────────────────────────────────────────

  DateTime? get lastSyncedAt {
    final ms = _prefs.getInt(_PrefKeys.lastSyncedAt);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastSyncedAt(DateTime dt) =>
      _prefs.setInt(_PrefKeys.lastSyncedAt, dt.millisecondsSinceEpoch);

  // ── Organization selection ─────────────────────────────────────────────────

  String? get selectedOrganizationId =>
      _prefs.getString(_PrefKeys.selectedOrganization);

  Future<void> setSelectedOrganizationId(String id) =>
      _prefs.setString(_PrefKeys.selectedOrganization, id);

  // ── Theme ──────────────────────────────────────────────────────────────────

  String get themeMode => _prefs.getString(_PrefKeys.themeMode) ?? 'light';

  Future<void> setThemeMode(String mode) =>
      _prefs.setString(_PrefKeys.themeMode, mode);

  // ── FCM ───────────────────────────────────────────────────────────────────

  String? get fcmToken => _prefs.getString(_PrefKeys.fcmToken);

  Future<void> setFcmToken(String token) =>
      _prefs.setString(_PrefKeys.fcmToken, token);

  // ── Onboarding ────────────────────────────────────────────────────────────

  bool get onboardingComplete =>
      _prefs.getBool(_PrefKeys.onboardingComplete) ?? false;

  Future<void> setOnboardingComplete() =>
      _prefs.setBool(_PrefKeys.onboardingComplete, true);

  // ── Generic clear ─────────────────────────────────────────────────────────

  Future<void> clearAll() => _prefs.clear();
}

/// Async provider — must be overridden at startup after `await SharedPreferences.getInstance()`.
final preferencesProvider = Provider<PreferencesService>((ref) {
  throw UnimplementedError(
    'preferencesProvider must be overridden in main.dart after init.',
  );
});
