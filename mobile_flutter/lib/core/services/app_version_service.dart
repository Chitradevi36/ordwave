import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../network/api_client.dart';

// ---------------------------------------------------------------------------
// Version check result model
// ---------------------------------------------------------------------------

enum VersionCheckStatus { ok, updateRequired, maintenance }

class VersionCheckResult {
  const VersionCheckResult({
    required this.status,
    this.currentVersion,
    this.minVersion,
    this.maintenanceMessage,
  });

  final VersionCheckStatus status;
  final String? currentVersion;
  final String? minVersion;
  final String? maintenanceMessage;
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class AppVersionService {
  AppVersionService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// Returns true if [current] is at least [minimum] (semver comparison).
  static bool _meetsMinimum(String current, String minimum) {
    try {
      final curr = current.split('.')..removeWhere((s) => s.isEmpty);
      final min  = minimum.split('.')..removeWhere((s) => s.isEmpty);

      for (var i = 0; i < min.length; i++) {
        final c = i < curr.length ? (int.tryParse(curr[i]) ?? 0) : 0;
        final m = int.tryParse(min[i]) ?? 0;
        if (c > m) return true;
        if (c < m) return false;
      }
      return true; // equal
    } catch (_) {
      return true; // fail-open: don't block on parse error
    }
  }

  /// Fetches `/health` and returns a [VersionCheckResult].
  Future<VersionCheckResult> checkVersion() async {
    late String currentVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion = info.version;
    } catch (_) {
      currentVersion = '0.0.0';
    }

    try {
      final response = await _dio.get(
        '/health',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      final data = response.data as Map<String, dynamic>? ?? {};

      // Maintenance mode takes priority
      if (data['maintenance_mode'] == true) {
        return VersionCheckResult(
          status: VersionCheckStatus.maintenance,
          currentVersion: currentVersion,
          maintenanceMessage: data['maintenance_message'] as String? ??
              'OrderLane Pro is undergoing scheduled maintenance.\nPlease check back shortly.',
        );
      }

      // Force-update check
      final minVersion = data['min_mobile_version'] as String?;
      if (minVersion != null && !_meetsMinimum(currentVersion, minVersion)) {
        return VersionCheckResult(
          status: VersionCheckStatus.updateRequired,
          currentVersion: currentVersion,
          minVersion: minVersion,
        );
      }

      return VersionCheckResult(
        status: VersionCheckStatus.ok,
        currentVersion: currentVersion,
        minVersion: minVersion,
      );
    } catch (e) {
      debugPrint('[AppVersionService] health check failed: $e');
      // Network failure → fail-open, do not block the user
      return VersionCheckResult(
        status: VersionCheckStatus.ok,
        currentVersion: currentVersion,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final appVersionServiceProvider = Provider<AppVersionService>((ref) {
  final dio = ref.watch(apiClientProvider);
  return AppVersionService(dio: dio);
});

final versionCheckProvider = FutureProvider<VersionCheckResult>((ref) {
  return ref.watch(appVersionServiceProvider).checkVersion();
});

// ---------------------------------------------------------------------------
// Overlay widget — call showVersionGate() in the root widget's initState
// ---------------------------------------------------------------------------

/// Shows a blocking dialog when a force-update or maintenance check fails.
/// No-op when status is [VersionCheckStatus.ok].
void handleVersionCheckResult(BuildContext context, VersionCheckResult result) {
  if (result.status == VersionCheckStatus.ok) return;

  final isMaintenance = result.status == VersionCheckStatus.maintenance;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(isMaintenance ? 'Down for Maintenance' : 'Update Required'),
        content: Text(
          isMaintenance
              ? (result.maintenanceMessage ?? 'Please check back shortly.')
              : 'Your app version (${result.currentVersion ?? '–'}) is no longer supported.\n'
                  'Please update to v${result.minVersion ?? '–'} or later to continue.',
        ),
        actions: isMaintenance
            ? [] // No action — user must wait
            : [
                TextButton(
                  onPressed: () {
                    // In production: launch app store URL
                    // launchUrl(Uri.parse(kAppStoreUrl));
                  },
                  child: const Text('Update Now'),
                ),
              ],
      ),
    ),
  );
}
