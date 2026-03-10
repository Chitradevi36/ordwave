import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/local_db/app_database.dart';
import '../../../core/network/api_client.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// API LAYER
// ═══════════════════════════════════════════════════════════════════════════════

class RetailerApi {
  RetailerApi(this._dio);

  final Dio _dio;

  /// Fetches all active customers, paginated (default 200 per sync).
  Future<List<Map<String, dynamic>>> fetchAll({int perPage = 200}) async {
    final result = <Map<String, dynamic>>[];
    int page = 1;
    bool hasMore = true;

    while (hasMore) {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/customers',
        queryParameters: {
          'status':   'active',
          'per_page': perPage,
          'page':     page,
        },
      );
      final body = res.data!;
      final items = (body['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      result.addAll(items);

      final meta  = body['meta'] as Map<String, dynamic>?;
      final total = meta?['total'] as int? ?? items.length;
      hasMore = result.length < total && items.isNotEmpty;
      page++;
    }

    return result;
  }

  /// Fetches a single customer by ID (with includes).
  Future<Map<String, dynamic>?> fetchById(int id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/customers/$id',
        queryParameters: {'include': 'recent_orders,recent_payments'},
      );
      return res.data?['data'] as Map<String, dynamic>?;
    } on DioException {
      return null;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REPOSITORY
// ═══════════════════════════════════════════════════════════════════════════════

class RetailerRepository {
  RetailerRepository({required this.db, required this.api});

  final AppDatabase    db;
  final RetailerApi    api;

  static const _staleThresholdMinutes = 120; // 2 hours

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns retailers matching [query] from the local DB.
  /// Falls back to an empty list (not the network) — sync must have run first.
  Future<List<Retailer>> searchRetailers(String query) =>
      db.searchRetailers(query);

  Future<List<Retailer>> getRetailersByStatus(String status) {
    if (status == 'overdue') return db.getOverdueRetailers();
    if (status == 'all')     return db.searchRetailers('');
    return db.getRetailersByStatus(status);
  }

  /// Returns a single retailer from local cache if fresh, else re-fetches.
  Future<Retailer?> getRetailer(int id) async {
    final local = await db.getRetailerById(id);
    if (local != null && !_isStale(local.syncedAt)) return local;

    final remote = await api.fetchById(id);
    if (remote == null) return local; // return stale if network fails

    final companion = _toCompanion(remote);
    await db.upsertRetailer(companion);
    return db.getRetailerById(id);
  }

  /// Full sync: fetch all customers from server and upsert into local DB.
  /// Returns the count of synced records.
  Future<SyncResult> syncRetailers() async {
    final start = DateTime.now();
    try {
      final remotes = await api.fetchAll();
      final companions = remotes.map(_toCompanion).toList();
      await db.upsertRetailers(companions);
      await db.upsertSyncMeta(
        entityType: 'retailers',
        syncedAt:   start,
        count:      companions.length,
      );
      return SyncResult(success: true, count: companions.length);
    } catch (e) {
      return SyncResult(success: false, count: 0, error: e.toString());
    }
  }

  Future<DateTime?> getLastSyncTime() async {
    final meta = await db.getSyncMeta('retailers');
    final raw  = meta?.lastSyncedAt;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<bool> needsSync() async {
    final last = await getLastSyncTime();
    if (last == null) return true;
    return DateTime.now().difference(last).inMinutes > _staleThresholdMinutes;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  bool _isStale(String syncedAtIso) {
    final dt = DateTime.tryParse(syncedAtIso);
    if (dt == null) return true;
    return DateTime.now().difference(dt).inMinutes > _staleThresholdMinutes;
  }

  static RetailersCompanion _toCompanion(Map<String, dynamic> m) {
    final ca = m['credit_account'] as Map<String, dynamic>?;
    return RetailersCompanion(
      id:              Value((m['id'] as num).toInt()),
      name:            Value(m['name']?.toString() ?? ''),
      code:            Value(m['code']?.toString()),
      channel:         Value(m['channel']?.toString()),
      tier:            Value(m['tier']?.toString()),
      status:          Value(m['status']?.toString() ?? 'active'),
      outstanding:     Value(_toDouble(ca?['current_balance'])),
      creditLimit:     Value(_toDouble(ca?['credit_limit'])),
      creditStatus:    Value(_deriveCreditStatus(ca)),
      phone:           Value(m['phone']?.toString()),
      gstin:           Value(m['gstin']?.toString()),
      address:         Value(_primaryAddress(m)),
      lastOrderDate:   Value(m['last_order_date']?.toString()),
      lastPaymentDate: Value(m['last_payment_date']?.toString()),
      lastVisitDate:   Value(m['last_visit_date']?.toString()),
      syncedAt:        Value(DateTime.now().toIso8601String()),
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static String? _deriveCreditStatus(Map<String, dynamic>? ca) {
    if (ca == null) return null;
    if (ca['blocked'] == true) return 'blocked';
    if (ca['hold_required'] == true) return 'hold';
    final overdue = _toDouble(ca['overdue_amount']);
    if (overdue > 0) return 'overdue';
    final balance = _toDouble(ca['current_balance']);
    final limit   = _toDouble(ca['credit_limit']);
    if (limit > 0 && balance >= limit * 0.9) return 'near_limit';
    return 'ok';
  }

  static String? _primaryAddress(Map<String, dynamic> m) {
    final addrs = m['addresses'] as List?;
    if (addrs == null || addrs.isEmpty) return null;
    final primary = (addrs.cast<Map<String, dynamic>>()).firstWhere(
      (a) => a['address_type'] == 'billing',
      orElse: () => addrs.first as Map<String, dynamic>,
    );
    final parts = [
      primary['line1'],
      primary['city'],
      primary['state'],
    ].where((p) => p != null && p.toString().isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(', ');
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RESULT + PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════════

class SyncResult {
  const SyncResult({required this.success, required this.count, this.error});
  final bool   success;
  final int    count;
  final String? error;
}

final retailerApiProvider = Provider<RetailerApi>(
  (ref) => RetailerApi(ref.watch(apiClientProvider)),
);

final retailerRepositoryProvider = Provider<RetailerRepository>((ref) {
  return RetailerRepository(
    db:  ref.watch(appDatabaseProvider),
    api: ref.watch(retailerApiProvider),
  );
});

/// AsyncNotifier that drives an in-app sync of retailers.
class RetailerSyncNotifier extends AsyncNotifier<SyncResult?> {
  @override
  Future<SyncResult?> build() async => null;

  Future<void> sync() async {
    state = const AsyncValue.loading();
    final repo   = ref.read(retailerRepositoryProvider);
    final result = await repo.syncRetailers();
    state = AsyncValue.data(result);
  }
}

final retailerSyncProvider =
    AsyncNotifierProvider<RetailerSyncNotifier, SyncResult?>(
  RetailerSyncNotifier.new,
);
