import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/pick_list.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pick List List Provider — all orders pending_pick or in picking
// ─────────────────────────────────────────────────────────────────────────────

final pickListsProvider = FutureProvider<List<PickList>>((ref) async {
  final dio = ref.watch(apiClientProvider);
  final res = await dio.get(
    '/api/v1/sales_orders',
    queryParameters: {
      'pick_status': 'pending_pick,picking',
      'per_page':    50,
    },
  );
  final list = (res.data['data'] as List? ?? []);
  return list
      .map((e) => PickList.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ─────────────────────────────────────────────────────────────────────────────
// Single Pick List Detail Provider — includes pick_list_items
// ─────────────────────────────────────────────────────────────────────────────

final pickListDetailProvider =
    FutureProvider.family<PickList, int>((ref, orderId) async {
  final dio = ref.watch(apiClientProvider);
  final res = await dio.get('/api/v1/sales_orders/$orderId/pick_list');
  return PickList.fromJson(res.data['data'] as Map<String, dynamic>);
});

// ─────────────────────────────────────────────────────────────────────────────
// Pick Notifier — submits picked quantities
// ─────────────────────────────────────────────────────────────────────────────

class PickState {
  const PickState({this.loading = false, this.error, this.success = false});
  final bool    loading;
  final String? error;
  final bool    success;

  PickState copyWith({bool? loading, String? error, bool? success}) => PickState(
        loading: loading ?? this.loading,
        error:   error,
        success: success ?? this.success,
      );
}

class PickNotifier extends StateNotifier<PickState> {
  PickNotifier(this._dio) : super(const PickState());

  final Dio _dio;

  /// Record pick: submit all item quantities and mark order as picked.
  Future<bool> submitPick({
    required int salesOrderId,
    required List<PickListItem> items,
  }) async {
    state = state.copyWith(loading: true, error: null, success: false);
    try {
      final payload = {
        'pick_list_items': items
            .map((i) => {
                  'id':         i.id,
                  'qty_picked': i.qtyPicked,
                })
            .toList(),
      };
      await _dio.post(
        '/api/v1/sales_orders/$salesOrderId/pick',
        data: payload,
      );
      state = state.copyWith(loading: false, success: true);
      return true;
    } on DioException catch (e) {
      final msg = _extractError(e);
      state = state.copyWith(loading: false, error: msg);
      return false;
    }
  }

  /// Confirm pick (manager/owner action) — marks items ready for dispatch.
  Future<bool> confirmPick({required int salesOrderId}) async {
    state = state.copyWith(loading: true, error: null, success: false);
    try {
      await _dio.post('/api/v1/sales_orders/$salesOrderId/confirm_pick');
      state = state.copyWith(loading: false, success: true);
      return true;
    } on DioException catch (e) {
      final msg = _extractError(e);
      state = state.copyWith(loading: false, error: msg);
      return false;
    }
  }

  String _extractError(DioException e) {
    try {
      final data   = e.response?.data;
      final errors = data is Map ? (data['errors'] as List?)?.join(', ') : null;
      return errors ?? e.message ?? 'Unknown error';
    } catch (_) {
      return e.message ?? 'Unknown error';
    }
  }
}

final pickNotifierProvider =
    StateNotifierProvider.autoDispose<PickNotifier, PickState>((ref) {
  final dio = ref.watch(apiClientProvider);
  return PickNotifier(dio);
});
