// ignore_for_file: type=lint
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'app_database.g.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// TABLE DEFINITIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Local retailer (customer) cache.
class Retailers extends Table {
  IntColumn  get id            => integer()();
  TextColumn get name          => text()();
  TextColumn get code          => text().nullable()();
  TextColumn get channel       => text().nullable()();
  TextColumn get tier          => text().nullable()();
  TextColumn get status        => text().withDefault(const Constant('active'))();
  RealColumn get outstanding   => real().withDefault(const Constant(0.0))();
  RealColumn get creditLimit   => real().withDefault(const Constant(0.0))();
  TextColumn get creditStatus  => text().nullable()();
  TextColumn get phone         => text().nullable()();
  TextColumn get gstin         => text().nullable()();
  TextColumn get address       => text().nullable()();
  TextColumn get lastOrderDate   => text().nullable()(); // ISO-8601
  TextColumn get lastPaymentDate => text().nullable()();
  TextColumn get lastVisitDate   => text().nullable()();
  TextColumn get syncedAt        => text()();            // ISO-8601

  @override
  Set<Column> get primaryKey => {id};
}

/// Local product cache.
class Products extends Table {
  IntColumn  get id              => integer()();
  TextColumn get sku             => text()();
  TextColumn get name            => text()();
  TextColumn get categoryName    => text().nullable()();
  TextColumn get unit            => text().nullable()();
  RealColumn get gstRate         => real().withDefault(const Constant(0.0))();
  RealColumn get defaultPrice    => real().withDefault(const Constant(0.0))();
  IntColumn  get stockAvailable  => integer().withDefault(const Constant(0))();
  TextColumn get status          => text().withDefault(const Constant('active'))();
  TextColumn get hsnCode         => text().nullable()();
  TextColumn get syncedAt        => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local price-list item cache (product × price list).
class PriceListItemsLocal extends Table {
  IntColumn  get id            => integer()();
  IntColumn  get productId     => integer()();
  IntColumn  get priceListId   => integer()();
  TextColumn get priceListName => text()();
  RealColumn get unitPrice     => real()();
  IntColumn  get minQty        => integer().withDefault(const Constant(1))();
  RealColumn get discountPct   => real().withDefault(const Constant(0.0))();
  TextColumn get syncedAt      => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tracks when each entity type was last synced from the server.
class SyncMetadata extends Table {
  TextColumn get entityType  => text()();   // 'retailers' | 'products' | 'price_list_items'
  TextColumn get lastSyncedAt => text().nullable()();
  IntColumn  get recordCount  => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {entityType};
}

/// Offline order queue — orders created while offline, pending sync to server.
class PendingOrders extends Table {
  IntColumn  get localId           => integer().autoIncrement()();
  IntColumn  get customerId        => integer()();
  TextColumn get customerName      => text()();
  IntColumn  get branchId          => integer()();
  TextColumn get linesJson         => text()();  // JSON-encoded List<CartLine>
  TextColumn get status            => text().withDefault(const Constant('pending'))(); // pending|syncing|synced|failed
  TextColumn get localOrderNumber  => text()();  // e.g. L-20241201-0001
  TextColumn get createdAt         => text()();  // ISO-8601
  TextColumn get syncedAt          => text().nullable()();
  IntColumn  get serverId          => integer().nullable()();
  TextColumn get serverOrderNumber => text().nullable()();
  TextColumn get errorMessage      => text().nullable()();
}

/// Offline trip stop cache for driver delivery workflow.
class TripStops extends Table {
  IntColumn  get localId       => integer().autoIncrement()();
  IntColumn  get serverId      => integer().nullable()();
  IntColumn  get tripId        => integer()();
  IntColumn  get sequence      => integer().withDefault(const Constant(0))();
  TextColumn get status        => text().withDefault(const Constant('pending'))();
  IntColumn  get salesOrderId  => integer().nullable()();
  TextColumn get customerName  => text()();
  TextColumn get address       => text().nullable()();
  TextColumn get phone         => text().nullable()();
  TextColumn get orderLinesJson => text().withDefault(const Constant('[]'))();
  TextColumn get completedAt   => text().nullable()();    // ISO-8601 device timestamp
  TextColumn get syncedAt      => text().nullable()();

  @override
  Set<Column> get primaryKey => {localId};
}

/// Offline delivery rejection items (returned / refused products at delivery).
class DeliveryRejections extends Table {
  IntColumn  get localId      => integer().autoIncrement()();
  IntColumn  get stopLocalId  => integer()();             // FK → TripStops.localId
  IntColumn  get productId    => integer()();
  TextColumn get productName  => text()();
  RealColumn get qtyRejected  => real().withDefault(const Constant(0.0))();
  TextColumn get reasonCode   => text().nullable()();     // 'damaged'|'refused'|'expired'
  TextColumn get condition    => text().nullable()();
  TextColumn get photoPath    => text().nullable()();     // local file path
}

/// Local notifications inbox (persisted across app restarts).
class LocalNotifications extends Table {
  IntColumn  get id          => integer().autoIncrement()();
  IntColumn  get serverId    => integer().nullable()();
  TextColumn get type        => text()();
  TextColumn get title       => text()();
  TextColumn get body        => text()();
  TextColumn get deepLink    => text().nullable()();
  TextColumn get severity    => text().withDefault(const Constant('medium'))();
  BoolColumn get isRead      => boolean().withDefault(const Constant(false))();
  TextColumn get receivedAt  => text()();
  TextColumn get data        => text().nullable()(); // JSON blob for extra attributes
}

/// Offline payment queue — payments created while offline, pending sync to server.
class PendingPayments extends Table {
  IntColumn  get localId             => integer().autoIncrement()();
  IntColumn  get customerId          => integer()();
  TextColumn get customerName        => text()();
  IntColumn  get branchId            => integer()();
  RealColumn get amount              => real()();
  TextColumn get paymentMode         => text().withDefault(const Constant('cash'))();
  TextColumn get reference           => text().nullable()();
  TextColumn get notes               => text().nullable()();
  TextColumn get receivedDate        => text()();            // ISO-8601 date
  IntColumn  get collectionScheduleId => integer().nullable()();  // FK if from schedule
  TextColumn get status              => text().withDefault(const Constant('pending'))();
  // pending | syncing | synced | failed
  IntColumn  get serverId            => integer().nullable()();
  TextColumn get serverPaymentNumber => text().nullable()();
  TextColumn get errorMessage        => text().nullable()();
  TextColumn get createdAt           => text()();            // ISO-8601 datetime
  TextColumn get idempotencyKey      => text().nullable()(); // UUID v4 for server dedup
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATABASE
// ═══════════════════════════════════════════════════════════════════════════════

@DriftDatabase(tables: [Retailers, Products, PriceListItemsLocal, SyncMetadata, PendingOrders, TripStops, DeliveryRejections, PendingPayments, LocalNotifications])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 7;

  // ── Schema migrations ────────────────────────────────────────────────────
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // Create performance indexes on fresh install
      await customStatement('CREATE INDEX IF NOT EXISTS idx_retailers_search ON retailers (name, code)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_products_search ON products (name, sku)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_pending_orders_status ON pending_orders (status, created_at)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_pending_payments_status ON pending_payments (status, local_id)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_trip_stops_trip ON trip_stops (trip_id, sequence)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_notifications_read ON local_notifications (is_read, received_at)');
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(pendingOrders);
      }
      if (from < 3) {
        await m.createTable(tripStops);
        await m.createTable(deliveryRejections);
      }
      if (from < 4) {
        await m.createTable(pendingPayments);
      }
      if (from < 5) {
        await m.createTable(localNotifications);
      }
      if (from < 6) {
        // Composite indexes for common search queries (M7.4 performance)
        await customStatement('CREATE INDEX IF NOT EXISTS idx_retailers_search ON retailers (name, code)');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_products_search ON products (name, sku)');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_pending_orders_status ON pending_orders (status, created_at)');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_pending_payments_status ON pending_payments (status, local_id)');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_trip_stops_trip ON trip_stops (trip_id, sequence)');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_notifications_read ON local_notifications (is_read, received_at)');
      }
      if (from < 7) {
        // Add idempotency key column to pending_payments for server-side deduplication
        await m.addColumn(pendingPayments, pendingPayments.idempotencyKey);
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Ensure native sqlite3 libs are available on Android.
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();

    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'orderlane_pro.db'));
    return NativeDatabase.createInBackground(file);
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// DAOs
// ═══════════════════════════════════════════════════════════════════════════════

extension RetailersDao on AppDatabase {
  // ── Queries ──────────────────────────────────────────────────────────────

  Future<List<Retailer>> searchRetailers(String query) {
    if (query.isEmpty) {
      return (select(retailers)
            ..orderBy([(r) => OrderingTerm.asc(r.name)]))
          .get();
    }
    final q = '%${query.toLowerCase()}%';
    return (select(retailers)
          ..where((r) => r.name.lower().like(q) | r.code.lower().like(q))
          ..orderBy([(r) => OrderingTerm.asc(r.name)]))
        .get();
  }

  Future<Retailer?> getRetailerById(int id) =>
      (select(retailers)..where((r) => r.id.equals(id))).getSingleOrNull();

  Future<List<Retailer>> getRetailersByStatus(String status) =>
      (select(retailers)
            ..where((r) => r.status.equals(status))
            ..orderBy([(r) => OrderingTerm.asc(r.name)]))
          .get();

  Future<List<Retailer>> getOverdueRetailers() =>
      (select(retailers)
            ..where((r) => r.creditStatus.equals('overdue'))
            ..orderBy([(r) => OrderingTerm.desc(r.outstanding)]))
          .get();

  // ── Upserts ──────────────────────────────────────────────────────────────

  Future<void> upsertRetailer(RetailersCompanion companion) =>
      into(retailers).insertOnConflictUpdate(companion);

  Future<void> upsertRetailers(List<RetailersCompanion> companions) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(retailers, companions);
    });
  }

  Future<int> countRetailers() async {
    final count = retailers.id.count();
    final q = selectOnly(retailers)..addColumns([count]);
    final row = await q.getSingle();
    return row.read(count) ?? 0;
  }
}

extension ProductsDao on AppDatabase {
  // ── Queries ──────────────────────────────────────────────────────────────

  Future<List<Product>> searchProducts(String query) {
    if (query.isEmpty) {
      return (select(products)
            ..orderBy([(p) => OrderingTerm.asc(p.name)]))
          .get();
    }
    final q = '%${query.toLowerCase()}%';
    return (select(products)
          ..where((p) => p.name.lower().like(q) | p.sku.lower().like(q))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();
  }

  Future<Product?> getProductById(int id) =>
      (select(products)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<List<Product>> getActiveProducts() =>
      (select(products)
            ..where((p) => p.status.equals('active'))
            ..orderBy([(p) => OrderingTerm.asc(p.name)]))
          .get();

  Future<List<PriceListItemsLocalData>> getPriceListItemsForProduct(int productId) =>
      (select(priceListItemsLocal)
            ..where((i) => i.productId.equals(productId)))
          .get();

  // ── Upserts ──────────────────────────────────────────────────────────────

  Future<void> upsertProduct(ProductsCompanion companion) =>
      into(products).insertOnConflictUpdate(companion);

  Future<void> upsertProducts(List<ProductsCompanion> companions) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(products, companions);
    });
  }

  Future<void> upsertPriceListItems(List<PriceListItemsLocalCompanion> companions) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(priceListItemsLocal, companions);
    });
  }

  Future<int> countProducts() async {
    final count = products.id.count();
    final q = selectOnly(products)..addColumns([count]);
    final row = await q.getSingle();
    return row.read(count) ?? 0;
  }
}

extension SyncMetadataDao on AppDatabase {
  Future<SyncMetadatum?> getSyncMeta(String entityType) =>
      (select(syncMetadata)..where((s) => s.entityType.equals(entityType))).getSingleOrNull();

  Future<void> upsertSyncMeta({
    required String entityType,
    required DateTime syncedAt,
    required int count,
  }) =>
      into(syncMetadata).insertOnConflictUpdate(
        SyncMetadataCompanion(
          entityType:   Value(entityType),
          lastSyncedAt: Value(syncedAt.toIso8601String()),
          recordCount:  Value(count),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

extension PendingOrdersDao on AppDatabase {
  // ── Insert ────────────────────────────────────────────────────────────────
  Future<int> insertPendingOrder(PendingOrdersCompanion companion) =>
      into(pendingOrders).insert(companion);

  // ── Queries ───────────────────────────────────────────────────────────────
  Future<List<PendingOrder>> getPendingOrders() =>
      (select(pendingOrders)
            ..where((o) => o.status.equals('pending') | o.status.equals('failed'))
            ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
          .get();

  Future<List<PendingOrder>> getAllLocalOrders() =>
      (select(pendingOrders)
            ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
          .get();

  // ── Updates ───────────────────────────────────────────────────────────────
  Future<void> markOrderSynced(
      int localId, int serverId, String serverNumber) =>
      (update(pendingOrders)..where((o) => o.localId.equals(localId))).write(
        PendingOrdersCompanion(
          status:            const Value('synced'),
          serverId:          Value(serverId),
          serverOrderNumber: Value(serverNumber),
          syncedAt:          Value(DateTime.now().toIso8601String()),
          errorMessage:      const Value(null),
        ),
      );

  Future<void> markOrderFailed(int localId, String error) =>
      (update(pendingOrders)..where((o) => o.localId.equals(localId))).write(
        PendingOrdersCompanion(
          status:       const Value('failed'),
          errorMessage: Value(error),
        ),
      );

  Future<void> markOrderSyncing(int localId) =>
      (update(pendingOrders)..where((o) => o.localId.equals(localId))).write(
        const PendingOrdersCompanion(status: Value('syncing')),
      );

  /// Permanently discard a failed/pending local order.
  Future<void> discardOrder(int localId) =>
      (delete(pendingOrders)..where((o) => o.localId.equals(localId))).go();

  // ── Helpers ───────────────────────────────────────────────────────────────
  Future<int> countPendingOrders() async {
    final count = pendingOrders.localId.count();
    final q = selectOnly(pendingOrders)
      ..where(pendingOrders.status.equals('pending'))
      ..addColumns([count]);
    final row = await q.getSingle();
    return row.read(count) ?? 0;
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// ═══════════════════════════════════════════════════════════════════════════════
// TRIP STOPS DAO
// ═══════════════════════════════════════════════════════════════════════════════

extension TripStopsDao on AppDatabase {
  Future<List<TripStop>> getStopsForTrip(int tripId) =>
      (select(tripStops)
            ..where((s) => s.tripId.equals(tripId))
            ..orderBy([(s) => OrderingTerm.asc(s.sequence)]))
          .get();

  Future<TripStop?> getStopById(int localId) =>
      (select(tripStops)..where((s) => s.localId.equals(localId))).getSingleOrNull();

  Future<int> upsertTripStop(TripStopsCompanion companion) =>
      into(tripStops).insertOnConflictUpdate(companion);

  Future<void> upsertTripStops(List<TripStopsCompanion> companions) async {
    await batch((b) => b.insertAllOnConflictUpdate(tripStops, companions));
  }

  Future<void> updateStopStatus(int localId, String status, {String? completedAt}) =>
      (update(tripStops)..where((s) => s.localId.equals(localId))).write(
        TripStopsCompanion(
          status:      Value(status),
          completedAt: completedAt != null ? Value(completedAt) : const Value.absent(),
        ),
      );

  Future<void> markStopSynced(int localId) =>
      (update(tripStops)..where((s) => s.localId.equals(localId))).write(
        TripStopsCompanion(syncedAt: Value(DateTime.now().toIso8601String())),
      );

  Future<List<TripStop>> getUnsyncedStops() =>
      (select(tripStops)..where((s) => s.syncedAt.isNull())).get();

  Future<int> countUnsyncedStops() async {
    final count = tripStops.localId.count();
    final q = selectOnly(tripStops)
      ..where(tripStops.syncedAt.isNull())
      ..addColumns([count]);
    return (await q.getSingle()).read(count) ?? 0;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DELIVERY REJECTIONS DAO
// ═══════════════════════════════════════════════════════════════════════════════

extension DeliveryRejectionsDao on AppDatabase {
  Future<List<DeliveryRejection>> getRejectionsForStop(int stopLocalId) =>
      (select(deliveryRejections)
            ..where((r) => r.stopLocalId.equals(stopLocalId)))
          .get();

  Future<int> insertRejection(DeliveryRejectionsCompanion companion) =>
      into(deliveryRejections).insert(companion);

  Future<void> deleteRejectionsForStop(int stopLocalId) =>
      (delete(deliveryRejections)..where((r) => r.stopLocalId.equals(stopLocalId))).go();

  Future<List<DeliveryRejection>> getUnsyncedRejections() =>
      (select(deliveryRejections)..where((r) => r.synced.equals(false))).get();

  Future<void> markRejectionSynced(int localId) =>
      (update(deliveryRejections)..where((r) => r.localId.equals(localId))).write(
        const DeliveryRejectionsCompanion(synced: Value(true)),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// PENDING PAYMENTS DAO
// ═══════════════════════════════════════════════════════════════════════════════

extension PendingPaymentsDao on AppDatabase {
  /// Insert a new offline payment into the local queue.
  Future<int> queuePayment(PendingPaymentsCompanion companion) =>
      into(pendingPayments).insert(companion);

  /// All payments with a given status.
  Future<List<PendingPayment>> getPaymentsByStatus(String status) =>
      (select(pendingPayments)
            ..where((p) => p.status.equals(status))
            ..orderBy([(p) => OrderingTerm.desc(p.localId)]))
          .get();

  /// Payments not yet synced to the server.
  Future<List<PendingPayment>> getPendingPayments() =>
      (select(pendingPayments)
            ..where((p) => p.status.isIn(['pending', 'failed']))
            ..orderBy([(p) => OrderingTerm.asc(p.localId)]))
          .get();

  /// All payments, newest first (for Recent Collections view).
  Future<List<PendingPayment>> getAllPayments({int limit = 50}) =>
      (select(pendingPayments)
            ..orderBy([(p) => OrderingTerm.desc(p.localId)])
            ..limit(limit))
          .get();

  /// Mark a payment as synced with the server response.
  Future<void> markPaymentSynced(
    int localId, {
    required int serverId,
    required String serverPaymentNumber,
  }) =>
      (update(pendingPayments)..where((p) => p.localId.equals(localId))).write(
        PendingPaymentsCompanion(
          status:              const Value('synced'),
          serverId:            Value(serverId),
          serverPaymentNumber: Value(serverPaymentNumber),
          errorMessage:        const Value(null),
        ),
      );

  /// Mark a payment sync attempt as failed.
  Future<void> markPaymentFailed(int localId, String error) =>
      (update(pendingPayments)..where((p) => p.localId.equals(localId))).write(
        PendingPaymentsCompanion(
          status:       const Value('failed'),
          errorMessage: Value(error),
        ),
      );

  /// Mark a payment as currently being synced.
  Future<void> markPaymentSyncing(int localId) =>
      (update(pendingPayments)..where((p) => p.localId.equals(localId))).write(
        const PendingPaymentsCompanion(status: Value('syncing')),
      );

  /// Permanently discard a failed/pending local payment.
  Future<void> discardPayment(int localId) =>
      (delete(pendingPayments)..where((p) => p.localId.equals(localId))).go();

  /// Count of pending/failed payments (badge indicator).
  Future<int> countUnsyncedPayments() async {
    final count = pendingPayments.localId.count();
    final q = selectOnly(pendingPayments)
      ..where(pendingPayments.status.isIn(['pending', 'failed']))
      ..addColumns([count]);
    return (await q.getSingle()).read(count) ?? 0;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOCAL NOTIFICATIONS DAO
// ═══════════════════════════════════════════════════════════════════════════════

extension LocalNotificationsDao on AppDatabase {
  Stream<List<LocalNotification>> watchNotifications() =>
      (select(localNotifications)
            ..orderBy([(n) => OrderingTerm.desc(n.receivedAt)]))
          .watch();

  Future<int> insertNotification(LocalNotificationsCompanion companion) =>
      into(localNotifications).insertOnConflictUpdate(companion);

  Future<void> markNotificationRead(int id) =>
      (update(localNotifications)..where((n) => n.id.equals(id))).write(
        const LocalNotificationsCompanion(isRead: Value(true)),
      );

  Future<void> markAllNotificationsRead() =>
      (update(localNotifications)
            ..where((n) => n.isRead.equals(false)))
          .write(const LocalNotificationsCompanion(isRead: Value(true)));

  Future<int> countUnreadNotifications() async {
    final count = localNotifications.id.count();
    final q = selectOnly(localNotifications)
      ..where(localNotifications.isRead.equals(false))
      ..addColumns([count]);
    return (await q.getSingle()).read(count) ?? 0;
  }
}
