import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/local_db/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';

// ── Quick-collect submit state ─────────────────────────────────────────────────

class QuickCollectState {
  final bool loading;
  final bool success;
  final String? error;
  final int? localId;        // Drift localId after queueing
  final int? serverId;       // server payment id if online submit succeeded

  const QuickCollectState({
    this.loading = false,
    this.success = false,
    this.error,
    this.localId,
    this.serverId,
  });

  QuickCollectState copyWith({
    bool? loading,
    bool? success,
    String? error,
    int? localId,
    int? serverId,
  }) =>
      QuickCollectState(
        loading:  loading  ?? this.loading,
        success:  success  ?? this.success,
        error:    error,
        localId:  localId  ?? this.localId,
        serverId: serverId ?? this.serverId,
      );
}

class QuickCollectNotifier extends StateNotifier<QuickCollectState> {
  QuickCollectNotifier(this._dio, this._db, this._storage)
      : super(const QuickCollectState());

  final Dio                  _dio;
  final AppDatabase          _db;
  final SecureStorageService _storage;

  void reset() => state = const QuickCollectState();

  /// Submit a quick collection. Queues offline if network fails.
  Future<void> submit({
    required int    customerId,
    required String customerName,
    required double amount,
    required String paymentMode,
    String? reference,
    String? notes,
    required String receivedDate,
    int? collectionScheduleId,
  }) async {
    state = const QuickCollectState(loading: true);

    final branchId = int.tryParse(await _storage.getBranchId() ?? '0') ?? 0;
    final idempotencyKey = const Uuid().v4();

    // 1. Always queue locally first
    final companion = PendingPaymentsCompanion(
      customerId:           Value(customerId),
      customerName:         Value(customerName),
      branchId:             Value(branchId),
      amount:               Value(amount),
      paymentMode:          Value(paymentMode),
      reference:            Value(reference),
      notes:                Value(notes),
      receivedDate:         Value(receivedDate),
      collectionScheduleId: Value(collectionScheduleId),
      createdAt:            Value(DateTime.now().toIso8601String()),
      idempotencyKey:       Value(idempotencyKey),
    );
    final localId = await _db.queuePayment(companion);

    // 2. Try online submit
    try {
      final body = <String, dynamic>{
        'payment': {
          'customer_id':    customerId,
          'amount':         amount,
          'payment_mode':   paymentMode,
          'received_date':  receivedDate,
          'idempotency_key': idempotencyKey,
          if (reference != null && reference.isNotEmpty) 'reference_number': reference,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          if (collectionScheduleId != null) 'collection_schedule_id': collectionScheduleId,
        },
      };

      final resp = await _dio.post('/api/v1/payments', data: body);
      final serverId = (resp.data as Map<String, dynamic>?)?['data']?['id'] as int?;
      final payNum   = (resp.data as Map<String, dynamic>?)?['data']?['payment_number'] as String?;

      if (serverId != null) {
        await _db.markPaymentSynced(localId,
            serverId: serverId,
            serverPaymentNumber: payNum ?? '');

        // If from schedule, mark schedule complete
        if (collectionScheduleId != null) {
          try {
            await _dio.post('/api/v1/collection_schedules/$collectionScheduleId/complete',
                data: {'payment_id': serverId});
          } catch (_) {}
        }
      }

      state = QuickCollectState(success: true, localId: localId, serverId: serverId);
    } on DioException catch (e) {
      // Online failed — keep in queue, show offline success
      await _db.markPaymentFailed(localId, e.message ?? 'Network error');
      state = QuickCollectState(
        success:  true,   // "success" from UX perspective — queued
        localId:  localId,
        error:    'Saved offline. Will sync when connected.',
      );
    } catch (e) {
      await _db.markPaymentFailed(localId, e.toString());
      state = QuickCollectState(
        success: true,
        localId: localId,
        error:   'Saved offline. Will sync when connected.',
      );
    }
  }
}

final quickCollectProvider =
    StateNotifierProvider.autoDispose<QuickCollectNotifier, QuickCollectState>((ref) {
  return QuickCollectNotifier(
    ref.watch(apiClientProvider),
    ref.watch(appDatabaseProvider),
    ref.watch(secureStorageProvider),
  );
});

// ── Collection schedules state ─────────────────────────────────────────────────

class CollectionSchedule {
  final int    id;
  final String scheduledDate;
  final double amountExpected;
  final String status;
  final String? notes;
  final String? customerName;
  final int?   customerId;
  final String? assignedToName;

  const CollectionSchedule({
    required this.id,
    required this.scheduledDate,
    required this.amountExpected,
    required this.status,
    this.notes,
    this.customerName,
    this.customerId,
    this.assignedToName,
  });

  factory CollectionSchedule.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final assignedTo = json['assigned_to'] as Map<String, dynamic>?;
    return CollectionSchedule(
      id:             (json['id'] as num).toInt(),
      scheduledDate:  json['scheduled_date']?.toString() ?? '',
      amountExpected: (json['amount_expected'] as num?)?.toDouble() ?? 0,
      status:         json['status']?.toString() ?? 'planned',
      notes:          json['notes']?.toString(),
      customerName:   customer?['name']?.toString(),
      customerId:     (customer?['id'] as num?)?.toInt(),
      assignedToName: assignedTo?['name']?.toString(),
    );
  }

  bool get isOverdue {
    final today = DateTime.now();
    final date  = DateTime.tryParse(scheduledDate);
    if (date == null) return false;
    return date.isBefore(DateTime(today.year, today.month, today.day)) && status == 'planned';
  }
}

class CollectionSchedulesState {
  final bool loading;
  final List<CollectionSchedule> schedules;
  final String? error;

  const CollectionSchedulesState({
    this.loading = false,
    this.schedules = const [],
    this.error,
  });
}

class CollectionSchedulesNotifier extends StateNotifier<CollectionSchedulesState> {
  CollectionSchedulesNotifier(this._dio) : super(const CollectionSchedulesState());

  final Dio _dio;

  Future<void> fetch({String? dateFrom, String? dateTo, String? date, String? status}) async {
    state = const CollectionSchedulesState(loading: true);
    try {
      final qp = <String, dynamic>{};
      if (date != null)     qp['date']      = date;
      if (dateFrom != null) qp['date_from'] = dateFrom;
      if (dateTo != null)   qp['date_to']   = dateTo;
      if (status != null)   qp['status']    = status;

      final resp = await _dio.get('/api/v1/collection_schedules',
          queryParameters: qp);
      final list = ((resp.data as Map<String, dynamic>?)?['data'] as List<dynamic>? ?? [])
          .map((e) => CollectionSchedule.fromJson(e as Map<String, dynamic>))
          .toList();
      state = CollectionSchedulesState(schedules: list);
    } on DioException catch (e) {
      state = CollectionSchedulesState(error: e.message ?? 'Error loading schedules');
    }
  }

  Future<bool> skip(int scheduleId, String reason) async {
    try {
      await _dio.post('/api/v1/collection_schedules/$scheduleId/skip',
          data: {'reason': reason});
      return true;
    } catch (_) {
      return false;
    }
  }
}

final collectionSchedulesProvider = StateNotifierProvider.autoDispose<
    CollectionSchedulesNotifier, CollectionSchedulesState>((ref) {
  return CollectionSchedulesNotifier(ref.watch(apiClientProvider));
});

// ── Recent payments state ──────────────────────────────────────────────────────

class RecentPayment {
  final int    id;
  final String paymentNumber;
  final String customerName;
  final double amount;
  final String paymentMode;
  final String receivedDate;
  final String status;

  const RecentPayment({
    required this.id,
    required this.paymentNumber,
    required this.customerName,
    required this.amount,
    required this.paymentMode,
    required this.receivedDate,
    required this.status,
  });

  factory RecentPayment.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    return RecentPayment(
      id:            (json['id'] as num).toInt(),
      paymentNumber: json['payment_number']?.toString() ?? '',
      customerName:  customer?['name']?.toString() ?? 'Unknown',
      amount:        (json['amount'] as num?)?.toDouble() ?? 0,
      paymentMode:   json['payment_mode']?.toString() ?? 'cash',
      receivedDate:  json['received_date']?.toString() ?? '',
      status:        json['status']?.toString() ?? 'confirmed',
    );
  }
}

class RecentPaymentsState {
  final bool loading;
  final List<RecentPayment> serverPayments;
  final List<PendingPayment> localPayments;
  final String? error;

  const RecentPaymentsState({
    this.loading = false,
    this.serverPayments = const [],
    this.localPayments  = const [],
    this.error,
  });
}

class RecentPaymentsNotifier extends StateNotifier<RecentPaymentsState> {
  RecentPaymentsNotifier(this._dio, this._db) : super(const RecentPaymentsState());

  final Dio         _dio;
  final AppDatabase _db;

  Future<void> fetch() async {
    state = const RecentPaymentsState(loading: true);
    // Always fetch local queue
    final local = await _db.getAllPayments(limit: 50);

    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final resp = await _dio.get('/api/v1/payments', queryParameters: {
        'date_from': sevenDaysAgo.toIso8601String().substring(0, 10),
      });
      final list = ((resp.data as Map<String, dynamic>?)?['data'] as List<dynamic>? ?? [])
          .map((e) => RecentPayment.fromJson(e as Map<String, dynamic>))
          .toList();
      state = RecentPaymentsState(serverPayments: list, localPayments: local);
    } on DioException {
      state = RecentPaymentsState(localPayments: local, error: 'Offline — showing local data');
    }
  }

  /// Retry syncing all pending/failed payments.
  Future<void> syncPending() async {
    final pending = await _db.getPendingPayments();
    for (final p in pending) {
      await _db.markPaymentSyncing(p.localId);
      try {
        final body = {
          'payment': {
            'customer_id':   p.customerId,
            'amount':        p.amount,
            'payment_mode':  p.paymentMode,
            'received_date': p.receivedDate,
            if (p.reference != null) 'reference_number': p.reference,
            if (p.notes != null)     'notes': p.notes,
          },
        };
        final resp = await _dio.post('/api/v1/payments', data: body);
        final serverId = (resp.data as Map<String, dynamic>?)?['data']?['id'] as int?;
        final payNum   = (resp.data as Map<String, dynamic>?)?['data']?['payment_number'] as String?;
        if (serverId != null) {
          await _db.markPaymentSynced(p.localId,
              serverId: serverId,
              serverPaymentNumber: payNum ?? '');
        }
      } catch (e) {
        await _db.markPaymentFailed(p.localId, e.toString());
      }
    }
    await fetch();
  }
}

final recentPaymentsProvider =
    StateNotifierProvider.autoDispose<RecentPaymentsNotifier, RecentPaymentsState>((ref) {
  return RecentPaymentsNotifier(
    ref.watch(apiClientProvider),
    ref.watch(appDatabaseProvider),
  );
});

// ── Today's schedule count (for home screen badge) ────────────────────────────
final todayScheduleCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final dio = ref.watch(apiClientProvider);
  try {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final resp  = await dio.get('/api/v1/collection_schedules',
        queryParameters: {'date': today, 'status': 'planned'});
    final list  = ((resp.data as Map<String, dynamic>?)?['data'] as List<dynamic>?) ?? [];
    return list.length;
  } catch (_) {
    return 0;
  }
});
