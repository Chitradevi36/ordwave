import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/local_db/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../retailers/repository/retailer_repository.dart' show SyncResult;

// ═══════════════════════════════════════════════════════════════════════════════
// API LAYER
// ═══════════════════════════════════════════════════════════════════════════════

class ProductApi {
  ProductApi(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> fetchAll({int perPage = 200}) async {
    final result  = <Map<String, dynamic>>[];
    int   page    = 1;
    bool  hasMore = true;

    while (hasMore) {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/products',
        queryParameters: {
          'status':   'active',
          'per_page': perPage,
          'page':     page,
        },
      );
      final body  = res.data!;
      final items = (body['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      result.addAll(items);

      final meta  = body['meta'] as Map<String, dynamic>?;
      final total = meta?['total'] as int? ?? items.length;
      hasMore = result.length < total && items.isNotEmpty;
      page++;
    }

    return result;
  }

  Future<Map<String, dynamic>?> fetchById(int id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/v1/products/$id');
      return res.data?['data'] as Map<String, dynamic>?;
    } on DioException {
      return null;
    }
  }

  /// Fetches all items for all active price lists.
  Future<List<Map<String, dynamic>>> fetchAllPriceListItems() async {
    final result = <Map<String, dynamic>>[];
    try {
      final listsRes = await _dio.get<Map<String, dynamic>>(
        '/api/v1/price_lists',
        queryParameters: {'per_page': 100},
      );
      final lists = (listsRes.data?['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      for (final pl in lists) {
        final plId    = (pl['id'] as num).toInt();
        final plName  = pl['name']?.toString() ?? '';
        final plType  = pl['list_type']?.toString() ?? 'standard';

        final itemsRes = await _dio.get<Map<String, dynamic>>(
          '/api/v1/price_lists/$plId',
          queryParameters: {'per_page': 500},
        );
        final items = (itemsRes.data?['data']?['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        for (final item in items) {
          result.add({...item, '_price_list_id': plId, '_price_list_name': plName, '_price_list_type': plType});
        }
      }
    } catch (_) {/*ignore*/}
    return result;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REPOSITORY
// ═══════════════════════════════════════════════════════════════════════════════

class ProductRepository {
  ProductRepository({required this.db, required this.api});
  final AppDatabase db;
  final ProductApi  api;

  static const _staleThresholdMinutes = 240; // 4 hours for product catalog

  Future<List<Product>> searchProducts(String query) => db.searchProducts(query);
  Future<List<Product>> getActiveProducts()           => db.getActiveProducts();
  Future<Product?>      getProductById(int id)        => db.getProductById(id);

  Future<List<PriceListItemsLocalData>> getPriceListItemsForProduct(int productId) =>
      db.getPriceListItemsForProduct(productId);

  SyncResult? _lastProductSync;
  SyncResult? get lastProductSync => _lastProductSync;

  /// Syncs products + price list items to local DB. Returns a [SyncResult].
  Future<SyncResult> syncProducts() async {
    final start = DateTime.now();
    try {
      final remotes    = await api.fetchAll();
      final companions = remotes.map(_productToCompanion).toList();
      await db.upsertProducts(companions);
      await db.upsertSyncMeta(entityType: 'products', syncedAt: start, count: companions.length);
      _lastProductSync = SyncResult(success: true, count: companions.length);
      return _lastProductSync!;
    } catch (e) {
      _lastProductSync = SyncResult(success: false, count: 0, error: e.toString());
      return _lastProductSync!;
    }
  }

  Future<SyncResult> syncPriceListItems() async {
    final start = DateTime.now();
    try {
      final remotes    = await api.fetchAllPriceListItems();
      final companions = remotes.map(_priceItemToCompanion).toList();
      await db.upsertPriceListItems(companions);
      await db.upsertSyncMeta(entityType: 'price_list_items', syncedAt: start, count: companions.length);
      return SyncResult(success: true, count: companions.length);
    } catch (e) {
      return SyncResult(success: false, count: 0, error: e.toString());
    }
  }

  Future<bool> needsSync() async {
    final meta = await db.getSyncMeta('products');
    final raw  = meta?.lastSyncedAt;
    if (raw == null) return true;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return true;
    return DateTime.now().difference(dt).inMinutes > _staleThresholdMinutes;
  }

  // ── Companions ────────────────────────────────────────────────────────────

  static ProductsCompanion _productToCompanion(Map<String, dynamic> m) {
    final cat    = m['category'] as Map<String, dynamic>?;
    final uom    = m['uom']     as Map<String, dynamic>?;
    final hsn    = m['hsn']     as Map<String, dynamic>?;
    final stocks = m['stock_by_branch'] as List?;
    final totalAvail = stocks == null ? 0 : stocks
        .cast<Map<String, dynamic>>()
        .fold<int>(0, (sum, s) => sum + _toInt(s['available']));
    return ProductsCompanion(
      id:             Value((m['id'] as num).toInt()),
      sku:            Value(m['sku']?.toString() ?? ''),
      name:           Value(m['name']?.toString() ?? ''),
      categoryName:   Value(cat?['name']?.toString()),
      unit:           Value(uom != null ? '${uom["name"] ?? ""} (${uom["symbol"] ?? ""})' : null),
      gstRate:        Value(_toDouble(m['gst_rate'])),
      defaultPrice:   Value(_toDouble(m['default_price'] ?? m['purchase_price'])),
      stockAvailable: Value(totalAvail),
      status:         Value(m['status']?.toString() ?? 'active'),
      hsnCode:        Value(hsn?['code']?.toString()),
      syncedAt:       Value(DateTime.now().toIso8601String()),
    );
  }

  static PriceListItemsLocalCompanion _priceItemToCompanion(Map<String, dynamic> m) {
    return PriceListItemsLocalCompanion(
      id:            Value((m['id'] as num).toInt()),
      productId:     Value((m['product_id'] as num).toInt()),
      priceListId:   Value((m['_price_list_id'] as num).toInt()),
      priceListName: Value(m['_price_list_name']?.toString() ?? ''),
      unitPrice:     Value(_toDouble(m['unit_price'])),
      minQty:        Value(_toInt(m['min_qty'] ?? 1)),
      discountPct:   Value(_toDouble(m['discount_pct'])),
      syncedAt:      Value(DateTime.now().toIso8601String()),
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════════

final productApiProvider = Provider<ProductApi>(
  (ref) => ProductApi(ref.watch(apiClientProvider)),
);

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(
    db:  ref.watch(appDatabaseProvider),
    api: ref.watch(productApiProvider),
  );
});

class ProductSyncNotifier extends AsyncNotifier<SyncResult?> {
  @override
  Future<SyncResult?> build() async => null;

  Future<void> sync() async {
    state = const AsyncValue.loading();
    final repo = ref.read(productRepositoryProvider);
    final r1   = await repo.syncProducts();
    final r2   = await repo.syncPriceListItems();
    state = AsyncValue.data(SyncResult(
      success: r1.success && r2.success,
      count:   r1.count + r2.count,
      error:   r1.error ?? r2.error,
    ));
  }
}

final productSyncProvider =
    AsyncNotifierProvider<ProductSyncNotifier, SyncResult?>(
  ProductSyncNotifier.new,
);
