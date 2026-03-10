import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/cart.dart';

// ─── Task names ────────────────────────────────────────────────────────────────
const kDeltaSyncTaskName    = 'deltaSync';
const kDeltaSyncUniqueName  = 'delta-sync';
const kConnectivitySyncName = 'connectivity-sync';

// ─── WorkManager callback (top-level) ─────────────────────────────────────────
/// Called by WorkManager in an isolate — must be a top-level function.
@pragma('vm:entry-point')
void workManagerCallback() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final db  = AppDatabase();
      final sto = SecureStorageService();
      final dio = _buildSimpleDio(sto);

      switch (task) {
        case kDeltaSyncTaskName:
        case kConnectivitySyncName:
          await SyncService._runSync(db: db, dio: dio, storage: sto);
          break;
      }

      await db.close();
      return Future.value(true);
    } catch (_) {
      return Future.value(false);
    }
  });
}

Dio _buildSimpleDio(SecureStorageService storage) {
  final dio = Dio(BaseOptions(
    baseUrl: const String.fromEnvironment('API_BASE_URL',
        defaultValue: 'http://localhost:3001'),
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));
  dio.interceptors.add(AuthInterceptor(storage: storage, dio: dio));
  return dio;
}

// ─── Sync Service ──────────────────────────────────────────────────────────────
class SyncService {
  const SyncService._();

  /// Register periodic background task (every 15 minutes).
  static Future<void> registerPeriodicSync() async {
    await Workmanager().initialize(workManagerCallback, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      kDeltaSyncUniqueName,
      kDeltaSyncTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  /// Trigger an immediate one-off sync (e.g., when connectivity is restored).
  static Future<void> triggerImmediateSync() async {
    await Workmanager().registerOneOffTask(
      kConnectivitySyncName,
      kConnectivitySyncName,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  /// Cancel all background tasks.
  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }

  // ── Core sync logic ────────────────────────────────────────────────────────

  /// 1. Push pending operations → 2. Delta-pull entity data.
  static Future<void> _runSync({
    required AppDatabase db,
    required Dio dio,
    required SecureStorageService storage,
  }) async {
    await _pushPendingOrders(db: db, dio: dio);
    await _pushPendingPayments(db: db, dio: dio);
    await _deltaPull(db: db, dio: dio);
  }

  // ── Push pending orders ───────────────────────────────────────────────────

  static Future<void> _pushPendingOrders({
    required AppDatabase db,
    required Dio dio,
  }) async {
    final pending = await db.getPendingOrders();
    if (pending.isEmpty) return;

    for (final order in pending) {
      await db.markOrderSyncing(order.localId);
      try {
        // Decode lines from JSON
        final rawLines  = jsonDecode(order.linesJson) as List<dynamic>;
        final cartLines = rawLines
            .map((e) => CartLine.fromJson(e as Map<String, dynamic>))
            .toList();

        final response = await dio.post<Map<String, dynamic>>(
          '/api/v1/sales_orders/from_mobile',
          data: {
            'order': {
              'customer_id': order.customerId,
              'branch_id':   order.branchId,
              'status':      'submitted',
              'lines': cartLines
                  .map((l) => {
                        'product_id': l.productId,
                        'qty':        l.qty,
                        'unit_price': l.unitPrice,
                      })
                  .toList(),
            },
          },
        );

        final data = response.data?['data'] as Map<String, dynamic>?;
        if (data != null) {
          await db.markOrderSynced(
            order.localId,
            data['id'] as int,
            data['order_number'] as String,
          );
        }
      } on DioException catch (e) {
        if (e.response != null) {
          // Server rejected — mark failed
          final msg = (e.response?.data?['errors'] as List?)?.first.toString() ??
              'Server error ${e.response?.statusCode}';
          await db.markOrderFailed(order.localId, msg);
        } else {
          // Network error — revert to pending so it retries next time
          await (db.update(db.pendingOrders)
                ..where((o) => o.localId.equals(order.localId)))
              .write(const PendingOrdersCompanion(status: Value('pending')));
        }
      }
    }
  }

  // ── Push pending payments ─────────────────────────────────────────────────

  static Future<void> _pushPendingPayments({
    required AppDatabase db,
    required Dio dio,
  }) async {
    final pending = await db.getPendingPayments();
    if (pending.isEmpty) return;

    for (final payment in pending) {
      await db.markPaymentSyncing(payment.localId);
      try {
        final body = <String, dynamic>{
          'payment': {
            'customer_id':   payment.customerId,
            'amount':        payment.amount,
            'payment_mode':  payment.paymentMode,
            'received_date': payment.receivedDate,
            if (payment.reference != null && payment.reference!.isNotEmpty)
              'reference_number': payment.reference,
            if (payment.notes != null && payment.notes!.isNotEmpty)
              'notes': payment.notes,
            if (payment.collectionScheduleId != null)
              'collection_schedule_id': payment.collectionScheduleId,
            if (payment.idempotencyKey != null)
              'idempotency_key': payment.idempotencyKey,
          },
        };

        final response = await dio.post<Map<String, dynamic>>(
          '/api/v1/payments',
          data: body,
        );

        final data = response.data?['data'] as Map<String, dynamic>?;
        if (data != null) {
          await db.markPaymentSynced(
            payment.localId,
            serverId: data['id'] as int,
            serverPaymentNumber: data['payment_number'] as String? ?? '',
          );
        }
      } on DioException catch (e) {
        if (e.response != null) {
          // Server rejected — mark permanently failed
          final msg = (e.response?.data?['errors'] as List?)?.first.toString() ??
              'Server error ${e.response?.statusCode}';
          await db.markPaymentFailed(payment.localId, msg);
        } else {
          // Network error — revert to pending so it retries next sync
          await (db.update(db.pendingPayments)
                ..where((p) => p.localId.equals(payment.localId)))
              .write(const PendingPaymentsCompanion(status: Value('pending')));
        }
      }
    }
  }

  // ── Delta pull ─────────────────────────────────────────────────────────────

  static Future<void> _deltaPull({
    required AppDatabase db,
    required Dio dio,
  }) async {
    // Build `since` param from latest SyncMetadata.
    // On first install (no metadata) pass a far-back date so the server
    // returns ALL master data rather than only the last 24 h.
    final meta  = await db.getSyncMeta('retailers');
    final since = meta?.lastSyncedAt ?? '2000-01-01T00:00:00.000Z';
    final queryParams = <String, dynamic>{'since': since};

    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/v1/sync/delta',
        queryParameters: queryParams,
      );

      final data = response.data ?? {};

      // ── Retailers (customers) ──────────────────────────────────────────
      final customers = data['customers'] as Map<String, dynamic>?;
      if (customers != null) {
        final upserted = (customers['upserted'] as List<dynamic>? ?? []);
        if (upserted.isNotEmpty) {
          await db.upsertRetailers(upserted.map((e) {
            final j = e as Map<String, dynamic>;
            return RetailersCompanion(
              id:            Value(j['id'] as int),
              name:          Value(j['name'] as String),
              code:          Value(j['code'] as String?),
              channel:       Value(j['channel'] as String?),
              tier:          Value(j['tier'] as String?),
              status:        Value(j['status'] as String? ?? 'active'),
              outstanding:   Value((j['outstanding_amount'] as num?)?.toDouble() ?? 0),
              creditLimit:   Value((j['credit_limit'] as num?)?.toDouble() ?? 0),
              creditStatus:  Value(j['credit_status'] as String?),
              phone:         Value(j['phone'] as String?),
              gstin:         Value(j['gstin'] as String?),
              syncedAt:      Value(DateTime.now().toIso8601String()),
            );
          }).toList());
        }
        await db.upsertSyncMeta(
            entityType: 'retailers',
            syncedAt: DateTime.now(),
            count: upserted.length);
      }

      // ── Products ───────────────────────────────────────────────────────
      final products = data['products'] as Map<String, dynamic>?;
      if (products != null) {
        final upserted = (products['upserted'] as List<dynamic>? ?? []);
        if (upserted.isNotEmpty) {
          await db.upsertProducts(upserted.map((e) {
            final j = e as Map<String, dynamic>;
            return ProductsCompanion(
              id:             Value(j['id'] as int),
              sku:            Value(j['sku'] as String),
              name:           Value(j['name'] as String),
              categoryName:   Value(j['category_name'] as String?),
              unit:           Value(j['unit'] as String?),
              gstRate:        Value((j['gst_rate'] as num?)?.toDouble() ?? 0),
              defaultPrice:   Value((j['default_price'] as num?)?.toDouble() ?? 0),
              stockAvailable: Value(j['stock_available'] as int? ?? 0),
              status:         Value(j['status'] as String? ?? 'active'),
              hsnCode:        Value(j['hsn_code'] as String?),
              syncedAt:       Value(DateTime.now().toIso8601String()),
            );
          }).toList());
        }
        await db.upsertSyncMeta(
            entityType: 'products',
            syncedAt: DateTime.now(),
            count: upserted.length);
      }

      // ── Price list items ───────────────────────────────────────────────
      final priceItems = data['price_list_items'] as Map<String, dynamic>?;
      if (priceItems != null) {
        final upserted = (priceItems['upserted'] as List<dynamic>? ?? []);
        if (upserted.isNotEmpty) {
          await db.upsertPriceListItems(upserted.map((e) {
            final j = e as Map<String, dynamic>;
            return PriceListItemsLocalCompanion(
              id:            Value(j['id'] as int),
              productId:     Value(j['product_id'] as int),
              priceListId:   Value(j['price_list_id'] as int),
              priceListName: Value(j['price_list_name'] as String? ?? ''),
              unitPrice:     Value((j['unit_price'] as num).toDouble()),
              minQty:        Value(j['min_qty'] as int? ?? 1),
              discountPct:   Value((j['discount_pct'] as num?)?.toDouble() ?? 0),
              syncedAt:      Value(DateTime.now().toIso8601String()),
            );
          }).toList());
        }
        await db.upsertSyncMeta(
            entityType: 'price_list_items',
            syncedAt: DateTime.now(),
            count: upserted.length);
      }
    } on DioException {
      // Offline — skip
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

/// Provider for triggering in-app sync (wraps into the current DI graph).
final syncServiceProvider = Provider<_InAppSyncRunner>((ref) {
  final db      = ref.watch(appDatabaseProvider);
  final dio     = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return _InAppSyncRunner(db: db, dio: dio, storage: storage);
});

class _InAppSyncRunner {
  const _InAppSyncRunner({
    required this.db,
    required this.dio,
    required this.storage,
  });

  final AppDatabase          db;
  final Dio                  dio;
  final SecureStorageService storage;

  Future<void> sync() =>
      SyncService._runSync(db: db, dio: dio, storage: storage);
}
