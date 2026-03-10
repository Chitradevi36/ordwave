import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/cart.dart';

// ─── Local Order Number Generator ─────────────────────────────────────────────
String _generateLocalOrderNumber(int localId) {
  final now = DateTime.now();
  final yyyymmdd =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  return 'L-$yyyymmdd-${localId.toString().padLeft(4, '0')}';
}

// ─── Cart Notifier ─────────────────────────────────────────────────────────────
class CartNotifier extends StateNotifier<Cart> {
  CartNotifier(this._db, this._dio, this._storage) : super(const Cart.empty());

  final AppDatabase _db;
  final Dio          _dio;
  final SecureStorageService _storage;

  // ── Cart mutations ────────────────────────────────────────────────────────

  void addLine(CartLine line) {
    final existing = state.lines.indexWhere((l) => l.productId == line.productId);
    if (existing >= 0) {
      final updated = [...state.lines];
      updated[existing] = updated[existing].copyWith(
        qty: updated[existing].qty + line.qty,
      );
      state = Cart(lines: updated);
    } else {
      state = Cart(lines: [...state.lines, line]);
    }
  }

  void updateQty(int productId, int qty) {
    if (qty <= 0) {
      removeFromCart(productId);
      return;
    }
    final updated = state.lines.map((l) {
      if (l.productId == productId) return l.copyWith(qty: qty);
      return l;
    }).toList();
    state = Cart(lines: updated);
  }

  void removeFromCart(int productId) {
    state = Cart(lines: state.lines.where((l) => l.productId != productId).toList());
  }

  void clearCart() => state = const Cart.empty();

  // ── Submit ────────────────────────────────────────────────────────────────

  /// Submits the current cart for the given customer and branch.
  /// If online → calls `POST /api/v1/sales_orders/from_mobile`.
  /// If offline → saves to [PendingOrders] and returns a local placeholder result.
  Future<CreditCheckResult> submitOrder({
    required int customerId,
    required String customerName,
    required int branchId,
  }) async {
    final lines = state.lines;
    if (lines.isEmpty) throw StateError('Cart is empty');

    final linesJson = jsonEncode(lines.map((l) => l.toJson()).toList());

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/sales_orders/from_mobile',
        data: {
          'order': {
            'customer_id':  customerId,
            'branch_id':    branchId,
            'status':       'submitted',
            'lines': lines.map((l) => {
              'product_id': l.productId,
              'qty':        l.qty,
              'unit_price': l.unitPrice,
            }).toList(),
          },
        },
      );

      // Server accepted — clear cart
      clearCart();
      return CreditCheckResult.fromJson(response.data!);
    } on DioException catch (e) {
      // Offline or server error — save locally
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.response == null) {
        // Save to Drift pending orders table
        final localId = await _db.insertPendingOrder(
          PendingOrdersCompanion(
            customerId:       Value(customerId),
            customerName:     Value(customerName),
            branchId:         Value(branchId),
            linesJson:        Value(linesJson),
            localOrderNumber: Value(_generateLocalOrderNumber(0)), // temp
            createdAt:        Value(DateTime.now().toIso8601String()),
          ),
        );

        // Update localOrderNumber with real localId
        final localNum = _generateLocalOrderNumber(localId);
        await (_db.update(_db.pendingOrders)
              ..where((o) => o.localId.equals(localId)))
            .write(PendingOrdersCompanion(
          localOrderNumber: Value(localNum),
        ));

        clearCart();

        return CreditCheckResult(
          decision:    'offline',
          reasons:     ['Order saved offline. Will sync when connectivity is restored.'],
          orderNumber: localNum,
        );
      }
      rethrow;
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────
final cartProvider = StateNotifierProvider<CartNotifier, Cart>((ref) {
  final db      = ref.watch(appDatabaseProvider);
  final dio     = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return CartNotifier(db, dio, storage);
});
