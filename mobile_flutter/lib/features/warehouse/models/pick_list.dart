// ─── Warehouse Feature: Models ────────────────────────────────────────────────

/// A single line on a pick list.
class PickListItem {
  final int     id;
  final int     productId;
  final String  productName;
  final String  productSku;
  final String? unit;
  final double  qtyRequested;
  double        qtyPicked;
  String        status; // 'pending' | 'picked' | 'short'
  String?       locationCode;

  PickListItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productSku,
    this.unit,
    required this.qtyRequested,
    this.qtyPicked = 0,
    this.status = 'pending',
    this.locationCode,
  });

  bool get isPending  => status == 'pending';
  bool get isPicked   => status == 'picked';
  bool get isShort    => status == 'short';

  factory PickListItem.fromJson(Map<String, dynamic> j) => PickListItem(
        id:           j['id'] as int,
        productId:    j['product_id'] as int,
        productName:  j['product_name'] as String,
        productSku:   j['product_sku'] as String,
        unit:         j['unit'] as String?,
        qtyRequested: (j['qty_requested'] as num).toDouble(),
        qtyPicked:    (j['qty_picked'] as num? ?? 0).toDouble(),
        status:       j['status'] as String? ?? 'pending',
        locationCode: j['location_code'] as String?,
      );
}

/// High-level summary of a pick list for a given sales order.
class PickList {
  final int              id;
  final int              salesOrderId;
  final String           orderNumber;
  final String           customerName;
  final String           status; // 'pending_pick' | 'picking' | 'picked' | 'pick_confirmed'
  final String?          pickedByName;
  final String?          pickedAt;
  final List<PickListItem> items;

  PickList({
    required this.id,
    required this.salesOrderId,
    required this.orderNumber,
    required this.customerName,
    required this.status,
    this.pickedByName,
    this.pickedAt,
    required this.items,
  });

  bool get allPicked  => items.every((i) => i.isPicked || i.isShort);
  int  get pendingCount => items.where((i) => i.isPending).length;
  int  get pickedCount  => items.where((i) => i.isPicked).length;

  factory PickList.fromJson(Map<String, dynamic> j) {
    final rawItems = j['pick_list_items'] as List<dynamic>? ?? [];
    return PickList(
      id:          j['id'] as int,
      salesOrderId: j['sales_order_id'] as int,
      orderNumber: j['order_number'] as String? ?? '',
      customerName: j['customer_name'] as String? ?? '',
      status:      j['pick_status'] as String? ?? 'pending_pick',
      pickedByName: j['picked_by_name'] as String?,
      pickedAt:    j['picked_at'] as String?,
      items: rawItems
          .map((e) => PickListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
