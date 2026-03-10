import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class BeatRetailer {
  const BeatRetailer({
    required this.retailerId,
    required this.retailerName,
    required this.phone,
    required this.address,
    this.sequence,
    this.lastVisitDate,
    this.visitId,
    this.visitStatus,
  });

  final int    retailerId;
  final String retailerName;
  final String? phone;
  final String? address;
  final int?   sequence;
  final String? lastVisitDate;
  final int?   visitId;
  final String? visitStatus;  // null | 'checked_in' | 'checked_out' | 'skipped'

  factory BeatRetailer.fromJson(Map<String, dynamic> json) {
    return BeatRetailer(
      retailerId:    json['customer_id']    as int,
      retailerName:  json['customer_name']  as String,
      phone:         json['phone']          as String?,
      address:       json['address']        as String?,
      sequence:      json['sequence']       as int?,
      lastVisitDate: json['last_visit_date'] as String?,
      visitId:       json['visit_id']       as int?,
      visitStatus:   json['visit_status']   as String?,
    );
  }
}

class TodayBeat {
  const TodayBeat({
    required this.beatId,
    required this.beatName,
    required this.retailers,
    required this.totalScheduled,
    required this.checkedIn,
    required this.completed,
    required this.skipped,
  });

  final int    beatId;
  final String beatName;
  final List<BeatRetailer> retailers;
  final int totalScheduled;
  final int checkedIn;
  final int completed;
  final int skipped;

  factory TodayBeat.fromJson(Map<String, dynamic> json) {
    final retList = (json['retailers'] as List<dynamic>? ?? [])
        .map((r) => BeatRetailer.fromJson(r as Map<String, dynamic>))
        .toList();
    return TodayBeat(
      beatId:         json['beat_id']         as int? ?? 0,
      beatName:       json['beat_name']        as String? ?? 'Beat',
      retailers:      retList,
      totalScheduled: json['total_scheduled']  as int? ?? retList.length,
      checkedIn:      json['checked_in']       as int? ?? 0,
      completed:      json['completed']        as int? ?? 0,
      skipped:        json['skipped']          as int? ?? 0,
    );
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

class BeatService {
  BeatService(this._dio);
  final Dio _dio;

  Future<TodayBeat?> fetchTodayBeat() async {
    try {
      final res = await _dio.get('/api/v1/visits/today');
      final data = res.data['data'] as Map<String, dynamic>? ?? {};
      return TodayBeat.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> checkIn({
    required int customerId,
    required double latitude,
    required double longitude,
  }) async {
    final res = await _dio.post('/api/v1/visits/checkin', data: {
      'customer_id': customerId,
      'latitude':    latitude,
      'longitude':   longitude,
    });
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> checkOut({
    required int visitId,
    required double latitude,
    required double longitude,
    String outcome = 'productive',
  }) async {
    final res = await _dio.post('/api/v1/visits/$visitId/checkout', data: {
      'latitude':  latitude,
      'longitude': longitude,
      'outcome':   outcome,
    });
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<void> skipVisit({
    required int visitId,
    required String reason,
  }) async {
    await _dio.post('/api/v1/visits/$visitId/skip', data: { 'reason': reason });
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final beatServiceProvider = Provider<BeatService>((ref) {
  return BeatService(ref.watch(apiClientProvider));
});

final todayBeatProvider = FutureProvider.autoDispose<TodayBeat?>((ref) async {
  return ref.read(beatServiceProvider).fetchTodayBeat();
});
