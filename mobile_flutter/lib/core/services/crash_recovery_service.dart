import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../local_db/app_database.dart';
import '../../theme/colors.dart';

// ── Keys ──────────────────────────────────────────────────────────────────────
const _kLastScreenKey      = 'crash_recovery_last_screen';
const _kCartCustomerId     = 'crash_recovery_cart_customer_id';
const _kCartCustomerName   = 'crash_recovery_cart_customer_name';
const _kActiveStopId       = 'crash_recovery_active_stop_id';

// ── Recovery intent ───────────────────────────────────────────────────────────

class RecoveryIntent {
  final RecoveryType type;
  final Map<String, dynamic> payload;
  const RecoveryIntent({required this.type, required this.payload});
}

enum RecoveryType { resumeOrder, resumeDelivery, none }

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICE
// ═══════════════════════════════════════════════════════════════════════════════

class CrashRecoveryService {
  CrashRecoveryService._(this._prefs, this._db);

  final SharedPreferences _prefs;
  final AppDatabase       _db;

  // ── Persist cart state ─────────────────────────────────────────────────────

  Future<void> saveCartProgress({
    required int    customerId,
    required String customerName,
  }) async {
    await _prefs.setString(_kLastScreenKey,    'cart');
    await _prefs.setInt(   _kCartCustomerId,    customerId);
    await _prefs.setString(_kCartCustomerName,  customerName);
  }

  Future<void> clearCartProgress() async {
    await _prefs.remove(_kLastScreenKey);
    await _prefs.remove(_kCartCustomerId);
    await _prefs.remove(_kCartCustomerName);
  }

  // ── Persist active delivery stop ───────────────────────────────────────────

  Future<void> saveActiveStop(int stopLocalId) async {
    await _prefs.setString(_kLastScreenKey, 'delivery');
    await _prefs.setInt(_kActiveStopId, stopLocalId);
  }

  Future<void> clearActiveStop() async {
    await _prefs.remove(_kLastScreenKey);
    await _prefs.remove(_kActiveStopId);
  }

  // ── Check on startup ────────────────────────────────────────────────────────

  Future<RecoveryIntent> checkRecovery() async {
    final screen = _prefs.getString(_kLastScreenKey);
    if (screen == null) return const RecoveryIntent(type: RecoveryType.none, payload: {});

    switch (screen) {
      case 'cart':
        final customerId   = _prefs.getInt(_kCartCustomerId);
        final customerName = _prefs.getString(_kCartCustomerName);
        if (customerId != null && customerName != null) {
          return RecoveryIntent(
            type: RecoveryType.resumeOrder,
            payload: {'customerId': customerId, 'customerName': customerName},
          );
        }
      case 'delivery':
        final stopId = _prefs.getInt(_kActiveStopId);
        if (stopId != null) {
          final stop = await _db.getStopById(stopId);
          if (stop != null && stop.status != 'completed') {
            return RecoveryIntent(
              type: RecoveryType.resumeDelivery,
              payload: {'stopLocalId': stopId, 'customerName': stop.customerName},
            );
          }
        }
    }
    return const RecoveryIntent(type: RecoveryType.none, payload: {});
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

final crashRecoveryProvider = FutureProvider<CrashRecoveryService>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final db    = ref.watch(appDatabaseProvider);
  return CrashRecoveryService._(prefs, db);
});

// ═══════════════════════════════════════════════════════════════════════════════
// RECOVERY BANNER WIDGET
// ═══════════════════════════════════════════════════════════════════════════════

/// Shown at the bottom of the home screen on first launch after a crash.
/// Asks user if they want to resume, dismiss, or ignore.
class CrashRecoveryBanner extends ConsumerWidget {
  const CrashRecoveryBanner({super.key, required this.onResume, required this.onDismiss});

  final void Function(RecoveryIntent intent) onResume;
  final VoidCallback                         onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recoveryAsync = ref.watch(crashRecoveryProvider);

    return recoveryAsync.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (service) => FutureBuilder<RecoveryIntent>(
        future: service.checkRecovery(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const SizedBox.shrink();
          final intent = snap.data!;
          if (intent.type == RecoveryType.none) return const SizedBox.shrink();

          final label = intent.type == RecoveryType.resumeOrder
              ? 'Resume your order for ${intent.payload['customerName']}?'
              : 'You were completing delivery for ${intent.payload['customerName']}. Continue?';

          return Material(
            elevation: 8,
            child: Container(
              color: OlColors.primary,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resume where you left off?',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            service.clearCartProgress();
                            service.clearActiveStop();
                            onResume(intent);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: OlColors.primary,
                            minimumSize: const Size(0, 40),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Resume', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () {
                          service.clearCartProgress();
                          service.clearActiveStop();
                          onDismiss();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white30),
                          minimumSize: const Size(0, 40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
