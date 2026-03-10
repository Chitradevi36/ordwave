import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/widgets/connectivity_banner.dart';
import '../models/cart.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PRIORITY LEVELS
// ═══════════════════════════════════════════════════════════════════════════════

enum SyncPriority {
  /// Money / fulfilment: payments, delivery completions.
  critical,
  /// Business operations: orders, visit check-ins/outs.
  high,
  /// Supplementary: return requests, collection schedule acks.
  normal,
  /// Low urgency: profile updates.
  low;

  int get sortOrder => index; // critical=0, high=1, normal=2, low=3
}

// ═══════════════════════════════════════════════════════════════════════════════
// SYNC RESULT
// ═══════════════════════════════════════════════════════════════════════════════

class SyncResult {
  final int pushed;
  final int failed;
  final int conflicts;
  final List<SyncConflict> unresolvedConflicts;

  const SyncResult({
    required this.pushed,
    required this.failed,
    required this.conflicts,
    this.unresolvedConflicts = const [],
  });

  bool get hasErrors => failed > 0 || unresolvedConflicts.isNotEmpty;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONFLICT MODEL
// ═══════════════════════════════════════════════════════════════════════════════

enum ConflictType {
  customerBlocked,
  priceChanged,
  paymentExceedsOutstanding,
  stockInsufficient,
  generic,
}

class SyncConflict {
  final ConflictType type;
  final String       entityId;
  final String       entityType;  // 'order' | 'payment'
  final String       message;
  final Map<String, dynamic> serverData;

  const SyncConflict({
    required this.type,
    required this.entityId,
    required this.entityType,
    required this.message,
    this.serverData = const {},
  });

  bool get isAutoResolvable => type == ConflictType.generic;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SYNC ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

/// Enhanced sync engine with:
/// • Priority ordering (critical > high > normal > low)
/// • Exponential backoff retry (max 5 retries)
/// • Per-operation conflict detection
/// • Banner state feedback
class SyncEngine {
  SyncEngine._({
    required this.db,
    required this.dio,
    required this.storage,
    required this.ref,
  });

  final AppDatabase          db;
  final Dio                  dio;
  final SecureStorageService storage;
  final Ref                  ref;

  static const int   _maxRetries  = 5;
  static const int   _backoffBase = 2; // seconds

  // ── Public entry point ─────────────────────────────────────────────────────

  Future<SyncResult> processQueue() async {
    // Signal syncing
    ref.read(syncBannerStateProvider.notifier).state = SyncBannerState.syncing;

    int pushed    = 0;
    int failed    = 0;
    int conflicts = 0;
    final unresolvedConflicts = <SyncConflict>[];

    try {
      // ── 1. Push pending PAYMENTS first (critical priority) ───────────────
      final payResult = await _pushPendingPayments();
      pushed    += payResult.pushed;
      failed    += payResult.failed;
      conflicts += payResult.conflicts;
      unresolvedConflicts.addAll(payResult.unresolvedConflicts);

      // ── 2. Push pending ORDERS (high priority) ───────────────────────────
      final orderResult = await _pushPendingOrders();
      pushed    += orderResult.pushed;
      failed    += orderResult.failed;
      conflicts += orderResult.conflicts;
      unresolvedConflicts.addAll(orderResult.unresolvedConflicts);

      // ── 3. Delta pull (normal priority) ─────────────────────────────────
      await _deltaPull();
    } catch (e) {
      // Unexpected failure — still update banner
    }

    // ── Signal done ──────────────────────────────────────────────────────
    ref.read(syncBannerStateProvider.notifier).state =
        failed == 0 ? SyncBannerState.synced : SyncBannerState.online;

    return SyncResult(
        pushed: pushed,
        failed: failed,
        conflicts: conflicts,
        unresolvedConflicts: unresolvedConflicts);
  }

  // ── Push payments ──────────────────────────────────────────────────────────

  Future<SyncResult> _pushPendingPayments() async {
    final pending = await db.getPendingPayments();
    int pushed = 0; int failed = 0; int conflicts = 0;
    final unresolved = <SyncConflict>[];

    for (final pay in pending) {
      // Skip if retry cooldown not reached
      if (!_isReadyForRetry(pay.errorMessage, pay.status)) continue;

      await db.markPaymentSyncing(pay.localId);
      try {
        final response = await dio.post<Map<String, dynamic>>(
          '/api/v1/payments',
          data: {
            'payment': {
              'customer_id':             pay.customerId,
              'branch_id':               pay.branchId,
              'amount':                  pay.amount,
              'payment_mode':            pay.paymentMode,
              'reference':               pay.reference,
              'notes':                   pay.notes,
              'received_date':           pay.receivedDate,
              'collection_schedule_id':  pay.collectionScheduleId,
            },
          },
        );
        final data = response.data?['data'] as Map<String, dynamic>?;
        if (data != null) {
          await db.markPaymentSynced(
            pay.localId,
            serverId:            data['id'] as int,
            serverPaymentNumber: data['payment_number'] as String,
          );
          pushed++;
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 409) {
          // Conflict
          final serverData = (e.response?.data as Map<String, dynamic>?) ?? {};
          final conflict = _detectPaymentConflict(pay, serverData);
          unresolved.add(conflict);
          conflicts++;
          await db.markPaymentFailed(pay.localId, 'Sync conflict: ${conflict.message}');
        } else if (e.response != null) {
          final msg = _extractError(e.response?.data);
          await db.markPaymentFailed(pay.localId, msg);
          failed++;
        } else {
          await db.markPaymentSyncing(pay.localId); // revert to pending for retry
        }
      }
    }
    return SyncResult(pushed: pushed, failed: failed, conflicts: conflicts, unresolvedConflicts: unresolved);
  }

  // ── Push orders ────────────────────────────────────────────────────────────

  Future<SyncResult> _pushPendingOrders() async {
    final pending = await db.getPendingOrders();
    int pushed = 0; int failed = 0; int conflicts = 0;
    final unresolved = <SyncConflict>[];

    for (final order in pending) {
      if (!_isReadyForRetry(order.errorMessage, order.status)) continue;

      await db.markOrderSyncing(order.localId);
      try {
        final rawLines  = (order.linesJson.isNotEmpty)
            ? (List<dynamic>.from(jsonDecode(order.linesJson) as List))
            : <dynamic>[];
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
          await db.markOrderSynced(order.localId, data['id'] as int, data['order_number'] as String);
          pushed++;
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 409) {
          final serverData = (e.response?.data as Map<String, dynamic>?) ?? {};
          final conflict = _detectOrderConflict(order, serverData);
          unresolved.add(conflict);
          conflicts++;
          await db.markOrderFailed(order.localId, 'Sync conflict: ${conflict.message}');
        } else if (e.response != null) {
          final retryCount = _parseRetryCount(order.errorMessage);
          if (retryCount >= _maxRetries) {
            final msg = _extractError(e.response?.data);
            await db.markOrderFailed(order.localId, 'Max retries reached: $msg');
            failed++;
          } else {
            final backoff    = math.pow(_backoffBase, retryCount + 1).toInt();
            final nextRetry  = DateTime.now().add(Duration(seconds: backoff));
            final msg        = _extractError(e.response?.data);
            await db.markOrderFailed(order.localId, 'retry:${retryCount + 1}|next:${nextRetry.toIso8601String()}|$msg');
          }
        } else {
          // Network error — revert to pending
          await (db.update(db.pendingOrders)
                ..where((o) => o.localId.equals(order.localId)))
              .write(const PendingOrdersCompanion(status: Value('pending')));
        }
      }
    }
    return SyncResult(pushed: pushed, failed: failed, conflicts: conflicts, unresolvedConflicts: unresolved);
  }

  // ── Delta pull ─────────────────────────────────────────────────────────────

  Future<void> _deltaPull() async {
    try {
      final meta   = await db.getSyncMeta('retailers');
      final since  = meta?.lastSyncedAt;
      final params = <String, dynamic>{};
      if (since != null) params['since'] = since;

      final response = await dio.get<Map<String, dynamic>>(
        '/api/v1/sync/delta',
        queryParameters: params,
        options: Options(headers: since != null ? {'If-Modified-Since': since} : {}),
      );

      final data = response.data ?? {};

      // Retailers
      final customers = data['customers'] as Map<String, dynamic>?;
      if (customers != null) {
        final upserted = customers['upserted'] as List<dynamic>? ?? [];
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
          await db.upsertSyncMeta(entityType: 'retailers', syncedAt: DateTime.now(), count: upserted.length);
        }
      }

      // Products
      final products = data['products'] as Map<String, dynamic>?;
      if (products != null) {
        final upserted = products['upserted'] as List<dynamic>? ?? [];
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
          await db.upsertSyncMeta(entityType: 'products', syncedAt: DateTime.now(), count: upserted.length);
        }
      }

      // Price list items  
      final priceItems = data['price_list_items'] as Map<String, dynamic>?;
      if (priceItems != null) {
        final upserted = priceItems['upserted'] as List<dynamic>? ?? [];
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
      }
    } on DioException {
      // Offline — skip delta pull silently
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool _isReadyForRetry(String? errorMessage, String status) {
    if (status == 'pending') return true;
    if (errorMessage == null) return status != 'syncing';
    // Parse next retry time from message
    final match = RegExp(r'next:([^|]+)').firstMatch(errorMessage);
    if (match == null) return true;
    try {
      final nextRetry = DateTime.parse(match.group(1)!);
      return DateTime.now().isAfter(nextRetry);
    } catch (_) {
      return true;
    }
  }

  int _parseRetryCount(String? msg) {
    if (msg == null) return 0;
    final match = RegExp(r'retry:(\d+)').firstMatch(msg);
    return int.tryParse(match?.group(1) ?? '0') ?? 0;
  }

  String _extractError(dynamic data) {
    if (data is Map) {
      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) return errors.first.toString();
      if (data['message'] != null) return data['message'].toString();
    }
    return 'Server error';
  }

  SyncConflict _detectOrderConflict(PendingOrder order, Map<String, dynamic> serverData) {
    final reason = serverData['conflict_reason'] as String? ?? '';
    if (reason.contains('blocked') || reason.contains('credit')) {
      return SyncConflict(
        type: ConflictType.customerBlocked,
        entityId: order.localId.toString(),
        entityType: 'order',
        message: 'Customer credit was blocked after this order was created.',
        serverData: serverData,
      );
    }
    if (reason.contains('price')) {
      return SyncConflict(
        type: ConflictType.priceChanged,
        entityId: order.localId.toString(),
        entityType: 'order',
        message: 'Product prices have changed since this order was created.',
        serverData: serverData,
      );
    }
    return SyncConflict(
      type: ConflictType.generic,
      entityId: order.localId.toString(),
      entityType: 'order',
      message: serverData['message']?.toString() ?? 'Unknown sync conflict.',
      serverData: serverData,
    );
  }

  SyncConflict _detectPaymentConflict(PendingPayment pay, Map<String, dynamic> serverData) {
    final newOutstanding = (serverData['outstanding'] as num?)?.toDouble();
    if (newOutstanding != null && pay.amount > newOutstanding) {
      return SyncConflict(
        type: ConflictType.paymentExceedsOutstanding,
        entityId: pay.localId.toString(),
        entityType: 'payment',
        message: 'Payment of ₹${pay.amount.toStringAsFixed(0)} exceeds outstanding ₹${newOutstanding.toStringAsFixed(0)}.',
        serverData: {'outstanding': newOutstanding, 'amount': pay.amount, ...serverData},
      );
    }
    return SyncConflict(
      type: ConflictType.generic,
      entityId: pay.localId.toString(),
      entityType: 'payment',
      message: serverData['message']?.toString() ?? 'Unknown sync conflict.',
      serverData: serverData,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

final syncEngineProvider = Provider<SyncEngine>((ref) => SyncEngine._(
      db:      ref.watch(appDatabaseProvider),
      dio:     ref.watch(apiClientProvider),
      storage: ref.watch(secureStorageProvider),
      ref:     ref,
    ));
