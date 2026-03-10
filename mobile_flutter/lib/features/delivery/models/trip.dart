// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'trip.freezed.dart';
part 'trip.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Delivery Trip (from server)
// ─────────────────────────────────────────────────────────────────────────────

@freezed
class DeliveryTrip with _$DeliveryTrip {
  const factory DeliveryTrip({
    required int    id,
    required String tripNumber,
    required String status,           // planned|dispatched|completed|cancelled
    String?         driverName,
    String?         vehicleNumber,
    int?            branchId,
    String?         branchName,
    String?         scheduledDate,
    String?         startedAt,
    String?         completedAt,
    @Default([]) List<TripStopItem> stops,
  }) = _DeliveryTrip;

  factory DeliveryTrip.fromJson(Map<String, dynamic> json) =>
      _$DeliveryTripFromJson(json);
}

// ─────────────────────────────────────────────────────────────────────────────
// Trip Stop (from server / local)
// ─────────────────────────────────────────────────────────────────────────────

@freezed
class TripStopItem with _$TripStopItem {
  const factory TripStopItem({
    required int    id,
    required int    sequence,
    required String status,           // pending|delivered|partial_delivery|failed|skipped
    required int    salesOrderId,
    required String customerName,
    String?         address,
    String?         phone,
    String?         exceptionCode,
    String?         completedAt,
    @Default([]) List<StopLine> lines,
  }) = _TripStopItem;

  factory TripStopItem.fromJson(Map<String, dynamic> json) =>
      _$TripStopItemFromJson(json);
}

// ─────────────────────────────────────────────────────────────────────────────
// Order line within a stop
// ─────────────────────────────────────────────────────────────────────────────

@freezed
class StopLine with _$StopLine {
  const factory StopLine({
    required int    id,
    required int    productId,
    required String productName,
    String?         sku,
    required double qtyOrdered,
    double?         qtyDelivered,
    double?         qtyRejected,
    required double unitPrice,
  }) = _StopLine;

  factory StopLine.fromJson(Map<String, dynamic> json) =>
      _$StopLineFromJson(json);
}

// ─────────────────────────────────────────────────────────────────────────────
// Trip Summary (from /summary endpoint)
// ─────────────────────────────────────────────────────────────────────────────

@freezed
class TripSummary with _$TripSummary {
  const factory TripSummary({
    required int    totalStops,
    required int    delivered,
    required int    partial,
    required int    failed,
    required int    skipped,
    required double totalOrderValue,
    required double deliveredValue,
    required double returnsValue,
    required double cashCollected,
    @Default([]) List<TripException> exceptions,
  }) = _TripSummary;

  factory TripSummary.fromJson(Map<String, dynamic> json) =>
      _$TripSummaryFromJson(json);
}

@freezed
class TripException with _$TripException {
  const factory TripException({
    required int    stopId,
    required String customerName,
    required String exceptionCode,
  }) = _TripException;

  factory TripException.fromJson(Map<String, dynamic> json) =>
      _$TripExceptionFromJson(json);
}

// ─────────────────────────────────────────────────────────────────────────────
// Rejection item (for partial delivery / returns flow)
// ─────────────────────────────────────────────────────────────────────────────

class RejectionItem {
  RejectionItem({
    required this.productId,
    required this.productName,
    required this.qtyRejected,
    this.reasonCode,
    this.condition,
    this.photoPath,
  });

  final int    productId;
  final String productName;
  double       qtyRejected;
  String?      reasonCode;         // 'damaged'|'refused'|'expired'
  String?      condition;
  String?      photoPath;
}

// ─────────────────────────────────────────────────────────────────────────────
// POD (Proof of Delivery) payload
// ─────────────────────────────────────────────────────────────────────────────

class PodPayload {
  PodPayload({required this.type, required this.data});
  final String type;   // 'photo'|'signature'|'otp'|'override'
  final String data;   // base64 image, SVG string, otp code, or reason text
}
