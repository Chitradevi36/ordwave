import 'dart:convert';

// ─── Cart Line ─────────────────────────────────────────────────────────────────
class CartLine {
  final int    productId;
  final String productName;
  final String productSku;
  final String unit;
  final double unitPrice;
  int qty;

  CartLine({
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.unit,
    required this.unitPrice,
    required this.qty,
  });

  double get lineTotal => qty * unitPrice;

  CartLine copyWith({int? qty}) => CartLine(
        productId:   productId,
        productName: productName,
        productSku:  productSku,
        unit:        unit,
        unitPrice:   unitPrice,
        qty:         qty ?? this.qty,
      );

  Map<String, dynamic> toJson() => {
        'product_id':   productId,
        'product_name': productName,
        'product_sku':  productSku,
        'unit':         unit,
        'unit_price':   unitPrice,
        'qty':          qty,
      };

  factory CartLine.fromJson(Map<String, dynamic> j) => CartLine(
        productId:   j['product_id'] as int,
        productName: j['product_name'] as String,
        productSku:  j['product_sku'] as String,
        unit:        j['unit'] as String? ?? 'unit',
        unitPrice:   (j['unit_price'] as num).toDouble(),
        qty:         j['qty'] as int,
      );
}

// ─── Cart ──────────────────────────────────────────────────────────────────────
class Cart {
  final List<CartLine> lines;

  const Cart({required this.lines});
  const Cart.empty() : lines = const [];

  bool get isEmpty  => lines.isEmpty;
  int  get itemCount => lines.fold(0, (s, l) => s + l.qty);
  double get subtotal => lines.fold(0.0, (s, l) => s + l.lineTotal);

  String toJson() => jsonEncode(lines.map((l) => l.toJson()).toList());

  static Cart fromJson(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return Cart(
      lines: list
          .map((e) => CartLine.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ─── Credit Check Result ───────────────────────────────────────────────────────
class CreditCheckResult {
  final String decision;  // 'ok' | 'hold' | 'blocked'
  final List<String> reasons;
  final Map<String, dynamic>? metrics;
  final int? orderId;
  final String? orderNumber;

  const CreditCheckResult({
    required this.decision,
    this.reasons = const [],
    this.metrics,
    this.orderId,
    this.orderNumber,
  });

  factory CreditCheckResult.fromJson(Map<String, dynamic> j) {
    final credit  = (j['credit'] as Map<String, dynamic>?) ?? {};
    final data    = (j['data']   as Map<String, dynamic>?) ?? {};
    return CreditCheckResult(
      decision:    credit['decision'] as String? ?? 'ok',
      reasons:     (credit['reasons'] as List<dynamic>?)
                       ?.map((e) => e.toString())
                       .toList() ??
                   [],
      metrics:     credit['metrics'] as Map<String, dynamic>?,
      orderId:     data['id'] as int?,
      orderNumber: data['order_number'] as String?,
    );
  }
}
