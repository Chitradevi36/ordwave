import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/local_db/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/connectivity_service.dart'
    show checkConnectivity;

/// Syncs offline trip stop completions with the server.
class DeliverySyncService {
  DeliverySyncService({required this.db, required this.dio});

  final AppDatabase         db;
  final Dio                 dio;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Sync all unsynced stops (and their rejections) to the server.
  Future<SyncResult> syncPendingStops() async {
    final isOnline = await checkConnectivity();
    if (!isOnline) return const SyncResult(synced: 0, failed: 0, skipped: 0);

    final unsynced = await db.getUnsyncedStops();
    int synced = 0, failed = 0;

    for (final stop in unsynced) {
      if (stop.serverId == null) {
        // No server ID yet — cannot sync this stop
        failed++;
        continue;
      }
      try {
        await _syncStop(stop);
        await db.markStopSynced(stop.localId);
        synced++;
      } catch (e) {
        failed++;
      }
    }

    return SyncResult(synced: synced, failed: failed, skipped: 0);
  }

  // ── Per-stop sync ──────────────────────────────────────────────────────────

  Future<void> _syncStop(TripStop stop) async {
    final rejections = await db.getRejectionsForStop(stop.localId);
    final lines      = _parseLines(stop.orderLinesJson);

    final payload = <String, dynamic>{
      'outcome':         stop.status,
      'delivered_lines': lines.map((l) => {
        'sales_order_line_id': l['id'],
        'product_id':          l['product_id'],
        'qty_delivered':       l['qty_delivered'] ?? l['qty_ordered'],
      }).toList(),
      if (rejections.isNotEmpty)
        'rejections': rejections.map((r) => {
          'product_id':   r.productId,
          'qty_rejected': r.qtyRejected,
          'qty_returned': r.qtyRejected,
          'reason_code':  r.reasonCode ?? 'refused',
          'condition':    r.condition  ?? 'good',
        }).toList(),
      if (stop.completedAt != null) 'completed_at': stop.completedAt,
    };

    // We need the server trip ID — stored on the stop itself (tripId is server's trip ID)
    await dio.post(
      '/api/v1/delivery_trips/${stop.tripId}/stops/${stop.serverId}/complete',
      data: payload,
    );

    // Mark rejections synced
    for (final r in rejections) {
      await db.markRejectionSynced(r.localId);
    }
  }

  List<Map<String, dynamic>> _parseLines(String json) {
    try {
      final decoded = jsonDecode(json) as List;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ── Save stop offline for later sync ─────────────────────────────────────

  Future<int> saveStopOffline({
    required int    serverId,
    required int    tripId,
    required int    sequence,
    required String status,
    required int    salesOrderId,
    required String customerName,
    String?         address,
    String?         phone,
    required List<Map<String, dynamic>> orderLines,
  }) => db.upsertTripStop(TripStopsCompanion.insert(
    serverId:      Value(serverId),
    tripId:        tripId,
    sequence:      Value(sequence),
    status:        Value(status),
    salesOrderId:  Value(salesOrderId),
    customerName:  customerName,
    address:       Value(address),
    phone:         Value(phone),
    orderLinesJson: Value(jsonEncode(orderLines)),
  ));

  Future<void> saveRejectionOffline({
    required int    stopLocalId,
    required int    productId,
    required String productName,
    required double qtyRejected,
    String?         reasonCode,
    String?         condition,
    String?         photoPath,
  }) async {
    await db.insertRejection(DeliveryRejectionsCompanion.insert(
      stopLocalId:  stopLocalId,
      productId:    productId,
      productName:  productName,
      qtyRejected:  Value(qtyRejected),
      reasonCode:   Value(reasonCode),
      condition:    Value(condition),
      photoPath:    Value(photoPath),
    ));
  }
}

// ─── Result ───────────────────────────────────────────────────────────────────

class SyncResult {
  const SyncResult({required this.synced, required this.failed, required this.skipped});
  final int synced;
  final int failed;
  final int skipped;

  @override
  String toString() => 'SyncResult(synced: $synced, failed: $failed, skipped: $skipped)';
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final deliverySyncServiceProvider = Provider<DeliverySyncService>((ref) {
  return DeliverySyncService(
    db:  ref.watch(appDatabaseProvider),
    dio: ref.watch(apiClientProvider),
  );
});
