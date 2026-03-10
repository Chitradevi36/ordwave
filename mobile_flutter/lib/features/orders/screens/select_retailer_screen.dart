import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/local_db/app_database.dart';
import '../../../core/theme/colors.dart';
import '../../retailers/repository/retailer_repository.dart';
import '../providers/cart_provider.dart';

// ─── Screen ────────────────────────────────────────────────────────────────────
class SelectRetailerScreen extends ConsumerStatefulWidget {
  const SelectRetailerScreen({super.key});

  @override
  ConsumerState<SelectRetailerScreen> createState() => _SelectRetailerScreenState();
}

class _SelectRetailerScreenState extends ConsumerState<SelectRetailerScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  List<Retailer> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadRetailers('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRetailers(String query) async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(retailerRepositoryProvider);
      final list = await repo.searchRetailers(query);
      if (mounted) setState(() => _results = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String q) {
    setState(() => _query = q);
    _loadRetailers(q);
  }

  void _selectRetailer(Retailer r) {
    // Clear cart when starting a new order for a different customer
    ref.read(cartProvider.notifier).clearCart();
    context.push('/home/orders/new/products/${r.id}?name=${Uri.encodeComponent(r.name)}');
  }

  Color _creditColor(String? creditStatus) {
    if (creditStatus == null || creditStatus == 'ok') return OlColors.success;
    if (creditStatus == 'hold') return OlColors.warning;
    return OlColors.error;
  }

  String _creditLabel(String? creditStatus) {
    switch (creditStatus) {
      case 'hold':     return 'Credit Hold';
      case 'overdue':  return 'Overdue';
      case 'blocked':  return 'Blocked';
      default:         return 'Good Standing';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OlColors.backgroundSubtle,
      appBar: AppBar(
        backgroundColor: OlColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Select Retailer', style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: OlColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search retailer name or code…',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.8)),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearch('');
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

          // List
          Expanded(
            child: _loading && _results.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.store_outlined, size: 48, color: OlColors.textTertiary),
                            const SizedBox(height: 12),
                            Text(
                              _query.isEmpty ? 'No retailers synced' : 'No results for "$_query"',
                              style: const TextStyle(color: OlColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (context, i) {
                          final r = _results[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: OlColors.primary50,
                              child: Text(
                                r.name.isNotEmpty
                                    ? r.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: OlColors.primary,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              r.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: OlColors.textPrimary),
                            ),
                            subtitle: Text(
                              [
                                if (r.code != null) r.code!,
                                if (r.channel != null) r.channel!,
                              ].join(' · '),
                              style: const TextStyle(
                                  color: OlColors.textSecondary, fontSize: 12),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _creditColor(r.creditStatus)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _creditLabel(r.creditStatus),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _creditColor(r.creditStatus),
                                    ),
                                  ),
                                ),
                                if (r.outstanding > 0) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${r.outstanding.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: OlColors.textSecondary),
                                  ),
                                ],
                              ],
                            ),
                            onTap: () => _selectRetailer(r),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
