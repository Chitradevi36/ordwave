import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/local_db/app_database.dart';
import '../../../core/theme/colors.dart';
import '../models/cart.dart';
import '../providers/cart_provider.dart';

// ─── Screen ────────────────────────────────────────────────────────────────────
class ProductPickerScreen extends ConsumerStatefulWidget {
  const ProductPickerScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  final int    customerId;
  final String customerName;

  @override
  ConsumerState<ProductPickerScreen> createState() =>
      _ProductPickerScreenState();
}

class _ProductPickerScreenState extends ConsumerState<ProductPickerScreen> {
  final _searchCtrl = TextEditingController();
  String _query     = '';
  String _category  = '';
  List<Product> _allProducts = [];
  final Set<String> _categories = {};
  bool _loading = false;

  // Qty overrides per productId
  final Map<int, int> _qty = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    try {
      final db = ref.read(appDatabaseProvider);
      final list = await db.getActiveProducts();
      final cats = <String>{};
      for (final p in list) {
        if (p.categoryName != null) cats.add(p.categoryName!);
      }
      if (mounted) {
        setState(() {
          _allProducts = list;
          _categories ..clear() ..addAll(cats);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Product> get _filtered {
    var list = _allProducts;
    if (_category.isNotEmpty) {
      list = list.where((p) => p.categoryName == _category).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.sku.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  int _getQty(int productId) => _qty[productId] ?? 0;

  void _setQty(int productId, int qty) {
    setState(() {
      if (qty <= 0) {
        _qty.remove(productId);
      } else {
        _qty[productId] = qty;
      }
    });
  }

  int get _cartItemCount => _qty.values.fold(0, (s, q) => s + q);

  void _reviewCart() {
    if (_qty.isEmpty) return;

    final cart     = ref.read(cartProvider);
    final notifier = ref.read(cartProvider.notifier);

    // Add all non-zero qty items to cart
    for (final p in _allProducts) {
      final qty = _qty[p.id];
      if (qty == null || qty <= 0) continue;

      // Use defaultPrice as the fallback unit price
      notifier.addLine(CartLine(
        productId:   p.id,
        productName: p.name,
        productSku:  p.sku,
        unit:        p.unit ?? 'unit',
        unitPrice:   p.defaultPrice,
        qty:         qty,
      ));
    }

    context.push(
      '/home/orders/new/cart',
      extra: {
        'customerId':   widget.customerId,
        'customerName': widget.customerName,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: OlColors.backgroundSubtle,
      appBar: AppBar(
        backgroundColor: OlColors.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Products', style: TextStyle(color: Colors.white, fontSize: 16)),
            Text(
              widget.customerName,
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search row
          Container(
            color: OlColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search product name or SKU…',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.8)),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Category chips
          if (_categories.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _CategoryChip(
                    label: 'All',
                    selected: _category.isEmpty,
                    onTap: () => setState(() => _category = ''),
                  ),
                  ..._categories.map((cat) => _CategoryChip(
                        label: cat,
                        selected: _category == cat,
                        onTap: () =>
                            setState(() => _category = _category == cat ? '' : cat),
                      )),
                ],
              ),
            ),

          // Product list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(
                        child: Text('No products match',
                            style: TextStyle(color: OlColors.textSecondary)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, i) {
                          final p   = filtered[i];
                          final qty = _getQty(p.id);

                          return Container(
                            decoration: BoxDecoration(
                              color: qty > 0
                                  ? OlColors.primary50
                                  : OlColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: qty > 0
                                    ? OlColors.primary200
                                    : OlColors.border,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                // Product info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: OlColors.textPrimary,
                                            fontSize: 13),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${p.sku}  ·  ${p.unit ?? 'unit'}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: OlColors.textSecondary),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₹${p.defaultPrice.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: OlColors.primary,
                                            fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),

                                // Qty stepper (48dp tap targets)
                                _QtyStepper(
                                  qty: qty,
                                  onDecrement: () => _setQty(p.id, qty - 1),
                                  onIncrement: () => _setQty(p.id, qty + 1),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),

      // Bottom bar — review cart
      bottomNavigationBar: _cartItemCount > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OlColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _reviewCart,
                  child: Text(
                    'Review Cart ($_cartItemCount item${_cartItemCount > 1 ? 's' : ''})',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

// ─── Category Chip ─────────────────────────────────────────────────────────────
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String   label;
  final bool     selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? OlColors.primary : OlColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? OlColors.primary : OlColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : OlColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Qty Stepper ───────────────────────────────────────────────────────────────
class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.qty,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int      qty;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (qty > 0) ...[
          SizedBox(
            height: 40,
            width: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 20,
              icon: const Icon(Icons.remove_circle_outline),
              color: OlColors.primary,
              onPressed: onDecrement,
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: OlColors.textPrimary),
            ),
          ),
        ],
        SizedBox(
          height: 40,
          width: 40,
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 20,
            icon: const Icon(Icons.add_circle_outline),
            color: OlColors.primary,
            onPressed: onIncrement,
          ),
        ),
      ],
    );
  }
}
