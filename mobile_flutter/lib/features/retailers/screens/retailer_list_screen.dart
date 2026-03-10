import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/local_db/app_database.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/freshness_indicator.dart';
import '../repository/retailer_repository.dart';

// ─── Providers ─────────────────────────────────────────────────────────────────

final _searchQueryProvider = StateProvider<String>((_) => '');
final _statusFilterProvider = StateProvider<String>((_) => 'all');
final _retailerLastSyncProvider = StateProvider<DateTime?>((_) => null);

final _retailerListProvider = FutureProvider.autoDispose<List<Retailer>>((ref) {
  final repo   = ref.watch(retailerRepositoryProvider);
  final query  = ref.watch(_searchQueryProvider);
  final status = ref.watch(_statusFilterProvider);

  if (query.isNotEmpty) return repo.searchRetailers(query);
  return repo.getRetailersByStatus(status);
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class RetailerListScreen extends ConsumerStatefulWidget {
  const RetailerListScreen({super.key});

  @override
  ConsumerState<RetailerListScreen> createState() => _RetailerListScreenState();
}

class _RetailerListScreenState extends ConsumerState<RetailerListScreen> {
  final _searchCtrl = TextEditingController();
  bool _syncing = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _triggerSync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await ref.read(retailerSyncProvider.notifier).sync();
      if (mounted) {
        ref.read(_retailerLastSyncProvider.notifier).state = DateTime.now();
        ref.invalidate(_retailerListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Retailers synced'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusFilter  = ref.watch(_statusFilterProvider);
    final retailers     = ref.watch(_retailerListProvider);
    final lastSyncedAt  = ref.watch(_retailerLastSyncProvider);

    return Scaffold(
      backgroundColor: OlColors.backgroundSubtle,
      appBar: AppBar(
        backgroundColor: OlColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Retailers', style: TextStyle(color: Colors.white)),
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync),
              color: Colors.white,
              tooltip: 'Sync retailers',
              onPressed: _triggerSync,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────────────────────
          Container(
            color: OlColors.primary,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => ref.read(_searchQueryProvider.notifier).state = v,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'Search by name or code…',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(_searchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.12),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ),

          // ── Filter chips ──────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final option in _filterOptions)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label:    Text(option.$2),
                        selected: statusFilter == option.$1,
                        onSelected: (_) {
                          ref.read(_statusFilterProvider.notifier).state = option.$1;
                        },
                        selectedColor: OlColors.primary50,
                        checkmarkColor: OlColors.primary,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: statusFilter == option.$1 ? OlColors.primary : OlColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // ── Freshness indicator ───────────────────────────────────────
          if (lastSyncedAt != null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: FreshnessIndicator(
                lastSyncedAt: lastSyncedAt,
                onSyncNow: _syncing ? null : _triggerSync,
              ),
            ),

          // ── List ──────────────────────────────────────────────────────────
          Expanded(
            child: retailers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => _ErrorState(error: e.toString(), onRetry: () => ref.invalidate(_retailerListProvider)),
              data:    (list) {
                if (list.isEmpty) {
                  return _searchCtrl.text.isNotEmpty
                      ? AppEmptyState.searchEmpty(query: _searchCtrl.text)
                      : AppEmptyState.noRetailers(onSync: _triggerSync);
                }
                return RefreshIndicator(
                  onRefresh: _triggerSync,
                  child: ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (ctx, i) => _RetailerTile(retailer: list[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

const _filterOptions = [
  ('all',      'All'),
  ('active',   'Active'),
  ('blocked',  'Blocked'),
  ('overdue',  'Overdue'),
  ('inactive', 'Inactive'),
];

// ─── Retailer Tile ─────────────────────────────────────────────────────────────

class _RetailerTile extends StatelessWidget {
  const _RetailerTile({required this.retailer});
  final Retailer retailer;

  Color get _channelColor {
    switch (retailer.channel?.toLowerCase()) {
      case 'general_trade': return OlColors.primary;
      case 'modern_trade':  return OlColors.info;
      case 'horeca':        return OlColors.warning;
      default:              return OlColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final outstanding    = retailer.outstanding;
    final creditStatus   = retailer.creditStatus ?? 'ok';
    final isOverdue      = creditStatus == 'overdue';
    final isBlocked      = creditStatus == 'blocked' || retailer.status == 'blocked';

    return InkWell(
      onTap: () => context.go('/home/retailers/${retailer.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // ── Avatar ───────────────────────────────────────────────────
            CircleAvatar(
              radius: 22,
              backgroundColor: _channelColor.withOpacity(0.15),
              child: Text(
                retailer.name.isNotEmpty ? retailer.name[0].toUpperCase() : '?',
                style: TextStyle(color: _channelColor, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),

            // ── Details ──────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    retailer.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: OlColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (retailer.code != null) ...[
                        Text(retailer.code!, style: const TextStyle(fontSize: 11, color: OlColors.textSecondary, fontFamily: 'monospace')),
                        const SizedBox(width: 6),
                        Container(width: 3, height: 3, decoration: const BoxDecoration(color: OlColors.textTertiary, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                      ],
                      if (retailer.tier != null)
                        Text(retailer.tier!, style: const TextStyle(fontSize: 11, color: OlColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // ── Trailing: outstanding + credit chip ───────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Semantics(
                  label: 'Outstanding: ${outstanding.toStringAsFixed(0)} rupees${isOverdue ? ', overdue' : ''}',
                  child: Text(
                    '₹${_fmtAmount(outstanding)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isOverdue ? OlColors.error : OlColors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                _CreditChip(status: creditStatus, isBlocked: isBlocked),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtAmount(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _CreditChip extends StatelessWidget {
  const _CreditChip({required this.status, required this.isBlocked});
  final String status;
  final bool   isBlocked;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'blocked'    => ('Blocked',   OlColors.error50,   OlColors.error),
      'hold'       => ('On Hold',   OlColors.warning50, OlColors.warning),
      'overdue'    => ('Overdue',   OlColors.error50,   OlColors.error),
      'near_limit' => ('Near Limit',OlColors.warning50, OlColors.warning),
      _            => ('OK',        OlColors.success50, OlColors.success),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Error State ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: OlColors.error),
          const SizedBox(height: 12),
          Text(error, textAlign: TextAlign.center, style: const TextStyle(color: OlColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
