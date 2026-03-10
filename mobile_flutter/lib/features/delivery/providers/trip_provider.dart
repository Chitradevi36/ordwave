import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../models/trip.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Trip List Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches trips from the server.  filter: 'today'|'all'|'dispatched'
final tripListProvider = FutureProvider.family<List<DeliveryTrip>, String>((ref, filter) async {
  final dio = ref.watch(apiClientProvider);
  final params = <String, dynamic>{};
  if (filter == 'today') {
    final now = DateTime.now();
    params['scheduled_date'] =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  } else if (filter == 'dispatched') {
    params['status'] = 'dispatched';
  }
  final res = await dio.get('/api/v1/delivery_trips', queryParameters: params);
  final list = (res.data['data'] as List? ?? []);
  final trips = list.map((e) => DeliveryTrip.fromJson(e as Map<String, dynamic>)).toList();

  // Pre-cache all trip details into SharedPreferences for offline access
  final prefs = await SharedPreferences.getInstance();
  for (final trip in trips) {
    try {
      final detailRes = await dio.get('/api/v1/delivery_trips/${trip.id}');
      final rawJson = jsonEncode(detailRes.data['data']);
      await prefs.setString('trip_cache_${trip.id}', rawJson);
    } catch (_) {
      // Best-effort — skip if individual detail fetch fails
    }
  }

  return trips;
});

// ─────────────────────────────────────────────────────────────────────────────
// Trip Detail Provider — server first, SharedPreferences fallback
// ─────────────────────────────────────────────────────────────────────────────

final tripDetailProvider = FutureProvider.family<DeliveryTrip, int>((ref, tripId) async {
  final dio = ref.watch(apiClientProvider);
  try {
    final res   = await dio.get('/api/v1/delivery_trips/$tripId');
    final trip  = DeliveryTrip.fromJson(res.data['data'] as Map<String, dynamic>);

    // Cache for offline use
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('trip_cache_$tripId', jsonEncode(res.data['data']));

    return trip;
  } on DioException {
    // Network error — attempt cached data
    final prefs   = await SharedPreferences.getInstance();
    final cached  = prefs.getString('trip_cache_$tripId');
    if (cached != null) {
      return DeliveryTrip.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    }
    rethrow;
  }
});

final tripSummaryProvider = FutureProvider.family<TripSummary, int>((ref, tripId) async {
  final dio = ref.watch(apiClientProvider);
  final res = await dio.get('/api/v1/delivery_trips/$tripId/summary');
  return TripSummary.fromJson(res.data as Map<String, dynamic>);
});

// ─────────────────────────────────────────────────────────────────────────────
// Stop Complete Notifier
// ─────────────────────────────────────────────────────────────────────────────

class CompleteStopState {
  const CompleteStopState({this.loading = false, this.error});
  final bool    loading;
  final String? error;
}

class CompleteStopNotifier extends StateNotifier<CompleteStopState> {
  CompleteStopNotifier(this._dio) : super(const CompleteStopState());

  final Dio _dio;

  Future<bool> completeStop({
    required int    tripId,
    required int    stopId,
    required String outcome,
    required List<Map<String, dynamic>> deliveredLines,
    List<Map<String, dynamic>>          rejections   = const [],
    Map<String, dynamic>?               proof,
    String?                             completedAt,
  }) async {
    state = const CompleteStopState(loading: true);
    try {
      await _dio.post(
        '/api/v1/delivery_trips/$tripId/stops/$stopId/complete',
        data: {
          'outcome':        outcome,
          'delivered_lines': deliveredLines,
          if (rejections.isNotEmpty) 'rejections': rejections,
          if (proof != null)        'proof':       proof,
          if (completedAt != null)  'completed_at': completedAt,
        },
      );
      state = const CompleteStopState();
      return true;
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?['error'] as String? ?? e.message ?? 'Unknown error';
      state = CompleteStopState(error: msg);
      return false;
    }
  }

  void clearError() => state = const CompleteStopState();
}

final completeStopProvider =
    StateNotifierProvider.autoDispose<CompleteStopNotifier, CompleteStopState>((ref) {
  return CompleteStopNotifier(ref.watch(apiClientProvider));
});

// ─────────────────────────────────────────────────────────────────────────────
// Cash Collection Notifier
// ─────────────────────────────────────────────────────────────────────────────

class RecordCashState {
  const RecordCashState({this.loading = false, this.error, this.success = false});
  final bool    loading;
  final String? error;
  final bool    success;
}

class RecordCashNotifier extends StateNotifier<RecordCashState> {
  RecordCashNotifier(this._dio) : super(const RecordCashState());
  final Dio _dio;

  Future<bool> recordCash({
    required int    tripId,
    required int    stopId,
    required double amount,
    required String paymentMode,   // 'cash'|'upi'|'cheque'
    String?         reference,
    String?         notes,
  }) async {
    state = const RecordCashState(loading: true);
    try {
      await _dio.post(
        '/api/v1/delivery_trips/$tripId/stops/$stopId/payments',
        data: {
          'amount':       amount,
          'payment_mode': paymentMode,
          if (reference != null) 'reference': reference,
          if (notes     != null) 'notes':     notes,
        },
      );
      state = const RecordCashState(success: true);
      return true;
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?['error'] as String? ?? 'Error recording payment';
      state = RecordCashState(error: msg);
      return false;
    }
  }

  void reset() => state = const RecordCashState();
}

final recordCashProvider =
    StateNotifierProvider.autoDispose<RecordCashNotifier, RecordCashState>((ref) {
  return RecordCashNotifier(ref.watch(apiClientProvider));
});

// ─────────────────────────────────────────────────────────────────────────────
// Pending line quantities state (per-stop editing)
// ─────────────────────────────────────────────────────────────────────────────

/// Maps productId → {delivered, rejected} quantities for the active stop.
final stopLineEditorProvider =
    StateProvider.autoDispose<Map<int, ({double delivered, double rejected})>>((ref) => {});
